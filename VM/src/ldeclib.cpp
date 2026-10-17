// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
#include "lualib.h"

#include "lcommon.h"
#include "lnumutils.h"
#include "lobject.h"

#include <climits>
#include <cmath>
#include <stdlib.h>
#include <string.h>

// Decimal values are stored as `mantissa * 10^exponent` with an int64 mantissa and an int32 exponent.
// Values are always normalized: the mantissa has no trailing zeros and zero has exponent 0, so two decimals are equal iff both fields are equal.
// Arithmetic is computed exactly in 128 bits and then rounded (half-even) to the 63 bits that fit in the mantissa.

#if !defined(__SIZEOF_INT128__)
#error "decimal library currently requires __int128"
#endif

typedef __int128 wide;

static const int kMaxExp = 100;
static const int kMinExp = -100;

static wide pow10w(int n)
{
    LUAU_ASSERT(n >= 0 && n <= 38);
    wide r = 1;
    while (n-- > 0)
        r *= 10;
    return r;
}

static int ndigits(wide a)
{
    int n = 0;
    while (a > 0)
    {
        a /= 10;
        n++;
    }
    return n;
}

// divides a (non-negative) by 10^drop, rounding half-even
static wide dropdigits(wide a, int drop)
{
    if (drop <= 0)
        return a;
    if (drop > 38)
        return 0;

    wide div = pow10w(drop);
    wide q = a / div;
    wide twice = (a % div) * 2;
    if (twice > div || (twice == div && (q & 1)))
        q++;
    return q;
}

// reduces m * 10^e to a normalized (om, oe) pair, returns false if the exponent is out of range
static bool reducewide(wide m, int e, int64_t& om, int& oe)
{
    bool neg = m < 0;
    wide a = neg ? -m : m;

    while (a > wide(INT64_MAX))
    {
        int drop = 0;
        for (wide t = a; t > wide(INT64_MAX); t /= 10)
            drop++;

        a = dropdigits(a, drop);
        e += drop;
    }

    if (a == 0)
        e = 0;

    if (e < kMinExp)
    {
        a = dropdigits(a, kMinExp - e);
        e = kMinExp;
    }

    if (a == 0)
        e = 0;

    while (a != 0 && a % 10 == 0 && e < kMaxExp)
    {
        a /= 10;
        e++;
    }

    if (e > kMaxExp)
        return false;

    om = int64_t(neg ? -a : a);
    oe = e;
    return true;
}

static void pushwide(lua_State* L, wide m, int e)
{
    int64_t om;
    int oe;
    if (!reducewide(m, e, om, oe))
        luaL_error(L, "decimal overflow");

    lua_pushdecimal(L, om, oe);
}

static void checkdecimal(lua_State* L, int narg, int64_t& m, int& e)
{
    if (!lua_todecimal(L, narg, &m, &e))
        luaL_typeerror(L, narg, "decimal");
}

static wide addaligned(wide a, int ea, wide b, int eb, int& oe)
{
    if (a == 0)
    {
        oe = eb;
        return b;
    }
    if (b == 0)
    {
        oe = ea;
        return a;
    }

    if (ea < eb)
    {
        wide t = a;
        a = b;
        b = t;
        int te = ea;
        ea = eb;
        eb = te;
    }

    // now ea >= eb; scale a (at most 19 digits, so a * 10^19 still fits in 128 bits) down to eb, rounding b if the gap is too large
    int diff = ea - eb;
    if (diff > 19)
    {
        bool neg = b < 0;
        wide mag = dropdigits(neg ? -b : b, diff - 19);
        b = neg ? -mag : mag;
        a *= pow10w(19);
        oe = ea - 19;
        return a + b;
    }

    oe = eb;
    return a * pow10w(diff) + b;
}

static int decimal_add(lua_State* L)
{
    int64_t ma, mb;
    int ea, eb;
    checkdecimal(L, 1, ma, ea);
    checkdecimal(L, 2, mb, eb);

    int e;
    wide r = addaligned(ma, ea, mb, eb, e);
    pushwide(L, r, e);
    return 1;
}

static int decimal_sub(lua_State* L)
{
    int64_t ma, mb;
    int ea, eb;
    checkdecimal(L, 1, ma, ea);
    checkdecimal(L, 2, mb, eb);

    int e;
    wide r = addaligned(ma, ea, -wide(mb), eb, e);
    pushwide(L, r, e);
    return 1;
}

static int decimal_mul(lua_State* L)
{
    int64_t ma, mb;
    int ea, eb;
    checkdecimal(L, 1, ma, ea);
    checkdecimal(L, 2, mb, eb);

    pushwide(L, wide(ma) * wide(mb), ea + eb);
    return 1;
}

static int decimal_neg(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimal(L, 1, m, e);

    pushwide(L, -wide(m), e);
    return 1;
}

static int decimal_round(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimal(L, 1, m, e);
    int places = luaL_checkinteger(L, 2);
    const char* mode = luaL_optstring(L, 3, "halfup");

    enum
    {
        HalfUp,
        HalfEven,
        Truncate
    } rounding;

    if (strcmp(mode, "halfup") == 0)
        rounding = HalfUp;
    else if (strcmp(mode, "halfeven") == 0)
        rounding = HalfEven;
    else if (strcmp(mode, "truncate") == 0)
        rounding = Truncate;
    else
        luaL_argerror(L, 3, "invalid rounding mode, expected 'halfup', 'halfeven' or 'truncate'");

    // target exponent; digits below it are dropped
    long target = -long(places);
    if (e >= target)
    {
        lua_pushdecimal(L, m, e);
        return 1;
    }

    bool neg = m < 0;
    wide a = neg ? -wide(m) : wide(m);

    long drop = target - e;
    wide q = 0;
    if (drop <= 19) // |m| < 10^19, anything beyond that rounds to zero
    {
        wide div = pow10w(int(drop));
        q = a / div;
        wide twice = (a % div) * 2;

        if (rounding == HalfUp && twice >= div)
            q++;
        else if (rounding == HalfEven && (twice > div || (twice == div && (q & 1))))
            q++;
    }

    pushwide(L, neg ? -q : q, int(target));
    return 1;
}

static int cmpdec(int64_t ma, int ea, int64_t mb, int eb)
{
    int sa = (ma > 0) - (ma < 0);
    int sb = (mb > 0) - (mb < 0);
    if (sa != sb)
        return sa < sb ? -1 : 1;
    if (sa == 0)
        return 0;

    wide a = ma < 0 ? -wide(ma) : wide(ma);
    wide b = mb < 0 ? -wide(mb) : wide(mb);

    int oa = ndigits(a) + ea;
    int ob = ndigits(b) + eb;

    int r;
    if (oa != ob)
    {
        r = oa < ob ? -1 : 1;
    }
    else
    {
        // same order of magnitude, so the exponents differ by less than 19 and scaling is exact
        if (ea > eb)
            a *= pow10w(ea - eb);
        else
            b *= pow10w(eb - ea);

        r = a < b ? -1 : (a > b ? 1 : 0);
    }

    return sa < 0 ? -r : r;
}

static int decimal_lt(lua_State* L)
{
    int64_t ma, mb;
    int ea, eb;
    checkdecimal(L, 1, ma, ea);
    checkdecimal(L, 2, mb, eb);

    lua_pushboolean(L, cmpdec(ma, ea, mb, eb) < 0);
    return 1;
}

static int decimal_le(lua_State* L)
{
    int64_t ma, mb;
    int ea, eb;
    checkdecimal(L, 1, ma, ea);
    checkdecimal(L, 2, mb, eb);

    lua_pushboolean(L, cmpdec(ma, ea, mb, eb) <= 0);
    return 1;
}

static int decimal_tostring(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimal(L, 1, m, e);

    char s[LUAI_MAXDEC2STR];
    char* end = luai_dec2str(s, m, e);
    lua_pushlstring(L, s, end - s);
    return 1;
}

static int decimal_tonumber(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimal(L, 1, m, e);

    char s[LUAI_MAXDEC2STR];
    luai_dec2str(s, m, e);
    lua_pushnumber(L, luai_str2num(s, nullptr));
    return 1;
}

// accepts [+-]digits[.digits][(e|E)[+-]digits]
static bool parsedec(const char* s, size_t n, wide& m, int& e)
{
    size_t i = 0;
    bool neg = false;
    if (i < n && (s[i] == '-' || s[i] == '+'))
        neg = s[i++] == '-';

    const wide cap = pow10w(36); // digits beyond this are far below the precision we keep

    m = 0;
    e = 0;
    bool any = false, dot = false;

    for (; i < n; i++)
    {
        char c = s[i];
        if (c >= '0' && c <= '9')
        {
            any = true;
            if (m < cap)
            {
                m = m * 10 + (c - '0');
                if (dot)
                    e--;
            }
            else if (!dot)
            {
                e++;
            }
        }
        else if (c == '.' && !dot)
        {
            dot = true;
        }
        else
        {
            break;
        }
    }

    if (!any)
        return false;

    if (i < n && (s[i] == 'e' || s[i] == 'E'))
    {
        i++;
        bool eneg = false;
        if (i < n && (s[i] == '+' || s[i] == '-'))
            eneg = s[i++] == '-';

        if (i >= n)
            return false;

        long ex = 0;
        for (; i < n && s[i] >= '0' && s[i] <= '9'; i++)
        {
            if (ex < 100000)
                ex = ex * 10 + (s[i] - '0');
        }

        e += int(eneg ? -ex : ex);
    }

    if (i != n)
        return false;

    if (neg)
        m = -m;

    return true;
}

static int pushparsed(lua_State* L, const char* s, size_t n)
{
    wide m;
    int e;
    int64_t om;
    int oe;

    if (!parsedec(s, n, m, e) || !reducewide(m, e, om, oe))
    {
        lua_pushnil(L);
        return 1;
    }

    lua_pushdecimal(L, om, oe);
    return 1;
}

static int decimal_fromstring(lua_State* L)
{
    size_t n;
    const char* s = luaL_checklstring(L, 1, &n);
    return pushparsed(L, s, n);
}

static int decimal_create(lua_State* L)
{
    switch (lua_type(L, 1))
    {
    case LUA_TDECIMAL:
        lua_pushvalue(L, 1);
        return 1;
    case LUA_TINTEGER:
    {
        int64_t om;
        int oe;
        reducewide(lua_tointeger64(L, 1, nullptr), 0, om, oe); // always fits
        lua_pushdecimal(L, om, oe);
        return 1;
    }
    case LUA_TNUMBER:
    {
        double v = lua_tonumber(L, 1);
        if (!std::isfinite(v))
        {
            lua_pushnil(L);
            return 1;
        }

        // shortest representation that round-trips, so decimal.create(0.1) is exactly 0.1
        char s[LUAI_MAXNUM2STR];
        char* end = luai_num2str(s, v);
        return pushparsed(L, s, end - s);
    }
    case LUA_TSTRING:
    {
        size_t n;
        const char* s = lua_tolstring(L, 1, &n);
        return pushparsed(L, s, n);
    }
    default:
        luaL_typeerror(L, 1, "number, integer, string or decimal");
    }
}

static const luaL_Reg declib[] = {
    {"create", decimal_create},
    {"fromstring", decimal_fromstring},
    {"tostring", decimal_tostring},
    {"tonumber", decimal_tonumber},
    {"neg", decimal_neg},
    {"add", decimal_add},
    {"sub", decimal_sub},
    {"mul", decimal_mul},
    {"round", decimal_round},
    {"lt", decimal_lt},
    {"le", decimal_le},
    {NULL, NULL},
};

int luaopen_decimal(lua_State* L)
{
    luaL_register(L, LUA_DECLIBNAME, declib);
    return 1;
}

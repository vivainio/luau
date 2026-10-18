// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
#include "lualib.h"

#include "lcommon.h"
#include "lnumutils.h"
#include "lobject.h"

#include <climits>
#include <cmath>
#include <stdlib.h>
#include <string.h>

// Decimal values are stored as `mantissa * 10^exponent` with an int64 mantissa and an int32 exponent, where the exponent is the negated
// scale of the value: it is always in [-28, 0], so the scale (number of digits after the decimal point) is in [0, 28], as in .NET.
//
// The scale is preserved: 2.50 has mantissa 250 and exponent -2, 2.5 has mantissa 25 and exponent -1. Equality and ordering are numeric.
// Arithmetic is computed exactly in 128 bits and then rounded (half-even) to the 63 bits that fit in the mantissa, which lowers the scale.
// Values that cannot be represented even at scale 0 raise an overflow error.

#if !defined(__SIZEOF_INT128__)
#error "decimal library currently requires __int128"
#endif

typedef __int128 wide;

static const int kMaxScale = 28;

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

static wide absw(wide a)
{
    return a < 0 ? -a : a;
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

// reduces m * 10^e to a valid (int64 mantissa, exponent in [-28, 0]) pair, returns false if the value does not fit
static bool reducewide(wide m, int e, int64_t& om, int& oe)
{
    bool neg = m < 0;
    wide a = absw(m);

    while (a > wide(INT64_MAX))
    {
        int drop = 0;
        for (wide t = a; t > wide(INT64_MAX); t /= 10)
            drop++;

        a = dropdigits(a, drop);
        e += drop;
    }

    if (e < -kMaxScale)
    {
        a = dropdigits(a, -kMaxScale - e);
        e = -kMaxScale;
    }

    // a positive exponent means the value is an integer that was scaled down; bring it back to scale 0 if it fits
    while (e > 0)
    {
        if (a > wide(INT64_MAX / 10))
            return false;

        a *= 10;
        e--;
    }

    om = int64_t(neg ? -a : a);
    oe = e;
    return true;
}

static void checkdecimalarg(lua_State* L, int narg, int64_t& m, int& e)
{
    if (lua_todecimal(L, narg, &m, &e))
        return;

    if (lua_isinteger64(L, narg))
    {
        m = lua_tointeger64(L, narg, nullptr);
        e = 0;
        return;
    }

    luaL_typeerror(L, narg, "decimal");
}

// adds two values given as mantissa and exponent; the result has the smaller of the two exponents (larger scale) if it fits
static wide addaligned(wide a, int ea, wide b, int eb, int& oe)
{
    if (ea < eb)
    {
        wide t = a;
        a = b;
        b = t;
        int te = ea;
        ea = eb;
        eb = te;
    }

    // now ea >= eb; scale a down to eb
    int diff = ea - eb;
    if (ndigits(absw(a)) + diff <= 38)
    {
        oe = eb;
        return a * pow10w(diff) + b;
    }

    // a * 10^diff would not fit in 128 bits, but the result has more than 19 digits anyway so it is rounded below; drop the low digits of b
    bool neg = b < 0;
    wide mag = dropdigits(neg ? -b : b, diff - 19);
    b = neg ? -mag : mag;
    oe = ea - 19;
    return a * pow10w(19) + b;
}

bool luai_decadd(int64_t ma, int ea, int64_t mb, int eb, int64_t* om, int* oe)
{
    int e;
    wide r = addaligned(ma, ea, mb, eb, e);
    return reducewide(r, e, *om, *oe);
}

bool luai_decsub(int64_t ma, int ea, int64_t mb, int eb, int64_t* om, int* oe)
{
    int e;
    wide r = addaligned(ma, ea, -wide(mb), eb, e);
    return reducewide(r, e, *om, *oe);
}

bool luai_decmul(int64_t ma, int ea, int64_t mb, int eb, int64_t* om, int* oe)
{
    return reducewide(wide(ma) * wide(mb), ea + eb, *om, *oe);
}

bool luai_decneg(int64_t m, int e, int64_t* om, int* oe)
{
    return reducewide(-wide(m), e, *om, *oe);
}

// the result has as many digits as fit, then trailing zeros are removed down to the preferred scale max(scale(a) - scale(b), 0)
int luai_decdiv(int64_t ma, int ea, int64_t mb, int eb, int64_t* om, int* oe)
{
    if (mb == 0)
        return LUAI_DEC_DIVZERO;

    int s0 = eb - ea; // scale(a) - scale(b), since the exponent is the negated scale
    int preferred = s0 > 0 ? s0 : 0;

    if (ma == 0)
    {
        *om = 0;
        *oe = -preferred;
        return LUAI_DEC_OK;
    }

    wide a = absw(ma);
    wide b = absw(mb);

    // the quotient a / b * 10^k has scale s0 + k, which must be in [0, 28], and a * 10^k must fit in 128 bits
    int kmin = s0 < 0 ? -s0 : 0;
    int kmax = kMaxScale - s0;
    if (kmax > 38 - ndigits(a))
        kmax = 38 - ndigits(a);

    if (kmin > kmax)
        return LUAI_DEC_OVERFLOW;

    // the quotient grows with k, and we want the largest k for which it still fits in the mantissa; the digit counts give a close
    // estimate, so only a couple of 128-bit divisions are needed
    int k = 19 - (ndigits(a) - ndigits(b));
    k = k < kmin ? kmin : (k > kmax ? kmax : k);

    wide q = (a * pow10w(k)) / b;
    while (q > wide(INT64_MAX) && k > kmin)
    {
        k--;
        q = (a * pow10w(k)) / b;
    }

    while (k < kmax)
    {
        wide next = (a * pow10w(k + 1)) / b;
        if (next > wide(INT64_MAX))
            break;

        k++;
        q = next;
    }

    // round half-even using the remainder of the final division
    wide r = (a * pow10w(k)) % b;
    wide twice = r * 2;
    if (twice > b || (twice == b && (q & 1)))
        q++;

    bool neg = (ma < 0) != (mb < 0);
    int scale = s0 + k;

    int64_t m;
    int e;
    if (!reducewide(neg ? -q : q, -scale, m, e))
        return LUAI_DEC_OVERFLOW;

    while (m % 10 == 0 && -e > preferred)
    {
        m /= 10;
        e++;
    }

    *om = m;
    *oe = e;
    return LUAI_DEC_OK;
}

// remainder with the sign of the dividend (truncated division), the scale is the larger of the two operand scales
int luai_decrem(int64_t ma, int ea, int64_t mb, int eb, int64_t* om, int* oe)
{
    if (mb == 0)
        return LUAI_DEC_DIVZERO;

    int e = ea < eb ? ea : eb;
    int da = ea - e;
    int db = eb - e;

    if (ndigits(absw(ma)) + da > 38 || ndigits(absw(mb)) + db > 38)
        return LUAI_DEC_OVERFLOW;

    wide a = wide(ma) * pow10w(da);
    wide b = wide(mb) * pow10w(db);

    return reducewide(a % b, e, *om, *oe) ? LUAI_DEC_OK : LUAI_DEC_OVERFLOW;
}

int luai_deccmp(int64_t ma, int ea, int64_t mb, int eb)
{
    int sa = (ma > 0) - (ma < 0);
    int sb = (mb > 0) - (mb < 0);
    if (sa != sb)
        return sa < sb ? -1 : 1;
    if (sa == 0)
        return 0;

    wide a = absw(ma);
    wide b = absw(mb);

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

static void pushreduced(lua_State* L, wide m, int e)
{
    int64_t om;
    int oe;
    if (!reducewide(m, e, om, oe))
        luaL_error(L, "decimal overflow");

    lua_pushdecimal(L, om, oe);
}

static int decimal_binop(lua_State* L, bool (*op)(int64_t, int, int64_t, int, int64_t*, int*))
{
    int64_t ma, mb, om;
    int ea, eb, oe;
    checkdecimalarg(L, 1, ma, ea);
    checkdecimalarg(L, 2, mb, eb);

    if (!op(ma, ea, mb, eb, &om, &oe))
        luaL_error(L, "decimal overflow");

    lua_pushdecimal(L, om, oe);
    return 1;
}

static int decimal_divop(lua_State* L, int (*op)(int64_t, int, int64_t, int, int64_t*, int*))
{
    int64_t ma, mb, om;
    int ea, eb, oe;
    checkdecimalarg(L, 1, ma, ea);
    checkdecimalarg(L, 2, mb, eb);

    switch (op(ma, ea, mb, eb, &om, &oe))
    {
    case LUAI_DEC_OK:
        lua_pushdecimal(L, om, oe);
        return 1;
    case LUAI_DEC_DIVZERO:
        luaL_error(L, "decimal division by zero");
    default:
        luaL_error(L, "decimal overflow");
    }
}

static bool decimal_addfast(int64_t ma, int ea, int64_t mb, int eb, int64_t* om, int* oe)
{
    return luai_decaddfast(ma, ea, mb, eb, om, oe) || luai_decadd(ma, ea, mb, eb, om, oe);
}

static bool decimal_subfast(int64_t ma, int ea, int64_t mb, int eb, int64_t* om, int* oe)
{
    return luai_decsubfast(ma, ea, mb, eb, om, oe) || luai_decsub(ma, ea, mb, eb, om, oe);
}

static bool decimal_mulfast(int64_t ma, int ea, int64_t mb, int eb, int64_t* om, int* oe)
{
    return luai_decmulfast(ma, ea, mb, eb, om, oe) || luai_decmul(ma, ea, mb, eb, om, oe);
}

static int decimal_add(lua_State* L)
{
    return decimal_binop(L, decimal_addfast);
}

static int decimal_sub(lua_State* L)
{
    return decimal_binop(L, decimal_subfast);
}

static int decimal_mul(lua_State* L)
{
    return decimal_binop(L, decimal_mulfast);
}

static int decimal_div(lua_State* L)
{
    return decimal_divop(L, luai_decdiv);
}

static int decimal_rem(lua_State* L)
{
    return decimal_divop(L, luai_decrem);
}

static int decimal_neg(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);

    pushreduced(L, -wide(m), e);
    return 1;
}

static int decimal_abs(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);

    pushreduced(L, absw(m), e);
    return 1;
}

static int decimal_sign(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);

    lua_pushnumber(L, (m > 0) - (m < 0));
    return 1;
}

static int decimal_scale(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);

    lua_pushnumber(L, -e);
    return 1;
}

enum RoundMode
{
    HalfEven,
    AwayFromZero,
    ToZero,
    ToNegativeInfinity,
    ToPositiveInfinity,
};

// rounds to the given number of digits after the decimal point; values that already have at most that many are unchanged
static void roundto(lua_State* L, int64_t m, int e, int places, RoundMode mode)
{
    int target = -places;
    if (e >= target)
    {
        lua_pushdecimal(L, m, e);
        return;
    }

    bool neg = m < 0;
    wide a = absw(m);

    // |m| < 10^19 and the scale is at most 28, so this is at most 10^28
    wide div = pow10w(target - e);
    wide q = a / div;
    wide rem = a % div;
    wide twice = rem * 2;

    bool up = false;
    switch (mode)
    {
    case HalfEven:
        up = twice > div || (twice == div && (q & 1));
        break;
    case AwayFromZero:
        up = twice >= div;
        break;
    case ToZero:
        break;
    case ToNegativeInfinity:
        up = neg && rem != 0;
        break;
    case ToPositiveInfinity:
        up = !neg && rem != 0;
        break;
    }

    if (up)
        q++;

    pushreduced(L, neg ? -q : q, target);
}

static int decimal_round(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);
    int places = luaL_checkinteger(L, 2);
    const char* mode = luaL_optstring(L, 3, "halfeven");

    luaL_argcheck(L, places >= 0 && places <= kMaxScale, 2, "number of places out of range [0, 28]");

    RoundMode rounding;
    if (strcmp(mode, "halfeven") == 0)
        rounding = HalfEven;
    else if (strcmp(mode, "awayfromzero") == 0)
        rounding = AwayFromZero;
    else if (strcmp(mode, "tozero") == 0)
        rounding = ToZero;
    else if (strcmp(mode, "tonegativeinfinity") == 0)
        rounding = ToNegativeInfinity;
    else if (strcmp(mode, "topositiveinfinity") == 0)
        rounding = ToPositiveInfinity;
    else
        luaL_argerror(L, 3, "invalid rounding mode, expected 'halfeven', 'awayfromzero', 'tozero', 'tonegativeinfinity' or 'topositiveinfinity'");

    roundto(L, m, e, places, rounding);
    return 1;
}

static int decimal_floor(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);
    roundto(L, m, e, 0, ToNegativeInfinity);
    return 1;
}

static int decimal_ceil(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);
    roundto(L, m, e, 0, ToPositiveInfinity);
    return 1;
}

static int decimal_trunc(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);
    roundto(L, m, e, 0, ToZero);
    return 1;
}

static int decimal_minmax(lua_State* L, bool wantMax)
{
    int n = lua_gettop(L);

    int64_t bm;
    int be;
    checkdecimalarg(L, 1, bm, be);

    for (int i = 2; i <= n; i++)
    {
        int64_t m;
        int e;
        checkdecimalarg(L, i, m, e);

        int c = luai_deccmp(m, e, bm, be);
        // for equal values max keeps the earlier argument and min takes the later one, like Math.Max and Math.Min in .NET
        if (wantMax ? c > 0 : c <= 0)
        {
            bm = m;
            be = e;
        }
    }

    lua_pushdecimal(L, bm, be);
    return 1;
}

static int decimal_min(lua_State* L)
{
    return decimal_minmax(L, false);
}

static int decimal_max(lua_State* L)
{
    return decimal_minmax(L, true);
}

static int decimal_lt(lua_State* L)
{
    int64_t ma, mb;
    int ea, eb;
    checkdecimalarg(L, 1, ma, ea);
    checkdecimalarg(L, 2, mb, eb);

    lua_pushboolean(L, luai_deccmp(ma, ea, mb, eb) < 0);
    return 1;
}

static int decimal_le(lua_State* L)
{
    int64_t ma, mb;
    int ea, eb;
    checkdecimalarg(L, 1, ma, ea);
    checkdecimalarg(L, 2, mb, eb);

    lua_pushboolean(L, luai_deccmp(ma, ea, mb, eb) <= 0);
    return 1;
}

static int decimal_tostring(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);

    char s[LUAI_MAXDEC2STR];
    char* end = luai_dec2str(s, m, e);
    lua_pushlstring(L, s, end - s);
    return 1;
}

static int decimal_tonumber(lua_State* L)
{
    int64_t m;
    int e;
    checkdecimalarg(L, 1, m, e);

    char s[LUAI_MAXDEC2STR];
    luai_dec2str(s, m, e);
    lua_pushnumber(L, luai_str2num(s, nullptr));
    return 1;
}

// accepts [+-]digits[.digits][(e|E)[+-]digits]; trailing zeros after the decimal point are kept
static bool parsedec(const char* s, size_t n, wide& m, int& e)
{
    // surrounding whitespace is allowed, as in .NET's decimal.Parse
    while (n > 0 && (s[n - 1] == ' ' || (s[n - 1] >= '\t' && s[n - 1] <= '\r')))
        n--;

    size_t i = 0;
    while (i < n && (s[i] == ' ' || (s[i] >= '\t' && s[i] <= '\r')))
        i++;

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
    {"abs", decimal_abs},
    {"sign", decimal_sign},
    {"scale", decimal_scale},
    {"add", decimal_add},
    {"sub", decimal_sub},
    {"mul", decimal_mul},
    {"div", decimal_div},
    {"rem", decimal_rem},
    {"round", decimal_round},
    {"floor", decimal_floor},
    {"ceil", decimal_ceil},
    {"trunc", decimal_trunc},
    {"min", decimal_min},
    {"max", decimal_max},
    {"lt", decimal_lt},
    {"le", decimal_le},
    {NULL, NULL},
};

int luaopen_decimal(lua_State* L)
{
    luaL_register(L, LUA_DECLIBNAME, declib);
    return 1;
}

// What an embedder can do today: register a decimal as a userdata type from C++.
// This is a deliberately small version (add, subtract, multiply, compare, tostring, parse) to measure the
// approach, not a complete library. The arithmetic is the same idea as the core type: int64 mantissa and scale.
//
// Build (from the repository root, after `make luau config=release`):
//   c++ -std=c++17 -O2 -I VM/include -I Compiler/include -I Common/include demos/decimal/baseline/host.cpp \
//       build/release/libluaucompiler.a build/release/libluaubytecode.a build/release/libluauast.a build/release/libluauvm.a \
//       build/release/libluaucommon.a -o /tmp/decimal-host
//   /tmp/decimal-host demos/decimal/baseline/bench-userdata.luau
#include "lua.h"
#include "lualib.h"
#include "luacode.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

struct Decimal
{
    int64_t m;
    int s;
};

typedef __int128 wide;

static wide pow10w(int n)
{
    wide r = 1;
    while (n-- > 0)
        r *= 10;
    return r;
}

static Decimal* checkdec(lua_State* L, int idx)
{
    return (Decimal*)luaL_checkudata(L, idx, "Decimal");
}

static int push(lua_State* L, wide m, int s)
{
    // narrow to 63 bits by dropping digits (no rounding, this is only a benchmark baseline)
    while (m > INT64_MAX || m < -(wide)INT64_MAX)
    {
        m /= 10;
        s--;
    }
    Decimal* d = (Decimal*)lua_newuserdata(L, sizeof(Decimal));
    d->m = (int64_t)m;
    d->s = s;
    luaL_getmetatable(L, "Decimal");
    lua_setmetatable(L, -2);
    return 1;
}

static void align(Decimal* a, Decimal* b, wide& x, wide& y, int& s)
{
    s = a->s > b->s ? a->s : b->s;
    x = (wide)a->m * pow10w(s - a->s);
    y = (wide)b->m * pow10w(s - b->s);
}

static int d_add(lua_State* L)
{
    wide x, y;
    int s;
    align(checkdec(L, 1), checkdec(L, 2), x, y, s);
    return push(L, x + y, s);
}

static int d_sub(lua_State* L)
{
    wide x, y;
    int s;
    align(checkdec(L, 1), checkdec(L, 2), x, y, s);
    return push(L, x - y, s);
}

static int d_mul(lua_State* L)
{
    Decimal* a = checkdec(L, 1);
    Decimal* b = checkdec(L, 2);
    return push(L, (wide)a->m * b->m, a->s + b->s);
}

static int d_eq(lua_State* L)
{
    wide x, y;
    int s;
    align(checkdec(L, 1), checkdec(L, 2), x, y, s);
    lua_pushboolean(L, x == y);
    return 1;
}

static int d_lt(lua_State* L)
{
    wide x, y;
    int s;
    align(checkdec(L, 1), checkdec(L, 2), x, y, s);
    lua_pushboolean(L, x < y);
    return 1;
}

static int d_le(lua_State* L)
{
    wide x, y;
    int s;
    align(checkdec(L, 1), checkdec(L, 2), x, y, s);
    lua_pushboolean(L, x <= y);
    return 1;
}

static int d_tostring(lua_State* L)
{
    Decimal* d = checkdec(L, 1);
    std::string digits = std::to_string(d->m < 0 ? -(wide)d->m > 0 ? (long long)-d->m : 0 : (long long)d->m);
    if (d->s > 0)
    {
        if ((int)digits.size() <= d->s)
            digits.insert(0, d->s + 1 - digits.size(), '0');
        digits.insert(digits.size() - d->s, ".");
    }
    if (d->m < 0)
        digits.insert(0, "-");
    lua_pushstring(L, digits.c_str());
    return 1;
}

static int d_parse(lua_State* L)
{
    const char* text = luaL_checkstring(L, 1);
    const char* dot = strchr(text, '.');
    int s = dot ? (int)strlen(dot + 1) : 0;
    std::string digits;
    for (const char* p = text; *p; p++)
        if (*p != '.')
            digits += *p;
    return push(L, (wide)strtoll(digits.c_str(), nullptr, 10), s);
}

// collectgarbage is provided by the embedder in Luau (the luau CLI defines its own); this is the same minimal version
static int collectgarbage(lua_State* L)
{
    const char* option = luaL_optstring(L, 1, "collect");
    if (strcmp(option, "collect") == 0)
    {
        lua_gc(L, LUA_GCCOLLECT, 0);
        return 0;
    }
    if (strcmp(option, "count") == 0)
    {
        int bytes = lua_gc(L, LUA_GCCOUNTB, 0);
        lua_pushnumber(L, lua_gc(L, LUA_GCCOUNT, 0) + double(bytes) / 1024);
        return 1;
    }
    luaL_error(L, "collectgarbage must be called with 'count' or 'collect'");
}

int main(int argc, char** argv)
{
    if (argc < 2)
    {
        fprintf(stderr, "usage: %s script.luau\n", argv[0]);
        return 2;
    }

    FILE* f = fopen(argv[1], "rb");
    if (!f)
    {
        fprintf(stderr, "cannot open %s\n", argv[1]);
        return 2;
    }
    std::string source;
    char buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), f)) > 0)
        source.append(buf, n);
    fclose(f);

    lua_State* L = luaL_newstate();
    luaL_openlibs(L);

    luaL_newmetatable(L, "Decimal");
    const luaL_Reg meta[] = {
        {"__add", d_add}, {"__sub", d_sub}, {"__mul", d_mul}, {"__eq", d_eq},
        {"__lt", d_lt}, {"__le", d_le}, {"__tostring", d_tostring}, {nullptr, nullptr},
    };
    luaL_register(L, nullptr, meta);
    lua_pop(L, 1);

    lua_pushcfunction(L, collectgarbage, "collectgarbage");
    lua_setglobal(L, "collectgarbage");

    lua_newtable(L);
    lua_pushcfunction(L, d_parse, "parse");
    lua_setfield(L, -2, "parse");
    lua_setglobal(L, "Decimal");

    size_t bytecodeSize = 0;
    char* bytecode = luau_compile(source.data(), source.size(), nullptr, &bytecodeSize);
    int status = luau_load(L, "=script", bytecode, bytecodeSize, 0);
    free(bytecode);

    if (status == 0)
        status = lua_pcall(L, 0, 0, 0);

    if (status != 0)
    {
        fprintf(stderr, "error: %s\n", lua_tostring(L, -1));
        return 1;
    }

    lua_close(L);
    return 0;
}

// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details

#include "Luau/Type.h"
#include "Luau/VisitType.h"

#include "Fixture.h"

#include "doctest.h"

LUAU_FASTFLAG(LuauIntegerType2)

using namespace Luau;

TEST_SUITE_BEGIN("TypeInferPrimitives");

TEST_CASE_FIXTURE(Fixture, "cannot_call_primitives")
{
    CheckResult result = check("local foo = 5    foo()");
    LUAU_REQUIRE_ERROR_COUNT(1, result);

    REQUIRE(get<CannotCallNonFunction>(result.errors[0]) != nullptr);
}

TEST_CASE_FIXTURE(Fixture, "string_length")
{
    CheckResult result = check(R"(
        local s = "Hello, World!"
        local t = #s
    )");

    LUAU_REQUIRE_NO_ERRORS(result);
    CHECK_EQ(getBuiltins()->numberType, requireType("t"));
}

TEST_CASE_FIXTURE(Fixture, "string_index")
{
    CheckResult result = check(R"(
        local s = "Hello, World!"
        local t = s[4]
    )");

    LUAU_REQUIRE_ERROR_COUNT(1, result);

    NotATable* nat = get<NotATable>(result.errors[0]);
    REQUIRE(nat);
    CHECK_EQ("string", toString(nat->ty));

    CHECK_EQ("*error-type*", toString(requireType("t")));
}

TEST_CASE_FIXTURE(Fixture, "string_method")
{
    CheckResult result = check(R"(
        local p = ("tacos"):len()
    )");

    LUAU_REQUIRE_NO_ERRORS(result);
    CHECK("number" == toString(requireType("p")));
}

TEST_CASE_FIXTURE(Fixture, "string_function_indirect")
{
    CheckResult result = check(R"(
        local s:string
        local l = s.lower
        local p = l(s)
    )");

    LUAU_REQUIRE_NO_ERRORS(result);
    CHECK("string" == toString(requireType("p")));
}

TEST_CASE_FIXTURE(Fixture, "check_methods_of_number")
{
    CheckResult result = check(R"(
        local x: number = 9999
        function x:y(z: number)
            local s: string = z
        end
    )");

    LUAU_REQUIRE_ERROR_COUNT(2, result);

    if (!FFlag::DebugLuauForceOldSolver)
    {
        CHECK("Expected type table, got 'number' instead" == toString(result.errors[0]));
        CHECK("Expected this to be 'string', but got 'number'" == toString(result.errors[1]));
    }
    else
    {
        CHECK_EQ(toString(result.errors[0]), "Cannot add method to non-table type 'number'");
        CHECK("Expected this to be 'string', but got 'number'" == toString(result.errors[1]));
    }
}

TEST_CASE("singleton_types")
{
    BuiltinsFixture a;

    {
        BuiltinsFixture b;
    }

    // Check that Frontend 'a' environment wasn't modified by 'b'
    CheckResult result = a.check("local s: string = 'hello' local t = s:lower()");

    CHECK(result.errors.empty());
}

TEST_CASE_FIXTURE(BuiltinsFixture, "property_of_buffers")
{
    CheckResult result = check(R"(
        local b = buffer.create(100)
        print(b.foo)
    )");

    LUAU_REQUIRE_ERROR_COUNT(1, result);
}

TEST_CASE_FIXTURE(BuiltinsFixture, "properties_of_vectors")
{
    CheckResult result = check(R"(
        local a = vector.create(1, 2, 3)
        local b = vector.create(4, 5, 6)

        local t1 = {
            a + b,
            a - b,
            a * 3,
            a * b,
            3 * b,
            a / 3,
            a / b,
            3 / b,
            a // 4,
            a // b,
            4 // b,
            -a,
        }
        local t2 = {
            a.x,
            a.y,
            a.z,
        }
    )");

    LUAU_REQUIRE_NO_ERRORS(result);
}

TEST_CASE_FIXTURE(BuiltinsFixture, "decimal_literal_has_decimal_type")
{
    CheckResult result = check(R"(
        local a = 1.25d
        local b: decimal = 100d
    )");

    LUAU_REQUIRE_NO_ERRORS(result);
    CHECK_EQ(getBuiltins()->decimalType, requireType("a"));
    CHECK_EQ("decimal", toString(requireType("b")));
}

TEST_CASE_FIXTURE(BuiltinsFixture, "decimal_operators_between_decimals")
{
    CheckResult result = check(R"(
        local a: decimal = 1.5d
        local b: decimal = 2d
        local sum = a + b
        local diff = a - b
        local prod = a * b
        local neg = -a
        local lt = a < b
        local le = a <= b
        local gt = a > b
        local ge = a >= b
        local eq = a == b
    )");

    LUAU_REQUIRE_NO_ERRORS(result);
    CHECK_EQ(getBuiltins()->decimalType, requireType("sum"));
    CHECK_EQ(getBuiltins()->decimalType, requireType("diff"));
    CHECK_EQ(getBuiltins()->decimalType, requireType("prod"));
    CHECK_EQ(getBuiltins()->decimalType, requireType("neg"));
    CHECK_EQ(getBuiltins()->booleanType, requireType("lt"));
    CHECK_EQ(getBuiltins()->booleanType, requireType("le"));
}

TEST_CASE_FIXTURE(BuiltinsFixture, "decimal_does_not_mix_with_number")
{
    CheckResult result = check(R"(
        local a: decimal = 1.5d
        local x = a + 1
    )");

    LUAU_REQUIRE_ERRORS(result);

    result = check(R"(
        local a: decimal = 1.5d
        local n: number = a
    )");

    LUAU_REQUIRE_ERRORS(result);

    result = check(R"(
        local n: number = 1.5
        local a: decimal = n
    )");

    LUAU_REQUIRE_ERRORS(result);
}

TEST_CASE_FIXTURE(BuiltinsFixture, "decimal_library_functions")
{
    CheckResult result = check(R"(
        local a = decimal.fromstring("1.5")
        local b: decimal = decimal.add(1.5d, 2d)
        local c = decimal.round(b, 2)
        local s: string = decimal.tostring(c)
        local n: number = decimal.tonumber(c)
        local bad = decimal.add(1.5d, 2)
    )");

    LUAU_REQUIRE_ERROR_COUNT(1, result);
    CHECK_EQ("decimal?", toString(requireType("a")));
}

TEST_CASE_FIXTURE(BuiltinsFixture, "decimal_division_and_remainder")
{
    CheckResult result = check(R"(
        local a: decimal = 7.5d
        local b: decimal = 2d
        local q = a / b
        local r = a % b
    )");

    LUAU_REQUIRE_NO_ERRORS(result);
    CHECK_EQ(getBuiltins()->decimalType, requireType("q"));
    CHECK_EQ(getBuiltins()->decimalType, requireType("r"));
}

TEST_CASE("decimal_mixes_with_integer")
{
    // the decimal and integer definitions depend on the flag, so it has to be set before the globals are created
    ScopedFastFlag sff{FFlag::LuauIntegerType2, true};
    BuiltinsFixture fix;

    CheckResult result = fix.check(R"(
        local a: decimal = 1.5d
        local i: integer = 2i
        local s1 = a + i
        local s2 = i * a
        local s3 = a / i
        local c1 = a < i
        local c2 = i <= a
        local c3 = a >= i
    )");

    INFO(fix.getErrors(result));
    REQUIRE_EQ(0, result.errors.size());
    CHECK_EQ(fix.getBuiltins()->decimalType, fix.requireType("s1"));
    CHECK_EQ(fix.getBuiltins()->decimalType, fix.requireType("s2"));
    CHECK_EQ(fix.getBuiltins()->decimalType, fix.requireType("s3"));
    CHECK_EQ(fix.getBuiltins()->booleanType, fix.requireType("c1"));
}

TEST_CASE_FIXTURE(BuiltinsFixture, "decimal_does_not_support_floor_division_or_exponent")
{
    CheckResult result = check(R"(
        local a: decimal = 1.5d
        local x = a // a
    )");

    LUAU_REQUIRE_ERRORS(result);

    result = check(R"(
        local a: decimal = 1.5d
        local x = a ^ a
    )");

    LUAU_REQUIRE_ERRORS(result);
}

TEST_CASE("decimal_library_rounding_functions")
{
    ScopedFastFlag sff{FFlag::LuauIntegerType2, true};
    BuiltinsFixture fix;

    CheckResult result = fix.check(R"(
        local a = 2.675d
        local r: decimal = decimal.round(a, 2, "halfeven")
        local f: decimal = decimal.floor(a)
        local c: decimal = decimal.ceil(a)
        local t: decimal = decimal.trunc(a)
        local ab: decimal = decimal.abs(a)
        local sg: number = decimal.sign(a)
        local sc: number = decimal.scale(a)
        local mn: decimal = decimal.min(a, 1d, 3i)
        local mx: decimal = decimal.max(a, 1d, 3i)
        local q: decimal = decimal.div(a, 2i)
        local m: decimal = decimal.rem(a, 2i)
    )");

    INFO(fix.getErrors(result));
    REQUIRE_EQ(0, result.errors.size());
}

TEST_CASE_FIXTURE(BuiltinsFixture, "typeof_decimal_refines")
{
    CheckResult result = check(R"(
        local function f(x: decimal | string): decimal?
            if type(x) == "decimal" then
                return x
            end
            return nil
        end
        local r = f(1d)
    )");

    LUAU_REQUIRE_NO_ERRORS(result);
    CHECK_EQ("decimal?", toString(requireType("r")));
}

TEST_SUITE_END();

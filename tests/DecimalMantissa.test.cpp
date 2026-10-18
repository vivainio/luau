// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
#include "Luau/Decimal128.h"
#include "Luau/DecimalMantissa.h"

#include "doctest.h"

#include <limits>
#include <random>
#include <string>

TEST_SUITE_BEGIN("DecimalMantissa");

TEST_CASE("portable_signed_boundaries")
{
    using S = Decimal128<true>;
    using U = Decimal128<false>;
    S minimum = std::numeric_limits<int64_t>::min();
    CHECK(minimum < S(0));
    CHECK(uint64_t(-minimum) == (uint64_t(1) << 63));
    CHECK(uint64_t((-minimum) >> 64) == 0);
    CHECK(uint64_t(S(U(uint64_t(-1)))) == uint64_t(-1));
    CHECK(S(U(uint64_t(-1))) > S(0));
    S boundary = S(1) << 64;
    CHECK((boundary - 1) < boundary);
    CHECK(uint64_t(boundary - 1) == uint64_t(-1));
    CHECK(uint64_t((boundary - 1) >> 64) == 0);
    CHECK((boundary + (-boundary)) == S(0));
    CHECK((S(-123) / 10) == S(-12));
    CHECK(S(-123) % 10 == -3);
    CHECK(((U(1) << 127) >> 127) == U(1));
}

TEST_CASE("mantissa_format_and_multiply")
{
    char buffer[41];
    decimalMantissaToString(buffer, kDecimalMaxMantissa);
    CHECK(std::string(buffer) == "1237940039285380274899124223");
    decimalMantissaToString(buffer, -kDecimalMaxMantissa);
    CHECK(std::string(buffer) == "-1237940039285380274899124223");
    DecimalMantissa result;
    CHECK(decimalMantissaMultiply(kDecimalMaxMantissa, 1, &result));
    CHECK((result == kDecimalMaxMantissa));
    CHECK(decimalMantissaMultiply(-kDecimalMaxMantissa, -1, &result));
    CHECK((result == kDecimalMaxMantissa));
    CHECK_FALSE(decimalMantissaMultiply(kDecimalMaxMantissa, 2, &result));
    CHECK_FALSE(decimalMantissaMultiply(kDecimalMaxMantissa, kDecimalMaxMantissa, &result));
    CHECK(decimalMantissaMultiply(kDecimalMaxMantissa, 0, &result));
    CHECK((result == 0));
}

#if defined(__SIZEOF_INT128__)
TEST_CASE("portable_matches_native_reference")
{
    using S = Decimal128<true>;
    using U = Decimal128<false>;
    std::mt19937_64 random(0xdec128);
    for (int i = 0; i < 10000; ++i)
    {
        uint64_t lo = random(), hi = random() & 0x3ffffff;
        uint64_t blo = random(), bhi = random() & 0x3ffffff;
        unsigned __int128 u = (static_cast<unsigned __int128>(hi) << 64) | lo;
        unsigned __int128 v = (static_cast<unsigned __int128>(bhi) << 64) | blo;
        U a = U::words(lo, hi), b = U::words(blo, bhi);
        auto checkUnsigned = [](U actual, unsigned __int128 expected) {
            CHECK(actual.lo == uint64_t(expected));
            CHECK(actual.hi == uint64_t(expected >> 64));
        };
        checkUnsigned(a + b, u + v);
        checkUnsigned(a - b, u - v);
        checkUnsigned(a * 10, u * 10);
        checkUnsigned(a / 10, u / 10);
        CHECK(a % 10 == int64_t(u % 10));
        unsigned shift = unsigned(random() % 128);
        checkUnsigned(a << shift, u << shift);
        checkUnsigned(a >> shift, u >> shift);
        CHECK((a < b) == (u < v));
        __int128 x = (i & 1) ? -__int128(u) : __int128(u);
        __int128 y = (i & 2) ? -__int128(v) : __int128(v);
        S sa = (i & 1) ? -S(a) : S(a);
        S sb = (i & 2) ? -S(b) : S(b);
        auto checkSigned = [&](S actual, __int128 expected) { checkUnsigned(U(actual), static_cast<unsigned __int128>(expected)); };
        checkSigned(sa + sb, x + y);
        checkSigned(sa - sb, x - y);
        checkSigned(sa / 10, x / 10);
        CHECK(sa % 10 == int64_t(x % 10));
        CHECK((sa < sb) == (x < y));

        // Use smaller products too, so the multiplication check covers both outcomes.
        if (i & 4)
        {
            u &= (static_cast<unsigned __int128>(1) << 45) - 1;
            v &= (static_cast<unsigned __int128>(1) << 45) - 1;
        }
        DecimalMagnitude ma = (DecimalMagnitude(uint64_t(u >> 64)) << 64) | uint64_t(u);
        DecimalMagnitude mb = (DecimalMagnitude(uint64_t(v >> 64)) << 64) | uint64_t(v);
        unsigned __int128 product;
        bool fits = !__builtin_mul_overflow(u, v, &product) && (product >> 90) == 0;
        DecimalMagnitude actual;
        CHECK(decimalMagnitudeMultiply(ma, mb, &actual) == fits);
        DecimalMantissa signedA = decimalMantissaJoin((i & 1) != 0, uint64_t(u >> 64), uint64_t(u));
        DecimalMantissa signedB = decimalMantissaJoin((i & 2) != 0, uint64_t(v >> 64), uint64_t(v));
        DecimalMantissa signedResult;
        CHECK(decimalMantissaMultiply(signedA, signedB, &signedResult) == fits);
        if (fits)
        {
            DecimalMantissa expected = decimalMantissaJoin(((i & 1) != 0) != ((i & 2) != 0), uint64_t(product >> 64), uint64_t(product));
            CHECK((signedResult == expected));
        }
        if (fits)
        {
            CHECK(uint64_t(actual) == uint64_t(product));
            CHECK(uint64_t(actual >> 64) == uint64_t(product >> 64));
        }
    }
}
#endif

TEST_SUITE_END();

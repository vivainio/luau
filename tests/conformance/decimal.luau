-- This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
print("testing decimals")

local d = decimal
local function dec(s) return d.fromstring(s) end
local function str(x) return tostring(x) end

-- type
assert(type(dec("1.5")) == "decimal")
assert(typeof(dec("1.5")) == "decimal")

-- literals
assert(type(1.25d) == "decimal")
assert(typeof(1.25d) == "decimal")
assert(1.25d == dec("1.25"))
assert(100d == dec("100"))
assert(1e3d == dec("1000"))
assert(1.5e-3d == dec("0.0015"))
assert(0d == -0d)
assert(1_000.5d == dec("1000.5"))
assert(0x1d == 29) -- hexadecimal numbers are not affected by the suffix
assert(0.1d + 0.2d == 0.3d)
assert(19.99d * 3d == 59.97d)
assert(-1.5d == dec("-1.5"))
assert(9223372036854775807d == dec("9223372036854775807"))
assert(0.1d < 0.2d)
assert(not (1.5d == 1.5))
assert(select(2, loadstring("return 1.2.3d")):find("Malformed decimal"))
assert(select(2, loadstring("return 1e30d")):find("out of range"))
assert(select(2, loadstring("return 1e-29d")):find("out of range"))
assert(select(2, loadstring("return 9223372036854775808d")):find("out of range"))
assert(loadstring("return 0.0000000000000000000000000001d")) -- scale 28 is the maximum
assert(select(2, loadstring("return 0.00000000000000000000000000001d")):find("out of range"))

-- scale is preserved
assert(str(1.50d) == "1.50")
assert(str(1.5d) == "1.5")
assert(str(100d) == "100")
assert(str(0.00d) == "0.00")
assert(str(0.0100d) == "0.0100")
assert(str(1e3d) == "1000")
assert(str(-2.50d) == "-2.50")
assert(d.scale(1.50d) == 2)
assert(d.scale(1.5d) == 1)
assert(d.scale(100d) == 0)
assert(d.scale(0.00d) == 2)
assert(str(d.fromstring("2.50")) == "2.50")
assert(str(d.create("1.50")) == "1.50")
assert(str(d.create(0.1)) == "0.1")
assert(str(d.fromstring("1e3")) == "1000")

-- equality and ordering are numeric, regardless of scale
assert(1.50d == 1.5d)
assert(rawequal(1.50d, 1.5d))
assert(0.00d == 0d)
assert(100d == 100.000d)
assert(1.5d ~= 1.6d)
assert(1.5d ~= 15d)
assert(not rawequal(1d, 1))
assert(1d ~= 1)
assert(d.le(2.50d, 2.5d) and not d.lt(2.50d, 2.5d))
assert(1.10d > 1.1d == false)
assert(1.10d >= 1.1d and 1.10d <= 1.1d)

-- construction
assert(d.create(0.1) == dec("0.1"))
assert(d.create(-2.5) == dec("-2.50"))
assert(d.create(42) == dec("42"))
assert(d.create("1e3") == dec("1000"))
assert(d.create(dec("7.5")) == dec("7.5"))
assert(d.create(0/0) == nil)
assert(d.create(math.huge) == nil)
assert(d.create(1e30) == nil) -- does not fit
assert(dec("abc") == nil)
assert(dec("") == nil)
assert(dec("1.2.3") == nil)
assert(dec("1e") == nil)
assert(dec("1e500") == nil)
assert(dec("+3.0") == dec("3"))
assert(dec(".5") == dec("0.5"))
assert(dec("5.") == dec("5"))
assert(dec("-0") == dec("0"))
assert(pcall(d.create, {}) == false)
-- too many digits are rounded half-even
assert(dec("0.1234567890123456789012345678901") == dec("0.1234567890123456789"))
assert(dec("0.00000000000000000000000000004") == dec("0"))

-- tostring
assert(str(dec("19.99")) == "19.99")
assert(str(dec("0.00012")) == "0.00012")
assert(str(dec("-0.5")) == "-0.5")
assert(str(dec("-12.375")) == "-12.375")
assert(str(dec("0")) == "0")
assert(d.tostring(dec("3.14")) == "3.14")
assert(`{2.50d}` == "2.50")

-- tonumber
assert(d.tonumber(dec("12.345")) == 12.345)
assert(d.tonumber(dec("-0.1")) == -0.1)
assert(d.tonumber(1000000d) == 1e6)

-- add and subtract: the result has the larger scale
assert(str(1.5d + 1.25d) == "2.75")
assert(str(1.50d + 1.5d) == "3.00")
assert(str(1d + 0.001d) == "1.001")
assert(str(1.10d - 0.1d) == "1.00")
assert(str(0.00d + 1.5d) == "1.50")
assert(str(5d - 5d) == "0")
assert(str(0d - 2.5d) == "-2.5")
assert(d.add(dec("0.1"), dec("0.2")) == dec("0.3"))
assert(0.1 + 0.2 ~= 0.3) -- the reason this type exists
assert(d.sub(dec("1"), dec("0.0000001")) == dec("0.9999999"))
assert(d.neg(dec("1.5")) == dec("-1.5"))
assert(str(d.neg(dec("1.50"))) == "-1.50")
assert(str(-0.00d) == "0.00")
-- very different magnitudes still work
assert(1d + 0.0000000000000000000000000001d == 1d)

-- multiply: the result scale is the sum of the scales
assert(str(1.5d * 2d) == "3.0")
assert(str(1.50d * 2.0d) == "3.000")
assert(str(19.99d * 3d) == "59.97")
assert(str(0.1d * 0.1d) == "0.01")
assert(str(-2d * 2.5d) == "-5.0")
assert(str(0d * 123.456d) == "0.000")
-- scale above 28 is rounded
assert(str(0.0000000000000001d * 0.00000000000000001d) == "0.0000000000000000000000000000")

-- division: as many digits as fit, trailing zeros removed down to the preferred scale
assert(str(6d / 2d) == "3")
assert(str(1d / 2d) == "0.5")
assert(str(1.00d / 2d) == "0.50")
assert(str(7.50d / 2.5d) == "3.0")
assert(str(10d / 4d) == "2.5")
assert(str(1d / 8d) == "0.125")
assert(str(1d / 3d) == "0.3333333333333333333")
assert(str(2d / 3d) == "0.6666666666666666667")
assert(str(-1d / 3d) == "-0.3333333333333333333")
assert(str(1d / -4d) == "-0.25")
assert(str(0d / 5d) == "0")
assert(str(100d / 0.5d) == "200")
assert(d.div(dec("9"), dec("3")) == dec("3"))
assert(not pcall(function() return 1d / 0d end))
assert(select(2, pcall(function() return 1d / 0d end)):find("division by zero"))
assert(select(2, pcall(d.div, dec("1"), dec("0.00"))):find("division by zero"))

-- remainder takes the sign of the dividend
assert(7d % 3d == 1d)
assert(-7d % 3d == -1d)
assert(7d % -3d == 1d)
assert(str(7.5d % 2d) == "1.5")
assert(str(5.25d % 0.5d) == "0.25")
assert(str(5d % 0.50d) == "0.00")
assert(d.rem(dec("10"), dec("4")) == dec("2"))
assert(select(2, pcall(function() return 1d % 0d end)):find("division by zero"))

-- mixing with integers is implicit, with numbers it is not
assert(1.5d + 2i == 3.5d)
assert(2i + 1.5d == 3.5d)
assert(3i * 0.5d == 1.5d)
assert(10i / 4d == 2.5d)
assert(7i % 4d == 3d)
assert(1.5d - 1i == 0.5d)
assert(1.5d < 2i and 2i > 1.5d and 1.5d <= 2i and 1i < 1.5d)
assert(not (2i < 1.5d))
assert(d.add(1i, 2.5d) == 3.5d)
assert(d.create(5i) == dec("5"))
assert(d.min(1i, 2.5d) == 1d)
assert(1d ~= 1i) -- equality is strict about types, like integer and number
assert(not rawequal(1d, 1i))
assert(not pcall(function() return 1.5d + 1 end))
assert(not pcall(function() return 1 + 1.5d end))
assert(not pcall(function() return 1.5d * 2 end))
assert(not pcall(function() return 1.5d < 2 end))
assert(not pcall(function() return 2 <= 1.5d end))
assert(not pcall(d.add, dec("1"), 1))
assert(not pcall(d.add, 1, dec("1")))

-- operators that are not defined
assert(not pcall(function() return dec("1") // dec("3") end))
assert(not pcall(function() return dec("2") ^ dec("3") end))
assert(not pcall(function() return dec("1") .. "x" end))
assert(not pcall(function() return #dec("1") end))

-- precision is limited to a 64-bit mantissa, extra digits are rounded half-even
assert(d.mul(dec("123456789.123456789"), dec("1")) == dec("123456789.123456789"))
assert(not pcall(d.add, dec("9223372036854775807"), dec("1"))) -- integers that do not fit in the mantissa overflow
assert(str(dec("92233720368547758.07") + dec("0.01")) == "92233720368547758.1") -- one digit too many, so the scale drops to 1
assert(str(dec("92233720368547758.07") + dec("0.001")) == "92233720368547758.07")

-- overflow
assert(not pcall(function() return 9223372036854775807d * 10d end))
assert(select(2, pcall(function() return 9223372036854775807d * 10d end)):find("decimal overflow"))
assert(not pcall(function() return 9223372036854775807d + 9223372036854775807d end))
assert(not pcall(d.mul, dec("9223372036854775807"), dec("2")))

-- round: half-even by default, places in [0, 28]
assert(str(d.round(2.675d, 2)) == "2.68")
assert(str(d.round(2.665d, 2)) == "2.66")
assert(str(d.round(2.5d, 0)) == "2")
assert(str(d.round(3.5d, 0)) == "4")
assert(str(d.round(-2.5d, 0)) == "-2")
assert(str(d.round(2.675d, 2, "halfeven")) == "2.68")
assert(str(d.round(2.675d, 2, "awayfromzero")) == "2.68")
assert(str(d.round(2.665d, 2, "awayfromzero")) == "2.67")
assert(str(d.round(-2.5d, 0, "awayfromzero")) == "-3")
assert(str(d.round(2.678d, 2, "tozero")) == "2.67")
assert(str(d.round(-2.9d, 0, "tozero")) == "-2")
assert(str(d.round(-2.1d, 0, "tonegativeinfinity")) == "-3")
assert(str(d.round(2.9d, 0, "tonegativeinfinity")) == "2")
assert(str(d.round(2.1d, 0, "topositiveinfinity")) == "3")
assert(str(d.round(-2.9d, 0, "topositiveinfinity")) == "-2")
assert(str(d.round(2.5d, 5)) == "2.5") -- a value with fewer places is unchanged
assert(str(d.round(1234.5d, 0)) == "1234")
assert(str(d.round(0.4d, 0)) == "0")
assert(str(d.round(5i, 2)) == "5")
assert(not pcall(d.round, dec("1"), -1))
assert(not pcall(d.round, dec("1"), 29))
assert(not pcall(d.round, dec("1"), 0, "bogus"))
assert(not pcall(d.round, dec("1")))

-- floor, ceil, trunc
assert(str(d.floor(2.7d)) == "2")
assert(str(d.floor(-2.7d)) == "-3")
assert(str(d.floor(5.00d)) == "5")
assert(str(d.ceil(2.1d)) == "3")
assert(str(d.ceil(-2.1d)) == "-2")
assert(str(d.ceil(7d)) == "7")
assert(str(d.trunc(2.9d)) == "2")
assert(str(d.trunc(-2.9d)) == "-2")

-- abs, sign, min, max
assert(str(d.abs(-3.10d)) == "3.10")
assert(str(d.abs(3.1d)) == "3.1")
assert(d.sign(-3.1d) == -1 and d.sign(0d) == 0 and d.sign(0.50d) == 1)
assert(str(d.min(1.5d, 1.25d, 3d)) == "1.25")
assert(str(d.max(1.5d, 1.50d, 0.2d)) == "1.5")
assert(str(d.max(2d)) == "2")
assert(not pcall(d.max))

-- operators
do
    local a, b = dec("0.1"), dec("0.2")
    assert(a + b == dec("0.3"))
    assert(b - a == a)
    assert(a * b == dec("0.02"))
    assert(-a == dec("-0.1"))
    assert(a < b and a <= b and b > a and b >= a)
    assert(not (b < a) and not (b <= a))
    assert(a <= dec("0.10") and a >= dec("0.10"))
    assert(dec("-1") < dec("1"))
    assert(19.99d * 3d + 1.01d == 60.98d)

    local x = 0d
    for i = 1, 10 do x += 0.1d end
    assert(x == 1d)

    local t = {dec("3"), dec("1"), dec("2")}
    table.sort(t, function(p, q) return p < q end)
    assert(t[1] == dec("1") and t[3] == dec("3"))
    table.sort(t)
    assert(t[1] == dec("1") and t[2] == dec("2") and t[3] == dec("3"))
end

-- money example
do
    local total = 19.99d * 3d
    local tax = total * 0.24d
    local grand = total + d.round(tax, 2)
    assert(grand == 74.36d)
    assert(str(grand) == "74.36")
    local split = grand / 3d
    assert(str(d.round(split, 2)) == "24.79")
end

-- type errors
assert(not pcall(d.add, dec("1"), {}))
assert(not pcall(d.tostring, 1))

-- decimals as table values
do
    local t = {dec("1.5"), dec("2.5")}
    assert(t[1] == dec("1.5"))
    t.x = dec("9")
    assert(t.x == dec("9"))
end

-- decimals cannot be table keys
do
    local t = {}
    assert(t[dec("1")] == nil)
    assert(not pcall(function() t[dec("1")] = 1 end))
    assert(not pcall(rawset, t, dec("1"), 1))
end

-- varargs, select and pcall passthrough
do
    local function id(...) return ... end
    assert(id(dec("1.25")) == dec("1.25"))
    assert(select("#", id(dec("1"), dec("2"))) == 2)
end

-- string.format("%s") does not coerce decimals (same as integers), use tostring
assert(not pcall(string.format, "%s", dec("1.5")))
assert(string.format("%s", tostring(dec("1.5"))) == "1.5")

return "OK"

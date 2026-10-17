-- This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
print("testing decimals")

local d = decimal
local function dec(s) return d.fromstring(s) end

-- type
assert(type(dec("1.5")) == "decimal")
assert(typeof(dec("1.5")) == "decimal")

-- construction
assert(d.create(0.1) == dec("0.1"))
assert(d.create(-2.5) == dec("-2.50"))
assert(d.create(42) == dec("42"))
assert(d.create("1e3") == dec("1000"))
assert(d.create(dec("7.5")) == dec("7.5"))
assert(d.create(0/0) == nil)
assert(d.create(math.huge) == nil)
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

-- equality (normalized representation)
assert(dec("1.50") == dec("1.5"))
assert(dec("100") == dec("1e2"))
assert(dec("0.0") == dec("-0.000"))
assert(dec("1.5") ~= dec("1.6"))
assert(dec("1.5") ~= dec("15"))
assert(rawequal(dec("0.10"), dec("0.1")))
assert(not rawequal(dec("1"), 1))
assert(dec("1") ~= 1)

-- tostring
assert(tostring(dec("19.99")) == "19.99")
assert(tostring(dec("100")) == "100")
assert(tostring(dec("1e5")) == "100000")
assert(tostring(dec("0.00012")) == "0.00012")
assert(tostring(dec("-0.5")) == "-0.5")
assert(tostring(dec("-12.375")) == "-12.375")
assert(tostring(dec("0")) == "0")
assert(d.tostring(dec("3.14")) == "3.14")
assert(d.tostring(dec("1e30")) == "1000000000000000000000000000000")
assert(`{dec("2.5")}` == "2.5")

-- tonumber
assert(d.tonumber(dec("12.345")) == 12.345)
assert(d.tonumber(dec("-0.1")) == -0.1)
assert(d.tonumber(dec("1e20")) == 1e20)

-- add / sub / neg
assert(d.add(dec("0.1"), dec("0.2")) == dec("0.3"))
assert(0.1 + 0.2 ~= 0.3) -- the reason this type exists
assert(d.add(dec("1000"), dec("0.001")) == dec("1000.001"))
assert(d.sub(dec("1"), dec("0.0000001")) == dec("0.9999999"))
assert(d.sub(dec("5"), dec("5")) == dec("0"))
assert(d.sub(dec("0"), dec("2.5")) == dec("-2.5"))
assert(d.add(dec("0"), dec("2.5")) == dec("2.5"))
assert(d.neg(dec("1.5")) == dec("-1.5"))
assert(d.neg(dec("0")) == dec("0"))
-- very different magnitudes keep the larger operand
assert(d.add(dec("1"), dec("1e-60")) == dec("1"))
assert(d.add(dec("1e-60"), dec("1")) == dec("1"))

-- mul
assert(d.mul(dec("19.99"), dec("3")) == dec("59.97"))
assert(d.mul(dec("0.1"), dec("0.1")) == dec("0.01"))
assert(d.mul(dec("-2"), dec("2.5")) == dec("-5"))
assert(d.mul(dec("0"), dec("123.456")) == dec("0"))
assert(d.mul(dec("1e50"), dec("1e50")) == dec("1e100"))

-- precision is limited to what fits in a 64-bit mantissa, extra digits round half-even
assert(d.mul(dec("123456789.123456789"), dec("1")) == dec("123456789.123456789"))
assert(d.add(dec("9223372036854775807"), dec("1")) == dec("9223372036854775808"))
assert(d.add(dec("92233720368547758070"), dec("5")) == dec("92233720368547758080"))

-- overflow
assert(not pcall(d.mul, dec("1e100"), dec("10")))

-- comparison
assert(d.lt(dec("1.5"), dec("2")))
assert(not d.lt(dec("2"), dec("2")))
assert(d.le(dec("2"), dec("2.0")))
assert(d.lt(dec("-3"), dec("-2.9")))
assert(d.lt(dec("-1"), dec("1")))
assert(d.lt(dec("0"), dec("0.0001")))
assert(not d.lt(dec("0.0001"), dec("0")))
assert(d.lt(dec("0.9"), dec("10")))
assert(d.lt(dec("99.9"), dec("100")))
assert(d.le(dec("1e-30"), dec("1e-29")))

-- round
assert(d.round(dec("2.675"), 2) == dec("2.68"))
assert(d.round(dec("2.665"), 2, "halfeven") == dec("2.66"))
assert(d.round(dec("2.675"), 2, "halfeven") == dec("2.68"))
assert(d.round(dec("2.678"), 2, "truncate") == dec("2.67"))
assert(d.round(dec("-2.5"), 0) == dec("-3"))
assert(d.round(dec("-2.5"), 0, "halfeven") == dec("-2"))
assert(d.round(dec("-2.9"), 0, "truncate") == dec("-2"))
assert(d.round(dec("1234.5"), -2) == dec("1200"))
assert(d.round(dec("1.5"), 5) == dec("1.5"))
assert(d.round(dec("0.4"), 0) == dec("0"))
assert(d.round(dec("0.0000000000000000000001"), 2) == dec("0"))
assert(not pcall(d.round, dec("1"), 0, "bogus"))
assert(not pcall(d.round, dec("1")))

-- money example
do
    local total = d.mul(dec("19.99"), dec("3"))
    local tax = d.mul(total, dec("0.24"))
    local grand = d.add(total, d.round(tax, 2))
    assert(grand == dec("74.36"))
end

-- type errors
assert(not pcall(d.add, dec("1"), 1))
assert(not pcall(d.add, 1, dec("1")))
assert(not pcall(d.tostring, 1))
assert(not pcall(function() return dec("1") + dec("1") end))
assert(not pcall(function() return dec("1") < dec("2") end))

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

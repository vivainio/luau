-- Addition, subtraction, multiplication and negation, including mixing with integers.
local function section(title: string) print("\n== " .. title .. " ==") end
local function show(label: string, value: any) print(string.format("%-34s %s", label, tostring(value))) end

section("addition and subtraction (scale = the larger scale)")
show("1.5d + 1.25d", 1.5d + 1.25d)
show("1.50d + 1.5d", 1.50d + 1.5d)
show("100d + 0.01d", 100d + 0.01d)
show("0.1d + 0.2d", 0.1d + 0.2d)
show("1d - 0.001d", 1d - 0.001d)
show("0.3d - 0.1d - 0.2d", 0.3d - 0.1d - 0.2d)
show("-1.5d + 1.5d", -1.5d + 1.5d)
show("-1.5d - 1.5d", -1.5d - 1.5d)
show("12345678.9d + 0.01d", 12345678.9d + 0.01d)

section("multiplication (scale = the sum of the scales)")
show("2d * 3d", 2d * 3d)
show("1.5d * 2d", 1.5d * 2d)
show("1.5d * 1.5d", 1.5d * 1.5d)
show("19.99d * 3d", 19.99d * 3d)
show("0.1d * 0.1d * 0.1d", 0.1d * 0.1d * 0.1d)
show("-2d * 2.5d", -2d * 2.5d)
show("0d * 123.456d", 0d * 123.456d)
show("1000000d * 1000000d", 1000000d * 1000000d)
show("0.5d * 0.5d * 0.5d * 0.5d", 0.5d * 0.5d * 0.5d * 0.5d)

section("negation")
show("-(1.50d)", -(1.50d))
show("-(-1.5d)", -(-1.5d))
show("-0d", -0d)
show("decimal.neg(2.5d)", decimal.neg(2.5d))
show("decimal.abs(-3.10d)", decimal.abs(-3.10d))
show("decimal.sign(-3.1d)", decimal.sign(-3.1d))
show("decimal.sign(0d)", decimal.sign(0d))
show("decimal.sign(0.50d)", decimal.sign(0.50d))

section("operator precedence works as for numbers")
show("1d + 2d * 3d", 1d + 2d * 3d)
show("(1d + 2d) * 3d", (1d + 2d) * 3d)
show("10d - 2d - 3d", 10d - 2d - 3d)
show("-2d * -3d", -2d * -3d)

section("compound assignment")
local total = 0d
total += 19.99d
total += 5.01d
total -= 0.50d
total *= 2d
show("total after += -= *=", total)

section("integers mix in implicitly")
show("1.5d + 2i", 1.5d + 2i)
show("2i + 1.5d", 2i + 1.5d)
show("3i * 0.5d", 3i * 0.5d)
show("1.5d - 1i", 1.5d - 1i)
show("10i - 0.25d", 10i - 0.25d)
show("decimal.add(1i, 2.5d)", decimal.add(1i, 2.5d))
show("decimal.mul(3i, 3i)", decimal.mul(3i, 3i))

section("function forms")
show("decimal.add(1.1d, 2.2d)", decimal.add(1.1d, 2.2d))
show("decimal.sub(1.1d, 2.2d)", decimal.sub(1.1d, 2.2d))
show("decimal.mul(1.1d, 2.2d)", decimal.mul(1.1d, 2.2d))

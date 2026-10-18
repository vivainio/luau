-- Scale (digits after the decimal point) is part of the value's representation, like in .NET.
-- Equality and ordering ignore it; printing and the result of each operation do not.
local function section(title: string) print("\n== " .. title .. " ==") end
local function show(label: string, value: any) print(string.format("%-34s %s", label, tostring(value))) end

section("scale is preserved")
for _, d in { 1d, 1.0d, 1.00d, 1.50d, 1.5d, 100d, 0d, 0.00d, 0.0100d, -2.50d } do
    show(`{d}`, `scale {decimal.scale(d)}`)
end

section("equality and ordering are numeric")
show("1.50d == 1.5d", 1.50d == 1.5d)
show("1.50d ~= 1.5d", 1.50d ~= 1.5d)
show("0.00d == 0d", 0.00d == 0d)
show("rawequal(1.50d, 1.5d)", rawequal(1.50d, 1.5d))
show("1.50d < 1.5d", 1.50d < 1.5d)
show("1.50d <= 1.5d", 1.50d <= 1.5d)
show("1.50d >= 1.5d", 1.50d >= 1.5d)
show("100d == 100.000d", 100d == 100.000d)
show("0.1d < 0.10001d", 0.1d < 0.10001d)

section("how operations treat scale")
show("1.50d + 1.5d (larger scale)", 1.50d + 1.5d)
show("1d + 0.001d", 1d + 0.001d)
show("1.5d - 0.50d", 1.5d - 0.50d)
show("1.5d * 2d (scales add)", 1.5d * 2d)
show("1.50d * 2.0d", 1.50d * 2.0d)
show("0.1d * 0.1d", 0.1d * 0.1d)
show("2.50d * 1d", 2.50d * 1d)
show("5d - 5d", 5d - 5d)
show("5.00d - 5d (zero keeps scale)", 5.00d - 5d)
show("0.00d + 1.5d", 0.00d + 1.5d)
show("-0.00d (no negative zero)", -0.00d)

section("normalizing when you want to")
-- decimal.round with the current scale of the value is a no-op, with a smaller one it shortens it
show("round(2.50d, 5)", decimal.round(2.50d, 5))
show("round(2.50d, 1)", decimal.round(2.50d, 1))
show("round(2.50d, 0)", decimal.round(2.50d, 0))

section("equal values, different text")
local seen = {}
for _, d in { 1d, 1.0d, 1.00d } do
    seen[tostring(d)] = true
end
local keys = {}
for k in seen do
    table.insert(keys, k)
end
table.sort(keys)
show("distinct strings for 1, 1.0, 1.00", table.concat(keys, ", "))
show("all equal to each other", 1d == 1.0d and 1.0d == 1.00d)

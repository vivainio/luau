-- The classic double-precision surprises, next to the decimal results.
local function section(title: string) print("\n== " .. title .. " ==") end
local function show(label: string, value: any) print(string.format("%-34s %s", label, tostring(value))) end
local function exact(x: number): string return string.format("%.17g", x) end

section("0.1 + 0.2")
show("number: 0.1 + 0.2", exact(0.1 + 0.2))
show("number: 0.1 + 0.2 == 0.3", 0.1 + 0.2 == 0.3)
show("decimal: 0.1d + 0.2d", 0.1d + 0.2d)
show("decimal: 0.1d + 0.2d == 0.3d", 0.1d + 0.2d == 0.3d)

section("adding 0.1 ten times")
local n = 0
local d = 0d
for i = 1, 10 do
    n += 0.1
    d += 0.1d
end
show("number sum", exact(n))
show("number sum == 1", n == 1)
show("decimal sum", d)
show("decimal sum == 1d", d == 1d)

section("adding one cent a thousand times")
local cents = 0
local dcents = 0d
for i = 1, 1000 do
    cents += 0.01
    dcents += 0.01d
end
show("number total", exact(cents))
show("number total == 10", cents == 10)
show("decimal total", dcents)
show("decimal total == 10d", dcents == 10d)

section("multiplication")
show("number: 0.1 * 3", exact(0.1 * 3))
show("decimal: 0.1d * 3d", 0.1d * 3d)
show("number: 1.15 * 100", exact(1.15 * 100))
show("decimal: 1.15d * 100d", 1.15d * 100d)
show("number: 4.35 * 100", exact(4.35 * 100))
show("decimal: 4.35d * 100d", 4.35d * 100d)

section("comparison")
show("number: 0.1 + 0.7 < 0.8", 0.1 + 0.7 < 0.8)
show("decimal: 0.1d + 0.7d < 0.8d", 0.1d + 0.7d < 0.8d)
show("number: 1.1 + 2.2 > 3.3", 1.1 + 2.2 > 3.3)
show("decimal: 1.1d + 2.2d > 3.3d", 1.1d + 2.2d > 3.3d)

section("rounding a half")
show("number: string.format('%.2f', 2.675)", string.format("%.2f", 2.675))
show("number 2.675 stored as", exact(2.675))
show("decimal: round(2.675d, 2)", decimal.round(2.675d, 2))
show("decimal: round(2.675d, 2, 'awayfromzero')", decimal.round(2.675d, 2, "awayfromzero"))
show("decimal: round(2.665d, 2) half-even", decimal.round(2.665d, 2))
show("decimal: round(2.665d, 2, 'awayfromzero')", decimal.round(2.665d, 2, "awayfromzero"))

section("where decimals do NOT help")
show("1d / 3d (finite digits)", 1d / 3d)
show("1d / 3d * 3d", 1d / 3d * 3d)
-- like in .NET, a third has no finite decimal expansion, so (1/3)*3 comes back as 0.999...9 and not as 1 (27 digits here, 28 in .NET).
show("(1d / 3d) * 3d == 1d", (1d / 3d) * 3d == 1d)
show("1d / 3d is not exact either", 1d / 3d == 0.3333333333333333333d)

section("converting from a double keeps the shortest digits")
show("decimal.create(0.1)", decimal.create(0.1))
show("decimal.create(0.1 + 0.2)", decimal.create(0.1 + 0.2))
show("decimal.create(2.675)", decimal.create(2.675))
show("decimal.create(1/3)", decimal.create(1 / 3))

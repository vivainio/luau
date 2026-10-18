-- Decimal basics: literals, the type, printing, and the library at a glance.
local function section(title: string) print("\n== " .. title .. " ==") end
local function show(label: string, value: any) print(string.format("%-34s %s", label, tostring(value))) end

section("literals")
show("1.25d", 1.25d)
show("100d", 100d)
show("1e3d", 1e3d)
show("1.5e-3d", 1.5e-3d)
show("1_000.50d", 1_000.50d)
show("0.1d", 0.1d)
show("0d", 0d)
show("-1.5d", -1.5d)
show("0x1d (hex, not a decimal)", 0x1d)

section("the type")
show("type(1.25d)", type(1.25d))
show("typeof(1.25d)", typeof(1.25d))
show("type(1.25)", type(1.25))
show("type(1i)", type(1i))
show("1.25d is a decimal", typeof(1.25d) == "decimal")

section("printing and string building")
local price = 19.99d
show("print / tostring", price)
show("interpolation", `price is {price}`)
show("decimal.tostring", decimal.tostring(price))
show("string.format with tostring", string.format("%s EUR", tostring(price)))
show("scale is kept in the output", `{2.50d} vs {2.5d}`)

section("library at a glance")
local names = {}
for name in decimal do
    table.insert(names, name)
end
table.sort(names)
show("decimal library functions", table.concat(names, " "))

section("a first calculation")
local unit = 19.99d
local quantity = 3d
local subtotal = unit * quantity
local vat = subtotal * 0.24d
show("subtotal", subtotal)
show("vat at 24%", vat)
show("vat rounded to 2 places", decimal.round(vat, 2))
show("total", subtotal + decimal.round(vat, 2))

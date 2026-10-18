-- Rounding modes, floor/ceil/trunc, and why the default is half-even.
local function section(title: string) print("\n== " .. title .. " ==") end
local function show(label: string, value: any) print(string.format("%-34s %s", label, tostring(value))) end
local function try(label: string, f: () -> any)
    local ok, result = pcall(f)
    if ok then
        show(label, result)
    else
        show(label, "error: " .. (tostring(result):gsub("^.-:%d+: ", "")))
    end
end

local modes = { "halfeven", "awayfromzero", "tozero", "tonegativeinfinity", "topositiveinfinity" }
local function row(label: string, value: decimal, places: number)
    local cells = {}
    for _, mode in modes do
        table.insert(cells, string.format("%7s", tostring(decimal.round(value, places, mode))))
    end
    print(string.format("%-12s %s", label, table.concat(cells, " ")))
end

section(`rounding to 0 places: {table.concat(modes, " ")}`)
print(string.format("%-12s %7s %7s %7s %7s %7s", "", "even", "away", "zero", "-inf", "+inf"))
for _, v in { 0.5d, 1.5d, 2.5d, 3.5d, -0.5d, -1.5d, -2.5d, 2.4d, 2.6d, -2.4d, -2.6d, 2d } do
    row(tostring(v), v, 0)
end

section("rounding to 2 places")
print(string.format("%-12s %7s %7s %7s %7s %7s", "", "even", "away", "zero", "-inf", "+inf"))
for _, v in { 2.675d, 2.665d, 2.665001d, 2.664999d, -2.675d, -2.665d, 2.6d, 2.6000d, 0.005d, 0.015d, 0.025d } do
    row(tostring(v), v, 2)
end

section("default is half-even (banker's rounding)")
show("round(0.5d, 0)", decimal.round(0.5d, 0))
show("round(1.5d, 0)", decimal.round(1.5d, 0))
show("round(2.5d, 0)", decimal.round(2.5d, 0))
show("round(3.5d, 0)", decimal.round(3.5d, 0))
local even, away = 0d, 0d
local exact = 0d
for i = 0, 99 do
    local x = decimal.create(i) + 0.5d
    even += decimal.round(x, 0)
    away += decimal.round(x, 0, "awayfromzero")
    exact += x
end
show("sum of 0.5 .. 99.5 (exact)", exact)
show("sum of those rounded half-even", even)
show("sum of those rounded away from zero", away)

section("places that are already enough")
show("round(2.5d, 1)", decimal.round(2.5d, 1))
show("round(2.5d, 5)", decimal.round(2.5d, 5))
show("round(2.50d, 5)", decimal.round(2.50d, 5))
show("round(5d, 2)", decimal.round(5d, 2))
show("round(5i, 2)", decimal.round(5i, 2))

section("the result scale is the number of places (or less)")
show("round(1.23456d, 3)", decimal.round(1.23456d, 3))
show("round(1.20000d, 3)", decimal.round(1.20000d, 3))
show("round(9.999d, 2)", decimal.round(9.999d, 2))
show("round(0.001d, 2)", decimal.round(0.001d, 2))
show("round(-0.001d, 2)", decimal.round(-0.001d, 2))

section("floor, ceil and trunc (always scale 0)")
for _, v in { 2.7d, 2.2d, 2d, -2.2d, -2.7d, 5.00d, 0.5d, -0.5d } do
    show(`{v}`, `floor {decimal.floor(v)}  ceil {decimal.ceil(v)}  trunc {decimal.trunc(v)}`)
end

section("invalid arguments")
try("round(1d, -1)", function() return decimal.round(1d, -1) end)
try("round(1d, 29)", function() return decimal.round(1d, 29) end)
try("round(1d, 1.5) truncates like other libs", function() return decimal.round(1d, 1.5) end)
try("round(1d, 0, 'bogus')", function() return decimal.round(1d, 0, "bogus") end)
try("round(1d)", function() return decimal.round(1d) end)
try("round(1.5, 0)", function() return decimal.round(1.5, 0) end)
try("floor('x')", function() return decimal.floor("x" :: any) end)

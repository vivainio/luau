-- Getting decimals in and out: create, fromstring, tostring, tonumber.
local function section(title: string) print("\n== " .. title .. " ==") end
local function show(label: string, value: any) print(string.format("%-40s %s", label, tostring(value))) end
local function try(label: string, f: () -> any)
    local ok, result = pcall(f)
    if ok then
        show(label, result)
    else
        show(label, "error: " .. (tostring(result):gsub("^.-:%d+: ", "")))
    end
end

section("decimal.create from a number: shortest digits that round-trip")
for _, x in { 0.1, 0.5, 0.25, 2.675, 100, -3.5, 1e-5, 123456.789, 0.1 + 0.2, 1 / 3, 2 / 3, 1e15, 1e18 } do
    show(`create({string.format("%.17g", x)})`, decimal.create(x))
end

section("decimal.create from other types")
show("create(42)", decimal.create(42))
show("create(5i)", decimal.create(5i))
show("create('1.50')", decimal.create("1.50"))
show("create('  1.5  ') (whitespace is fine)", decimal.create("  1.5  "))
show("create(2.5d) (decimals pass through)", decimal.create(2.5d))
try("create(true)", function() return decimal.create(true :: any) end)
try("create({})", function() return decimal.create({} :: any) end)
try("create(nil)", function() return decimal.create(nil :: any) end)

section("numbers that cannot be decimals give nil")
show("create(0/0)", decimal.create(0 / 0))
show("create(math.huge)", decimal.create(math.huge))
show("create(-math.huge)", decimal.create(-math.huge))
show("create(1e30) (too large)", decimal.create(1e30))
show("create(1e19) (too large)", decimal.create(1e19))
show("create(1e-30) (rounds to zero)", decimal.create(1e-30))

section("decimal.fromstring: accepted forms")
for _, s in { "0", "1", "-1", "+1", "1.5", "1.50", "-1.50", ".5", "5.", "0.00", "007", "1e3", "1E3", "1e+3", "1.5e-3", "12.5e1", "1_000" } do
    show(`fromstring('{s}')`, decimal.fromstring(s))
end

section("decimal.fromstring: rejected forms give nil")
for _, s in { "", " ", "abc", "1.2.3", "1e", "e5", "--1", "1,5", "0x10", "1 2", "NaN", "inf", "1e500" } do
    show(`fromstring('{s}')`, decimal.fromstring(s))
end

section("more digits than fit are rounded half-even")
show("19 digits", decimal.fromstring("1234567890.123456789"))
show("31 digits", decimal.fromstring("0.1234567890123456789012345678901"))
show("beyond scale 28", decimal.fromstring("0.00000000000000000000000000004"))
show("beyond scale 28, half", decimal.fromstring("0.00000000000000000000000000005"))
show("too many integer digits", decimal.fromstring("99999999999999999999"))

section("decimal.tostring and tonumber")
for _, d in { 0.1d, 1.50d, 100d, 1d / 3d, 12345.6789d, -0.001d } do
    show(`tostring({d})`, `{decimal.tostring(d)}  ->  tonumber {string.format("%.17g", decimal.tonumber(d))}`)
end
show("tonumber(1000000d) == 1e6", decimal.tonumber(1000000d) == 1e6)
show("tonumber(0.1d) == 0.1", decimal.tonumber(0.1d) == 0.1)
show("tonumber(1d/3d) == 1/3", decimal.tonumber(1d / 3d) == 1 / 3)

section("round trip through a number is only exact for 'nice' values")
for _, d in { 0.5d, 0.1d, 0.123456789012345678d } do
    local back = decimal.create(decimal.tonumber(d))
    show(`{d}`, `back: {back}   same: {back == d}`)
end

section("no implicit conversion")
try("decimal.tonumber(5)", function() return decimal.tonumber(5 :: any) end)
try("decimal.tostring('x')", function() return decimal.tostring("x" :: any) end)
try("1.5d + decimal.create(1)", function() return 1.5d + decimal.create(1) :: any end)
try("1.5d + 1", function() return (1.5d :: any) + 1 end)

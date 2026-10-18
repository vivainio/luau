-- The limits of the 64-bit mantissa: how many digits fit, what happens beyond that, and what overflows.
local function section(title: string) print("\n== " .. title .. " ==") end
local function show(label: string, value: any) print(string.format("%-44s %s", label, tostring(value))) end
local function try(label: string, f: () -> any)
    local ok, result = pcall(f)
    if ok then
        show(label, result)
    else
        show(label, "error: " .. (tostring(result):gsub("^.-:%d+: ", "")))
    end
end

section("the largest and smallest values")
show("9223372036854775807d (max mantissa)", 9223372036854775807d)
show("-9223372036854775807d", -9223372036854775807d)
show("92233720368547758.07d (scale 2)", 92233720368547758.07d)
show("0.9223372036854775807d (scale 19)", 0.9223372036854775807d)
show("0.0000000000000000000000000001d (scale 28)", 0.0000000000000000000000000001d)
show("9.223372036854775807d", 9.223372036854775807d)

section("literals that do not fit are syntax errors")
for _, src in {
    "return 9223372036854775808d",
    "return 92233720368547758070d",
    "return 1e19d",
    "return 1e30d",
    "return 0.00000000000000000000000000001d",
    "return 1e-29d",
    "return 1.2.3d",
    "return 1ed",
} do
    local f, err = loadstring(src)
    show(src, f and "compiles" or (err :: string):gsub("^%[.-%]:%d+: ", ""))
end

section("a result with too many digits is rounded, the scale drops")
show("92233720368547758.07d + 0.01d", 92233720368547758.07d + 0.01d)
show("92233720368547758.07d + 0.001d", 92233720368547758.07d + 0.001d)
show("92233720368547758.07d + 0.1d", 92233720368547758.07d + 0.1d)
show("0.1234567890123456789d * 1d", 0.1234567890123456789d * 1d)
show("0.1234567890123456789d * 0.1234567890123456789d", 0.1234567890123456789d * 0.1234567890123456789d)
show("9223372036854775.807d * 1.5d", 9223372036854775.807d * 1.5d)
show("1d / 3d * 3d", 1d / 3d * 3d)

section("the scale is capped at 28")
show("0.0000000000000001d * 0.0000000000000001d", 0.0000000000000001d * 0.0000000000000001d)
show("0.0000000000000001d * 0.00000000000000001d", 0.0000000000000001d * 0.00000000000000001d)
show("0.0000000000000001d * 0.000000000000000001d", 0.0000000000000001d * 0.000000000000000001d)
show("1d / 9223372036854775807d", 1d / 9223372036854775807d)
show("decimal.create(1e-29)", decimal.create(1e-29))

section("overflow: a value that does not fit even at scale 0")
try("9223372036854775807d + 1d", function() return 9223372036854775807d + 1d end)
try("9223372036854775807d * 2d", function() return 9223372036854775807d * 2d end)
try("9223372036854775807d * 10d", function() return 9223372036854775807d * 10d end)
try("-9223372036854775807d - 2d", function() return -9223372036854775807d - 2d end)
try("1000000000d * 1000000000d * 100d", function() return 1000000000d * 1000000000d * 100d end)
try("decimal.mul(5000000000d, 5000000000d)", function() return decimal.mul(5000000000d, 5000000000d) end)
show("1000000000d * 1000000000d (fits)", 1000000000d * 1000000000d)
show("99999999999999999d + 1d (fits)", 99999999999999999d + 1d)

section("but digits can be traded for range")
show("922337203685477580.7d + 0.1d", 922337203685477580.7d + 0.1d)
show("922337203685477580.7d * 10d", 922337203685477580.7d * 10d)
try("922337203685477580.7d * 100d", function() return 922337203685477580.7d * 100d end)

section("remainder has its own limit: both operands scaled to a common scale")
show("1d % 0.0000000000000000001d", 1d % 0.0000000000000000001d)
try("9223372036854775807d % 0.0000000000000000000000001d", function() return 9223372036854775807d % 0.0000000000000000000000001d end)

section("what 63 bits are good for")
local balance = 92233720368547758.07d -- the largest 2-decimal amount, 92 quadrillion
show("largest amount with 2 decimals", balance)
show("largest amount with 4 decimals", 922337203685477.5807d)
show("largest amount with 8 decimals", 92233720368.54775807d)
show("largest amount with 18 decimals", 9.223372036854775807d)

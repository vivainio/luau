-- Division and remainder. The quotient keeps as many digits as fit in the mantissa, then trailing zeros are
-- removed down to the "preferred scale" max(scale(a) - scale(b), 0). The same rule is checked against .NET in dotnet/.
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

section("exact quotients")
show("6d / 2d", 6d / 2d)
show("1d / 2d", 1d / 2d)
show("1d / 8d", 1d / 8d)
show("10d / 4d", 10d / 4d)
show("100d / 0.5d", 100d / 0.5d)
show("9d / 3d", 9d / 3d)
show("-1d / 4d", -1d / 4d)
show("1d / -4d", 1d / -4d)
show("-1d / -4d", -1d / -4d)

section("preferred scale keeps what the operands had")
show("1.0d / 2d", 1.0d / 2d)
show("1.00d / 2d", 1.00d / 2d)
show("1.000d / 2d", 1.000d / 2d)
show("7.50d / 2.5d", 7.50d / 2.5d)
show("1.50d / 0.5d", 1.50d / 0.5d)
show("2.50d / 1.25d", 2.50d / 1.25d)
show("12.5d / 0.25d", 12.5d / 0.25d)
show("0.00d / 5d", 0.00d / 5d)
show("0d / 5d", 0d / 5d)

section("quotients that do not terminate")
show("1d / 3d", 1d / 3d)
show("2d / 3d", 2d / 3d)
show("-1d / 3d", -1d / 3d)
show("1d / 7d", 1d / 7d)
show("100d / 3d", 100d / 3d)
show("0.5d / 3d", 0.5d / 3d)
show("1.000d / 3d", 1.000d / 3d)
show("22d / 7d", 22d / 7d)
show("123456789.123456789d / 7d", 123456789.123456789d / 7d)
show("1d / 9223372036854775807d", 1d / 9223372036854775807d)

section("remainder takes the sign of the dividend")
show("7d % 3d", 7d % 3d)
show("-7d % 3d", -7d % 3d)
show("7d % -3d", 7d % -3d)
show("-7d % -3d", -7d % -3d)
show("7.5d % 2d", 7.5d % 2d)
show("5.25d % 0.5d", 5.25d % 0.5d)
show("5d % 0.50d (scale 2)", 5d % 0.50d)
show("10d % 5d", 10d % 5d)
show("0.3d % 0.1d (exact, unlike 0.3 % 0.1)", 0.3d % 0.1d)
show("number: 0.3 % 0.1", 0.3 % 0.1)

section("division and remainder go together")
local a, b = 17.5d, 4d
local q = decimal.trunc(a / b)
local r = a % b
show("17.5d / 4d (truncated)", q)
show("17.5d % 4d", r)
show("q * b + r == a", q * b + r == a)

section("function forms")
show("decimal.div(10d, 4d)", decimal.div(10d, 4d))
show("decimal.rem(10d, 4d)", decimal.rem(10d, 4d))
show("decimal.div(1i, 8i)", decimal.div(1i, 8i))

section("division by zero")
try("1d / 0d", function() return 1d / 0d end)
try("0d / 0d", function() return 0d / 0d end)
try("1d % 0d", function() return 1d % 0d end)
try("1d / 0.00d", function() return 1d / 0.00d end)
try("decimal.div(1d, 0d)", function() return decimal.div(1d, 0d) end)

section("not defined")
try("5d // 2d", function() return 5d // 2d end)
try("2d ^ 3d", function() return 2d ^ 3d end)
show("use trunc for a floor-style quotient", decimal.trunc(5d / 2d))

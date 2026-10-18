-- What mixes with what. Integers mix with decimals; numbers never do. Equality is type-strict.
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

local d: decimal = 1.5d
local i: integer = 2i
local n: number = 2

section("decimal and integer: arithmetic works in both orders")
show("d + i", d + i)
show("i + d", i + d)
show("d - i", d - i)
show("i - d", i - d)
show("d * i", d * i)
show("i * d", i * d)
show("d / i", d / i)
show("i / d", i / d)
show("d % i", d % i)
show("i % d", i % d)
show("the result is always a decimal", typeof(d + i))
show("integer / integer stays an error", (pcall(function() return (i :: any) / (i :: any) end)))

section("decimal and integer: ordering works in both orders")
show("d < i", d < i)
show("d <= i", d <= i)
show("d > i", d > i)
show("d >= i", d >= i)
show("i < d", i < d)
show("i > d", i > d)
show("2.00d <= 2i", 2.00d <= 2i)
show("2.00d >= 2i", 2.00d >= 2i)
show("big integer 9223372036854775807i > 1d", 9223372036854775807i > 1d)

section("equality is strict about types")
show("2d == 2i", 2d == 2i)
show("2d ~= 2i", 2d ~= 2i)
show("2d == 2", 2d == 2)
show("2i == 2", 2i == 2)
show("rawequal(2d, 2i)", rawequal(2d, 2i))
show("convert first: 2d == decimal.create(2i)", 2d == decimal.create(2i))
show("2d <= 2i and 2d >= 2i", 2d <= 2i and 2d >= 2i)

section("decimal and number: never implicit")
try("d + n", function() return (d :: any) + (n :: any) end)
try("n + d", function() return (n :: any) + (d :: any) end)
try("d * n", function() return (d :: any) * (n :: any) end)
try("d / n", function() return (d :: any) / (n :: any) end)
try("d % n", function() return (d :: any) % (n :: any) end)
try("d < n", function() return (d :: any) < (n :: any) end)
try("n <= d", function() return (n :: any) <= (d :: any) end)
try("-n then + d", function() return (d :: any) + (-n :: any) end)
show("d == n (just false)", (d :: any) == (n :: any))
show("convert explicitly", d + decimal.create(n))
show("or go the other way", decimal.tonumber(d) + n)

section("decimal and strings: no coercion either")
try("d + '1'", function() return (d :: any) + ("1" :: any) end)
try("'1' + d", function() return ("1" :: any) + (d :: any) end)
try("d .. 'x'", function() return (d :: any) .. "x" end)
try("'x' .. d", function() return "x" .. (d :: any) end)
try("d < '1'", function() return (d :: any) < ("1" :: any) end)
show("tostring first", "x" .. tostring(d))

section("decimal and booleans, nil, tables")
try("d + true", function() return (d :: any) + (true :: any) end)
try("d + nil", function() return (d :: any) + (nil :: any) end)
try("d + {}", function() return (d :: any) + ({} :: any) end)
show("d == nil", (d :: any) == nil)
show("d == {}", (d :: any) == {})
show("not d", not d)
show("d and 'yes' or 'no'", d and "yes" or "no")
show("0d is truthy", 0d and "truthy" or "falsy")

section("the library accepts integers wherever it accepts decimals")
show("decimal.add(1i, 2i)", decimal.add(1i, 2i))
show("decimal.min(3i, 2.5d, 4i)", decimal.min(3i, 2.5d, 4i))
show("decimal.max(3i, 2.5d, 4i)", decimal.max(3i, 2.5d, 4i))
show("decimal.floor(7i)", decimal.floor(7i))
show("decimal.lt(1i, 1.5d)", decimal.lt(1i, 1.5d))
show("decimal.le(2i, 2.00d)", decimal.le(2i, 2.00d))
show("decimal.scale(7i)", decimal.scale(7i))
try("decimal.add(1, 2d)", function() return decimal.add(1 :: any, 2d) end)

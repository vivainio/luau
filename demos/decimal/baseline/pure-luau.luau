--!strict
-- What you can do today without touching the VM: a decimal written in Luau, as a table with a metatable.
-- The mantissa is a double, so it is exact only up to 2^53 (about 15 digits), and every value is a table.
local Dec = {}
Dec.__index = Dec

export type Decimal = typeof(setmetatable({} :: { m: number, s: number }, Dec))

local POW10 = {}
for i = 0, 22 do
    POW10[i] = 10 ^ i
end

local function new(m: number, s: number): Decimal
    return setmetatable({ m = m, s = s }, Dec)
end

-- decimal.new("19.99") is the closest thing to the literal 19.99d
local function parse(text: string): Decimal
    local sign, int, frac = string.match(text, "^([+-]?)(%d*)%.?(%d*)$")
    assert(sign ~= nil and (int ~= "" or frac ~= ""), "malformed decimal")
    local m = tonumber((int :: string) .. (frac :: string)) :: number
    return new(if sign == "-" then -m else m, #(frac :: string))
end

local function align(a: Decimal, b: Decimal): (number, number, number)
    if a.s == b.s then
        return a.m, b.m, a.s
    elseif a.s < b.s then
        return a.m * POW10[b.s - a.s], b.m, b.s
    else
        return a.m, b.m * POW10[a.s - b.s], a.s
    end
end

function Dec.__add(a: Decimal, b: Decimal): Decimal
    local x, y, s = align(a, b)
    return new(x + y, s)
end

function Dec.__sub(a: Decimal, b: Decimal): Decimal
    local x, y, s = align(a, b)
    return new(x - y, s)
end

function Dec.__mul(a: Decimal, b: Decimal): Decimal
    return new(a.m * b.m, a.s + b.s)
end

function Dec.__unm(a: Decimal): Decimal
    return new(-a.m, a.s)
end

function Dec.__eq(a: Decimal, b: Decimal): boolean
    local x, y = align(a, b)
    return x == y
end

function Dec.__lt(a: Decimal, b: Decimal): boolean
    local x, y = align(a, b)
    return x < y
end

function Dec.__le(a: Decimal, b: Decimal): boolean
    local x, y = align(a, b)
    return x <= y
end

function Dec.__tostring(a: Decimal): string
    local digits = string.format("%.0f", math.abs(a.m))
    if a.s > 0 then
        digits = string.rep("0", math.max(0, a.s + 1 - #digits)) .. digits
        digits = string.sub(digits, 1, #digits - a.s) .. "." .. string.sub(digits, #digits - a.s + 1)
    end
    return (if a.m < 0 then "-" else "") .. digits
end

return { new = new, parse = parse }

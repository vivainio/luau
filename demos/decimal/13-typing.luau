--!strict
-- Run with luau-analyze (not luau): this file is checked, and the expected diagnostics are in 13-typing.expected.
-- Lines marked OK must produce no diagnostic, lines marked ERROR must produce one.

local a: decimal = 1.5d
local b: decimal = 2d
local i: integer = 2i
local n: number = 2

-- literals and the type
local lit1 = 1.25d -- OK: decimal
local lit2: decimal = 100d -- OK
local lit3: number = 1.25d -- ERROR: decimal is not a number
local lit4: decimal = 1.25 -- ERROR: a number is not a decimal

-- operators between decimals
local op1: decimal = a + b -- OK
local op2: decimal = a - b -- OK
local op3: decimal = a * b -- OK
local op4: decimal = a / b -- OK
local op5: decimal = a % b -- OK
local op6: decimal = -a -- OK
local op7: boolean = a < b -- OK
local op8: boolean = a <= b -- OK
local op9: boolean = a > b -- OK
local op10: boolean = a >= b -- OK
local op11: boolean = a == b -- OK
local op12: boolean = a ~= b -- OK

-- operators that do not exist
local bad1 = a // b -- ERROR
local bad2 = a ^ b -- ERROR
local bad3 = #a -- ERROR
local bad4 = a .. "x" -- ERROR
local bad5 = "x" .. a -- ERROR

-- mixing with integers is fine, in both orders
local mix1: decimal = a + i -- OK
local mix2: decimal = i + a -- OK
local mix3: decimal = i * a -- OK
local mix4: decimal = a / i -- OK
local mix5: boolean = a < i -- OK
local mix6: boolean = i <= a -- OK

-- mixing with numbers is an error
local num1 = a + n -- ERROR
local num2 = n + a -- ERROR
local num3 = a * n -- ERROR
local num4 = a < n -- ERROR
local num5 = n <= a -- ERROR
local num6: number = a + b -- ERROR: the result is a decimal

-- the result type of mixed arithmetic
local res1 = a + i
local res2 = i / a
local res3: decimal = res1 + res2 -- OK

-- library
local lib1: decimal? = decimal.create(0.1) -- OK
local lib2: decimal? = decimal.create("1.5") -- OK
local lib3: decimal? = decimal.fromstring("1.5") -- OK
local lib4: string = decimal.tostring(a) -- OK
local lib5: number = decimal.tonumber(a) -- OK
local lib6: decimal = decimal.round(a, 2) -- OK
local lib7: decimal = decimal.round(a, 2, "tozero") -- OK
local lib8: decimal = decimal.floor(a) -- OK
local lib9: decimal = decimal.min(a, b, i) -- OK
local lib10: number = decimal.scale(a) -- OK
local lib11: decimal = decimal.add(a, i) -- OK
local lib12: decimal = decimal.round(a, "2") -- ERROR: places is a number
local lib13: decimal = decimal.add(a, n) -- ERROR: number
local lib14: decimal = decimal.create(true) -- ERROR
local lib15: number = decimal.create(0.1) -- ERROR: decimal? is not a number

-- optionals have to be handled
local opt: decimal? = decimal.fromstring("1.5")
local opt1 = opt + a -- ERROR: opt may be nil
if opt then
    local opt2: decimal = opt + a -- OK: refined
    print(opt2)
end

-- type refinement with type()
local function describe(x: decimal | number | string): string
    if type(x) == "decimal" then
        local y: decimal = x -- OK: x is a decimal here
        return decimal.tostring(y)
    elseif type(x) == "number" then
        local y: number = x -- OK
        return tostring(y)
    else
        local y: string = x -- OK
        return y
    end
end

-- generics and functions
local function twice<T>(x: T): (T, T) return x, x end
local g1, g2 = twice(a)
local g3: decimal = g1 + g2 -- OK
local function sum(values: { decimal }): decimal
    local total: decimal = 0d
    for _, v in values do
        total += v -- OK
    end
    return total
end
local sumOk = sum({ 1d, 2.5d }) -- OK
local sumBad = sum({ 1, 2.5 }) -- ERROR: numbers in the list

-- tables
local prices: { [string]: decimal } = { apple = 0.5d, pear = 0.75d } -- OK
local bad6: { [string]: decimal } = { apple = 0.5 } -- ERROR
local keyed: { [decimal]: number } = {} -- OK to write the type, but a decimal can never be stored as a key at runtime

print(lit1, lit2, lit3, lit4, op1, op2, op3, op4, op5, op6, op7, op8, op9, op10, op11, op12)
print(bad1, bad2, bad3, bad4, bad5, mix1, mix2, mix3, mix4, mix5, mix6, num1, num2, num3, num4, num5, num6)
print(res3, lib1, lib2, lib3, lib4, lib5, lib6, lib7, lib8, lib9, lib10, lib11, lib12, lib13, lib14, lib15)
print(opt1, describe, g3, sumOk, sumBad, prices, bad6, keyed)

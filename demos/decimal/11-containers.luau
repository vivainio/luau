-- Decimals in tables, sorting, aggregation and function boundaries.
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
local function join(t: { decimal }): string
    local parts = {}
    for _, v in t do
        table.insert(parts, tostring(v))
    end
    return table.concat(parts, ", ")
end

section("arrays and records")
local prices: { decimal } = { 9.99d, 0.5d, 120d, 3.10d, 7d }
show("prices", join(prices))
local item = { name = "pen", price = 1.20d, qty = 10d }
show("record field", item.price)
item.price += 0.05d
show("after += 0.05d", item.price)
show("nested arithmetic", item.price * item.qty)

section("sorting")
local sorted = table.clone(prices)
table.sort(sorted)
show("table.sort default order", join(sorted))
table.sort(sorted, function(a, b) return a > b end)
show("descending", join(sorted))
local mixed: { decimal } = { 1.5d, 1.50d, 1.500d, 1.4d }
table.sort(mixed)
show("smallest first", mixed[1])
show("the three equal values are adjacent", mixed[2] == mixed[3] and mixed[3] == mixed[4])
local named = { { n = "a", v = 2.5d }, { n = "b", v = 1.5d }, { n = "c", v = 3.25d } }
table.sort(named, function(x, y) return x.v < y.v end)
show("sorted records", `{named[1].n} {named[2].n} {named[3].n}`)

section("aggregation")
local sum, lo, hi = 0d, prices[1], prices[1]
for _, p in prices do
    sum += p
    lo = decimal.min(lo, p)
    hi = decimal.max(hi, p)
end
show("sum", sum)
show("min", lo)
show("max", hi)
show("average", decimal.round(sum / decimal.create(#prices), 4))
show("min(...) / max(...) variadic", `{decimal.min(table.unpack(prices))} {decimal.max(table.unpack(prices))}`)
show("table.unpack", select("#", table.unpack(prices)))

section("tables of decimals as maps (values only)")
local cart: { [string]: decimal } = {}
cart.apple = 0.5d
cart.pear = 0.75d
cart.apple += 0.25d
local keys = {}
for k in cart do
    table.insert(keys, k)
end
table.sort(keys)
for _, k in keys do
    show(k, cart[k])
end

section("decimals cannot be table keys")
local t: { [any]: number } = {}
try("t[1.5d] = 1", function() t[1.5d :: any] = 1 end)
try("rawset(t, 1.5d, 1)", function() rawset(t, 1.5d, 1) end)
show("t[1.5d] (a read is just nil)", t[1.5d :: any])
show("workaround: key by tostring", (function()
    local byText: { [string]: number } = {}
    byText[tostring(1.50d)] = 1
    return byText[tostring(1.50d)]
end)())
show("note: tostring keeps the scale", tostring(1.5d) == tostring(1.50d))

section("table.find")
show("table.find(prices, 120d)", table.find(prices, 120d))
show("table.find(prices, 120.000d) (numeric)", table.find(prices, 120.000d))
show("table.find(prices, 3.1d) (scale ignored)", table.find(prices, 3.1d))
show("table.find(prices, 4d)", table.find(prices, 4d))
show("table.find(prices, 120) (a number)", table.find(prices :: any, 120))

section("functions: arguments, returns, varargs, closures")
local function addAll(...: decimal): decimal
    local total = 0d
    for _, v in { ... } do
        total += v
    end
    return total
end
show("varargs sum", addAll(1.1d, 2.2d, 3.3d))
local function counter(step: decimal)
    local value = 0d
    return function(): decimal
        value += step
        return value
    end
end
local next = counter(0.1d)
next()
next()
show("closure after 3 calls", next())
local function minmax(a: decimal, b: decimal): (decimal, decimal)
    return decimal.min(a, b), decimal.max(a, b)
end
show("multiple returns", join({ minmax(5.5d, 2.25d) }))
show("pcall passes decimals through", select(2, pcall(function() return 1.25d end)))
show("coroutine passes decimals through", select(2, coroutine.resume(coroutine.create(function() coroutine.yield(3.5d) end))))

section("strings: no coercion, but interpolation works")
try("string.format('%s', d)", function() return string.format("%s", 1.5d) end)
try("string.format('%d', d)", function() return string.format("%d", 1.5d) end)
try("string.format('%.2f', d)", function() return string.format("%.2f", 1.5d) end)
try("'total ' .. d", function() return "total " .. (1.5d :: any) end)
show("string.format with tostring", string.format("%s", tostring(1.5d)))
show("interpolation", `total {1.5d}`)
show("string.format('%.2f', tonumber(d))", string.format("%.2f", decimal.tonumber(1.5d)))
show("print(d) shows scale", 1.50d)

section("other library functions refuse decimals")
try("math.max(1d, 2d)", function() return math.max(1d :: any, 2d :: any) end)
try("math.floor(1.5d)", function() return math.floor(1.5d :: any) end)
try("math.abs(-1d)", function() return math.abs(-1d :: any) end)
try("tonumber(1.5d)", function() return tonumber(1.5d :: any) end)
try("#1.5d", function() return #(1.5d :: any) end)
try("select('#', 1.5d)", function() return select("#", 1.5d) end)

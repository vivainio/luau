-- Worked money examples: invoices, tax, discounts, splitting a bill, interest.
local function section(title: string) print("\n== " .. title .. " ==") end
local function show(label: string, value: any) print(string.format("%-38s %s", label, tostring(value))) end
local function cents(x: decimal): decimal return decimal.round(x, 2) end

section("an invoice")
type Line = { name: string, unit: decimal, qty: decimal }
local lines: { Line } = {
    { name = "Widget", unit = 19.99d, qty = 3d },
    { name = "Gadget", unit = 4.95d, qty = 12d },
    { name = "Gizmo", unit = 0.333d, qty = 100d },
    { name = "Service", unit = 85d, qty = 1.5d },
}
local net = 0d
for _, line in lines do
    local amount = line.unit * line.qty
    net += amount
    print(string.format("%-10s %8s x %6s = %10s", line.name, tostring(line.unit), tostring(line.qty), tostring(amount)))
end
show("net", net)
local vat = net * 0.24d
show("vat at 24% (unrounded)", vat)
show("vat (rounded)", cents(vat))
show("gross", net + cents(vat))

section("round per line or round the total?")
-- three items of 0.333 with 24% vat: each line is 0.41292, which rounds to 0.41
local items = { 0.333d, 0.333d, 0.333d }
local perLine, total = 0d, 0d
for _, price in items do
    perLine += cents(price * 1.24d)
    total += price * 1.24d
end
show("sum of lines rounded to cents", perLine)
show("total rounded once", cents(total))
show("they differ", perLine ~= cents(total))
show("difference", cents(total) - perLine)
-- which one is right depends on the law or contract; the type does not decide it for you

section("discounts and percentages")
local price = 249.90d
show("price", price)
show("20% off", price * 0.8d)
show("20% off, rounded", cents(price * 0.8d))
show("discount amount", cents(price * 0.2d))
show("price + 24% vat", cents(price * 1.24d))
show("price including vat, extract vat", cents(price - price / 1.24d))
show("net from a gross price", cents(price / 1.24d))

section("splitting a bill without losing a cent")
local function split(amount: decimal, parts: number): { decimal }
    local share = decimal.round(amount / decimal.create(parts), 2, "tozero")
    local result = {}
    local remainder = amount - share * decimal.create(parts)
    for i = 1, parts do
        local extra = 0d
        if remainder >= 0.01d then
            extra = 0.01d
            remainder -= 0.01d
        end
        table.insert(result, share + extra)
    end
    return result
end
for _, amount in { 100d, 10d, 0.05d, 99.99d } do
    local shares = split(amount, 3)
    local sum = 0d
    local parts = {}
    for _, s in shares do
        sum += s
        table.insert(parts, tostring(s))
    end
    show(`{amount} / 3`, `{table.concat(parts, " + ")} = {sum}`)
end
show("naive 100 / 3 * 3 with doubles", string.format("%.17g", 100 / 3 * 3))
show("naive rounded thirds", cents(100d / 3d) * 3d)

section("compound interest, rounded each month")
local balance = 10000d
local monthly = 0.05d / 12d
show("monthly rate", monthly)
for month = 1, 12 do
    balance += cents(balance * monthly)
end
show("after 12 months", balance)
local unrounded = 10000d
for month = 1, 12 do
    unrounded += unrounded * monthly
end
show("same without rounding", unrounded)
show("the closed form needs a power", "not available: decimal has no ^")

section("currency conversion")
local rate = 1.0873d
local eur = 250d
show("250 EUR at 1.0873", eur * rate)
show("in cents", cents(eur * rate))
show("and back", cents(cents(eur * rate) / rate))

section("basis points and unit prices")
local bps = 25d
show("25 bps of 1,000,000", 1000000d * bps / 10000d)
show("price per kg for 0.35 kg costing 2.79", cents(2.79d / 0.35d))
show("price of 1 unit at 3 for 10", decimal.round(10d / 3d, 4))
show("price of 3 units", decimal.round(10d / 3d, 4) * 3d)

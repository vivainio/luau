local N = 1000000
local t = os.clock()
local x = Decimal.parse("0")
local step = Decimal.parse("0.01")
for i = 1, N do
    x = x + step
end
local ms = (os.clock() - t) * 1000
print(string.format("embedded userdata: %d additions in %.0f ms (%.2f ns each), result %s", N, ms, ms * 1e6 / N, tostring(x)))
print("typeof:", typeof(x), "equal across scales:", Decimal.parse("1.50") == Decimal.parse("1.5"), "0.1+0.2==0.3:", Decimal.parse("0.1") + Decimal.parse("0.2") == Decimal.parse("0.3"))

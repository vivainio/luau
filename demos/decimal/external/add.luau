local N = 1000000
local t = os.clock()
local x = D"0"
local step = D"0.01"
for i = 1, N do
    x = x + step
end
local ms = (os.clock() - t) * 1000
print(string.format("mlua-decimal: %d additions in %.0f ms (%.2f ns each), result %s", N, ms, ms * 1e6 / N, tostring(x)))

local N = 10000000
local t = os.clock()
local x = 0
local step = 0.01
for i = 1, N do
    x = x + step
end
local ms = (os.clock() - t) * 1000
print(string.format("number: %d additions in %.0f ms (%.2f ns each), result %s", N, ms, ms * 1e6 / N, tostring(x)))

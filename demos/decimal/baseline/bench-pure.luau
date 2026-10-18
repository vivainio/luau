local D = require("./pure-luau")
local N = 1000000
local t = os.clock()
local x = D.parse("0")
local step = D.parse("0.01")
for i = 1, N do
    x = x + step
end
local ms = (os.clock() - t) * 1000
print(string.format("pure Luau: %d additions in %.0f ms (%.0f ns each), result %s", N, ms, ms * 1e6 / N, tostring(x)))

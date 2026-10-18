local N = 1000000
collectgarbage()
local before = collectgarbage("count")
local t = table.create(N, 0d)
for i = 1, N do t[i] = decimal.create(i) * 0.01d end
collectgarbage()
local kb = collectgarbage("count") - before
print(string.format("core decimal: %d values in an array: %.1f MB (%.0f bytes each)", N, kb / 1024, kb * 1024 / N))

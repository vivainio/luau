local N = 1000000
collectgarbage()
local before = collectgarbage("count")
local t = table.create(N)
local cent = Decimal.parse("0.01")
for i = 1, N do t[i] = Decimal.parse(tostring(i)) * cent end
collectgarbage()
local kb = collectgarbage("count") - before
print(string.format("embedded userdata: %d values in an array: %.1f MB (%.0f bytes each)", N, kb / 1024, kb * 1024 / N))

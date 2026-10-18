local N = 1000000
gc_collect()
local before = used_memory()
local t = table.create(N)
local cent = D"0.01"
for i = 1, N do t[i] = D(i) * cent end
gc_collect()
local kb = (used_memory() - before) / 1024
print(string.format("mlua-decimal: %d values in an array: %.1f MB (%.0f bytes each)", N, kb / 1024, kb * 1024 / N))

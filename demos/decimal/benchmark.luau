-- Rough timings for decimal operations in the interpreter. Not part of run.sh because the numbers vary by machine.
-- Run: ./luau demos/decimal/benchmark.luau   (or with --codegen)
local N = 10000000
local function time(label, f)
    local t = os.clock()
    local r = f()
    print(string.format("%-34s %6.0f ms   (%s)", label, (os.clock() - t) * 1000, tostring(r)))
end
time("number: x += 0.01", function() local x = 0 for i = 1, N do x += 0.01 end return x end)
time("decimal: x += 0.01d", function() local x = 0d for i = 1, N do x += 0.01d end return x end)
time("decimal: x = round(x * 1.01d, 2)", function() local x = 1d for i = 1, N // 10 do x = decimal.round(x * 1.01d, 2) if x > 1000d then x = 1d end end return x end)
time("decimal: x += y / 3d", function() local x, y = 0d, 1d for i = 1, N // 10 do x += y / 3d end return x end)
time("decimal.add(x, y) library call", function() local x = 0d local y = 0.01d for i = 1, N do x = decimal.add(x, y) end return x end)
time("decimal: x < y", function() local x, y, c = 1d, 2d, 0 for i = 1, N do if x < y then c += 1 end end return c end)
time("decimal: x == y", function() local x, y, c = 1d, 1.0d, 0 for i = 1, N do if x == y then c += 1 end end return c end)
time("table of 1e6 decimals, sum", function() local t = table.create(1000000, 0.01d) local s = 0d for _, v in t do s += v end return s end)

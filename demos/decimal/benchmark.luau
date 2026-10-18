-- Timings of decimal operations in the interpreter or (with --codegen) with native code generation.
-- Prints one "label<TAB>nanoseconds per operation" line per row; run-benchmarks.sh runs this in both modes.
-- Not part of run.sh because the numbers vary by machine.
local N = 10000000

local function bench(label: string, iterations: number, f: (n: number) -> any)
    f(1000) -- warm up
    local t = os.clock()
    f(iterations)
    local ns = (os.clock() - t) * 1e9 / iterations
    print(string.format("%s\t%.2f", label, ns))
end

bench("number: x += 0.01", N, function(n) local x = 0 for i = 1, n do x += 0.01 end return x end)
bench("decimal: x += 0.01d", N, function(n) local x = 0d for i = 1, n do x += 0.01d end return x end)
-- different scales: this takes the general path (align, add in 128 bits, round) instead of the same-scale fast path
bench("decimal: x + y, scales 1 and 2", N, function(n) local x, y, r = decimal.fromstring("1.5"), decimal.fromstring("0.25"), 0d for i = 1, n do r = x + y end return r end)
bench("decimal.add(x, y)", N, function(n) local x, y = 0d, 0.01d for i = 1, n do x = decimal.add(x, y) end return x end)
-- the operands come from strings at run time: with constant operands the compiler folds == away entirely
bench("decimal: x < y", N, function(n) local x, y, c = decimal.fromstring("1"), decimal.fromstring("2"), 0 for i = 1, n do if x < y then c += 1 end end return c end)
bench("decimal: x == y", N, function(n) local x, y, c = decimal.fromstring("1"), decimal.fromstring("1.0"), 0 for i = 1, n do if x == y then c += 1 end end return c end)
bench("decimal: x * 1.01d, rounded to 2", N // 10, function(n) local x = 1d for i = 1, n do x = decimal.round(x * 1.01d, 2) if x > 1000d then x = 1d end end return x end)
bench("decimal: x += y / 3d", N // 10, function(n) local x, y = 0d, 1d for i = 1, n do x += y / 3d end return x end)
local array = table.create(1000000, 0.01d)
bench("decimal: sum an array, per element", 1000000, function(n) local s = 0d for _, v in array do s += v end return s end)

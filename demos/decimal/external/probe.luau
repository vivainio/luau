local a = D"1.5"
local tests = {
    { "a + a", function(x) return x + x end },
    { "a - a", function(x) return x - x end },
    { "a * a", function(x) return x * x end },
    { "a / a", function(x) return x / x end },
    { "a // a", function(x) return x // x end },
    { "a % a", function(x) return x % x end },
    { "a ^ a", function(x) return x ^ x end },
    { "-a", function(x) return -x end },
    { "a < a", function(x) return x < x end },
    { "a <= a", function(x) return x <= x end },
    { "a == a", function(x) return x == x end },
    { "a + 1 (integer-valued number)", function(x) return x + 1 end },
    { "a + 0.5 (number with a fraction)", function(x) return x + 0.5 end },
    { "a < 2 (number)", function(x) return x < 2 end },
    { "a == 2 (number, no error)", function(x) return x == 2 end },
    { "a .. 'x'", function(x) return x .. "x" end },
    { "interpolation", function(x) return `{x}` end },
    { "tostring(a)", function(x) return tostring(x) end },
    { "t[a] = 1 (as table key)", function(x) local t = {} t[x] = 1 end },
    { "table.sort({a, a})", function(x) table.sort({ x, x }) end },
    { "math.max(a, a)", function(x) return math.max(x, x) end },
    { "string.format('%s', a)", function(x) return string.format("%s", x) end },
    { "string.format('%d', a)", function(x) return string.format("%d", x) end },
    { "#a", function(x) return #x end },
    { "type(a)", function(x) return type(x) end },
    { "typeof(a)", function(x) return typeof(x) end },
}
for _, t in tests do
    local s, r = pcall(t[2], a)
    print(string.format("%-34s %s", t[1], s and ("ok: " .. tostring(r)) or ("error: " .. (tostring(r):gsub("^.-:%d+: ", ""):sub(1, 70)))))
end
-- identity and equality
local t = {}
t[D"1.5"] = "first"
print("t[D'1.5'] with an equal value:", t[D"1.5"])
print("table.find({D'1.5'}, D'1.5'):", table.find({ D"1.5" }, D"1.5"))
print("rawequal(D'1.5', D'1.5'):", rawequal(D"1.5", D"1.5"))
print("D'1.50' == D'1.5':", D"1.50" == D"1.5")
print("D'1' == D'1' used as `d == d` in a branch:", D"1" == D"1")

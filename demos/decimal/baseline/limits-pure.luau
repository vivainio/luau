-- Where a pure-Luau decimal falls short, next to the same lines with the core type.
local D = require("./pure-luau")
local function show(label: string, value: any) print(string.format("%-46s %s", label, tostring(value))) end

print("== it works for the easy cases ==")
show("parse('0.1') + parse('0.2')", D.parse("0.1") + D.parse("0.2"))
show("parse('19.99') * parse('3')", D.parse("19.99") * D.parse("3"))
show("parse('0.1') + parse('0.2') == parse('0.3')", D.parse("0.1") + D.parse("0.2") == D.parse("0.3"))
show("parse('1.50') == parse('1.5')", D.parse("1.50") == D.parse("1.5"))
show("parse('1.5') < parse('2')", D.parse("1.5") < D.parse("2"))

print("\n== the mantissa is a double ==")
show("parse('9007199254740993')  (2^53 + 1)", D.parse("9007199254740993"))
show("core: 9007199254740993d", 9007199254740993d)
show("parse('0.1234567890123456789')", D.parse("0.1234567890123456789"))
show("core: 0.1234567890123456789d", 0.1234567890123456789d)
show("parse('123456789.123456789') * parse('1000')", D.parse("123456789.123456789") * D.parse("1000"))
show("core: 123456789.123456789d * 1000d", 123456789.123456789d * 1000d)

print("\n== it is a table, and looks like one ==")
local d = D.parse("1.5")
show("type(d)", type(d))
show("typeof(d)", typeof(d))
show("core: typeof(1.5d)", typeof(1.5d))
show("d.m (the representation is public)", (d :: any).m)
local raw: any = d
raw.m = 999
show("after d.m = 999", d)

print("\n== no literal, no folding ==")
show("pure Luau needs a call per constant", "D.parse('19.99')  vs  19.99d")

print("\n== tables ==")
local t = {}
t[D.parse("1.5")] = "a"
show("t[parse('1.5')] looked up with an equal value", t[D.parse("1.5")])
show("core: a decimal key", "error: table index is a decimal")

print("\n== mixing ==")
show("D.parse('1') + 1 (a plain number)", select(2, pcall(function() return (D.parse("1") :: any) + 1 end)))

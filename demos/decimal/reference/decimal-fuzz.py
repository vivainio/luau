#!/usr/bin/env python3
"""Fuzz test for the decimal library: every operation is run in Luau and compared with a reference built on Python's decimal module and
integers.

The reference states the rules, not the implementation:

  * a decimal is mantissa * 10^exponent with |mantissa| <= 2^90 - 1 and exponent in [-28, 0] (the negated scale), scale is preserved,
  * an arithmetic result is computed exactly and then rounded half-even ONCE, to the finest scale (not finer than the natural scale of the
    result, not finer than 28) at which the mantissa fits; an integer part that does not fit is an overflow, never rounded,
  * division gives the largest scale (at most 28) at which the rounded quotient fits, then trailing zeros are removed down to the preferred
    scale max(scale(a) - scale(b), 0); the remainder has the sign of the dividend and the larger of the two scales,
  * rounding modes map onto Python's: halfeven, awayfromzero = ROUND_HALF_UP (ties away from zero), tozero = ROUND_DOWN,
    tonegativeinfinity = ROUND_FLOOR, topositiveinfinity = ROUND_CEILING.

Operators and the library function forms are both tested (the operators take the interpreter fast paths when the scales match).

Run from the repository root after `make luau config=release`:
    python3 demos/decimal/reference/decimal-fuzz.py [cases-per-batch] [batches] [seed]
"""
import random
import re
import subprocess
import sys
import tempfile
from decimal import (
    Decimal,
    Context,
    ROUND_CEILING,
    ROUND_DOWN,
    ROUND_FLOOR,
    ROUND_HALF_EVEN,
    ROUND_HALF_UP,
    localcontext,
)

CASES = int(sys.argv[1]) if len(sys.argv) > 1 else 12000
BATCHES = int(sys.argv[2]) if len(sys.argv) > 2 else 6
SEED = int(sys.argv[3]) if len(sys.argv) > 3 else 20261018
random.seed(SEED)

MAX = 2**90 - 1
MAXSCALE = 28
CTX = Context(prec=600, Emax=10**6, Emin=-(10**6), traps=[])


def D(x):
    return CTX.create_decimal(x)


# a decimal is (mantissa as a signed int, exponent <= 0); a failed operation is the string "ERR ..."
def fit(v, e_in):
    """Round the exact value v to the finest scale >= max(e_in, -28) at which the mantissa fits, or None."""
    start = min(max(e_in, -MAXSCALE), 0)
    for t in range(start, 1):
        q = v.quantize(D(1).scaleb(t, CTX), rounding=ROUND_HALF_EVEN, context=CTX)
        m = int(q.scaleb(-t, CTX))
        if abs(m) <= MAX:
            return (m, t)
    return None


def to_value(d):
    m, e = d
    return D(m).scaleb(e, CTX)


def fmt(d):
    if d is None:
        return "ERR decimal overflow"
    if isinstance(d, str):
        return d
    m, e = d
    digits = str(abs(m))
    sc = -e
    if sc > 0:
        digits = digits.rjust(sc + 1, "0")
        digits = digits[:-sc] + "." + digits[-sc:]
    return ("-" if m < 0 else "") + digits


PARSE = re.compile(r"^\s*([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?\s*$")


def parse(s):
    m = PARSE.match(s)
    if not m:
        return None
    sign, ip, fp, ex = m.group(1), m.group(2), m.group(3), m.group(4)
    if fp is None:
        fp = ""
    if not ip and not fp:
        return None
    digits = (ip + fp) or "0"
    e_in = (int(ex) if ex else 0) - len(fp)
    if int(digits) == 0:
        return (0, min(max(e_in, -MAXSCALE), 0))  # zero keeps its scale, within the limits
    # the exponent of a nonzero value that is positive or huge can only overflow or underflow
    if e_in > 60:
        return None
    v = D(("-" if sign == "-" else "") + digits).scaleb(e_in, CTX)
    return fit(v, e_in)


def cmp(a, b):
    x, y = to_value(a), to_value(b)
    return (x > y) - (x < y)


def add(a, b, sign=1):
    x, y = to_value(a), to_value(b)
    return fit(CTX.add(x, y) if sign > 0 else CTX.subtract(x, y), min(a[1], b[1]))


def mul(a, b):
    return fit(CTX.multiply(to_value(a), to_value(b)), a[1] + b[1])


def ndig(x):
    return len(str(x))


def div(a, b):
    if b[0] == 0:
        return "ERR decimal division by zero"
    s0 = b[1] - a[1]
    pref = max(s0, 0)
    if a[0] == 0:
        return (0, -pref)
    x, y = abs(a[0]), abs(b[0])
    kmin, kmax = max(0, -s0), min(MAXSCALE - s0, 77 - ndig(x))
    if kmin > kmax:
        return None

    def rounded(k):
        q, r = divmod(x * 10**k, y)
        if 2 * r > y or (2 * r == y and q % 2 == 1):
            q += 1
        return q

    k = next((kk for kk in range(kmax, kmin - 1, -1) if rounded(kk) <= MAX), None)
    if k is None:
        return None
    q = rounded(k)
    scale = s0 + k
    while q % 10 == 0 and scale > pref and q != 0:
        q //= 10
        scale -= 1
    if q == 0:
        return (0, 0)  # a quotient that rounds to zero is plain zero, as in .NET
    return (-q if (a[0] < 0) != (b[0] < 0) else q, -scale)


def rem(a, b):
    if b[0] == 0:
        return "ERR decimal division by zero"
    r = CTX.remainder(to_value(a), to_value(b))  # the sign of the dividend, like the library
    return fit(r, min(a[1], b[1]))


MODES = {
    "halfeven": ROUND_HALF_EVEN,
    "awayfromzero": ROUND_HALF_UP,
    "tozero": ROUND_DOWN,
    "tonegativeinfinity": ROUND_FLOOR,
    "topositiveinfinity": ROUND_CEILING,
}


def round_to(a, places, mode):
    if a[1] >= -places:
        return a
    q = to_value(a).quantize(D(1).scaleb(-places, CTX), rounding=MODES[mode], context=CTX)
    return (int(q.scaleb(places, CTX)), -places)


def rand_digits(n):
    return "".join(random.choice("0123456789") for _ in range(n))


def rand_dec_string():
    """Random decimal text with up to 30 digits, 0 to 28 decimals, sometimes an edge value."""
    r = random.random()
    sign = random.choice(["", "", "-"])
    if r < 0.12:
        base = random.choice([MAX, MAX - 1, MAX + 1, 10**27, 10**27 - 1, 10**28 - 1, 10**random.randint(0, 28), 10**random.randint(1, 28) - 1])
        digits = str(base)
    elif r < 0.2:
        digits = "0" * random.randint(1, 4)
    else:
        n = random.choice([1, 1, 2, 3, 5, 8, 12, 17, 19, 20, 24, 27, 28, 28, 29, 30])
        digits = str(random.randint(1, 9)) + rand_digits(n - 1)
    scale = random.choice([0, 0, 1, 2, 2, 3, 4, 6, 8, random.randint(0, 28), random.randint(0, 28)])
    scale = min(scale, 28)
    if scale > 0:
        digits = digits.rjust(scale + 1, "0")
        text = digits[:-scale] + "." + digits[-scale:]
    else:
        text = digits
    return sign + text


def operand():
    """A string that parses to a valid decimal, with its reference value."""
    while True:
        s = rand_dec_string()
        d = parse(s)
        if d is not None and not isinstance(d, str):
            return s, d


def luau_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t") + '"'


cases = []  # (luau expression returning a printable value, expected output)


def case(expr, expected):
    cases.append((expr, expected))


def fs(s):
    return f"fs({luau_string(s)})"


def gen_batch(n):
    del cases[:]
    for _ in range(n):
        sa, a = operand()
        sb, b = operand()
        A, B = fs(sa), fs(sb)

        for name, op, fn in (("+", "add", lambda: add(a, b)), ("-", "sub", lambda: add(a, b, -1)), ("*", "mul", lambda: mul(a, b))):
            exp = fmt(fn())
            case(f"{A} {name} {B}", exp)
            case(f"decimal.{op}({A}, {B})", exp)
        exp = fmt(div(a, b))
        case(f"{A} / {B}", exp)
        case(f"decimal.div({A}, {B})", exp)
        exp = fmt(rem(a, b))
        case(f"{A} % {B}", exp)
        case(f"decimal.rem({A}, {B})", exp)

        c = cmp(a, b)
        case(f"tostring({A} < {B})", str(c < 0).lower())
        case(f"tostring({A} <= {B})", str(c <= 0).lower())
        case(f"tostring({A} > {B})", str(c > 0).lower())
        case(f"tostring({A} >= {B})", str(c >= 0).lower())
        case(f"tostring({A} == {B})", str(c == 0).lower())
        case(f"tostring({A} ~= {B})", str(c != 0).lower())
        case(f"tostring(decimal.lt({A}, {B}))", str(c < 0).lower())
        case(f"tostring(decimal.le({A}, {B}))", str(c <= 0).lower())
        case(f"decimal.min({A}, {B})", fmt(b if c >= 0 else a))
        case(f"decimal.max({A}, {B})", fmt(b if c < 0 else a))

        case(f"-{A}", fmt((-a[0], a[1])))
        case(f"decimal.neg({A})", fmt((-a[0], a[1])))
        case(f"decimal.abs({A})", fmt((abs(a[0]), a[1])))
        case(f"tostring(decimal.sign({A}))", str((a[0] > 0) - (a[0] < 0)))
        case(f"tostring(decimal.scale({A}))", str(-a[1]))
        case(f'string.format("%.17g", decimal.tonumber({A}))', "%.17g" % float(to_value(a)))

        places = random.choice([0, 0, 1, 2, 2, 3, random.randint(0, 28)])
        mode = random.choice(list(MODES))
        case(f'decimal.round({A}, {places}, "{mode}")', fmt(round_to(a, places, mode)))
        case(f"decimal.round({A}, {places})", fmt(round_to(a, places, "halfeven")))
        for fname, mname in (("floor", "tonegativeinfinity"), ("ceil", "topositiveinfinity"), ("trunc", "tozero")):
            case(f"decimal.{fname}({A})", fmt(round_to(a, 0, mname)))

        # integers mix in
        i = random.choice([0, 1, -1, 7, -42, 1000, random.randint(-(10**9), 10**9), random.randint(-(2**62), 2**62)])
        ai = (i, 0)
        case(f"{A} + {i}i", fmt(add(a, ai)))
        case(f"{i}i - {A}", fmt(add(ai, a, -1)))
        case(f"{A} * {i}i", fmt(mul(a, ai)))
        case(f"{i}i / {A}", fmt(div(ai, a)))
        case(f"{A} % {i}i", fmt(rem(a, ai)))
        case(f"tostring({A} < {i}i)", str(cmp(a, ai) < 0).lower())
        case(f"tostring({i}i <= {A})", str(cmp(ai, a) <= 0).lower())

        # text round trips through tostring
        case(f"tostring({A})", fmt(a))

    # fromstring on valid and invalid text
    for _ in range(n // 4):
        r = random.random()
        if r < 0.5:
            s = rand_dec_string()
        elif r < 0.7:
            s = rand_dec_string() + random.choice(["e3", "E-3", "e+2", "e-30", "e30", "e0"])
        elif r < 0.85:
            s = random.choice([" ", "\t1.5 ", " -2.50\n", "  7", "1 2", "", "abc", "1.2.3", "1e", "e5", "--1", "+-1", "1,5", "0x10", ".", "-", "+.", "1e500", "1e-500", "0e500", ".5", "5.", "-.5e1", "0.0000000000000000000000000000001"])
        else:
            s = rand_digits(random.randint(60, 75)) + random.choice(["", ".5", "e-40"])
        d = parse(s)
        case(f"fs({luau_string(s)})", "nil" if d is None else fmt(d))
    return list(cases)


PRELUDE = """local fs = decimal.fromstring
local out = {}
local function emit(f)
    local ok, r = pcall(f)
    if ok then
        out[#out + 1] = tostring(r)
    else
        out[#out + 1] = "ERR " .. (tostring(r):gsub("^.-:%d+: ", ""))
    end
end
"""


def run_batch(batch, mode):
    lines = [PRELUDE]
    # a function can only hold so many closures, so the cases go into functions of 3000
    for start in range(0, len(batch), 3000):
        lines.append("do local function chunk()")
        for expr, _ in batch[start : start + 3000]:
            lines.append(f"emit(function() return {expr} end)")
        lines.append("end chunk() end")
    lines.append('print(table.concat(out, "\\n"))')
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write("\n".join(lines))
        path = f.name
    cmd = ["./luau"] + (["--codegen"] if mode else []) + [path]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stderr[:500])
        sys.exit(2)
    return res.stdout.split("\n")


total = bad = 0
for b in range(BATCHES):
    batch = gen_batch(CASES)
    for mode in (False, True):
        got = run_batch(batch, mode)
        for (expr, expected), g in zip(batch, got):
            total += 1
            if g != expected:
                bad += 1
                if bad <= 12:
                    print("MISMATCH" + (" (codegen)" if mode else ""), expr[:160], "\n   got     ", g[:120], "\n   expected", expected[:120])
        if len(got) < len(batch):
            print("short output", len(got), len(batch))
            bad += 1
print(f"{total} cases, {bad} mismatches (seed {SEED})")
sys.exit(1 if bad else 0)

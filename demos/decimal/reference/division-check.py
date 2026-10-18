#!/usr/bin/env python3
"""Differential test for decimal division.

Generates random operand pairs, divides them with decimal.div in Luau, and compares the result with an independent
implementation of the documented rule written with Python integers:

  * the quotient has the largest scale (at most 28) for which the mantissa still fits in an int64,
  * it is rounded half-even,
  * trailing zeros are removed down to the preferred scale max(scale(a) - scale(b), 0).

Run from the repository root after `make luau config=release`:   python3 demos/decimal/reference/division-check.py
"""
import random
import subprocess
import sys
import tempfile

MAX = 2**63 - 1
random.seed(7)


def ndig(x):
    return len(str(x))


def ref_div(ma, sa, mb, sb):
    s0 = sa - sb
    pref = max(s0, 0)
    if ma == 0:
        return (0, pref)
    a, b = abs(ma), abs(mb)
    kmin, kmax = max(0, -s0), min(28 - s0, 38 - ndig(a))
    if kmin > kmax:
        return None
    k = next((kk for kk in range(kmax, kmin - 1, -1) if (a * 10**kk) // b <= MAX), kmin)
    q, r = divmod(a * 10**k, b)
    if 2 * r > b or (2 * r == b and q % 2 == 1):
        q += 1
    scale = s0 + k
    while q > MAX:
        q, rem = divmod(q, 10)
        q += 1 if rem > 5 or (rem == 5 and q % 2 == 1) else 0
        scale -= 1
    if scale < 0:
        return None
    while q % 10 == 0 and scale > pref and q != 0:
        q //= 10
        scale -= 1
    if q == 0:
        scale = min(scale, pref) if scale > pref else scale
    return ((-q if (ma < 0) != (mb < 0) else q), scale)


def fmt(m, s):
    d = str(abs(m))
    if s > 0:
        d = d.rjust(s + 1, "0")
        d = d[:-s] + "." + d[-s:]
    return ("-" if m < 0 else "") + d


pairs = []
for _ in range(20000):
    ma = random.randint(-(10 ** random.randint(1, 19)) + 1, 10 ** random.randint(1, 19) - 1)
    mb = random.randint(1, 10 ** random.randint(1, 19) - 1) * random.choice([1, -1])
    ma = ma % MAX if abs(ma) > MAX else ma
    mb = (mb % MAX or 1) if abs(mb) > MAX else mb
    pairs.append((ma, random.randint(0, 12), mb, random.randint(0, 12)))

source = "local pairs = {" + ",".join(f'{{"{fmt(ma, sa)}","{fmt(mb, sb)}"}}' for ma, sa, mb, sb in pairs) + "}\n"
source += 'local out = {}\nfor _, p in pairs do\n'
source += '  local ok, r = pcall(function() return decimal.div(decimal.fromstring(p[1]), decimal.fromstring(p[2])) end)\n'
source += '  table.insert(out, ok and tostring(r) or "ERR")\nend\nprint(table.concat(out, "\\n"))\n'

with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
    f.write(source)
    path = f.name

got = subprocess.run(["./luau", path], capture_output=True, text=True).stdout.split("\n")
bad = 0
for (ma, sa, mb, sb), g in zip(pairs, got):
    exp = ref_div(ma, sa, mb, sb)
    expected = "ERR" if exp is None else fmt(*exp)
    if g != expected:
        bad += 1
        if bad <= 8:
            print("MISMATCH", fmt(ma, sa), "/", fmt(mb, sb), "got", g, "expected", expected)
print(f"{len(pairs)} pairs, {bad} mismatches")
sys.exit(1 if bad else 0)

#!/usr/bin/env python3
"""Fuzz test for VM/src/lwide.h, the 256-bit arithmetic used by the decimal library.

Every operation is run with random and structured operands and the result is compared with Python's arbitrary precision integers.
The structured operands (limbs made only of 0, 1, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF and similar) are the ones that exercise the
rare paths of the division algorithm, such as the quotient estimate being one too large.

Run from the repository root:   python3 demos/decimal/reference/wide-fuzz.py [cases-per-operation] [seed]
"""
import random
import subprocess
import sys

CASES = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
SEED = int(sys.argv[2]) if len(sys.argv) > 2 else 20261018
random.seed(SEED)

MASK = (1 << 256) - 1
SPECIAL_LIMBS = [0, 1, 2, 3, 0x7FFFFFFE, 0x7FFFFFFF, 0x80000000, 0x80000001, 0xFFFFFFFD, 0xFFFFFFFE, 0xFFFFFFFF]

subprocess.run(
    ["c++", "-std=c++17", "-O2", "-Wall", "-Wextra", "-I", "VM/src", "demos/decimal/reference/wide-fuzz.cpp", "-o", "/tmp/wide-fuzz"],
    check=True,
)


def rand_bits(maxbits):
    return random.getrandbits(random.randint(1, maxbits))


def special_number(limbs=None):
    limbs = limbs or random.randint(1, 8)
    value = 0
    for i in range(limbs):
        limb = random.choice(SPECIAL_LIMBS) if random.random() < 0.8 else random.getrandbits(32)
        value |= limb << (32 * i)
    return value


def edge_number():
    k = random.randint(0, 255)
    choice = random.randint(0, 6)
    if choice == 0:
        return (1 << k) - 1
    if choice == 1:
        return 1 << k
    if choice == 2:
        return (1 << k) + 1
    if choice == 3:
        return min(10 ** random.randint(0, 77), MASK)
    if choice == 4:
        return min(10 ** random.randint(1, 77) - 1, MASK)
    if choice == 5:
        return MASK - random.randint(0, 3)
    return random.randint(0, 3)


def operand(maxbits=256):
    r = random.random()
    if r < 0.5:
        return rand_bits(maxbits)
    if r < 0.8:
        return special_number() & ((1 << maxbits) - 1)
    return edge_number() & ((1 << maxbits) - 1)


cases = []  # (input line, expected output)

for _ in range(CASES):
    a, b = operand(), operand()
    cases.append((f"add {a} {b}", str((a + b) & MASK)))
    if a < b:
        a, b = b, a
    cases.append((f"sub {a} {b}", str(a - b)))
    a, b = operand(), operand()
    cases.append((f"cmp {a} {b}", str((a > b) - (a < b))))
    cases.append((f"cmp {a} {a}", "0"))

for _ in range(CASES):
    abits = random.randint(1, 255)
    a = operand(abits)
    b = operand(256 - a.bit_length() if a.bit_length() < 256 else 1)
    cases.append((f"mul {a} {b}", str(a * b)))
    # the realistic shapes: mantissa times mantissa, mantissa times a power of ten
    a, b = operand(90), operand(90)
    cases.append((f"mul {a} {b}", str(a * b)))
    a, p = operand(90), random.randint(0, 28)
    cases.append((f"mul {a} {10 ** p}", str(a * 10 ** p)))
    m = random.getrandbits(32)
    a = operand(224)
    cases.append((f"mulsmall {a} {m}", str((a * m) & MASK)))

for _ in range(CASES):
    n = operand()
    d = operand() or 1
    cases.append((f"divmod {n} {d}", f"{n // d} {n % d}"))
    # the realistic shapes: numerator scaled by a power of ten over a mantissa; value over a power of ten
    n, d, k = operand(90), operand(90) or 1, random.randint(0, 28)
    cases.append((f"divmod {n * 10 ** k} {d}", f"{n * 10 ** k // d} {n * 10 ** k % d}"))
    n, k = operand(256), random.randint(1, 77)
    cases.append((f"divmod {n} {10 ** k}", f"{n // 10 ** k} {n % 10 ** k}"))
    # structured operands with many limbs, which is where algorithm D's rare corrections happen
    n, d = special_number(8), special_number(random.randint(2, 8)) or 1
    cases.append((f"divmod {n} {d}", f"{n // d} {n % d}"))
    n, d = special_number(8), special_number(random.randint(1, 3)) or 1
    cases.append((f"divmod {n} {d}", f"{n // d} {n % d}"))

for _ in range(CASES // 4):
    a = operand()
    cases.append((f"digits {a}", str(len(str(a))) if a else "0"))
    cases.append((f"bits {a}", str(a.bit_length())))
for k in range(78):
    cases.append((f"pow10 {k}", str(10 ** k)))
    cases.append((f"digits {10 ** k}", str(k + 1)))
    cases.append((f"digits {10 ** k - 1}", str(k) if k else "0"))

# classic corner cases for algorithm D (from Hacker's Delight's divmnu tests, widened to 32-bit limbs)
def limbs(*ls):
    return sum(l << (32 * i) for i, l in enumerate(ls))


for u, v in [
    (limbs(0, 0, 0x80000000, 0x7FFFFFFF), limbs(1, 0, 0x80000000)),
    (limbs(0, 0xFFFFFFFE, 0x80000000), limbs(0xFFFFFFFF, 0x80000000)),
    (limbs(0, 0xFFFFFFFE, 0x80000000), limbs(0xFFFFFFFF, 0x80000000)),
    (limbs(3, 0, 0x80000000), limbs(1, 0, 0x20000000)),
    (limbs(0, 0, 0x80000000, 0x7FFFFFFF), limbs(0xFFFFFFFF, 0, 0x80000000)),
    (limbs(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF), limbs(0xFFFFFFFF, 0xFFFFFFFF)),
    (MASK, MASK),
    (MASK, 1),
    (MASK, MASK - 1),
    (0, 12345),
    (limbs(0, 0, 0, 0, 0, 0, 0, 0x80000000), limbs(1, 0, 0, 0x80000000)),
]:
    cases.append((f"divmod {u} {v}", f"{u // v} {u % v}"))

random.shuffle(cases)
payload = "\n".join(line for line, _ in cases) + "\n"
result = subprocess.run(["/tmp/wide-fuzz"], input=payload, capture_output=True, text=True, check=True)
got = result.stdout.split("\n")

bad = 0
for (line, expected), g in zip(cases, got):
    if g != expected:
        bad += 1
        if bad <= 10:
            print("MISMATCH", line[:200], "\n   got     ", g[:200], "\n   expected", expected[:200])

print(f"{len(cases)} cases, {bad} mismatches (seed {SEED})")
sys.exit(1 if bad or len(got) < len(cases) else 0)

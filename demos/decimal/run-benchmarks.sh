#!/usr/bin/env bash
# Runs the decimal benchmarks in the interpreter and with native code generation and prints markdown tables.
# Each number is the median of 5 runs. Needs: make luau config=release, and a C++ compiler for the host baseline.
#
#   ./demos/decimal/run-benchmarks.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
luau="${LUAU:-$root/luau}"
host="${DECIMAL_HOST:-/tmp/decimal-host}"
runs=5

median() { sort -n | sed -n "$(( (runs + 1) / 2 ))p"; }

# builds the host baseline if there is no binary yet
if [ ! -x "$host" ]; then
    (cd "$root" && c++ -std=c++17 -O2 -I VM/include -I Compiler/include -I CodeGen/include -I Common/include \
        demos/decimal/baseline/host.cpp build/release/libluaucodegen.a build/release/libluaucompiler.a \
        build/release/libluaubytecode.a build/release/libluauast.a build/release/libluauvm.a \
        build/release/libluaucommon.a -o "$host")
fi

nsper() { # command... -> median ns per addition reported by an addition benchmark
    for _ in $(seq $runs); do "$@" | head -1 | grep -o '([0-9.]* ns' | tr -d '( ns'; done | median
}

bytes() { # command... -> bytes per stored value
    "$@" | grep -o '([0-9]* bytes' | tr -d '( bytes'
}

cd "$root"
echo "### One addition (ns, median of $runs runs)"
echo
echo "| | interpreter | native codegen |"
echo "|---|---:|---:|"
printf "| number | %s | %s |\n" "$(nsper "$luau" demos/decimal/baseline/bench-number.luau)" "$(nsper "$luau" --codegen demos/decimal/baseline/bench-number.luau)"
printf "| core decimal | %s | %s |\n" "$(nsper "$luau" demos/decimal/baseline/bench-core.luau)" "$(nsper "$luau" --codegen demos/decimal/baseline/bench-core.luau)"
printf "| host userdata | %s | %s |\n" "$(nsper "$host" demos/decimal/baseline/bench-userdata.luau)" "$(nsper "$host" --codegen demos/decimal/baseline/bench-userdata.luau)"
printf "| pure Luau | %s | %s |\n" "$(nsper "$luau" demos/decimal/baseline/bench-pure.luau)" "$(nsper "$luau" --codegen demos/decimal/baseline/bench-pure.luau)"
echo
echo "### Memory per stored value (bytes, including the 16-byte slot in the array)"
echo
echo "| core decimal | host userdata | pure Luau |"
echo "|---:|---:|---:|"
printf "| %s | %s | %s |\n" "$(bytes "$luau" demos/decimal/baseline/memory-core.luau)" "$(bytes "$host" demos/decimal/baseline/memory-userdata.luau)" "$(bytes "$luau" demos/decimal/baseline/memory-pure.luau)"
echo
echo "### Core decimal operations (ns per operation)"
echo
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for mode in interp codegen; do
    flag=""; [ "$mode" = codegen ] && flag="--codegen"
    for i in $(seq $runs); do "$luau" $flag demos/decimal/benchmark.luau > "$tmp/$mode.$i"; done
done
echo "| operation | interpreter | native codegen |"
echo "|---|---:|---:|"
labels="$(cut -f1 "$tmp/interp.1")"
IFS=$'\n'
for label in $labels; do
    a="$(for i in $(seq $runs); do grep -F "$label	" "$tmp/interp.$i" | cut -f2; done | median)"
    b="$(for i in $(seq $runs); do grep -F "$label	" "$tmp/codegen.$i" | cut -f2; done | median)"
    printf "| %s | %s | %s |\n" "$label" "$a" "$b"
done

#!/usr/bin/env bash
# Measures the external mlua-decimal crate (an exact Decimal userdata for mlua) and compares it with the core decimal type.
#
#   ./demos/decimal/external/run.sh
#
# Needs a Rust toolchain (the first run downloads and builds mlua with a vendored Luau, about a minute) and the release `luau` binary.
# Absolute times are not comparable across the two: the Luau that mlua vendors is built with different flags (a plain number addition
# takes 3.5 ns there and 1.5 ns in this repository), so every table also shows the plain number addition for scale.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
luau="${LUAU:-$root/luau}"

cargo build --release --manifest-path "$here/Cargo.toml" >&2
bin="$here/target/release/mlua-decimal-compare"

median() { sort -n | sed -n 3p; }

echo "### One addition (ns, median of 5)"
echo
for i in 1 2 3 4 5; do "$bin" "$here/add.luau" 2>/dev/null | grep -o '([0-9.]* ns' | tr -d '( ns'; done | median | sed 's/^/mlua-decimal: /'
for i in 1 2 3 4 5; do "$luau" "$root/demos/decimal/baseline/bench-core.luau" | grep -o '([0-9.]* ns' | tr -d '( ns'; done | median | sed 's/^/core decimal: /'
echo
echo "### Memory per stored value"
"$bin" "$here/memory.luau" 2>/dev/null
"$luau" "$root/demos/decimal/baseline/memory-core.luau"
echo
echo "### Operations (ns per operation): mlua-decimal"
"$bin" "$here/ops.luau" 2>/dev/null
echo
echo "### What works"
"$bin" "$here/probe.luau" 2>/dev/null
echo
echo "### The 75 .NET cases"
if command -v dotnet >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    (cd "$tmp" && cp "$root/demos/decimal/dotnet/cases.cs" . && dotnet run cases.cs 2>/dev/null | grep " = " > net.txt)
    "$bin" "$here/cases.luau" 2>/dev/null > "$tmp/mlua.txt"
    echo "differences from .NET ($(grep -c '^<' <(diff "$tmp/net.txt" "$tmp/mlua.txt") || true) lines):"
    diff "$tmp/net.txt" "$tmp/mlua.txt" | grep '^[<>]' || true
else
    echo "dotnet is not installed, skipping"
fi

#!/usr/bin/env bash
# Runs the same decimal cases through .NET System.Decimal (cases.cs) and through Luau (cases.luau)
# and prints the lines that differ. The expected set of differences is in differences.expected;
# every one of them is a consequence of the 90-bit mantissa (27 digits always) or of how doubles are converted.
#
#   ./demos/decimal/dotnet/compare.sh            compare against differences.expected
#   ./demos/decimal/dotnet/compare.sh --update   rewrite differences.expected
#   ./demos/decimal/dotnet/compare.sh --full     print both outputs side by side
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
luau="${LUAU:-$here/../../../luau}"

if ! command -v dotnet >/dev/null 2>&1; then
    echo "dotnet is not installed, skipping the .NET comparison" >&2
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

(cd "$tmp" && cp "$here/cases.cs" . && dotnet run cases.cs 2>/dev/null | grep " = " > net.txt)
"$luau" "$here/cases.luau" > "$tmp/luau.txt"

case "${1:-}" in
--full)
    paste -d'\n' "$tmp/net.txt" "$tmp/luau.txt" | awk 'NR % 2 == 1 { printf ".NET  %s\n", $0 } NR % 2 == 0 { printf "Luau  %s\n\n", $0 }'
    ;;
--update)
    diff "$tmp/net.txt" "$tmp/luau.txt" > "$here/differences.expected" || true
    echo "updated differences.expected ($(grep -c '^<' "$here/differences.expected") differing lines)"
    ;;
*)
    diff "$tmp/net.txt" "$tmp/luau.txt" > "$tmp/differences.txt" || true
    if diff -u "$here/differences.expected" "$tmp/differences.txt"; then
        echo "dotnet comparison: $(grep -c '^<' "$tmp/differences.txt") expected differences, $(wc -l < "$tmp/net.txt" | tr -d ' ') cases"
    else
        echo "dotnet comparison: the set of differences changed" >&2
        exit 1
    fi
    ;;
esac

#!/usr/bin/env bash
# Runs the decimal demo suite and checks the output against the committed .expected files.
#
#   ./demos/decimal/run.sh              check everything
#   ./demos/decimal/run.sh --update     rewrite the .expected files from the current behavior
#   ./demos/decimal/run.sh 05 07        only the demos whose name starts with 05 or 07
#
# Every demo is run twice, in the interpreter and with --codegen (native code generation), and both outputs
# must be identical. 13-typing.luau is checked with luau-analyze instead, and its "-- ERROR" markers must
# match the diagnostics line for line.
# Build first with: make luau luau-analyze config=release
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
luau="${LUAU:-$root/luau}"
analyze="${LUAU_ANALYZE:-$root/luau-analyze}"

update=0
filters=()
for arg in "$@"; do
    if [ "$arg" = "--update" ]; then update=1; else filters+=("$arg"); fi
done

cd "$root"
pass=0
fail=0

wanted() {
    [ ${#filters[@]} -eq 0 ] && return 0
    for f in "${filters[@]}"; do
        case "$(basename "$1")" in "$f"*) return 0 ;; esac
    done
    return 1
}

check() { # name expected-file actual-file
    if [ "$update" = 1 ]; then
        cp "$3" "$2"
        echo "updated  $1"
        pass=$((pass + 1))
    elif diff -u "$2" "$3" > /tmp/decimal-demo-diff.$$ 2>&1; then
        echo "ok       $1"
        pass=$((pass + 1))
    else
        echo "FAILED   $1"
        head -40 /tmp/decimal-demo-diff.$$
        fail=$((fail + 1))
    fi
    rm -f /tmp/decimal-demo-diff.$$
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for script in "$here"/[0-9][0-9]-*.luau; do
    wanted "$script" || continue
    name="$(basename "$script" .luau)"
    rel="demos/decimal/$name.luau"

    if [ "$name" = "13-typing" ]; then
        "$analyze" "$rel" > "$tmp/$name.out" 2>&1
        # every line marked ERROR must have a type error, and no other line may
        grep -n -- '-- ERROR' "$rel" | cut -d: -f1 | sort -n > "$tmp/marked"
        grep -o "13-typing.luau([0-9]*" "$tmp/$name.out" | grep -o '[0-9]*$' | sort -n -u > "$tmp/reported"
        if ! diff "$tmp/marked" "$tmp/reported" > "$tmp/markers.diff"; then
            echo "FAILED   $name (ERROR markers and diagnostics disagree)"
            cat "$tmp/markers.diff"
            fail=$((fail + 1))
            continue
        fi
        check "$name (analyzer)" "$here/$name.expected" "$tmp/$name.out"
        continue
    fi

    "$luau" "$rel" > "$tmp/$name.out" 2>&1
    "$luau" --codegen "$rel" > "$tmp/$name.codegen.out" 2>&1
    if ! diff -q "$tmp/$name.out" "$tmp/$name.codegen.out" > /dev/null; then
        echo "FAILED   $name (interpreter and --codegen outputs differ)"
        diff "$tmp/$name.out" "$tmp/$name.codegen.out" | head -20
        fail=$((fail + 1))
        continue
    fi
    check "$name" "$here/$name.expected" "$tmp/$name.out"
done

if [ ${#filters[@]} -eq 0 ] && [ "$update" = 0 ]; then
    "$here/dotnet/compare.sh" && echo "ok       dotnet comparison" || { echo "FAILED   dotnet comparison"; fail=$((fail + 1)); }
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]

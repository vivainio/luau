# The external alternative: mlua-decimal

[`mlua-decimal`](https://github.com/vivainio/mlua-decimal) exposes an exact decimal to Luau from the host side: a Rust userdata on top
of `rust_decimal` (96-bit mantissa, 28 digits, scale kept), installed with `mlua_decimal::install(&lua)`. It needs no change to the Luau
VM. This directory measures it and compares it with the core decimal type of this branch.

`run.sh` builds a small harness (`src/main.rs`: install the crate, run a script) and runs:

| script | what it measures |
|---|---|
| `add.luau`, `memory.luau`, `ops.luau` | the same loops as `../benchmark.luau` and `../baseline/` |
| `probe.luau` | which operations work on the userdata |
| `cases.luau` | the 75 cases of `../dotnet/cases.luau`, translated (`1.5d` becomes `D"1.5"`), compared with .NET |

The article that discusses the results is in the Luau decimal series: "A core type or a host library?".

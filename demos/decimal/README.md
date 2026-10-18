# Decimal demo suite

Executable demonstrations of how the `decimal` type behaves in this implementation. Each demo is a small Luau
script that prints labelled results, and the committed `.expected` file next to it is the output the
implementation is required to produce. The demos are written to be read: open one next to its `.expected` file.

| Demo | What it shows |
|---|---|
| `01-basics` | literals, the type, printing, the library at a glance |
| `02-scale` | scale is preserved; equality and ordering are numeric |
| `03-floating-point` | the classic double surprises next to the decimal results |
| `04-arithmetic` | `+ - *`, negation, compound assignment, mixing with integers |
| `05-division` | `/` and `%`, preferred scale, non-terminating quotients, division by zero |
| `06-rounding` | all five rounding modes on a grid of inputs, floor/ceil/trunc, why half-even |
| `07-conversions` | `create`, `fromstring`, `tostring`, `tonumber`, accepted and rejected strings |
| `08-mixing` | what mixes with what: integers yes, numbers and strings no; strict equality |
| `09-limits` | the 90-bit mantissa: digits that fit, rounding beyond that, overflow, scale cap |
| `10-money` | invoices, vat, discounts, splitting a bill, interest, currency conversion |
| `11-containers` | tables, sorting, aggregation, functions, strings, library functions that refuse decimals |
| `12-errors` | a catalog of every error message |
| `13-typing` | the static types, checked with `luau-analyze`, with `-- ERROR` markers verified line by line |
| `benchmark` | timings of decimal operations; `run-benchmarks.sh` runs them with the baselines in the interpreter and with `--codegen` and prints the tables (not checked by `run.sh`, the numbers vary by machine) |
| `baseline/` | what an embedder can do without a core type: a pure-Luau decimal and a host-registered userdata decimal, with benchmarks and a list of where they fall short |
| `external/` | the real host-side alternative, the `mlua-decimal` crate (a Rust userdata on `rust_decimal`): speed, memory, what works, and its 75 .NET cases, via a small Rust harness |
| `dotnet/` | the same cases run through .NET `System.Decimal`, with the expected set of differences |

## Running

```bash
make luau luau-analyze config=release
./demos/decimal/run.sh              # check everything
./demos/decimal/run.sh 05 07        # only some demos
./demos/decimal/run.sh --update     # rewrite the .expected files after an intended change
```

Every demo runs twice, in the interpreter and with `--codegen`, and both outputs must be identical. The `.NET`
comparison needs the `dotnet` SDK and is skipped when it is not installed; `dotnet/compare.sh --full` prints both
outputs side by side.

## Reading the output

- `1.50` and `1.5` are different representations of the same value; `==` ignores the scale, printing does not.
- Anything that looks surprising next to .NET is listed in `dotnet/differences.expected` together with its cause:
  the 90-bit mantissa (27 digits always, 28 up to 1.24e27, instead of 28 to 29), and how a double is converted.

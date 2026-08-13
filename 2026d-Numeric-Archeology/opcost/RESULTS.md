# Operator costs for 1C types, measured

`procost` for every comparison operator in PostgreSQL is **1**, for `int4` and for
`mvarchar` alike. This measures what those operators really cost, so the catalog
can be told the truth.

## Method

`opcost_bench()` (see `opcost.c`) calls the operator's support function in a tight
loop through `FunctionCallInvoke` — the same entry point the expression
interpreter uses — with the operands built once beforehand. No relation is
touched, so there is no disk, no buffer manager and no tuple deforming in the
measurement. The empty-loop floor is 1.5 ns; a call of `int4eq` is 2.24 ns.

Two decisions matter more than anything else about the numbers:

**Operands are packed into the one-byte varlena header form.** A type's input
function returns a four-byte header; `heap_fill_tuple` converts anything that fits
to the short form when storing it. Everything in a 1C table is therefore
short-header, and for a short-header input `PG_GETARG_NUMERIC` *detoasts* —
`VARATT_IS_EXTENDED` is true for one-byte headers — which means `palloc` +
`memcpy` + `pfree` per argument per call. Benchmarking the input-function form
measures a path this workload never takes; the first version of this benchmark did
exactly that and produced numbers that were wrong by a factor of two.
`opcost_width()` reports the width actually compared, so the claim is checkable.

**Widths are the median widths of the two 1C databases** (`pg_statistic` on
`erp_v` and `cherkizovo`, which agree closely):

| type | median | p75 | p95 | max |
|---|---:|---:|---:|---:|
| `numeric` | 3 B | 5 | 6 | 12 |
| `bytea` | 17 B | 17 | 20 | 1789 |
| `mvarchar` | 9 B | 40 | 125 | 1479 |
| `mchar` | 27 B | 27 | 44 | 194 |
| `timestamp` | 8 B | | | |
| `integer` | 4 B | | | |
| `boolean` | 1 B | | | |

Five repetitions per case, minimum reported; spread between repetitions was
under 5% except where noted. Machine: 8 CPU, PostgreSQL 18.3, `-O2`, JIT off.

## Measured, nanoseconds per call

Both builds shown because the `numeric` figures differ sharply between them.
`A` = `1C_18_1` (upstream numeric code), `B` = `1C_18_1-numeric-unpack`.

| operator | width | A, ns | B, ns | A cost | B cost |
|---|---:|---:|---:|---:|---:|
| `int4eq` / `int4lt` / `btint4cmp` | 4 | **2.24** | 2.24 | **1.0** | 1.0 |
| `booleq` / `boollt` / `btboolcmp` | 1 | 2.24 | 2.25 | 1.0 | 1.0 |
| `timestamp_eq` / `_lt` / `_cmp` | 8 | 2.24 | 2.24 | 1.0 | 1.0 |
| `hashint4` | 4 | 3.92 | 3.93 | 1.8 | 1.8 |
| `timestamp_hash` | 8 | 5.40 | 5.43 | 2.4 | 2.4 |
| `bytealt` / `byteale` / `byteagt` / `byteage` | 17 | 9.60 | 9.49 | 4.3 | 4.2 |
| `byteacmp` | 17 | 9.90 | 10.07 | 4.4 | 4.5 |
| `hashbytea` | 17 | 13.54 | 13.66 | 6.0 | 6.1 |
| `byteaeq` / `byteane` | 17 | 12.85 | 12.66 | 5.7 | 5.7 |
| `hash_numeric` | 5 | 22.05 | 16.70 | 9.8 | 7.5 |
| `numeric_lt` / `_le` / `_gt` / `_ge` | 5 | 32.74 | 23.71 | 14.6 | 10.6 |
| `numeric_cmp` | 5 | 33.09 | 24.21 | 14.8 | 10.8 |
| `numeric_eq` / `_ne`, operands differ | 5 | 33.15 | 28.07 | 14.8 | 12.5 |
| `numeric_eq` / `_ne`, operands equal | 5 | 34.42 | 7.83 | 15.4 | 3.5 |
| `mchar_icase_eq`, equal | 31 | 70.11 | 74.09 | 31 | 33 |
| `mchar_icase_eq`, differ | 31 | 94.21 | 95.79 | 42 | 43 |
| `mchar_icase_lt` | 31 | 95.66 | 96.70 | 43 | 43 |
| `mchar_icase_cmp` | 31 | 96.66 | 97.73 | 43 | 44 |
| `mvarchar_icase_eq`, equal | 9 | 80.95 | 83.95 | 36 | 37 |
| `mvarchar_icase_eq`, differ | 9 | 120.62 | 122.03 | 54 | 54 |
| `mvarchar_icase_lt` | 9 | 122.65 | 123.78 | 55 | 55 |
| `mvarchar_icase_cmp` | 9 | 121.97 | 123.47 | 54 | 55 |
| `mvarchar_hash` | 9 | 315.60 | 318.52 | **141** | 142 |
| `mchar_hash` | 31 | 353.86 | 351.50 | **158** | 157 |

For reference, the type 1C does not use: `texteq` 15.1 ns (6.7), `bttextcmp`
78.7 ns (35).

## What the code says, per type

**`int4`, `bool`, `timestamp`** — `int4eq` is `PG_RETURN_BOOL(arg1 == arg2)`. The
2.24 ns is essentially the indirect call and the loop; the comparison itself is
one instruction. These are the only types in a 1C database that a cost of 1
describes correctly.

**`bytea`** — pass-by-reference but no detoast in the equality path:
`byteaeq` uses `PG_GETARG_BYTEA_PP` (packed, no copy), compares lengths, then one
`memcmp`. Width barely matters: 5 B and 17 B measure the same, because 16 bytes is
one `memcmp` call either way. The ordering operators go through `byteacmp` →
`memcmp` + length tiebreak, slightly cheaper than `byteaeq` because equality also
has to prove the lengths match first. So ~4–6, driven by call overhead and one
detoast-free pointer walk rather than by the data.

**`numeric`** — the expensive one, and for reasons that have nothing to do with
arithmetic. In the unpatched build both arguments go through
`PG_GETARG_NUMERIC` → `pg_detoast_datum` → `detoast_attr`, whose short-header
branch does `palloc` + `memcpy`; then `cmp_numerics`; then `pfree` twice. That is
~33 ns, **15× an `int4` comparison for a 5-byte value**. With
`numeric_unpack_local` the copy goes to a stack buffer instead and the cost drops
to 24 ns for ordering (10.6) and to 7.8 ns for a successful equality (3.5), where
the `memcmp` shortcut returns before any unpacking.

Note the shape of the patched `numeric_eq`: 3.5 when equal, 12.5 when not. A
single `procost` cannot express that. For a filter — where an equality mostly
fails — the honest number is the pessimistic one.

**`mvarchar` and `mchar`** — by far the worst, and this is the finding worth
acting on. The default operators are the **case-insensitive** ones
(`mvarchar_icase_eq`, `mchar_icase_eq`), so every comparison lowercases both
operands before comparing: a 9-byte `mvarchar` equality costs **54× an `int4`
equality**, and the hash functions cost **141–158×**. `mchar` at 31 bytes is
cheaper per byte than `mvarchar` at 9 only because `mchar` is blank-padded and the
comparison can stop earlier.

A `HashAggregate` grouping by one `mvarchar` column pays 142 units per row for the
hash alone, plus 54 per bucket collision check, against the 1 unit the planner
currently assumes. Group by four such columns and the planner is out by nearly
three orders of magnitude on that node.

## Caveats

- These are single-call costs on warm caches with the operands in L1. In a real
  scan the datum arrives from a shared buffer and the cache misses are charged
  elsewhere; `cpu_operator_cost` is not meant to cover them.
- `procost` is a `float4` multiplier of `cpu_operator_cost` (0.0025 by default), so
  raising `numeric_eq` to 15 charges 0.0375 per comparison. That changes plan
  choice, not just cost display: qual ordering, index-vs-seqscan crossovers, hash
  versus sort aggregation.
- Costs measured on this CPU. The ratios are stable across x86-64 but the absolute
  ns are not portable.
- The two builds agree everywhere except `numeric`, which is the expected result
  and a decent check that the harness measures what it claims.

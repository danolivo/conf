# v3: crash fix + division-free hot paths

Same harness and machine class as v2 (GCP `c3-standard-22`, Xeon Platinum 8481C,
us-east1-b, PG 18.3, base `567a42b4aa9`, `CFLAGS=-O2`, no `--enable-cassert`),
5M rows, 10 complete interleaved reps. VM deleted.

---

## The headline is not a performance number

While reviewing the sortsupport path for an optimisation opportunity I found
that **`ORDER BY` on numeric could crash the backend.**

`numeric_abbrev_convert()` opened with `PG_DETOAST_DATUM_PACKED()` and a
`VARATT_IS_SHORT()` realignment dance — varlena operations on a type that is now
fixed-width and non-toastable. They reinterpret the first byte of the packed
value as a varlena header. A mantissa with bit 60 set makes `VARATT_IS_SHORT()`
read true, `VARSIZE_SHORT() - VARHDRSZ_SHORT` underflows to `(size_t) -1`, and
the `memcpy` runs off the end of the datum.

```
-- reproducer on v2 and earlier: segfaults the backend
CREATE TABLE big AS SELECT (1152921504606846976::numeric + i) v
                   FROM generate_series(1,50000) i;
SET work_mem='64kB';
SELECT count(*) FROM (SELECT v FROM big ORDER BY v) t;
```

This needs ≥19 significant digits (2^60 ≈ 1.15×10^18). Below that the high half
of the packed value is zero, which reads as "not short", which is the only
reason every test so far passed. Sorting money-sized values was fine; sorting
account totals or scientific data was not.

Same bug class as the `jsonb_util.c` and `jsonpath.c` fixes. My earlier
look-around searched for `VARSIZE`/`VARDATA` and missed the detoast macros, so
this time I swept the whole tree for every varlena and detoast macro applied to
a Numeric, plus all references to the old packed layout. **This was the only
remaining site**; the `VARHDRSZ` hits in the typmod helpers are the historical
typmod offset, and `VARDATA_ANY(sstate)` operates on a genuine `bytea`
aggregate state.

The fix reads the datum in place, and — usefully — the correct version is also
the faster one: the scaled-integer mantissa is a better source for an
abbreviated key than a digit array, so the realignment buffer and the
`NumericVar` round trip both disappear.

**Sort correctness is now verified rather than assumed:** output is
byte-identical to stock at `work_mem` 64kB and 2GB (abbreviation on and
effectively off), zero misordered adjacent pairs over 300k mixed-magnitude
mixed-scale values, and an assert-enabled build cross-checks every
mantissa-derived weight and limb against a real unpack on every sort input
across the entire regression suite.

---

## Performance work: removing 128-bit division

`objdump` showed 42 call sites to libgcc's `__udivti3`/`__umodti3` in
`numeric.o`, concentrated in the unpack path, the hash path and division.
Neither x86-64 nor AArch64 has a 128-bit divide instruction, so each is a
function call of tens of cycles, versus ~5 for a compiler-generated
multiply-by-reciprocal.

Four changes:

- **`numeric_dec128_int128_to_var()`** (the unpack, on every slow-path
  operation): added a uint64 fast lane. When the whole coefficient aligned to a
  limb boundary fits a uint64 — anything up to 16 significant digits, i.e.
  ordinary money and measurement columns — every limb is extracted with
  divisions by the constant `NBASE`, which the compiler strength-reduces. The
  wide path is retained unchanged for genuinely large values.
- **`numeric_dec128_canonical()`** (hash join / hash aggregate, once per row per
  side): strip trailing zeroes on the unsigned magnitude in a uint64 lane with
  constant divisors. The signed 128-bit form does not strength-reduce.
- **`numeric_dec128_ndigits()`** (called twice per division): replaced an
  O(digits) loop of 128-bit comparisons with a `clz`-based estimate plus one
  correction.
- **`numeric_dec128_scaled_div()`**: 64-bit lane when the shifted numerator and
  divisor both fit.

A note on method: static call-site counts went *up* (42 → 50), because the
uint64 lanes are additions and the wide lanes remain. Counting call sites is the
wrong metric — it counts cold paths. What matters is whether the hot path
executes them, and that only measurement can settle.

---

## Tier A — marginal cost per operation

| op | stock | v2 | **v3** | v3 vs stock |
|---|---|---|---|---|
| add | 53.1 | 10.2 | **10.5** | 0.20× |
| sub | 52.0 | 10.6 | **10.9** | 0.21× |
| mul | 57.2 | 12.0 | **12.5** | 0.22× |
| cmp | 21.7 | 8.1 | **8.0** | 0.37× |
| div | 93.1 | 49.0 | **46.7** | **0.50×** |

Division improved ~5% (49.0 → 46.7 ns). Everything else is flat within noise.

## Tier B — query level

| query | stock ms | v2 | **v3** | v3 vs stock |
|---|---|---|---|---|
| `sum(v+v+…)` 8 adds | 2485.0 | 0.30× | **750.0** | 0.30× |
| `sum((v+v)*v-v)` | 1263.1 | 0.41× | **524.3** | 0.42× |
| `sum(v*w)` | 701.2 | 0.59× | **423.2** | 0.60× |
| `sum(v/w)` | 879.0 | 0.63× | **575.3** | 0.65× |
| `sum(v)` | 399.5 | 0.75× | **296.0** | 0.74× |
| `avg(v)` | 399.5 | 0.75× | **295.4** | 0.74× |
| `GROUP BY v` hash agg | 898.9 | 0.75× | **642.5** | **0.71×** |
| `WHERE v > 5.00` | 444.4 | 0.77× | **340.2** | 0.77× |
| **`count(v::int)`** | 543.3 | 1.09× *(slower)* | **531.8** | **0.98× (no difference)** |
| `cast_float8` | 889.5 | 0.98× | 873.9 | 0.98× |
| `scan_count` | 258.9 | 1.06× | 270.6 | 1.05× |
| hash join | 1013.1 | 1.01× | 1026.2 | 1.01× (n.s.) |
| `order_by_limit` | 0.1 | 0.94× | 0.1 | 0.98× (n.s.) |
| **`stddev(v)`** | 486.5 | 1.13× | **526.2** | **1.08×** |
| `count(v::text)` | 492.4 | 1.09× | 538.0 | 1.09× |
| `index_scan` | 84.1 | 1.11× | 93.0 | 1.11× |

Three real gains: `cast_int` went from 9% slower to no difference, `stddev` from
13% slower to 8%, and `hash_agg` from 0.75× to 0.71× — the last two are the
unpack and canonicalisation lanes showing up where predicted.

## Tier C — storage

Unchanged, as expected (these changes touch computation only): heap **+54.1%**,
btree index **+40.4%**. WAL read +12.5% here; across three runs the same 1M-row
probe has given +6.1%, −8.4% and +12.5%, so **WAL is still not reliably
measured** and needs its own run with `pg_stat_wal`.

---

## Honest assessment: this is the end of the road for `numeric.c`

The v3 gains are real but small, and that is exactly what the budget predicted
before I started:

| | ns/row |
|---|---|
| `count(v)` — scan and tuple deform only | **~54** |
| one add | ~10 |
| aggregate transition | ~5 |

Arithmetic is **~9% of `sum(v)`** and about a quarter of a two-operation query.
Division-free hot paths moved the operations that were already a small slice of
a query dominated by tuple access. Further micro-optimisation of this file will
not produce a large number.

### What would actually be much faster

**Tiered physical width, as DuckDB does** — `DECIMAL(p,s)` mapping to
int16/int32/int64/int128 by precision. For `p ≤ 18` an 8-byte payload is
pass-by-value, which removes the `palloc` that every arithmetic result
currently performs (`numeric_add_opt_error` still calls `palloc` and `pfree`),
removes a pointer dereference per value read, and cuts the row from 4+pad+16+16
to 4+pad+8+8 — turning **+54% heap into roughly +9%**, which also attacks the
54 ns/row scan floor. SPEC §9 dismissed the narrow tiers as storage-only; the
measurements say that is backwards. Your own §3.1 table agrees: dec64 add
1.90 ns versus dec128 6.75 ns is a 3.5× gap for identical arithmetic, and the
only difference is pass-by-value.

**But it cannot be done within one type.** `pg_type.typlen`/`typbyval` are
per-type, not per-typmod, and fmgr passes Datums uniformly — a
`numeric_add(numeric, numeric)` cannot know whether this particular column is
by-value or by-reference. DuckDB gets away with it because its executor is
templated on physical type and it has no fixed catalog width contract. In
PostgreSQL the achievable versions are: (a) a genuinely separate 8-byte type
with its own operators and implicit widening, which is the `dec64`/`dec128`
two-tier extension design you already have, or (b) making `numeric` itself
8-byte pass-by-value and accepting p ≤ 18, which is a different and much more
invasive experiment than this one.

**Beyond that, the remaining ceiling is the row store, not the type.** DuckDB's
advantage is vectorised execution over columnar batches — 2048 values per tight
loop, no per-value dispatch, no tuple header, no alignment padding. Matching
that needs a columnar table AM plus custom scan and aggregate nodes, which is a
far larger project than the type. The 5× arithmetic figure should not be read as
DuckDB parity being within reach.

**Cheap thing not yet tried:** `jit = on`. It was disabled per spec §3.1, which
was right when an add cost 30–90 ns. Now that a dec128 add is a couple of
instructions, LLVM can inline a whole expression tree and delete both the fmgr
dispatch and the `palloc`. For `sum_8add` — 8 pallocs and 8 indirect calls per
row — this could be significant, and it costs nothing but a GUC to test.

## Verification summary

- `make check`: 21/231 known failures, unchanged; no `TRAP` with assertions on.
- Differential vs stock, core bucket: **byte-for-byte identical**.
- Division/stddev bucket: **unchanged from v2** — the new division lane alters
  no output.
- Edge-case suite: unchanged.
- Crash reproducer: fixed; sort output identical to stock across `work_mem`
  settings; zero misordered pairs over 300k mixed values.
- Cross-scale hash and equality agreement (`1.5` = `1.500000000000000`) after
  the canonicalisation rewrite.
- One assertion fired during development and caught a genuine off-by-one in my
  own `ndigits` bound (the estimate reaches 38 for a 37-nine mantissa before
  correction). The algorithm was right; my claimed invariant was not.

# Phase 4 results: dec128 `numeric` vs stock `numeric`

Run 2026-08-11 on GCP `c3-standard-22` (Intel Xeon Platinum 8481C @ 2.70 GHz,
22 vCPU, 88 GB), Ubuntu 24.04, PostgreSQL 18.3. Both builds from commit
`567a42b4aa9` with identical configure flags and `CFLAGS=-O2`, no
`--enable-cassert`; they differ **only** by `numeric-dec128.patch`. Instance
deleted after the run.

Latency tiers: 5M rows, 9 fully-complete interleaved repetitions, single
backend pinned to one core, 32 GB `shared_buffers`, prewarmed, `jit=off`,
zero disk reads during measurement. Storage tier: 20M rows.

Measurement stability was very good — MAD is under 1% of the median on nearly
every row, and the bootstrap CIs are correspondingly tight. See "Caveats" for
what that does and does not license.

---

## Headline: this is a trade, not an improvement

The two representations do not differ by one factor. Fixed-width storage makes
**arithmetic between values** much cheaper and makes **getting a stored value
into arithmetic** more expensive. Which effect dominates is a property of the
query, not of the patch.

The single most useful predictor is **how many arithmetic operations a query
performs per numeric value it reads**:

| ops per value read | outcome |
|---|---|
| several (expressions, chained arithmetic) | **2–3× faster** |
| about one (plain `sum`, `avg`) | **~15% slower** |
| division anywhere | **40% slower** |
| storage- or IO-bound | **~50% more space** |

---

## Tier A — marginal cost per operation

Slope of execution time against operation count, so scan and aggregation
overhead lands in the discarded intercept. Spec §3.1's numbers are on an
Apple M4 Pro so absolute values are not comparable; the ratios are.

| op | stock ns/row | dec128 ns/row | ratio | spec §3.1 claimed ratio |
|---|---|---|---|---|
| add | 53.3 | 10.6 | **0.20× (5.1× faster)** | 4.3× faster |
| sub | 47.9 | 10.7 | **0.22× (4.5× faster)** | — |
| mul | 55.9 | 12.5 | **0.22× (4.5× faster)** | 2.8× faster |
| cmp | 22.6 | 8.4 | **0.37× (2.7× faster)** | ~43× faster |
| div | 91.8 | 146.1 | **1.59× (SLOWER)** | 2.3× faster |

Two of these contradict the spec and both are explainable:

**Division is 1.6× slower, where the spec predicted 2.3× faster.** This is a
direct consequence of a decision made during implementation: no
mantissa-level division fast path was written. Division therefore takes the
full NumericVar path *and* now additionally pays `round_var()` to clamp the
result to dec128's 15-digit scale ceiling. The spec's figure came from the
`dec64`/`dec128` extension prototype, which has a dedicated
`dec128_scaled_div()` doing long division on mantissas. That code was never
ported. This is a missing optimisation, not a defect in the representation.

**Comparison is 2.7× faster, not ~43×.** The spec's 0.2 ns/row for `dec128`
compare is below one clock cycle at 2.7 GHz and cannot be a per-row cost; it
looks like a measurement that eliminated the row rather than the comparison.
The real figure includes tuple deforming, which neither representation avoids.

---

## Tier B — query level

Ratio is dec128/stock; below 1.0 means dec128 is faster. CI is a bootstrap 95%
interval on the ratio of medians; p is Mann–Whitney U.

| query | stock ms | dec128 ms | ratio | 95% CI | verdict |
|---|---|---|---|---|---|
| `sum(v+v+…)` 8 adds | 2497.2 | 839.2 | **0.34×** | [0.34, 0.34] | 66% faster |
| `sum((v+v)*v-v)` | 1259.6 | 630.7 | **0.50×** | [0.50, 0.50] | 50% faster |
| `WHERE v > 5.00` | 463.5 | 332.4 | **0.72×** | [0.72, 0.72] | 28% faster |
| `GROUP BY v` (hash agg) | 873.9 | 641.1 | **0.73×** | [0.73, 0.74] | 27% faster |
| `sum(v*w)` | 686.9 | 548.8 | **0.80×** | [0.80, 0.80] | 20% faster |
| `ORDER BY v LIMIT 10` | 0.1 | 0.1 | 0.89× | [0.86, 0.94] | 11% faster |
| `cast_float8` | 850.7 | 868.8 | 1.02× | [1.02, 1.02] | no difference |
| `count(v)` scan | 248.8 | 261.0 | 1.05× | [1.05, 1.05] | ~5% slower |
| hash join on numeric | 975.3 | 1029.3 | 1.06× | [0.99, 1.07] | inconclusive |
| `index_scan` range | 84.4 | 93.5 | 1.11× | [1.09, 1.13] | 11% slower |
| `count(v::text)` | 480.7 | 534.9 | 1.11× | [1.11, 1.12] | 11% slower |
| `count(v::int)` | 509.6 | 569.3 | 1.12× | [1.12, 1.12] | 12% slower |
| **`sum(v)`** | 398.9 | 459.0 | **1.15×** | [1.15, 1.15] | **15% slower** |
| **`avg(v)`** | 398.2 | 459.3 | **1.15×** | [1.15, 1.16] | **15% slower** |
| `stddev(v)` | 482.8 | 558.7 | 1.16× | [1.16, 1.16] | 16% slower |
| **`sum(v/w)`** | 875.9 | 1226.9 | **1.40×** | [1.40, 1.40] | **40% slower** |

### `sum(v)` regresses 15%, and spec §3.2 claimed ×1.2 *faster*

This is the clearest failed prediction in the spec, and it reproduces cleanly
at scale with a CI of [1.15, 1.15]. The cause is structural rather than a bug:
in the extension prototype the accumulator worked directly on int128, whereas
in core `sum()` goes through `do_numeric_accum()` → `accum_sum_add()`, which is
NumericVar-based. Every row therefore pays one unpack that stock got for free
by pointing `digits` straight into the varlena. Fixed-width storage inherently
costs a conversion that variable-length storage did not.

`sum`, `avg` and `stddev` all regress by the same ~15%, consistent with a
single shared cause.

Both regressions have known fixes, already written or scoped:

- `sum`/`avg`: `0003-Use-an-int128-fast-sum-in-sum-numeric-and-avg-numeri.patch`
  in `~/pgdev-upstream` — wires an int128 accumulator into `do_numeric_accum()`,
  removing the per-row unpack entirely.
- division: port `dec128_scaled_div()` from the prototype.

Neither is in the current patch. With both, the loss column would shrink
substantially — but that is a prediction, not a measurement.

---

## Tier C — storage (20M rows, two numeric columns plus an int)

| metric | stock | dec128 | change |
|---|---|---|---|
| heap | 845 MiB | 1302 MiB | **+54.1%** |
| heap + indexes | 1274 MiB | 1905 MiB | +49.5% |
| btree index on numeric | 429 MiB | 602 MiB | +40.4% |

Worse than spec §3.3's +22% estimate, and the gap is explained by column
count: the test table carries two numeric columns, so it pays the 16-byte
fixed width *and* 8-byte (`typalign = 'd'`) padding twice per row. A
single-numeric-column table would land nearer the spec's figure. Any schema
with several numeric columns per row should expect the higher number.

**WAL volume was not measured reliably.** The 1M-row probe returned +6.1% in
the 20M run and −8.4% in the 5M run for an identical insert, so the
`pg_current_wal_lsn()` difference is picking up checkpoint and segment-boundary
effects rather than tuple size. Given the +54% heap, WAL almost certainly grows
too, but this harness cannot say by how much. It needs a dedicated run with
`pg_stat_wal` and checkpoints pinned down. **Treat WAL as an open question**,
which matters if the target system is replicated.

---

## Caveats

- **9 repetitions, not the planned 30.** Each rep costs ~9 min at 20M rows,
  so the latency tiers were rerun at 5M. The CIs are tight enough that more
  reps would not move the conclusions, but `hash_join` (p = 0.085) stayed
  inconclusive and would need more.
- **Latency at 5M rows, storage at 20M.** Per-operation cost is row-count
  invariant and 5M still exceeds L3 by a wide margin, so the ratios hold; the
  absolute millisecond figures are not comparable to spec §3.2's 20M numbers.
- **Turbo could not be disabled** — this GCP kernel exposes no
  `intel_pstate/no_turbo`, and the governor read back as `none`. Sub-1% MAD
  suggests it did not bite, but frequency behaviour was not under our control.
- **Parallel-query rows were not collected.** The run was stopped before that
  phase. Spec §3.2's ×3.0 two-worker figure is unverified here.
- **Synthetic data, not the real workload.** The ORM DDL and query mix
  (spec §7 items 2–3) were never supplied, so the mix above is a stand-in
  chosen to span the space, not a model of production.
- **No decision threshold was ever set** (spec §7 item 5), so no single
  yes/no verdict is issued here — only per-query effects. Supply a threshold
  and a weighted query mix and the verdict becomes mechanical.

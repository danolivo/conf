# Phase 4 re-run: dec128 `numeric` with both regressions fixed

Same harness, same machine class (GCP `c3-standard-22`, Intel Xeon Platinum
8481C @ 2.70 GHz, us-east1-b), same PostgreSQL 18.3 base commit
`567a42b4aa9`, same configure flags, no `--enable-cassert`. 5M rows, 10
complete interleaved repetitions for latency; 20M rows for storage. MAD is
again under 1% on nearly every row.

The two builds differ only by `numeric-dec128.patch`, which now additionally
contains the two fixes below. Instance deleted after the run.

---

## What changed in the patch

### 1. Division fast path

Ported `dec128_scaled_div()` from the `dec64`/`dec128` extension prototype:
long division on mantissas with a single-division fast path for the common
case where the shifted numerator still fits int128.

The non-obvious part was *not* the division. It was reproducing the result
scale. PostgreSQL picks a division's scale from the data
(`select_div_scale()`), and this build already clamps that to 15; the
prototype instead always returns the maximum scale. Adopting the prototype's
rule would have silently changed results that the Phase 3 differential run had
already validated. So `numeric_dec128_div_rscale()` reproduces
`select_div_scale()` exactly from the packed form, deriving each operand's
base-NBASE weight and leading limb from its mantissa's decimal digit count
rather than building any digit array.

Verified: `1000000::numeric/3` returns `333333.333333333333` — 12 decimals, the
data-dependent scale — **identically on both builds**, and the whole
known-divergence differential bucket is byte-for-byte unchanged from the
pre-fix patched build.

### 2. int128 fast sum accumulator

Adapted `0003-Use-an-int128-fast-sum-in-sum-numeric-and-avg-numeri.patch`.

The adaptation is *simpler and faster than upstream*, because a stored dec128
value already **is** an int128 coefficient plus a scale. Upstream needs
`numericvar_to_int128_scaled()` to convert a NumericVar digit array into a
coefficient, and rejects anything wider than four stored digits because the
conversion stops paying. Here `do_numeric_accum()` reads the mantissa and
scale straight out of the datum: no `init_var_from_num()`, no digit array, no
allocation, no memory-context switch, and no eligibility test beyond the
overflow check. That per-row unpack was exactly the 15% regression.

Promotion into the digit-array accumulator remains one-way and exact, so
results never depend on whether or when it happened.

**Two bugs found while verifying, both worth recording:**

An assertion-enabled run caught a state reaching the variance finaliser while
still in fast mode. Root cause: `numeric_deserialize()` constructs variance
states with `calcSumX2 = false` (the flag only drives whether the *transition
function* computes a sum of squares; deserialisation fills `sumX2` in
directly), so a "promoted = calcSumX2" rule did not fire for them.

Applying Tom Lane's "look around" rule turned up a second, worse instance:
`numeric_avg_deserialize()` would have read an `sumX128` it never wrote, i.e.
**silently returned a wrong sum for parallel `sum`/`avg`** rather than
crashing.

Rather than patch each site, the flag was inverted to `fastSum` (true = int128
sum in use). Zero — which is what `palloc0()` and `memset()` produce — now
means the safe digit-array representation, so the whole class of mistake is
unreachable instead of merely fixed. Three separate code paths build a state
that way.

**Known limitation, deliberate:** `numeric_avg_serialize()` promotes before
writing, keeping the parallel wire format byte-identical and leaving
`numeric_avg_deserialize()` untouched. Upstream instead ships the int128 with
a mode byte. The cost here is paid once per group per worker rather than per
row, but it does mean the fast representation's benefit stops at the
worker→leader boundary. Worth revisiting if parallel aggregation matters for
the decision.

### Correctness gates (all re-run after the fixes)

- `make check`: same 21/231 known failures, no new ones.
- Assertion-enabled `make check`: no `TRAP:` anywhere.
- Differential vs stock, core bucket: **byte-for-byte identical**.
- Known-divergence bucket: unchanged from the pre-fix patched build, i.e. the
  division fast path did not alter any output.
- Promotion is order-independent (spike at any position gives one answer).
- Parallel `sum`/`avg` == serial, both on ordinary values and with promotion
  actually exercised (18 × +10³⁷ then 18 × −10³⁷ per group).
- Window/moving-aggregate inverse transition, `FILTER`, `DISTINCT`, NaN/±Inf.

---

## Tier A — marginal cost per operation

| op | stock ns/row | dec128 before | dec128 **now** | now vs stock |
|---|---|---|---|---|
| add | 52.9 | 10.6 | **10.2** | **0.19× (5.2× faster)** |
| sub | 53.5 | 10.7 | **10.6** | **0.20× (5.0× faster)** |
| mul | 57.1 | 12.5 | **12.0** | **0.21× (4.8× faster)** |
| cmp | 21.6 | 8.4 | **8.1** | **0.37× (2.7× faster)** |
| div | 92.8 | 146.1 *(1.6× slower)* | **49.0** | **0.53× (1.9× faster)** |

Division went from 1.6× slower to 1.9× faster — a 3.0× improvement on that
operation alone. Spec §3.1 predicted 2.3× faster; 1.9× is the same order,
short of the prototype's figure because the result scale here is
data-dependent and clamped rather than fixed.

## Tier B — query level

| query | stock ms | dec128 before | dec128 **now** | now vs stock | 95% CI |
|---|---|---|---|---|---|
| `sum(v+v+…)` 8 adds | 2474.7 | 0.34× | **736.8** | **0.30×** | [0.30, 0.30] |
| `sum((v+v)*v-v)` | 1258.9 | 0.50× | **514.3** | **0.41×** | [0.41, 0.41] |
| `sum(v*w)` | 698.8 | 0.80× | **414.9** | **0.59×** | [0.59, 0.59] |
| **`sum(v/w)`** | 875.6 | 1.40× *(slower)* | **549.2** | **0.63×** | [0.63, 0.63] |
| **`sum(v)`** | 397.0 | 1.15× *(slower)* | **297.7** | **0.75×** | [0.75, 0.75] |
| **`avg(v)`** | 397.0 | 1.15× *(slower)* | **297.5** | **0.75×** | [0.75, 0.75] |
| `GROUP BY v` hash agg | 894.4 | 0.73× | 668.6 | 0.75× | [0.75, 0.75] |
| `WHERE v > 5.00` | 439.9 | 0.72× | 337.8 | 0.77× | [0.77, 0.77] |
| `ORDER BY v LIMIT 10` | 0.1 | 0.89× | 0.1 | 0.94× | inconclusive |
| `cast_float8` | 884.8 | 1.02× | 865.4 | 0.98× | no difference |
| hash join on numeric | 907.4 | 1.06× | 919.1 | 1.01× | no difference |
| `scan_count` | 255.6 | 1.05× | 271.8 | 1.06× | 5–7% slower |
| `count(v::text)` | 490.9 | 1.11× | 532.9 | 1.09× | 8–9% slower |
| `count(v::int)` | 508.1 | 1.12× | 551.7 | 1.09× | 8–9% slower |
| `index_scan` range | 82.9 | 1.11× | 91.8 | 1.11× | 10–13% slower |
| `stddev(v)` | 484.2 | 1.16× | 548.8 | 1.13× | 13% slower |

**Every query that regressed for arithmetic reasons now wins.** `sum` and
`avg` went from 15% slower to 25% faster; `sum(v/w)` from 40% slower to 37%
faster.

`stddev` still regresses 13%, and that is expected: variance states track a sum
of squares, which does not fit int128 for realistic inputs, so they are created
already promoted and never use the fast accumulator — the same reasoning as
upstream's `var_pop(int8)` precedent. Fixing it would need a different
approach, not this one.

The remaining losses are all non-arithmetic and all inherent to fixed-width
storage: reading more bytes per row (`scan_count`, `index_scan`) or converting
out of the type (`::text`, `::int`).

## Tier C — storage (20M rows, two numeric columns plus an int)

| metric | stock | dec128 | change |
|---|---|---|---|
| heap | 845 MiB | 1302 MiB | **+54.1%** |
| heap + indexes | 1274 MiB | 1905 MiB | +49.5% |
| btree index | 429 MiB | 602 MiB | +40.4% |
| WAL, 1M-row insert | 61 MiB | 69 MiB | +12.5% |

Unchanged by these fixes, as expected — they touch computation, not layout.
This run's WAL probe read +12.5%, versus +6.1% and −8.4% in the two earlier
runs for an identical insert. **WAL remains unreliably measured** by this
harness; the spread across runs is larger than any effect. Given +54% heap it
almost certainly grows, but a defensible figure needs a dedicated run with
`pg_stat_wal` and checkpoints pinned down.

---

## Where this leaves the decision

The trade is now much more one-sided than before, but it is still a trade:

| workload shape | outcome |
|---|---|
| arithmetic in expressions | **1.7–3.3× faster** |
| plain `sum` / `avg` | **1.3× faster** |
| division | **1.6× faster** |
| comparison / filtering / grouping | **1.3× faster** |
| `stddev` / `variance` | 13% slower |
| scanning, casting out, text output | 5–11% slower |
| storage | **~50% more space**, WAL unquantified |

So the CPU story is now a fairly clean win, and the case against is
essentially storage. Whether ~50% more heap and index space is acceptable is
not a question this benchmark can answer — it depends on whether the target
system is CPU-bound or IO/space-bound, and on replication cost that remains
unmeasured.

Two things still outstanding from before, neither affected by this work:

- **No decision threshold** (spec §7 item 5), so no single verdict is issued
  here. With a threshold and a weighted query mix the per-query CIs above turn
  into a mechanical answer.
- **Synthetic query mix.** The real ORM DDL and query mix (spec §7 items 2–3)
  were never supplied, so the weighting above is a stand-in. A division-heavy
  or `stddev`-heavy production mix would land differently — and note division
  still returns 15 decimals where stock returns up to 20, which an ORM may
  notice regardless of speed.

# Phase 4 benchmark: dec128 `numeric` vs stock `numeric`

Implements SPEC-numeric-as-dec128.md §6 Phase 4. The design goal there is
explicit and unusual: the deliverable is **not** "it got faster", it is a
defensible **yes / no / below the threshold of detectability**. So the harness is
built to be able to return "no difference" credibly, which means it has to be
able to *detect* a small difference and to *rule out* a large one.

## Why not just time some queries

Three failure modes this design guards against.

1. **Cherry-picking the operation.** The patched build is faster at some
   operations and slower at others — that is a measured fact, not a
   hypothetical (see "Known result going in" below). A benchmark that reports
   only chained arithmetic will conclude "yes, ×2"; one that reports only
   `sum(v)` will conclude "no, slower". Both are true and both are useless
   alone. Tier B therefore fixes the query mix in advance and reports every
   row, including the losses.

2. **Drift between builds.** Running all of build A then all of build B lets
   clock throttling, page-cache state and neighbour noise masquerade as an
   effect. Runs are **interleaved** A/B/A/B per repetition.

3. **Means over distributions.** Query latency is right-skewed with occasional
   large outliers; a mean is dominated by the tail and a t-test assumes
   normality it does not have. We report medians with MAD, and test with
   Mann–Whitney U, which assumes neither.

## Machine

**`c3-standard-22`** (22 vCPU, 88 GB, Intel Sapphire Rapids), `pd-balanced`
100 GB, Ubuntu 24.04 LTS, single zone.

Reasoning, since the brief allowed up to 64 cores and this is smaller:

- The quantity under test is **per-operation CPU cost in a single backend**.
  Core count does not improve that measurement; it only adds cost and, with
  more sockets/NUMA nodes, more variance. Extra cores would buy noise.
- 88 GB is the part that matters. The 20M-row table is ~700–850 MB depending
  on build, and we need it *entirely* in `shared_buffers` so we are measuring
  arithmetic and not the storage layer. 88 GB removes any doubt.
- 22 vCPU still covers the parallel-query rows of spec §3.2 (2 and 4 workers)
  with cores to spare and no oversubscription.
- C3 gives dedicated (not shared-core) vCPUs and a consistent CPU model, which
  matters more for reproducibility than raw width. Avoid `e2-*` and any
  `*-shared-core` shape: burstable credit accounting will silently distort
  microbenchmarks.

Downgrade to `c3-standard-8` to halve the cost — everything except the
4-worker parallel row is unaffected. Do **not** substitute a different CPU
family midway through a run.

Cost is roughly $1.1/hr for `c3-standard-22`; the full suite takes well under
an hour. **Delete the instance afterwards** — `provision.sh` prints the
command.

## Machine hygiene

`provision.sh` applies these, and `bench.sh` refuses to run if they are not in
place, because each one has been observed to produce double-digit percentage
artefacts:

| setting | why |
|---|---|
| `cpupower governor=performance` | frequency scaling otherwise ramps mid-query, and the *first* build measured pays the ramp |
| turbo disabled (`no_turbo=1`) | turbo residency depends on how hot the previous run left the package, which couples build A's result to build B's |
| `taskset -c 2` pinning, core 0–1 left free | migration between cores mid-query invalidates the per-op slope |
| THP `never` | khugepaged compaction pauses land as multi-ms outliers |
| `jit = off` | per spec §3.1; LLVM compile time swamps the effect being measured |
| `shared_buffers = 32GB` + `pg_prewarm` | measure CPU, not I/O |
| `track_io_timing = on`, verified zero reads | proves the above actually held |
| `max_parallel_workers_per_gather = 0` by default | parallelism is a separate, explicitly-labelled tier |
| deterministic data, no `random()` | both builds must see byte-identical input; `random()` also differs between builds because it routes through numeric |

## The three tiers

### Tier A — per-operation cost (the control)

This exists to answer "is the patched build faster at arithmetic *at all*". If
Tier A shows no difference, something is wrong with the build or the harness
and Tier B is not worth interpreting.

Rather than timing one operation and subtracting a baseline — which leaves the
result at the mercy of one noisy baseline number — we time
`count(v)`, `count(v+v)`, `count(v+v+v)` … up to 8 operations and take the
**slope** of time against operation count by least squares. The slope is the
marginal cost of one operation; the intercept absorbs scan and aggregation
overhead and is discarded. Reported in ns/row/op, comparable to spec §3.1.

Operations: add, subtract, multiply, divide, compare (`v > const`).

### Tier B — query level

Spec §3.2's mix, reproduced verbatim, plus the aggregation cases the earlier
work flagged. Every row is reported.

Includes `count(v::text)` because text output is on the path of every
client-visible query and was found to be doing redundant work; and a
`WHERE v > const` selectivity scan, an `ORDER BY v LIMIT 10` sort, a hash
aggregate and a hash join, which exercise comparison and hashing rather than
arithmetic.

### Tier C — the costs that are not latency

Easy to forget and capable of dominating the decision:

- **Relation size** (`pg_total_relation_size`). Spec §3.3 already records
  845 MB vs 692 MB — a ~22% storage regression, from 16 fixed bytes plus
  8-byte alignment padding versus packed varlena.
- **WAL volume** for the bulk load, by `pg_current_wal_lsn()` difference.
  A 22% larger tuple means proportionally more WAL, more full-page images and
  heavier checkpoints. On a write-heavy or replicated system this can outweigh
  any arithmetic win, and no latency measurement will show it.
- **Index size** for a btree on the numeric column.

## Known result going in

From a preliminary run in a 4-core VM (2M rows, single runs — directional
only, which is exactly why this harness exists):

| query | stock | patched |
|---|---|---|
| `count(v)` scan baseline | ~19 ms | ~19 ms |
| `sum(v)` | ~27 ms | **~31 ms (slower)** |
| `sum(v+v+v+v)` | ~87 ms | ~43 ms |
| `sum(v*v)` | ~48 ms | ~35 ms |
| `count(v::text)` | ~38 ms | ~35 ms |

Two things to carry into the analysis:

- **Chained arithmetic wins roughly 2×.** Consistent with the design intent.
- **`sum(v)` regresses ~15%, and spec §3.2 claims it should be ×1.2 *faster*.**
  That claim does not reproduce. The likely cause is structural: in the
  `dec64`/`dec128` extension prototype the accumulator worked directly on
  int128, whereas in core `sum()` goes through `do_numeric_accum()` →
  `accum_sum_add()`, which is NumericVar-based. Every row therefore pays one
  unpack that stock got for free by pointing `digits` into the varlena.
  Fixed-width storage inherently costs a conversion that varlena did not.

  If Tier B confirms this at scale, the fix is already written:
  `0003-Use-an-int128-fast-sum-in-sum-numeric-and-avg-numeri.patch` in
  `~/pgdev-upstream`. Decide before the run whether it is in scope, because it
  changes what the headline number means.

## Threshold — needed before the run, not after

Spec §7 item 5 asks the requester for the decision threshold and it has not
been supplied. **Fix it before running**, otherwise the analysis is unfalsifiable
and the run will be rationalised after the fact.

Concretely: pick a query or weighted mix from Tier B and a percentage. The
harness reports a bootstrap 95% CI on the median ratio per query, so any
threshold turns into a mechanical verdict:

- CI entirely better than the threshold → **yes**
- CI entirely inside ±threshold → **no, below the threshold of detectability**
- CI straddles it → **inconclusive, need more repetitions** (raise `REPS`)

Without a stated threshold the honest report is only "here is the per-query
distribution", with no verdict.

## Prerequisite that is not satisfied yet

Spec §6 Phase 3 point 2 gates benchmarking on byte-for-byte agreement **on the
benchmark's own data and queries**. What has been verified so far is a
5000-row synthetic mix (identical, `diff` exit 0) plus the known division and
stddev scale divergence. The real ORM DDL and query mix from spec §7 items 2–3
were never supplied, so this gate is passed only for a stand-in workload. Two
consequences:

- Division-heavy or `stddev`/`variance`-heavy reporting queries **will** differ
  in the last decimal place. That is the documented §3.3 clamp, not a bug, but
  it is a behavioural change an ORM may notice.
- Any third-party extension compiled against stock headers will silently
  misread numerics, because the `PG_MODULE_ABI_DATA` marker (spec §4.1) was
  never added. `bench.sh` checks `shared_preload_libraries` and warns.

## Running it

```sh
./provision.sh                      # prints gcloud commands; run them yourself
# on the VM, with both builds installed:
sudo ./bench.sh /opt/pg-stock /opt/pg-dec128 20000000 30
./analyze.py results.csv            # -> report.md
```

`bench.sh` takes: stock prefix, patched prefix, row count, repetitions.
30 repetitions is the floor for a stable median; use 50+ if a CI straddles
the threshold.

Both builds must come from the same commit base, differing only in the dec128
patch — otherwise unrelated changes are attributed to the representation.
`bench.sh` records both `pg_config --configure` outputs into the results file
so this is auditable after the fact.

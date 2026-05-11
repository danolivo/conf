# Flamegraph Comparison: Batched vs Vanilla Logical-Replication Apply

Two workloads analysed, each comparing the batched (`multi_insert = on`) apply worker against the vanilla per-tuple apply worker on the same data:

- **Scenario A** — target table **with indexes** (`flamegraph-multiinsert-index.svg` vs `flamegraph-vanilla-indexes.svg`).
- **Scenario B** — target table **without indexes** (`flamegraph-multiinsert.svg` vs `flamegraph-vanilla.svg`).

Both scenarios are total-CPU-normalised (100% at the apply worker's top frame). Each pairing is apples-to-apples: same workload, same indexing choice, same build.

---

# Scenario A: Indexed target table

## 1. Call frames that disappear with batching

The single-row executor path is eliminated — not merely shortened. The per-INSERT relation/index open+close cycle and lock acquire+release cycle that ran once per tuple in vanilla run once per buffer in the batched path.

| Vanilla call frame | % of vanilla CPU | Batched |
|---|---|---|
| `ExecSimpleRelationInsert` | **38.14** | absent |
| `heapam_tuple_insert` + `heap_insert` | 20.76 + 16.24 | absent |
| `create_edata_for_relation` | 4.80 | absent |
| `ExecOpenIndices` (per-INSERT) | 5.08 | absent at top |
| `ExecCloseIndices` (per-INSERT) | 2.68 | absent at top |
| `FreeExecutorState` (per-INSERT) | 3.39 | absent |
| `TargetPrivilegesCheck` (per-INSERT) | 2.82 | absent |
| `LockRelationOid` / `UnlockRelationId` / `LockAcquireExtended` | 2.54 + 2.40 + 2.26 | absent at top |

**Total per-tuple setup/teardown scaffolding eliminated:** ~25% of vanilla apply-worker CPU.

## 2. Call frames that are new in the batched profile

| Batched call frame | % of batched CPU |
|---|---|
| `apply_mi_buffer_add` | 58.97 |
| `apply_mi_buffer_flush` | 54.49 |
| `apply_mi_flush_heap_phase` | 53.21 |
| `table_multi_insert` | 9.62 |
| `heap_multi_insert` | 9.62 |
| `tts_virtual_copy_heap_tuple` | 7.05 |
| `ExecMaterializeSlot` | 4.49 |
| `ResourceOwnerEnlarge` | 4.49 |
| `ResourceOwnerAddToHash` | 4.49 |

The buffer-add path (virtualise + materialise into a persistent slot) becomes the new dominant frame. `heap_multi_insert` replaces `heap_insert × N` at roughly **1/4 the CPU share** for the same tuple count (9.62% vs 37%).

## 3. Call frames reshaped — same work, different share

| Call | Vanilla % | Batched % | Interpretation |
|---|---|---|---|
| `ExecInsertIndexTuples` | 16.95 | **42.95** | Same per-tuple work. Now the biggest remaining hotspot because everything around it got cheaper. PostgreSQL's `heap_multi_insert` does not batch index updates; the index loop still runs per-tuple. |
| `_bt_doinsert` | 14.97 | 39.74 | As above. |
| `_bt_check_unique` | not visible | 10.26 | Unique check now visible at profile top — not slower, just a relatively larger share. |
| `slot_store_data` | 18.50 | 23.72 | Roughly unchanged: text-protocol tuple parsing is unaffected by batching. |
| `InputFunctionCall` / `timestamptz_in` | 15.54 / 10.03 | 14.10 / 9.62 | Parsing cost unchanged. |
| `logicalrep_rel_open` | 5.65 | 3.85 | Slightly less — relative compression only; the function is still called per inbound message. |

## 4. Headline observations

1. **Per-tuple executor machinery is gone, not merely shortened.** `ExecSimpleRelationInsert`, `create_edata_for_relation`, `ExecOpenIndices` / `ExecCloseIndices`, `FreeExecutorState`, and per-INSERT `TargetPrivilegesCheck` / `LockRelationOid` — collectively ~25% of vanilla apply-CPU — do not appear at top of the batched profile. They run once per buffer lifetime instead of once per tuple.

2. **Heap work dropped roughly 4×.** 37% vanilla → 9.62% batched for the same tuple count. This maps directly to the spec's measured 3× subscriber-WAL reduction — one `heap_multi_insert` WAL record per batch replaces ~1000 `heap_insert` records.

3. **Index insertion is now the dominant remaining cost.** `ExecInsertIndexTuples` rose 17% → 43% of the profile purely from relative-share effects; per-tuple index work is identical. This is the frontier for the next release — `heap_multi_insert` does not currently batch index updates, and the btree insert loop now carries roughly the same apply-CPU share that the entire per-tuple executor used to carry. Anything that amortises index insertion (bulk-loaded CREATE INDEX-style accumulation per batch, or index AM-level batching) is the next ~2× lever.

4. **Text-protocol parsing is unchanged.** `slot_store_data` and the `timestamptz_in` / `float8in` chain stay at the same relative share. Neither batching nor per-tuple apply moves this; `binary = true` on the subscription is still the lever to pull when the workload has heavy type-input cost.

5. **`ResourceOwnerEnlarge` / `ResourceOwnerAddToHash` ~4.5% each** is new, bounded overhead from the persistent slot array — one-off per buffer init, not per tuple. This is the "cost of keeping slots alive across intermediate flushes" that the design pays in exchange for eliminating the 53% `ResourceOwnerForget` hotspot that an earlier single-mode flush exhibited. Net benefit is strongly positive.

## 5. Implications for the next release

- **Per-relation-batch index insertion** is the single largest remaining lever. Approaches worth evaluating: btree bulk-build-on-append for batched inputs; deferring index insertion to the end of the batch with a sort-then-insert pattern; or — more speculatively — a new index AM callback for batched insertion that lets each AM choose its own amortisation strategy.
- **Publisher-side batching (Release N+1)** compresses the wire stream and removes some of the `slot_store_data` / dispatch overhead, but does not touch the index-insert cost. Index batching and protocol batching are orthogonal wins.
- **Binary subscription protocol** is a workload-dependent win for parsing-heavy schemas (many timestamptz / float8 / numeric columns) but is a configuration choice, not a code change in this feature track.

---

# Scenario B: Un-indexed target table

Without indexes the batched-vs-vanilla contrast is uncluttered by the per-tuple btree loop that dominated Scenario A. The pilot's full effect is visible end-to-end: heap work halved, per-tuple scaffolding gone, WAL compressed into one record per batch.

## 6. Call frames that disappear with batching

| Vanilla (no-index) frame | % of vanilla CPU | Batched |
|---|---|---|
| `ExecSimpleRelationInsert` | **28.37** | absent |
| `heapam_tuple_insert` + `heap_insert` | 27.57 + 19.58 | absent |
| `create_edata_for_relation` | 5.69 | absent |
| `apply_handle_insert_internal` | 3.80 | absent |
| `TargetPrivilegesCheck` | 3.40 | absent |
| `FreeExecutorState` | 2.90 | absent |
| `MakePerTupleExprContext` | 2.40 | absent |
| `pg_class_aclcheck` / `pg_class_aclmask_ext` | 1.80 + 1.80 | absent |
| `check_enable_rls` | 1.50 | absent |
| `ExecInitExtraTupleSlot` | 1.40 | absent |

**Total per-tuple scaffolding eliminated:** ~25–30% of vanilla apply-worker CPU. ACL/RLS/executor-state machinery that ran once per INSERT now runs once per buffer init.

## 7. Call frames that are new in the batched profile

| Batched (no-index) frame | % of batched CPU |
|---|---|
| `apply_mi_buffer_flush` | 22.87 |
| `apply_mi_flush_heap_phase` | 22.08 |
| `heap_multi_insert` | 21.72 |
| `apply_mi_buffer_add` | 3.96 |
| `tts_virtual_materialize` | 3.43 |
| `ResourceOwnerEnlarge` / `ResourceOwnerForget` (residual) | 1.76 + 3.25 |

## 8. Heap insertion and WAL-record work

| Frame | Vanilla % | Batched % |
|---|---|---|
| `heap_insert` / `heapam_tuple_insert` vs `heap_multi_insert` | 19.58 + 27.57 = **47.15** | **21.72** |
| `XLogInsert` | 5.79 | 1.06 |
| `XLogInsertRecord` | 3.50 | 0.79 |

Heap insertion roughly halves as a share of apply CPU, and the WAL-insert frames drop ~5×. The WAL-record reduction is the direct signature of the 3× subscriber-WAL amplification fix the spec targets.

## 9. Parsing and protocol frames — relative share rises, absolute cost unchanged

| Frame | Vanilla % | Batched % |
|---|---|---|
| `slot_store_data` | 30.17 | 43.36 |
| `InputFunctionCall` | 24.98 | 34.48 |
| `timestamptz_in` | 15.78 | 22.87 |
| `logicalrep_rel_open` | 4.10 | 6.42 |

Per-tuple cost is identical; the relative share rises only because everything around it got cheap. Confirms the Scenario A finding: batching does not and cannot reduce text-protocol parsing.

## 10. Headline observations (no-index)

1. **Per-tuple scaffolding is the dominant vanilla inefficiency.** With indexes in the picture, `ExecInsertIndexTuples` masked this — without indexes, the vanilla profile is ~70% per-tuple executor + heap work. Batching converts that into once-per-buffer setup plus one bulk heap insert.
2. **`heap_multi_insert` genuinely halves heap work.** 47% → 22% for the same tuple count. With no indexes, no per-tuple index loop follows the bulk insert; the whole flush phase is one WAL record and its heap writes.
3. **`XLogInsert` drops ~5×.** This is the clearest signal in the profile that WAL amplification has collapsed. Vanilla writes ~1000 WAL records per 1000 tuples; batched writes 1.
4. **ACL / RLS / executor-init costs vanish from the hot path.** Vanilla spent ~7% per tuple on security checks (`TargetPrivilegesCheck`, `pg_class_aclcheck`, `check_enable_rls`) and ~12% on executor init/teardown (`create_edata_for_relation`, `FreeExecutorState`, `MakePerTupleExprContext`, `ExecInitExtraTupleSlot`). All of that amortises to per-buffer.
5. **Parsing is the new ceiling.** `slot_store_data` at 43% of batched CPU says the next big lever for workloads like this one is binary protocol (`CREATE SUBSCRIPTION ... WITH (binary = true)`), not further tweaking of the batching code.

---

# Cross-Scenario Summary

| Dimension | Scenario A (indexed) | Scenario B (un-indexed) |
|---|---|---|
| Dominant remaining hotspot (batched) | `ExecInsertIndexTuples` 43% | `slot_store_data` 43% |
| Biggest single vanilla frame eliminated | `ExecSimpleRelationInsert` 38% | `ExecSimpleRelationInsert` 28% |
| Heap-insert reduction | 37% → 9.6% (~4×) | 47% → 22% (~2×) |
| WAL-insert frame reduction | 5.65% → 5.77% (little change) | 5.79% → 1.06% (~5×) |
| Dominant cost after batching | Index insertion (not batched) | Text-protocol parsing |
| Next lever | Index-insert batching | Binary protocol on the subscription |

With indexes, batching shrinks the heap term more aggressively (because the index term stays and crowds everything else) but does not touch the WAL generated by per-tuple index updates. Without indexes, the pilot's full effect is visible end-to-end: heap work halved, scaffolding gone, WAL compressed into one record per batch.

The divergence is informative for release planning:

- **Tables with few/no indexes** (append-only fact tables, staging tables, time-series hypertables) see the full benefit today. The pilot's narrow-fact-table headline case is the workload where the pilot matters most, and the profile confirms it.
- **Heavily-indexed tables** still benefit from the heap+WAL compaction, but the per-tuple index loop becomes the ceiling. This points directly at the next-release opportunity: batched or deferred index insertion, which would close the gap between the two scenarios.
- **Parsing-bound workloads** (many wide, text-encoded columns) need binary protocol regardless of batching. That's a configuration lever, not a development one.

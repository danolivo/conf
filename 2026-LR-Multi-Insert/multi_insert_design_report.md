# Batched Multi-Insert for Logical Replication Apply — Design Explanation

## 1. What we wanted

When a publisher does a bulk load via `COPY`, PostgreSQL compresses the inserts into compact `heap_multi_insert` WAL records. The logical-replication subscriber, however, decodes each row into a separate `INSERT` protocol message and applies them one-by-one through `ExecSimpleRelationInsert` → `table_tuple_insert`. The result is a **3× WAL amplification** on the subscriber (21 GB to replay a 7 GB bulk load at 100 M rows), matching apply-throughput degradation, and downstream amplification for anything that consumes the subscriber's WAL (archiving, backups, cascading replication).

We wanted to close that gap without touching the wire protocol, without changing `pgoutput`, and without taking on the full design surface (triggers, FKs, generated columns, streaming, parallel apply) in one commit.

## 2. What we got

A subscriber-side opt-in that batches consecutive `INSERT` messages into a single `heap_multi_insert` call, exposed as a new subscription option `multi_insert = on`:

```sql
CREATE SUBSCRIPTION mysub CONNECTION '…' PUBLICATION mypub
    WITH (multi_insert = on);
```

Deliberate exclusions for this release:

- **Streaming** (`streaming != off` is rejected at `CREATE`/`ALTER` time). The streaming apply paths have their own xact/snapshot/memory-context discipline that the pilot does not validate.
- **Partitioned roots, tables with triggers, RLS, CHECK constraints, stored-generated columns, exclusion constraints, deferrable uniqueness.** Eligibility is checked per-relation at runtime; ineligible relations silently fall back to the per-tuple path.

What's in the commit by file:

| File | Purpose |
|---|---|
| `src/include/catalog/pg_subscription.h` | `submultiinsert` catalog column + `multiinsert` runtime field |
| `src/backend/catalog/pg_subscription.c` | `GetSubscription` wires catalog → runtime |
| `src/backend/commands/subscriptioncmds.c` | `SUBOPT_MULTI_INSERT` parsing + `CREATE`/`ALTER` mutual-exclusion check with `streaming` |
| `src/include/catalog/catversion.h` | `CATALOG_VERSION_NO` bump (`202604221`) |
| `src/backend/catalog/system_views.sql` | `GRANT SELECT` on the new column |
| `src/backend/replication/logical/worker.c` | `ApplyMIBuffer` struct + lifecycle + flush machinery (+flush hooks at ~20 call sites) |

## 3. How it works

### 3.1 The buffer

One `ApplyMIBuffer` at a time, living in the apply worker's `ApplyContext`. Fields:

- **Owned `Relation`** via `table_open(relid, RowExclusiveLock)` — decoupled from the caller's `logicalrep_rel_open`/`close` cycle (which NULLs the map entry mid-xact).
- **Persistent `EState` + `ResultRelInfo`** with indexes opened once at init via `ExecOpenIndices`.
- **Long-lived `receiveslot`** (`TTSOpsVirtual`) — every inbound INSERT deserialises into this one slot, saving a per-message `MakeSingleTupleTableSlot` + `ExecDropSingleTupleTableSlot` pair.
- **`slots[]` array**, geometric growth from 16 up to `APPLY_MI_MAX_SLOTS = 10000`; each slot is allocated lazily and reused across flushes via `ExecClearTuple`.
- **`has_immediate_unique`** — set iff the relation has any immediate UNIQUE/PRIMARY KEY index; controls whether the flush runs inside a subtransaction.
- **`owner_at_init`** — invariant: `CurrentResourceOwner` must equal this on flush exit.

### 3.2 Flow through `apply_handle_insert`

```
Protocol INSERT arrives
    ├─ multi_insert off, streaming on, parallel worker, or disabled-for-xact?
    │     → per-tuple path (unchanged)
    ├─ new buffer needed?
    │     apply_mi_relation_is_safe() classifier
    │     apply_mi_buffer_init() — opens Relation, estate, indexes, receiveslot
    ├─ apply_mi_buffer_add()
    │     slot_store_data(receiveslot) → materialise into slots[nslots]
    │     if cap hit → apply_mi_buffer_flush() (intermediate — keeps buffer alive)
    └─ logicalrep_rel_close(rel, NoLock); end_replication_step
```

### 3.3 Two flush modes

| Mode | Entry | Heap work | Slots after | Buffer after |
|---|---|---|---|---|
| Intermediate | Cap-hit inside `apply_mi_buffer_add` | `heap_multi_insert` + index loop | `ExecClearTuple`'d, reused | Alive |
| Final | `apply_handle_buffer_flush_any` at every non-INSERT hook | same | dropped | `NULL` |

The split was the key optimisation win: single-mode flush-and-destroy forced 1000-tuple caps within one xact to recreate slots each time, and `ResourceOwnerForget` on the tupdesc pins dominated the profile.

### 3.4 Conflict handling

If `has_immediate_unique`, the flush runs inside `BeginInternalSubTransaction`. On `ERRCODE_UNIQUE_VIOLATION` — the only conflict class the pilot admits — the subxact is rolled back, batching is disabled for the remainder of the apply xact, and the buffered tuples are replayed through `ExecSimpleRelationInsert`, which reaches the normal `CheckAndReportConflict` / `disable_on_error` / `ALTER SUBSCRIPTION SKIP` path. Any other error is re-thrown — crucially, cancel-class errors are not swallowed.

### 3.5 Error paths

- **Mid-flush non-unique error** → re-thrown; `start_apply`'s top-level `PG_CATCH` calls `apply_mi_buffer_abandon` (NULLs the pointer; ApplyContext reset reclaims memory) and `apply_mi_reset_xact_state` (so the retry starts fresh).
- **Xact boundary** → `apply_handle_buffer_flush_any` (final flush + destroy); snapshot is pushed/popped internally.
- **Relcache invalidation** → not wired in the pilot; the user asserts schema stability via the subscription option. Full Release N adds a callback.

### 3.6 Interrupt responsiveness

Batching widens the `CHECK_FOR_INTERRUPTS`-free window from one tuple (upstream) to up to `APPLY_MI_MAX_SLOTS` tuples. The flush path calls `CHECK_FOR_INTERRUPTS` at three points: between `table_multi_insert` and the per-tuple index loop; at the top of each iteration of that loop; and at the top of each iteration of the fallback per-row replay. Without this, `pg_terminate_backend`, SIGHUP, and statement-timeout-class events would be visibly sluggish during bulk loads.

## 4. The benefit

Relative to the per-tuple baseline from the spec's §3 benchmark:

| Metric | Baseline | Pilot | Basis |
|---|---|---|---|
| Subscriber WAL volume (10 M rows, no index) | 2120 MB | ~700 MB | One heap record per batch instead of per tuple; matches publisher-COPY WAL |
| Apply throughput (narrow table, no indexes) | 1× | 2–3× | Fewer lock acquisitions, fewer pin/unpin cycles, amortised WAL-insert overhead |
| Apply throughput (PK index present) | 1× | 1.5–2× | Index inserts remain per-tuple; heap batching still dominates |
| Profile shape | per-tuple `table_tuple_insert` hotspot | `heap_multi_insert` + parsing | Flamegraph capture post-optimisation |

Post-optimisation flamegraph confirms `apply_mi_buffer_flush` as the productive work site at 22% of apply CPU (actual heap + index insertion), with text-protocol type parsing at 43% — the remaining headroom is in `binary = true` for the subscription, not in the batching code. The optimisation round dropped `ResourceOwnerForget` from 53% → ~5.8% and `ExecDropSingleTupleTableSlot` from 53% → 0.6%, which is the whole reason the long-lived `receiveslot` + slot-reuse + intermediate-flush design exists.

## 5. What the pilot does not solve (and by design)

- **Streaming bulk loads** — the dominant real-world case. Full Release N covers this.
- **Publisher-side batching / wire-protocol compaction** (~25–30% further network reduction) — Release N+1.
- **Tables with triggers / FKs / RLS / generated columns** — ineligible, fall back transparently.
- **Per-tuple sub-subxact conflict isolation** — the pilot's coarse "disable for this xact" gives up latency but saves ~500 lines of complexity; full Release N refines this.

The pilot's position in the release trajectory is deliberate: it delivers the headline benefit for the narrow-fact-table case, establishes the `ApplyMIBuffer` + flush-mode infrastructure that later releases layer onto, and avoids any wire-protocol commitment until the design has soaked.

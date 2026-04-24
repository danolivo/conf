# Technical Specification: Batched Multi-Insert for PostgreSQL Logical Replication

| Field | Value |
|-------|-------|
| Title | Batched Multi-Insert for Logical Replication |
| Author | Andrei Lepikhov |
| Status | Draft |
| PostgreSQL Target | Release N: subscriber-side only; Release N+1: protocol extension |
| Discussion Thread | TBD |
| Related Patches | TBD |
| Date | 2026-04-22 |

---

## 1. Problem Statement

When data is bulk-loaded on the publisher via `COPY`, PostgreSQL uses `heap_multi_insert()` internally, which batches tuples into compact WAL records. However, the logical replication apply worker on the subscriber applies each replicated row individually via `ExecSimpleRelationInsert()` → `table_tuple_insert()` (the single-row heap insert path), losing all batching benefits. This creates three measurable inefficiencies: WAL amplification on the subscriber, an apply throughput bottleneck, and unnecessary network overhead.

**Concrete example.** A publisher loads 10 million rows into a 4-column table (bigint, float8, text, timestamptz) via `COPY`. The publisher generates 697 MB of WAL. The subscriber, applying the same 10 million rows one at a time, generates 2,120 MB of WAL — a 3x amplification. The subscriber takes ~65 seconds to apply what the publisher loaded in ~7 seconds. For deployments with cascading replication, WAL archiving, or backup on the subscriber, this amplification multiplies downstream.

**Current workaround.** None. The apply worker has no batching infrastructure. Users who need fast bulk loads on the subscriber must resort to disabling the subscription, loading directly on the subscriber, and re-enabling — which defeats the purpose of replication.

**Impact.** Performance (apply throughput), storage (WAL volume and disk I/O on subscriber), and operational cost (WAL archiving, backup, cascading replication all process the amplified WAL).

## 2. Background and Prior Art

### 2.1 Current PostgreSQL Behaviour

The logical replication data flow for INSERT operations:

```
Publisher:
  WAL (heap_multi_insert record for COPY, or heap_insert for INSERT)
    → decode.c: DecodeMultiInsert() / DecodeInsert()
      → ReorderBufferQueueChange() — one change per tuple
        → pgoutput: pgoutput_change() — one call per change
          → logicalrep_write_insert() — one 'I' message per tuple
            → wire: N individual INSERT messages

Subscriber:
  walreceiver receives N individual INSERT messages
    → apply_dispatch() routes each to apply_handle_insert()
      → logicalrep_read_insert() + logicalrep_read_tuple()
        → ExecSimpleRelationInsert() → table_tuple_insert()
          → heap_insert() — one WAL record per tuple
```

Key observation: the core logical decoding layer (`decode.c`, `reorderbuffer.c`) already decomposes multi-insert WAL records into individual changes. This is by design — the reorder buffer needs individual changes for transaction ordering and streaming. The batching opportunity exists at two points downstream: the output plugin (pgoutput) and the apply worker.

### 2.2 Existing Batching Infrastructure

`heap_multi_insert()` and the `table_multi_insert()` table AM callback are used by `COPY FROM` (via `CopyMultiInsertBuffer` in `src/backend/commands/copyfrom.c`). The COPY implementation batches up to 1000 tuples or 64 KB per `table_multi_insert()` call, producing one WAL record per batch instead of one per tuple. This is proven, stable infrastructure.

### 2.3 Protocol Version History

The logical replication protocol uses version numbers negotiated at subscription startup:

| Version | Feature | PostgreSQL |
|---------|---------|------------|
| 1 | Base logical replication | PG10 |
| 2 | Streaming of in-progress transactions | PG14 |
| 3 | Two-phase commit support | PG15 |
| 4 | Parallel apply for streamed transactions | PG16 |

The current maximum is `LOGICALREP_PROTO_MAX_VERSION_NUM = 4` (defined in `src/include/replication/logicalproto.h`).

### 2.4 Prior Proposals

No prior pgsql-hackers proposal has addressed batched apply for logical replication specifically. The closest related work is the parallel apply feature (PG16), which improves throughput for large transactions by distributing work across multiple workers — but each worker still applies changes one tuple at a time.

## 3. Benchmark Data

Results from a two-node logical replication setup (publisher port 5432, subscriber port 5433, both local, `wal_level = logical`, autovacuum off, `checkpoint_timeout = 1h`). Tables have no indexes.

### 100 Million Rows

| Metric | COPY | INSERT | Ratio |
|--------|------|--------|-------|
| Publisher load (ms) | 57,422 | 144,312 | 2.5x faster |
| Replication apply (ms) | 514,139 | 674,543 | 1.3x faster |
| Total (ms) | 571,561 | 818,855 | 1.4x faster |
| Publisher WAL | 6,968 MB | 11,264 MB | 38% less |
| Subscriber WAL | 21,504 MB | 21,504 MB | identical |
| Publisher table size | 8,880 MB | 8,880 MB | identical |
| Subscriber table size | 8,880 MB | 8,880 MB | identical |

At 100M rows, the subscriber generates **21 GB of WAL** regardless of the publisher's load method — a **3x amplification** relative to the publisher's COPY WAL (6.97 GB). The ratio is consistent across all three scale points (1M, 10M, 100M), confirming this is a structural issue, not a measurement artefact. The subscriber spends over 8.5 minutes applying what the publisher loaded in under 1 minute.

### 10 Million Rows

| Metric | COPY | INSERT | Ratio |
|--------|------|--------|-------|
| Publisher load (ms) | 6,928 | 38,785 | 5.6x faster |
| Replication apply (ms) | 64,953 | 69,396 | ~1x |
| Total (ms) | 71,881 | 108,181 | 1.5x faster |
| Publisher WAL | 697 MB | 1,148 MB | 40% less |
| Subscriber WAL | 2,120 MB | 2,120 MB | identical |
| Publisher table size | 888 MB | 888 MB | identical |
| Subscriber table size | 888 MB | 888 MB | identical |

### 1 Million Rows

| Metric | COPY | INSERT |
|--------|------|--------|
| Publisher load (ms) | 545 | 945 |
| Replication apply (ms) | 20,979 | 3,215 |
| Total (ms) | 21,525 | 4,161 |
| Publisher WAL | 70 MB | 115 MB |
| Subscriber WAL | 123 MB | 121 MB |

Note: the 1M COPY "apply" time is inflated because COPY finishes faster, so less replication happens concurrently with the load. Total time is the meaningful metric.

### WAL Amplification Summary

| Scale | Publisher WAL (COPY) | Subscriber WAL | Amplification |
|-------|---------------------|----------------|---------------|
| 1M rows | 70 MB | 123 MB | 1.8x |
| 10M rows | 697 MB | 2,120 MB | 3.0x |
| 100M rows | 6,968 MB | 21,504 MB | 3.1x |

The amplification factor stabilises at ~3x once the dataset is large enough that full-page writes are amortised. This is the structural overhead that batched multi-insert eliminates.

**TODO:** Repeat benchmarks with a primary key index on the table. Real-world tables almost always have indexes, and index insertion overhead (which remains per-tuple even with heap batching) will reduce the relative benefit. This is needed before proposing on pgsql-hackers.

## 4. Proposed Design

### 4.1 Multi-Release Strategy

The feature is split into three independently committable and testable increments. The first (the pilot) is a restricted opt-in that delivers the core benefit with minimal surface area and is the recommended starting point for review on pgsql-hackers.

**Release N-0 (Pilot) — Opt-In Subscriber-Side Batching with Schema Assertions.**
A subscription option `multi_insert = on` asserts that the subscriber's target tables have no triggers, no foreign keys, no RLS, no CHECK/NOT-NULL expressions beyond PK columns, no stored generated columns, no deferrable or exclusion constraints. UNIQUE and PRIMARY KEY indexes are permitted (they are needed for REPLICA IDENTITY). When the assertion holds, the apply worker calls `table_multi_insert()`; otherwise the per-tuple path is used for that table. No wire protocol changes. Intra-batch PK collisions are impossible by construction (see §4.12.4), so no dedup or per-tuple subxact replay is required. See §4.12 for the complete specification.

**Release N — Full Subscriber-Side Batching (no protocol changes).**
The apply worker buffers consecutive single INSERT messages for the same relation and calls `table_multi_insert()` instead of `table_tuple_insert()`. No changes to pgoutput, no wire protocol changes, no backward-compatibility concerns. Extends the pilot by removing the schema restrictions: tables with triggers / FKs / RLS / generated columns are handled via the subxact-wrapped flush + per-tuple subxact replay design of §4.3.5.

**Release N+1 — Publisher-Side Batching + Protocol Extension.**
pgoutput buffers consecutive INSERT changes and emits a new `MULTI_INSERT` wire protocol message. The subscriber dispatches this to a new handler that unpacks the batch and calls `table_multi_insert()`. This adds network traffic reduction (~25–30%) on top of the subscriber-side batching already in place. Orthogonal to the pilot — can be developed in parallel.

The remainder of this specification covers all three increments. Sections marked **(Pilot / N-0)**, **(Release N only)**, or **(Release N+1)** indicate which increment they belong to.

### 4.2 Architecture Overview

```
Release N (subscriber-side only):
  pgoutput sends N individual INSERT messages (unchanged)
    → apply worker receives N INSERT messages
      → apply_handle_insert() accumulates tuples in MultiInsertBuffer
      → On flush: table_multi_insert() + single WAL record per batch

Release N+1 (publisher-side + protocol):
  pgoutput buffers N consecutive INSERTs
    → emits one MULTI_INSERT message (N tuples)
      → apply worker receives MULTI_INSERT message
        → apply_handle_multi_insert() unpacks and calls table_multi_insert()
```

### 4.3 Subscriber-Side Batching (Release N)

#### 4.3.1 New Structure: ApplyMultiInsertBuffer

Added to the apply worker's per-relation state (or as a standalone structure in `worker.c`). Modelled after `CopyMultiInsertBuffer` in `copyfrom.c`:

```c
typedef struct ApplyMultiInsertBuffer
{
    Oid             relid;          /* relation OID of buffered tuples */
    LogicalRepRelMapEntry *rel;     /* borrowed relmap entry (not owned) */
    ResultRelInfo *relinfo;         /* palloc'd; NOT attached to estate list */
    EState         *estate;         /* owned executor state for flush */

    TupleTableSlot *receiveslot;    /* reusable deserialisation slot */
    TupleTableSlot **slots;         /* array of buffered tuple slots */
    int             nslots;         /* number of tuples currently buffered */
    int             max_slots;      /* capacity (default: 1000) */
    Size            bytes_used;     /* approximate byte usage */
    Size            max_bytes;      /* byte limit (default: 65536) */

    bool            needs_subxact;        /* flush must be subxact-wrapped? */
    bool            has_generated_stored; /* target has stored generated cols */
    bool            mid_flush;            /* set while inside a flush */
    bool            invalidated;          /* relcache invalidation observed */
} ApplyMultiInsertBuffer;
```

**Critical lifetime rules:**

- **One active buffer at a time.** The apply worker owns a single `apply_mi_buffer` static pointer. Relation change, non-INSERT change, transaction/stream boundary, or relcache invalidation all take the **final** flush path (§4.3.1.2: flush heap + index work, then destroy); the next INSERT re-allocates. A size-cap hit within a steady INSERT stream takes the **intermediate** flush path and keeps the buffer alive for continued reuse. The TupleDesc pin lives for the buffer's full lifetime, which is bounded above by the apply transaction — the buffer is never persisted across transaction boundaries (where the relcache expectations would break).

- **`needs_subxact` is precomputed at buffer init and cached.** The decision depends on relation properties that cannot change during the batch's lifetime (see Section 4.3.4). Recomputing per flush is wasteful.

- **`BulkInsertState` is allocated *per flush*, not per buffer.** `bistate->current_buf` holds a pinned buffer whose pin is tied to the current ResourceOwner at the moment of pin. A subtransaction rollback releases the subxact's ResourceOwner, so a `BulkInsertState` that acquired its pin inside a subxact becomes invalid after that subxact rolls back, even though the `BulkInsertState` struct itself lives in the caller's memory. Following the `copyfrom.c` pattern, allocate in `apply_mi_flush_heap_phase()` and `FreeBulkInsertState()` in a `PG_FINALLY` at exit. This trades one allocation per flush for immunity from subxact/pin lifetime skew.

- **`receiveslot` is a single long-lived deserialisation slot** allocated via `MakeSingleTupleTableSlot()` in `ApplyContext`. Every incoming INSERT deserialises into it; `apply_mi_buffer_add()` then copies and materialises into its own private buffered slot. **Do not use `ExecInitExtraTupleSlot(buf->estate, ...)` for the receive slot:** that function appends to `estate->es_tupleTable` using `CurrentMemoryContext`, and the apply-worker per-message context is reset at `end_replication_step()`. On the second INSERT the list header is a dangling pointer and `lappend()` asserts on `IsPointerList`. (This pitfall is not obvious; it was found during Release N implementation.)

  **Profile rationale.** Keeping the receiveslot alive across the buffer's lifetime is a profile-driven optimisation, not a mere convenience. A per-INSERT `MakeSingleTupleTableSlot` + `ExecDropSingleTupleTableSlot` pair does a `ResourceOwnerRemember`/`Forget` on the tupdesc pin, and the removal scans the ResourceArray holding that pin. Under a steady INSERT stream this accounted for roughly half of all apply-worker CPU in an early post-batching flamegraph — visible as `ResourceOwnerForget` dominating the profile at ~53%. Reusing a single slot collapses the cost to a single pin pair for the buffer's lifetime.

- **`ResultRelInfo` is `makeNode`'d explicitly and kept off `es_opened_result_relations`** so that `FreeExecutorState()` does not close its indexes. Buffer destroy is responsible for `ExecCloseIndices(relinfo)` and `pfree(relinfo)` in that order.

- **The buffer owns its own `Relation` handle.** At init, the buffer calls `table_open(relid, RowExclusiveLock)` and stores the result in `local_rel`; at destroy, it calls `table_close(local_rel, RowExclusiveLock)`. It does **not** hold on to the `LogicalRepRelMapEntry->localrel` pointer the caller passed in. The caller (`apply_handle_insert`) finishes with `logicalrep_rel_close(rel, NoLock)` at the bottom of the handler, which sets the map entry's `localrel` to `NULL`. If the buffer kept the caller's pointer, the flush at commit/prepare time — which can occur tens of thousands of INSERTs after the init — would dereference a stale pointer. A dedicated `table_open`/`table_close` pair gives the buffer a stable handle for its full lifetime and is independent of the per-INSERT open/close dance. This is the same category of pitfall as the `ExecInitExtraTupleSlot` note above: the obvious-looking shortcut breaks because of lifetime discipline elsewhere.

- **Slots array: lazy allocation and cross-flush reuse.** `slots[]` is sized to `capacity` (start 16, geometric growth capped at `APPLY_MI_MAX_SLOTS`) but each slot pointer is allocated lazily via `MakeSingleTupleTableSlot` only when `nslots` first reaches that index. After an *intermediate* flush (§4.3.1.2), slots are `ExecClearTuple`'d in place and kept alive; the next batch re-materialises into the same slots and pays no re-registration cost on the tupdesc pin. This is the same optimisation as `receiveslot` applied to the whole array, and is what keeps long INSERT streams (many consecutive 1000-tuple flushes within one remote xact) off the O(N²) `ResourceOwnerForget` curve.

- **`apply_mi_buffer_destroy` walks `capacity`, not `nslots`.** An intermediate flush may leave `nslots == 0` while `slots[]` still holds live allocations from the prior batch; destroy must release them regardless of the current fill level. The loop also walks `slots[i] != NULL` defensively so that a partially-initialised buffer (destroyed from an error path before any slot was allocated) does not segfault. Destroy order is `slots → receiveslot → ExecCloseIndices + pfree(relinfo) → FreeExecutorState(estate) → table_close(local_rel) → pfree(buffer)`; the order matters because `FreeExecutorState` walks `es_tupleTable`, the indexes are opened via the relation, and the receiveslot's tupdesc pin is derived from that same relation.

- **`owner_at_init` invariant.** `CurrentResourceOwner` is captured at buffer init. The flush path asserts that `CurrentResourceOwner` equals `owner_at_init` at exit (and after a snapshot push/pop cycle). A mismatch indicates that a subxact leaked, that the snapshot code re-pointed the owner, or that the flush is being called from a context the pilot did not plan for. This matches the discipline in `copyfrom.c` around `BulkInsertState`.

#### 4.3.1.1 Batch Size Rationale

The pilot chose **`APPLY_MI_MAX_SLOTS = 10000`, `APPLY_MI_MAX_BYTES = 8 MiB`, `APPLY_MI_INITIAL_SLOTS = 16`** (geometric growth from 16 up to the 10000 cap). These are 10× / 128× larger than COPY's corresponding constants (`MAX_BUFFERED_TUPLES = 1000`, `MAX_BUFFERED_BYTES = 65535`). The **constraints that forced those numbers on COPY do not apply here**, as argued below; the pilot's larger values were selected to maximise the per-flush amortisation benefit that is the whole point of batching.

COPY's hard cap at 1000 is driven by the partition-aware buffering in `copyfrom.c`: `CopyMultiInsertInfo` can hold *multiple* per-partition `CopyMultiInsertBuffer` entries simultaneously, so total memory scales as `N_partitions × MAX_BUFFERED_TUPLES`. The comment at `copyfrom.c:59–63` warns explicitly against increasing `MAX_BUFFERED_TUPLES` for this reason — "Increasing this can cause quadratic growth in memory requirements during copies into partitioned tables with a large number of partitions." The 2019 partition-aware refactor (commit 86b85044e82) weighed lowering the constant but instead added `MAX_PARTITION_BUFFERS = 32` to cap the number of simultaneously-live per-partition buffers. David Rowley's thread-raised concern ("if we're copying to a partitioned table with 10k partitions and we get over MAX_BUFFERED_TUPLES in a row for each partition, we'll end up with quite a lot of slots") is specific to COPY's multi-buffer shape.

**The apply-worker batching has a different shape and does not have this quadratic concern:**

- There is **exactly one active buffer at a time**, bound to exactly one relation (§4.3.1 lifetime rule). Relation change (`relid != apply_mi_buf->relid`) triggers a flush-and-destroy; the next INSERT allocates a fresh buffer for the new relation.
- Any UPDATE, DELETE, TRUNCATE, RELATION, TYPE, or transaction boundary also flushes.
- Peak memory is therefore `max_slots × per-slot-cost` for a **single** relation at a time, independent of how many distinct relations the remote transaction touches.
- Partitioned tables on the subscriber side use the existing tuple-routing path (§4.12.3 and Release N §4.11); batching never accumulates per-partition buffers in the first place.

Concretely, for a narrow-fact-table workload (few columns, no indexes, no triggers — the pilot's headline case) with an average tuple of ~80 bytes, peak working-set under the pilot's `APPLY_MI_MAX_BYTES = 8 MiB` cap is bounded at 8 MiB — single-relation, independent of how many partitions the target has and independent of how interleaved the remote transaction is across tables. For a wider table with ~4 KiB tuples the `APPLY_MI_MAX_SLOTS = 10000` cap bounds each batch to one 8 MiB flush before emptying.

**Implications for sizing:**

- The byte cap is the dominant bound in practice: the tuple-count cap of 10000 is only reached on narrow rows that fit inside the 8 MiB budget. The code enforces both simultaneously (whichever trips first triggers the intermediate flush, §4.3.1.2), with `APPLY_MI_MAX_BYTES` estimated per-tuple via `MAXALIGN(sizeof(HeapTupleHeaderData)) + MAXALIGN(natts * sizeof(Datum))` — cheap, overshoots wide TOASTed rows (triggers an earlier flush; correctness-safe).
- The cap can safely be raised again in future work without triggering the quadratic regression COPY was protecting against. A 10× increase remains bounded by a single relation's memory footprint.
- The pilot (§4.12.6) uses compile-time constants only. Full Release N exposes a subscription option `multi_insert_size` for tuple cap tuning; the upper bound of that option is a policy question rather than a hard memory-safety one, because of the single-buffer invariant described above.

#### 4.3.1.2 Flush Modes: Intermediate vs Final

The batching path distinguishes **two** flush modes, each with a different entry-point function. This split was driven by flamegraph analysis of a long-running apply worker: a single-mode "flush and destroy" made 1000-tuple caps within a long INSERT stream catastrophically expensive, because every batch recreated the buffer, its slots, and their tupdesc pins from scratch. The split preserves those allocations across batches.

| Aspect | Intermediate (`apply_mi_buffer_flush`) | Final (`apply_handle_buffer_flush_any`) |
|--------|----------------------------------------|------------------------------------------|
| **Triggered by** | `nslots >= APPLY_MI_MAX_SLOTS` or `cum_bytes >= APPLY_MI_MAX_BYTES` from inside `apply_mi_buffer_add` (only) | Any non-INSERT message, relation change, xact/stream boundary, relcache invalidation (Release N), PG_CATCH in the caller |
| **Heap + index work** | ✓ | ✓ |
| **Slots after exit** | `ExecClearTuple`'d, reused by the next batch | dropped (`ExecDropSingleTupleTableSlot`) |
| **`receiveslot` after exit** | alive | dropped |
| **`relinfo` / `estate` / `local_rel` after exit** | alive | dropped (ExecCloseIndices, FreeExecutorState, table_close) |
| **`apply_mi_buf` after exit** | non-NULL (same buffer) | NULL |
| **Next INSERT cost** | reuses slots + pins (cheap) | re-opens relation, re-inits estate, re-allocates slots (slower but one-off) |

Final is implemented as `apply_mi_buffer_flush() → apply_mi_buffer_destroy()`, so the heap/index work is shared. The split is an implementation concern only — the spec's flush-triggers table (§4.3.3) and the pilot's conflict-handling rules (§4.12.5) are unchanged by the split.

**Why the split matters for correctness as well as performance.** Intermediate flush is the *only* entry point that leaves the buffer live and expects the next caller to continue adding tuples into it. Every other flush-triggering event — relation change, non-INSERT message, xact end — must use the final variant, because the reason for flushing is that the buffer's relation / batch / xact is about to go away. Calling the intermediate variant from a commit or relation-change hook would leave a live buffer pointing at a relation the worker no longer intends to hold `RowExclusiveLock` on, and the next invalidation cycle would not tear it down.

#### 4.3.2 Buffering in apply_handle_insert()

The existing `apply_handle_insert()` function is modified. Instead of calling `apply_handle_insert_internal()` → `ExecSimpleRelationInsert()` immediately, it:

1. Checks whether batching is safe for this relation (see Section 4.3.4).
2. If safe: stores the tuple in `ApplyMultiInsertBuffer`. If the buffer is full or a flush trigger fires, flushes the buffer via `table_multi_insert()`.
3. If not safe: flushes any pending buffer, then applies the single tuple via the existing `ExecSimpleRelationInsert()` path.

#### 4.3.3 Flush Triggers

| Trigger | Condition | Release N-0 pilot |
|---------|-----------|-------------------|
| Buffer full | `nslots` reaches `APPLY_MI_MAX_SLOTS` (default 10000) or `cum_bytes` exceeds `APPLY_MI_MAX_BYTES` (default 8 MiB) | ✓ applies — **intermediate** flush, §4.3.1.2 |
| Relation change | Next INSERT targets a different relation OID | ✓ applies |
| Non-INSERT operation | Next change is UPDATE, DELETE, TRUNCATE, RELATION, TYPE, MESSAGE | ✓ applies |
| Transaction boundary | COMMIT, ABORT, PREPARE, COMMIT PREPARED, or ROLLBACK PREPARED received | ✓ applies — **final** flush (§4.3.1.2). COMMIT PREPARED / ROLLBACK PREPARED carry no INSERT work and inherit an empty buffer from PREPARE; an explicit flush hook there is unnecessary but an `Assert(apply_mi_buf == NULL)` is present in both handlers for defence-in-depth symmetry with the stream handlers |
| Stream boundary | In streaming mode, when STREAM_STOP is received | **N/A in pilot** — streaming is excluded entirely (§4.12.3.1). Stream handlers instead `Assert(apply_mi_buf == NULL)` as a defensive check |
| Relcache invalidation | Callback observed `invalidated = true` on the active buffer | **N/A in pilot** — the relcache callback is deferred to full Release N (§4.12.6). The user's schema-stability assertion at `CREATE SUBSCRIPTION ... WITH (multi_insert = on)` covers this in the pilot |
| Unsafe relation | Next INSERT targets a relation where batching is unsafe (see 4.3.4) | ✓ applies — disables batching for the rest of the apply xact via `apply_mi_disabled_for_xact` |

##### Per-Xact Disable Flag Lifecycle

`apply_mi_disabled_for_xact` is a `static bool` in the worker. It is set:

- at buffer init when `apply_mi_relation_is_safe` returns false for a new relation (so repeated INSERTs into the same unsafe relation don't re-run the classifier), and
- at mid-flush conflict (after the subxact rollback, before the per-row replay — see §4.12.5).

It is reset — via `apply_mi_reset_xact_state()` — at exactly two places:

1. **`apply_handle_begin` and `apply_handle_begin_prepare`.** A fresh remote xact starts with batching re-enabled, regardless of what happened in the prior xact.
2. **The outer `PG_CATCH` in `start_apply`.** The erroring apply xact is about to be retried from the same LSN; the retry must not inherit a stale "disabled" flag set by the run that errored out.

The flag is deliberately *not* reset at `STREAM_START` / `STREAM_STOP` (streaming is excluded from the pilot anyway, but this is called out for the Release N migration), nor at RELATION / TYPE messages, nor inside `apply_handle_buffer_flush_any`. Those are intra-xact boundaries; the user's expectation is that a conflict downgrades for the remainder of the current xact, not until the next non-INSERT message.

#### 4.3.4 Safety Checks (Subscriber-Side)

The subscriber performs two orthogonal classifications on the target relation, both computed once at buffer init (see Section 4.3.1):

**Classification A — Permitted to batch at all?** Batching falls back to per-tuple insertion when the **subscriber's** target relation has any of:

- `relkind != RELKIND_RELATION` — partitioned roots, foreign tables, views, etc. (Partitioned roots go through `apply_handle_tuple_routing()`; partition-leaf batching is a Release N limitation and a possible follow-up.)
- A table AM that does not implement `multi_insert` (custom storage engines without the batched insert path).
- BEFORE INSERT FOR EACH ROW triggers — must fire per tuple and can modify or reject the row.
- Row-Level Security active on the target (`relrowsecurity` or `check_enable_rls() == RLS_ENABLED`) — RLS policies are per-tuple by design.
- **Any unique index with `indimmediate = false`** (deferred uniqueness). Deferred unique checks fire at commit, not insert; a batched path would silently admit duplicates into the heap. The check walks the relation's index list via `RelationGetIndexList()` + `SearchSysCache1(INDEXRELID, ...)`.

**Classification B — If batched, does the flush need a subtransaction wrapper?** Set `needs_subxact = true` when any mid-batch failure is possible. The following trigger `needs_subxact`:

- Any unique index with `indimmediate = true` — heap insert succeeds; `ExecInsertIndexTuples()` may still throw on duplicate.
- Any exclusion constraint (`indisexclusion = true`).
- Any CHECK, NOT NULL, or domain constraint (`rd_att->constr != NULL`).
- Any stored generated column (`rd_att->constr->has_generated_stored`) — default-value expressions can raise.
- Any AFTER INSERT ROW trigger or transition table on the target.
- Any trigger at all on the relation (`relhastriggers`), which conservatively catches FK-backing triggers fired via AR-trigger.

When `needs_subxact == false` (pure narrow fact table, no indexes, no constraints, no triggers, no FKs), the flush runs with **zero subtransaction overhead** — the common bulk-load case. When `needs_subxact == true`, the flush is wrapped per Section 4.3.5.

**Important:** these checks are performed on the subscriber side, not the publisher side. The publisher does not know what triggers or constraints exist on the subscriber's tables. The publisher always sends data normally; the subscriber decides whether (and how) to batch.

Batching elects per-tuple when the `apply_mi_buffer->invalidated` flag is set by the relcache callback (Section 4.5.1); the next flush discards the buffer and rebuilds. This covers concurrent DDL on the subscriber target.

#### 4.3.5 Error Handling and Savepoints

`table_multi_insert()` can fail partway through a batch (e.g. unique violation on an index insertion that follows the heap insert, CHECK constraint, AR-trigger FK violation, exclusion constraint). To handle partial failures safely:

1. When `needs_subxact == true` (see Section 4.3.4), the flush is wrapped in an internal subtransaction via `BeginInternalSubTransaction()` and `ReleaseCurrentSubTransaction()` on success.
2. On failure inside the batched flush: `RollbackAndReleaseCurrentSubTransaction()` then `FlushErrorState()` to drop the caught error. The batched heap-insert is fully undone by the subxact rollback.
3. **Per-tuple replay uses one subtransaction *per tuple*, not one surrounding the entire replay.** This is a correction to the original design — wrapping the whole replay in a single subxact would cause a single bad row to abort the peers, making the fallback worse than the current per-tuple-always path. With one subxact per tuple:
   - A tuple that violates uniqueness / FK / CHECK / exclusion rolls back only its own subxact. The existing conflict-reporting and `disable_on_error` / `ALTER SUBSCRIPTION SKIP` machinery runs exactly as it does today.
   - Non-conflicting tuples commit their own subxact and advance.
   - A genuine fatal (OOM mid-commit, deadlock retry exhausted, FATAL) escapes through the per-tuple `PG_CATCH` via `PG_RE_THROW` and the standard apply-worker error path runs.
4. **When `needs_subxact == false`**, no subxact is entered — there is no per-tuple failure mode that batching could isolate, so the overhead is avoided. `heap_multi_insert()` runs directly; any error propagates naturally to the outer xact, as it would on the per-tuple path.
5. **`CheckAndReportConflict()` is not called directly from the batched path** — it is static in `execReplication.c`. The batched path lets `ExecInsertIndexTuples()` throw on conflict, the subxact catches it, and the per-tuple replay runs `ExecSimpleRelationInsert()` which reaches `CheckAndReportConflict()` through the normal code path. This preserves origin/xmin reporting semantics without exporting conflict-reporting internals.
6. The error context callback reports the relation name, batch size, and (when falling back to per-tuple) the specific tuple index.

**Alternative considered and rejected: pre-flush `ExecCheckIndexConstraints()` probe.** During Release N design an early draft attempted to probe all arbiter indexes before calling `heap_multi_insert()`, avoiding the subxact entirely when the probe was clean. This does not work:

- The probe uses a `DirtySnapshot` and reads the on-disk index. Tuples already in the buffer but not yet heap-inserted are invisible. An intra-batch PK duplicate passes the probe; `ExecInsertIndexTuples()` then throws for the second duplicate, and without a subxact to roll back to, the entire apply transaction aborts. Replay restarts from the same LSN and hits the same failure: the worker is stuck.
- The probe path ultimately reaches `check_exclusion_or_unique_constraint()` with `CEOUC_WAIT`, which calls `XactLockTableWait()` on concurrent local writers. The apply worker can be blocked indefinitely on a pre-flush check, which is unacceptable.
- Even on the clean path the probe costs an index scan per tuple that is repeated by `ExecInsertIndexTuples()` during the actual insert — double I/O for no benefit when there is no conflict.

The subxact-when-needed model in steps 1–5 is cheaper in the common case (zero cost when `needs_subxact == false`) and correct in all the cases the probe failed.

**`apply_mi_buffer_abandon` — the outer-PG_CATCH exit.** The subxact logic above handles *mid-flush* conflicts. There is a separate failure mode: an error escapes not just the subxact but the entire inner apply step — a fatal backend error, a propagated `PG_RE_THROW` of a non-unique-violation, OOM during deserialise, a cancel signal in the per-tuple index loop. These unwind all the way to `start_apply`'s top-level `PG_CATCH`, at which point the enclosing apply transaction is already being aborted. Cleanup of the buffer at that point cannot use `apply_mi_buffer_destroy`: the `table_close`, `ExecCloseIndices`, `FreeExecutorState`, and `ExecDropSingleTupleTableSlot` calls all dereference memory the xact abort has already freed, producing a use-after-free. The correct action is `apply_mi_buffer_abandon()`, which **only** NULLs the static pointer and leaves the `ApplyContext` allocations to be reclaimed by the context reset that the abort cycle runs. The caller in `start_apply`'s catch block also calls `apply_mi_reset_xact_state()` so the next apply xact starts with batching re-enabled.

This is a symmetry the destroy/abandon pair must preserve: **destroy releases, abandon forgets.** Mixing the two (e.g. calling destroy from a PG_CATCH "just to be safe") is the use-after-free described above. Mixing the other way (abandon-only from a non-erroring path) leaks the `RowExclusiveLock`, the `TupleDesc` pin, and all palloc'd state until the next xact end — in a long-running apply worker that is effectively a permanent leak.

#### 4.3.6 Transaction Callbacks

Transaction-boundary and stream-boundary flush hooks are enumerated in §4.3.3. All of them take the **final** variant (§4.3.1.2) — `apply_handle_buffer_flush_any` → flush + destroy. The purpose of this subsection is to call out the one non-obvious requirement the boundary hooks impose on the flush code.

**Flush-hook snapshot requirement.** Some flush-hook call sites — notably `apply_handle_commit()` and `apply_handle_prepare()` — run *outside* a `begin_replication_step()` / `end_replication_step()` bracket. Those brackets push/pop the active snapshot. `heap_multi_insert()` asserts `HaveRegisteredOrActiveSnapshot()` and will trip otherwise. `apply_mi_buffer_flush()` must therefore push a transaction snapshot itself when no active snapshot is set:

```c
if (!ActiveSnapshotSet())
{
    PushActiveSnapshot(GetTransactionSnapshot());
    pushed_snapshot = true;
}
/* … flush … */
if (pushed_snapshot)
    PopActiveSnapshot();
```

Skipping this pushes the assertion failure to production; it is not caught by the normal apply path which always flushes from inside `begin_replication_step()` for UPDATE/DELETE/TRUNCATE. The snapshot push is implemented in `apply_mi_buffer_flush` (both variants go through it), so boundary callers do not need to push a snapshot themselves.

#### 4.3.7 Placement: Inline vs Separate File

The original plan envisaged `src/backend/replication/logical/applymultiinsert.c` as a new file. In practice the buffer code must call several *static* helpers in `worker.c` (`TargetPrivilegesCheck()`, `create_edata_for_relation()`, `apply_handle_insert_internal()`). Exporting those to a new translation unit is more invasive than keeping the batching code inline in `worker.c`. The reference implementation follows the `CopyMultiInsertBuffer`-in-`copyfrom.c` precedent and places the buffer code inline in `worker.c`, occupying a contiguous block before `apply_handle_insert()`. Extracting to a separate file is a possible future refactor but is not required for Release N.

### 4.4 Interaction with Streaming Transactions

Since PG14, large in-progress transactions are streamed to the subscriber. The apply worker receives `STREAM_START`, then individual changes, then `STREAM_STOP`. These changes are spooled to BufFiles and replayed at `STREAM_COMMIT`.

**Release N behaviour:** During the BufFile replay at commit time, the apply worker reads back individual INSERT messages from the spool. The batching logic in `apply_handle_insert()` accumulates these during replay exactly as it would during live apply. `STREAM_STOP` and transaction boundaries trigger a flush. No special handling is needed — the existing flush triggers cover all streaming boundaries naturally.

**Release N+1 behaviour:** The publisher batches within each stream chunk, so BufFiles store MULTI_INSERT messages. During replay, `apply_dispatch()` routes them to `apply_handle_multi_insert()`. This is transparent to the streaming infrastructure.

### 4.5 Interaction with Parallel Apply

Since PG16, large streamed transactions can be applied by parallel workers. Parallel workers receive individual change messages through shared memory queues (`pa_send_data()`).

**Release N behaviour:** Each parallel apply worker has its own `ApplyMultiInsertBuffer`. The worker buffers consecutive INSERTs from its message queue and flushes via `table_multi_insert()` as normal. No changes to the parallel apply infrastructure itself. Consideration: the parallel worker processes changes for a single transaction, which may span multiple tables. Relation changes within the stream trigger buffer flushes, so batching effectiveness depends on how interleaved the changes are across tables.

**The relcache invalidation callback (Section 4.5.1 below) MUST be registered in both `ApplyWorkerMain` and `ParallelApplyWorkerMain`.** Registering only in the leader apply worker would leave parallel workers blind to invalidations, potentially flushing against a stale `TupleDesc`. In the reference implementation, the registration call is placed in `InitializeLogRepWorker()` which is reached by both code paths (via `SetupApplyOrSyncWorker()` for apply/tablesync/sequencesync workers and directly from `ParallelApplyWorkerMain()`), so a single call site covers both.

#### 4.5.1 Relcache Invalidation Callback (new subsection)

Concurrent DDL on a subscriber target — `ALTER TABLE ... ADD COLUMN`, creation of a trigger, creation of an index — can fire relcache invalidations mid-batch. The buffered tuples were shaped against the old `TupleDesc`; a flush after the DDL lands would either crash or silently corrupt data.

Handling:

1. Register an invalidation callback via `CacheRegisterRelcacheCallback(apply_mi_relcache_callback, (Datum) 0)` at worker init. The callback runs at arbitrary points — including from inside syscache lookups deep in executor code — so it MUST NOT perform any non-trivial work. It simply sets `buf->invalidated = true` if the callback's `relid` matches `buf->relid` (or `InvalidOid`, meaning "flush all").
2. On the next safe point — the top of `apply_handle_insert()`, the flush hook at non-INSERT entry points, or a transaction boundary — `apply_handle_buffer_flush_any()` observes the flag and discards the buffer (flushing first if tuples are accumulated). The next INSERT rebuilds.
3. If invalidation fires *during* `apply_mi_flush_heap_phase()`, the in-progress flush completes using `buf->local_rel` — the buffer's own `table_open`/`table_close`-owned handle (§4.3.1 "The buffer owns its own `Relation` handle"). The `RowExclusiveLock` and refcount held by the buffer keep it valid for the duration of the flush regardless of what the caller's `logicalrep_rel_open`/`logicalrep_rel_close` cycle is doing. The post-flush destroy path then observes the flag and tears down as normal.

The callback is over-eager — it fires on benign invalidations (e.g. ANALYZE updating statistics, reloption changes). For Release N this over-flushing is accepted as cheap insurance. A future refinement could inspect the invalidation reason.

#### 4.5.2 Parallel Apply Queue Sizing (Release N+1)

MULTI_INSERT wire messages (§4.6) are larger than single INSERT messages. The shared-memory queue used for handing changes to parallel apply workers (`pa_send_data()` → `shm_mq`) must accommodate messages up to `APPLY_MI_MAX_BYTES` (8 MiB). This likely exceeds the default `shm_mq` buffer, so one of two paths applies: either cap publisher-side batches to fit the queue, or split large MULTI_INSERT messages across multiple queue sends at the parallel-apply boundary. **TODO:** verify default `shm_mq` buffer size and document the constraint before Release N+1 lands.

### 4.6 Protocol Extension (Release N+1)

#### 4.6.1 New Message Type: MULTI_INSERT

| Offset | Field | Description |
|--------|-------|-------------|
| Byte 0 | Message type | `'M'` (0x4D) for MULTI_INSERT |
| Bytes 1–4 | Relation OID | uint32, same as single INSERT |
| Bytes 5–8 | Tuple count (N) | uint32, number of tuples in batch |
| Bytes 9+ | N × TupleData | Standard TupleData blocks, packed sequentially |

The TupleData format is identical to the existing INSERT message's TupleData. The subscriber's tuple parsing code (`logicalrep_read_tuple()`) is reused without modification — the only new logic is the outer loop that reads N tuples from a single message.

#### 4.6.2 Protocol Version Negotiation

The current protocol uses sequential version numbers (v1–v4), not a capability bitmask. Following the established pattern:

```c
#define LOGICALREP_PROTO_MULTI_INSERT_VERSION_NUM 5
#define LOGICALREP_PROTO_MAX_VERSION_NUM LOGICALREP_PROTO_MULTI_INSERT_VERSION_NUM
```

The publisher's pgoutput plugin emits MULTI_INSERT messages **only** when the negotiated protocol version is >= 5. Older subscribers negotiate a lower version and receive per-row INSERT messages with zero behavioural change.

**Note:** if a capability-based negotiation mechanism is introduced independently before this feature lands, it should be used instead of a version bump. The design is compatible with either approach.

#### 4.6.3 Buffering in pgoutput_change()

A new structure `PgOutputMultiInsertBuffer` is added to the pgoutput plugin's private data (`PGOutputData`):

```c
typedef struct PgOutputMultiInsertBuffer
{
    Oid             current_relid;  /* relation OID of buffered tuples */
    int             ntups;          /* number of tuples currently buffered */
    int             max_tups;       /* capacity (default: 1000) */
    Size            bytes_used;     /* current buffer byte usage */
    Size            max_bytes;      /* maximum buffer size (default: 65536) */
    StringInfoData  buf;            /* serialised TupleData blocks */
} PgOutputMultiInsertBuffer;
```

When `pgoutput_change()` receives an INSERT change:

1. If the negotiated protocol version < 5: use the existing per-tuple path (no buffering).
2. If the tuple's relation matches `current_relid` and the buffer is not full: serialise the TupleData into `buf`, increment `ntups`.
3. Otherwise: flush the current buffer, then start a new buffer with this tuple.

Publisher-side flush triggers:

| Trigger | Condition |
|---------|-----------|
| Buffer full | `ntups >= max_tups` or `bytes_used >= max_bytes` |
| Relation change | Next change targets a different relation OID |
| Non-INSERT operation | Next change is UPDATE, DELETE, or TRUNCATE |
| Transaction boundary | COMMIT, ABORT, or PREPARE callback invoked |
| Stream boundary | STREAM_STOP callback invoked |

Flush logic: if buffer contains 1 tuple, emit a standard INSERT message. If N > 1, emit a MULTI_INSERT message. Reset buffer state.

The `pgoutput_commit`, `pgoutput_abort`, `pgoutput_stream_stop`, and `pgoutput_prepare_txn` callbacks must flush the buffer before emitting their respective protocol messages.

#### 4.6.4 Column Lists and Row Filters

Since PG15, publications support column lists and row filters. On the publisher side, pgoutput already applies column lists and row filters before serialising each tuple. With batching:

- All tuples in a MULTI_INSERT batch target the same relation, so they share the same column list. No special handling needed.
- Row filters are applied per-tuple before the tuple enters the buffer. Tuples that fail the filter are never buffered. The buffer contains only tuples that passed the filter.

### 4.7 REPLICA IDENTITY and Conflict Detection

Logical replication conflict detection for INSERTs works by checking the replica identity index for duplicates during index insertion (which follows the heap insert). With `table_multi_insert()`:

- `heap_multi_insert()` does not check uniqueness — it inserts into the heap unconditionally.
- Index insertions happen per-tuple after the heap batch insert.
- A unique violation during index insertion triggers a savepoint rollback. Release N's variant (§4.3.5) uses a per-tuple sub-subxact replay; the pilot's simpler variant (§4.12.5) rolls back the whole batch once, disables batching for the remainder of the current apply transaction, and replays row-by-row through `ExecSimpleRelationInsert`. Both reach the same `CheckAndReportConflict()` code path.

This means conflict detection works correctly without modification — it just happens at the index insertion step rather than the heap insertion step, which is the same as the current per-tuple path.

For tables with `REPLICA IDENTITY FULL` (no index-based identity), the apply worker uses a sequential scan to find conflicts. This is inherently per-tuple and is unaffected by heap batching.

### 4.8 Tablesync Workers

Tablesync workers handle initial table synchronisation when a subscription is created or when a new table is added to a publication. The tablesync process has two phases, and the feature's impact is different in each:

1. **COPY phase** (`SUBREL_STATE_DATASYNC`) — **no impact, by design.** The tablesync worker requests a snapshot-consistent COPY of the entire table from the publisher. The publisher's walsender sends the data using the COPY protocol. On the subscriber, the tablesync worker receives this data and feeds it into `CopyFrom()` via the `copy_table()` helper in `tablesync.c`. `CopyFrom()` already batches internally via the existing `CopyMultiInsertBuffer` infrastructure in `copyfrom.c` — the COPY phase does not use the single-row `ExecSimpleRelationInsert()` path and does not need the subscriber-side `ApplyMultiInsertBuffer`. Enabling `multi_insert` on the subscription therefore changes **nothing** about COPY-phase performance: the bulk-load path is already as efficient as it can be in isolation, and is entirely independent of the apply-side batching machinery described here. An earlier draft of Release N included a "Patch 5" modifying tablesync; that patch has been dropped.

2. **Catch-up phase** (`SUBREL_STATE_FINISHEDCOPY` → `SUBREL_STATE_SYNCDONE` → `SUBREL_STATE_READY`) — **this is where the feature helps.** After the snapshot COPY completes, the tablesync worker (or the main apply worker) must replay any changes that accumulated on the publisher during the COPY: the publisher accepted writes during the snapshot export, and those writes are now buffered as logical-replication changes starting from the tablesync slot's origin LSN. These are regular `LOGICAL_REP_MSG_INSERT` / `UPDATE` / `DELETE` messages applied via the normal `apply_handle_insert()` path, so the catch-up phase inherits `ApplyMultiInsertBuffer` batching automatically with **no tablesync-specific code change** required. For subscriptions onto busy publishers, the catch-up backlog can itself be large (seconds to minutes of decoding lag), and the WAL-reduction benefit on the subscriber side applies there exactly as it does for ongoing apply.

**Net effect:**

- **Initial bulk load itself:** unchanged. COPY's own batching already dominates; `multi_insert` does not stack on top of it.
- **Post-COPY catch-up:** batched via the shared apply path, no extra code. For a busy publisher this can be the dominant fraction of total "time until tablesync enters READY state".
- **Steady-state apply after READY:** batched as in the non-tablesync case.

**Release N benefit for tablesync:** catch-up phase only, and only for subscriptions that spent meaningful decoding time in the catch-up stage. No code changes to `tablesync.c` are required.

**Release N+1 benefit for tablesync:** During the COPY phase, the publisher sends data using the COPY sub-protocol (not logical replication INSERT messages), so the MULTI_INSERT wire protocol does not apply here; COPY's own batching already minimises WAL on the subscriber. During the catch-up phase, MULTI_INSERT messages from the publisher's ongoing WAL stream are processed normally by the subscriber's batched apply path.

### 4.9 Failure Modes and Recovery

#### Process Crash (Apply Worker)

**What fails:** The apply worker crashes (SIGKILL, OOM, assertion failure) while a batch is partially accumulated in `ApplyMultiInsertBuffer` but not yet flushed.

**State after failure:** The in-memory buffer is lost. No tuples from the unflushed batch have been written to the heap. The transaction (if in-progress) is aborted by the postmaster. The replication origin's confirmed flush LSN has not been advanced past the unflushed tuples.

**Recovery:** The apply launcher restarts the apply worker. The worker reconnects to the publisher, and replication resumes from the last confirmed flush LSN. The tuples from the lost batch are re-sent by the publisher and re-applied. No data loss, no divergence.

**If recovery fails:** Standard apply worker restart logic. After repeated failures, the subscription can be disabled (`ALTER SUBSCRIPTION ... DISABLE`).

#### Process Crash (Walsender / pgoutput — Release N+1)

**What fails:** The walsender crashes while pgoutput has buffered tuples in `PgOutputMultiInsertBuffer`.

**State after failure:** The buffered tuples were never sent on the wire. The replication slot's confirmed_flush_lsn has not been advanced past the unsent tuples.

**Recovery:** The subscriber reconnects, walsender restarts from the slot's confirmed_flush_lsn, and re-decodes + re-sends the changes. No data loss.

#### Network Partition

**What fails:** The connection between publisher and subscriber drops.

**State:** The apply worker's in-memory buffer may contain unflushed tuples. The TCP connection timeout (or `wal_receiver_timeout`) eventually triggers disconnection.

**Recovery:** On reconnection, replication resumes from the last confirmed LSN. Unflushed buffer contents are re-received and re-applied.

#### Partial Batch Failure (Unique Violation)

**What fails:** One tuple in a batch of N violates a unique constraint on the subscriber.

**State:** The batch was wrapped in a savepoint. `table_multi_insert()` succeeds (heap insert), but the subsequent per-tuple index insertion fails on the conflicting tuple.

**Recovery:** Roll back to savepoint. Re-apply the entire batch tuple-by-tuple. The conflicting tuple is handled by the existing conflict resolution path (`disable_on_error`, logging, `ALTER SUBSCRIPTION SKIP`). Non-conflicting tuples are applied normally.

#### Disk Full on Subscriber

**What fails:** `table_multi_insert()` cannot extend the heap or write WAL.

**State:** The batch transaction is aborted. The savepoint mechanism ensures no partial state.

**Recovery:** Standard PostgreSQL error handling. The apply worker retries after the disk space issue is resolved.

### 4.10 Backward Compatibility

**Release N (subscriber-side only):** No protocol changes. No compatibility concerns. A new subscriber with batching works with any publisher version (PG10+). An old subscriber without batching continues to work normally. No changes to pg_dump, pg_restore, or pg_upgrade. Existing replication slots and origins are unaffected.

**Release N+1 (protocol extension):** Protocol version 5 is negotiated. If the subscriber doesn't support v5, the publisher falls back to v4 (or lower) and sends per-row INSERT messages. If the publisher doesn't support v5, the subscriber negotiates a lower version and operates without batching on the publisher side (but still batches locally if it has Release N). Rolling upgrades in either direction work correctly.

### 4.11 Interaction Matrix

| Subsystem | Status | Notes |
|-----------|--------|-------|
| Partitioned tables | Works correctly | `apply_handle_tuple_routing()` routes each tuple before buffering; tuples for different partitions flush the buffer (relation change) |
| Row-Level Security | Works correctly | RLS policies are checked during `ExecSimpleRelationInsert()` / `table_multi_insert()` on the subscriber; per-tuple evaluation is preserved |
| Triggers (BEFORE ROW) | Known limitation | Batching disabled for relations with BEFORE INSERT FOR EACH ROW triggers; falls back to per-tuple path |
| Triggers (AFTER ROW) | Works correctly | AFTER triggers fire after the batch; deferred triggers fire at commit |
| Generated columns (VIRTUAL) | Not applicable | Virtual generated columns are not stored; no subscriber-side computation required |
| Generated columns (STORED) | Works correctly | pgoutput omits stored generated columns from the wire message; the subscriber computes them via `ExecComputeStoredGenerated()`. The batched path calls this explicitly on each buffered slot before `table_multi_insert()` (same contract that `ExecSimpleRelationInsert()` honours at `execReplication.c:836–839`). Forgetting this step causes silent data corruption — stored generated columns insert as NULL when they should be computed. `needs_subxact` is forced true when `constr->has_generated_stored` is set, because the generator expression can raise |
| Large objects | Not applicable | Large objects are not replicated |
| Sequences | Not applicable | Sequence values are replicated as row data; batching doesn't affect sequence state |
| TRUNCATE with foreign keys | Not applicable | TRUNCATE is a separate operation type; flushes the buffer before processing |
| Parallel apply | Works correctly (Release N); **pilot: excluded** | Each parallel worker maintains its own buffer; see Section 4.5. The pilot refuses `multi_insert + streaming != off` at DDL time (§4.12.3.1), which transitively excludes parallel apply |
| Streaming transactions | Works correctly (Release N); **pilot: excluded** | Flush on STREAM_STOP; replay from BufFile naturally batches; see Section 4.4. The pilot excludes streaming entirely (§4.12.3.1) |
| Synchronous replication | Works correctly | Synchronous commit semantics are at the transaction level, not the tuple level; batching within a transaction is transparent |
| Cascading replication | Works correctly | The subscriber's WAL (now reduced by batching) is what cascading subscribers consume; they benefit from the reduced WAL volume |
| Two-phase commit | Works correctly (Release N); **pilot: supported but not exercised** | Flush on PREPARE; the prepared transaction contains the batched heap inserts. Pilot allows `multi_insert` with two-phase subscriptions (the DDL check is against `streaming`, not `two_phase`), but the test matrix focuses on non-streaming apply |
| Tablesync — COPY phase | No impact | The initial snapshot load goes through `CopyFrom()` / `CopyMultiInsertBuffer` and is already batched; the subscriber-side apply buffer is not involved. See Section 4.8 |
| Tablesync — catch-up phase | Benefits directly | Post-COPY replay of changes accumulated during the snapshot uses the normal `apply_handle_insert()` path; batching inherits transparently. The dominant beneficiary when the publisher was busy during COPY |
| Column lists (PG15+) | Works correctly | Column lists applied before buffering on publisher; all tuples in a batch share the same column list |
| Row filters (PG15+) | Works correctly | Row filters applied before buffering on publisher; only passing tuples are buffered |
| REPLICA IDENTITY FULL | Works correctly | Conflict detection for FULL identity uses sequential scan, which is per-tuple and unaffected by heap batching |
| ON CONFLICT handling | Known limitation | Batching disabled when subscriber-side conflict resolution requires per-tuple checking; falls back to per-tuple path |

### 4.12 Pilot Variant: `multi_insert` Protocol Option (Release N-0)

Before the full Release N design ships, a **pilot variant** offers a much smaller, easier-to-review path to the headline benefit. The pilot trades breadth of applicability for simplicity and for the absence of any new per-tuple failure-mode machinery.

#### 4.12.1 Goal and Scope

Deliver subscriber-side batched multi-insert for the common narrow-fact-table workload without any of the defensive subscriber-side schema introspection, stored-generated-column handling, or per-tuple replay subxact that Section 4.3 describes. The pilot is an **opt-in**: a publication or subscription option that asserts a set of schema restrictions hold. If the restrictions hold, the subscriber batches; if not, the subscriber falls back to the existing per-tuple path or refuses to enable batching at all.

#### 4.12.2 Subscription Option

A new boolean subscription option `multi_insert = on/off`. Default `off`. Stored in `pg_subscription.submultiinsert` (new catalog column, bumped `CATALOG_VERSION_NO`). Set at `CREATE SUBSCRIPTION ... WITH (multi_insert = on)` and changed at `ALTER SUBSCRIPTION ... SET (multi_insert = on)`; surfaces in `pg_dump` output and `psql \dRs+`.

When `on`, the apply worker's `apply_handle_insert()` may engage `table_multi_insert()` for batched insertion on eligible relations (§4.12.3); when `off`, existing per-tuple behaviour is preserved.

**No wire protocol changes in the pilot.** The option is purely a subscriber-side toggle; it does not travel on the wire and the publisher is unaware of it. The publisher continues to emit per-row INSERT messages regardless of the subscriber's setting. Subscriber-side negotiation with the publisher — so that a publisher-side `MULTI_INSERT` wire message could be emitted when and only when the subscriber supports it — is deferred to Release N+1 (§4.6) and is orthogonal to this pilot.

**Interaction with streaming.** `multi_insert = on` is mutually exclusive with `streaming != off`; see §4.12.3.1 for the rationale and the two enforcement points.

#### 4.12.3 Required Schema Restrictions (User-Asserted)

When `multi_insert = on`, the subscriber's target relation must satisfy **all** of the following for batching to engage. The subscriber verifies these at buffer init; a table failing any check silently falls back to per-tuple for that table only (does not disable the subscription).

- `relkind == RELKIND_RELATION` (no partitioned roots, foreign tables, views).
- Table AM implements `multi_insert`.
- **No triggers of any kind** (`relhastriggers == false`). Covers BEFORE/AFTER row triggers, statement triggers, and FK-backing triggers.
- **No foreign keys** (equivalent to `relhastriggers == false` above, since FKs are implemented as AR triggers).
- **No row-level security** (`relrowsecurity == false`, `check_enable_rls() != RLS_ENABLED`).
- **No CHECK constraints or stored generated columns** — these are the members of `rd_att->constr` that can raise per tuple. NOT NULL (also recorded in `constr`) is accepted: the publisher guarantees non-null values by its own constraint. Default-value evaluation via `slot_fill_defaults` is safe.
- **No exclusion constraints**.
- **No deferrable unique indexes** (every `indisunique` index has `indimmediate == true`).
- UNIQUE and PRIMARY KEY indexes **are permitted** — REPLICA IDENTITY depends on them, and the intra-batch safety argument (§4.12.4) makes them safe.

Schema identity between publisher and subscriber is **asserted by the user** via the subscription option; the subscriber does not verify it. If the user lies, the apply worker may insert rows that violate subscriber-side invariants the publisher did not know about — identical to what happens today when subscriber-side constraints diverge, no new failure mode.

**Implementation note:** an earlier draft used `tupdesc->constr != NULL` as shorthand for "no constraints". This is wrong: `tupdesc->constr` is non-NULL for any table with ANY `NOT NULL` column — which includes every PRIMARY KEY table. The test must specifically check `constr->num_check > 0 || constr->has_generated_stored`. A subtle failure: the check silently rejects every PK-bearing table, batching never engages, and WAL volume is unchanged from the non-batched baseline.

**Struct differences from §4.3.1.** The pilot collapses §4.3.1's `needs_subxact` field (full Release N's Classification B result) into a single boolean `has_immediate_unique`, which is true iff any valid, immediate UNIQUE or PRIMARY KEY index exists on the target. This is all the pilot's conflict-handling model (§4.12.5) needs: the wrap-in-subxact decision is binary. The full Release N design re-expands this into per-relation `needs_subxact` because its per-tuple-subxact replay path cares about a richer set of can-this-raise-per-tuple properties (CHECK, generated-stored, FK triggers, AR triggers). The pilot also omits the `mid_flush` and `invalidated` fields — both relate to the relcache-invalidation callback that §4.12.6 defers to full Release N.

The pilot **retains** the following fields from §4.3.1, with identical semantics: `relid`, `local_rel` (buffer-owned, see §4.3.1 "The buffer owns its own `Relation` handle"), `relinfo`, `estate`, `receiveslot` (long-lived, see §4.3.1 "Profile rationale"), `slots` / `nslots` / `capacity` (lazy allocation + reuse, see §4.3.1 "Slots array"), `cum_bytes`, and `owner_at_init`. The `bytes_used`/`max_bytes` field pair in the §4.3.1 struct is renamed to `cum_bytes` with a compile-time `APPLY_MI_MAX_BYTES` cap; full Release N exposes the cap as a subscription option, the pilot does not (§4.12.6).

#### 4.12.3.1 Mutual Exclusion with Streaming (Release N-0)

`multi_insert = on` and `streaming != off` are **mutually exclusive** in the pilot. The pilot's buffer lifetime, flush hooks, and intra-batch safety proof (§4.12.4) are specified for the non-streaming apply path only. The streaming apply paths — live-chunk spooling via `stream_write_change`, `TRANS_LEADER_SERIALIZE` spooled replay at `STREAM_COMMIT`, `TRANS_LEADER_SEND_TO_PARALLEL` handoff through shm_mq, and `TRANS_PARALLEL_APPLY` in the parallel worker — each have their own transaction/snapshot/memory-context shape that the pilot deliberately does not validate. Full Release N covers streaming; the pilot ships the smaller, provable case.

The restriction is enforced at two points:

1. **DDL time.** `CREATE SUBSCRIPTION ... WITH (streaming = ..., multi_insert = ...)` and `ALTER SUBSCRIPTION ... SET (...)` reject the combination with `errcode(ERRCODE_INVALID_PARAMETER_VALUE)` and hint `Set streaming = off to enable multi_insert.` The `ALTER` check uses the **effective** values after the ALTER — if the ALTER does not specify an option, its current catalog value is used.

2. **Runtime (defensive).** `apply_mi_buffer_init` asserts `MySubscription->stream == LOGICALREP_STREAM_OFF`, `!am_parallel_apply_worker()`, and `!in_streamed_transaction`. Hitting any of these asserts indicates the DDL check was bypassed (catalog corruption, direct catalog update, pg_upgrade defect) and constitutes a bug.

#### 4.12.4 Intra-Batch Duplicate Safety (Proof Sketch)

The pilot relies on the following invariant, which follows from the wire-format ordering and the subscriber's flush rules:

> **Invariant:** Within a single apply batch, no two buffered tuples share a value in any unique key.

The flush rules (Sections 4.3.3, 4.3.6) guarantee:

1. A batch contains only `INSERT` messages.
2. All buffered INSERTs target the same relation (relation-change flushes).
3. No `UPDATE`, `DELETE`, or `TRUNCATE` appears between two buffered INSERTs in the same batch (any non-INSERT flushes).
4. All buffered INSERTs originate from a single publisher transaction — transaction boundaries flush. (Streaming is excluded in the pilot per §4.12.3.1, so "streaming transaction chunk" is not a concern here; the proof holds only for non-streamed xacts in the pilot.)

Given these, the publisher could not have sent two INSERTs for the same unique-key value consecutively in the wire stream without an intervening DELETE or key-changing UPDATE — because its own unique constraint would have rejected the second INSERT at the source. A key-changing UPDATE is a non-INSERT and therefore flushes. Therefore two tuples with the same unique-key value cannot coexist in one buffered batch.

**This eliminates the class of bugs that motivated the full Release N subxact design.** The only residual conflict source is "a buffered tuple conflicts with a row already present on the subscriber" (e.g. from a prior failed apply, manual data, or divergence). That case is handled below.

#### 4.12.5 Conflict Handling

This section describes the pilot's simplification of the full Release N savepoint model (§4.3.5). The full design uses per-tuple sub-subxacts so a single bad row does not disturb its peers; the pilot degrades to per-row for the remainder of the apply transaction after the first conflict. See §4.12.7 for the migration path back to the finer-grained model.

Per §4.12.4 the only possible mid-batch failure is a conflict against a pre-existing subscriber row. Handling:

1. **If the relation has no unique indexes:** no subxact needed. `heap_multi_insert()` runs without any per-tuple index insertion that could fail. Batch always succeeds or the whole apply xact aborts for a non-conflict reason (OOM, WAL full, etc.) which the standard apply-worker error path handles.

2. **If the relation has at least one unique index:** wrap the flush in a single `BeginInternalSubTransaction()`. On conflict (`ExecInsertIndexTuples()` throws `ERROR_CODE_UNIQUE_VIOLATION` or similar), the pilot:
   - Rolls back the savepoint.
   - Disables batching for the remainder of this apply transaction.
   - Replays the buffered tuples through `ExecSimpleRelationInsert()`, which reaches the existing `CheckAndReportConflict()` path. `disable_on_error` and `ALTER SUBSCRIPTION SKIP` work unchanged.
   - Subsequent apply transactions re-enable batching automatically.

There is **no per-tuple sub-subxact loop**. A single conflict downgrades the rest of the transaction to per-tuple; the next transaction starts fresh. This is a deliberate simplification over §4.3.5: coarser isolation, materially less code, no semantic regression vs today (today's per-tuple path also aborts the entire apply xact if a conflict is not handled by `disable_on_error` / SKIP).

#### 4.12.5.1 Interrupt Processing

Batching increases the longest `CHECK_FOR_INTERRUPTS()`-free window on the apply worker from "one tuple" (upstream per-tuple path: one CFI per dispatched message in `LogicalRepApplyLoop`) to potentially "one batch" (the flush processes `max_slots` tuples through `heap_multi_insert` + the per-tuple `ExecInsertIndexTuples` loop, then potentially replays up to `max_slots` tuples via `ExecSimpleRelationInsert` on the fallback path). For `max_slots = 1000` and a mid-size indexed table, that window can reach ~100 ms — visibly slower response to `pg_terminate_backend`, SIGHUP config reload, and statement-timeout-like events than upstream.

**Requirements:**

1. `apply_mi_flush_heap_phase` MUST call `CHECK_FOR_INTERRUPTS()`:
   - once between `table_multi_insert()` and the per-tuple index loop (the heap-insert itself can run for tens of ms on large batches); and
   - once at the top of each iteration of the per-tuple `ExecInsertIndexTuples` loop.

2. The per-tuple replay loop in `apply_mi_buffer_flush`'s `PG_CATCH` MUST call `CHECK_FOR_INTERRUPTS()` at the top of each iteration. Without this, a batch rollback followed by replay could take as long as the heap phase it replaced, still uninterruptible. (The `PG_CATCH` lives in `apply_mi_buffer_flush` — the intermediate flush variant, §4.3.1.2 — because that is where the subxact is wrapped. `apply_handle_buffer_flush_any` is a thin wrapper that calls `apply_mi_buffer_flush` then `apply_mi_buffer_destroy`.)

3. The `PG_CATCH` block in `apply_mi_buffer_flush` MUST classify the caught error and re-throw anything that is not `ERRCODE_UNIQUE_VIOLATION`. A blanket catch swallows cancel-class errors (`ERRCODE_QUERY_CANCELED` thrown by `ProcessInterrupts`, which clears `QueryCancelPending` before raising): without the classification, the replay loop runs with the cancel flag already cleared, completes cleanly, and the cancel is silently lost. The safety check (§4.12.3) has already ruled out the other plausible conflict-class errors (exclusion, CHECK, NOT NULL on non-PK, FK), so `UNIQUE_VIOLATION` is the only one the catch needs to handle.

**Non-requirements:**

- `apply_mi_buffer_add` does not require CFI; the enclosing `LogicalRepApplyLoop` already calls `CHECK_FOR_INTERRUPTS()` per inbound message, and buffer-add runs once per message.
- `apply_mi_buffer_init` and `apply_mi_buffer_destroy` are bounded by the relation's index count (init) or `max_slots` slot drops (destroy), both fast; per-iteration CFI in these paths is noise.

Full Release N inherits these requirements unchanged; the per-tuple-sub-subxact refinement of §4.3.5 increases the number of subxact entries but does not change the shape of the CFI requirement.

#### 4.12.6 What the Pilot Explicitly Does Not Do

- **No streaming support.** `multi_insert = on` is mutually exclusive with `streaming != off`; see §4.12.3.1.  Streamed bulk loads are the dominant real-world workload for batching, so the pilot's utility is correspondingly narrow — it exists to validate the design, not to win benchmarks.  Full Release N adds streaming coverage.
- **No `ApplyExecutionData`-style tuple routing for partition roots.** Partitioned tables take the existing per-tuple path.
- **No relcache invalidation callback.** The user asserts schema stability for the subscription's lifetime; if they `ALTER TABLE ... ADD TRIGGER` mid-apply, the apply worker will happily miss the new trigger's firing until the buffer is destroyed at the next transaction boundary, at which point the safety check re-runs. This is a conscious trade-off: a missed trigger firing on in-flight buffered tuples is the user's responsibility when they enabled `multi_insert`.
- **No `pg_stat_subscription_stats` counters**. Ship these in the follow-up full Release N.
- **No per-subscription `multi_insert_size` tuning**. Compile-time constants only (`APPLY_MI_MAX_SLOTS = 10000`, `APPLY_MI_MAX_BYTES = 8 MiB`, `APPLY_MI_INITIAL_SLOTS = 16`; see §4.3.1.1). Tunability comes with the full Release N. Note that the apply-side buffer does not have COPY's quadratic-memory concern (see §4.3.1.1): only one relation is buffered at a time, so the cap is a throughput knob rather than a memory-safety bound.

#### 4.12.7 Migration Path to Full Release N

The pilot is designed to be additively replaced by the full Release N design, not rewritten:

- The `ApplyMultiInsertBuffer` struct and its core lifecycle (init / add / flush / destroy) are identical to the full design.
- The `needs_subxact` bool collapses to "has any unique index" in the pilot; the full design re-expands it to the full Classification B of §4.3.4.
- **Streaming support is added.** The `multi_insert + streaming` DDL check is dropped, the defensive runtime asserts in `apply_mi_buffer_init` are removed (or narrowed to exclude only the parallel-apply worker), and the flush-hook placement at `apply_handle_stream_commit` / `apply_handle_stream_prepare` is re-introduced (flush after `apply_spooled_messages`, before the commit/prepare internal).
- The relcache callback is added.
- The per-tuple sub-subxact replay replaces the coarse "disable batching for this xact" on-conflict behaviour.
- The restriction list of §4.12.3 relaxes: triggers / FK / RLS / stored-generated-columns each gain a code path.

No wire protocol changes are introduced by the pilot, so publisher-side `MULTI_INSERT` (Release N+1) is uninvolved and the two tracks can proceed independently once the pilot lands.

#### 4.12.8 Pilot Patch Decomposition

| Patch | Description | Est. Lines |
|-------|-------------|------------|
| P1 | Subscription option `multi_insert` (bool, default off); catalog column `submultiinsert`; plumbing through `parse_subscription_options`, `pg_dump`, `psql \dRs+` | ~150 |
| P2 | `ApplyMultiInsertBuffer` inline in `worker.c`: struct, init/add/flush/destroy, `apply_mi_relation_is_safe()` (single-boolean safe check per §4.12.3), subxact wrap when any unique index exists | ~250 |
| P3 | Modify `apply_handle_insert()` to buffer tuples; add flush hooks at `apply_handle_{update,delete,truncate,relation,type,message,commit,prepare,stream_*}`; `apply_mi_buffer_discard()` at stream-abort; `PushActiveSnapshot()` in flush hook | ~120 |
| P4 | TAP tests: narrow fact table, table with PK (conflict + no-conflict), table with disqualifying trigger (should fall back), streamed batch, two-phase | ~250 |

Total: **~770 lines** including tests. Compare full Release N: ~1600 lines.

## 5. Monitoring and Observability

### 5.1 New Statistics

Extend `pg_stat_subscription_stats` with:

- `multi_insert_count` — number of `table_multi_insert()` calls (batched flushes)
- `multi_insert_tuples` — total tuples inserted via `table_multi_insert()`
- `multi_insert_fallbacks` — number of times batching fell back to per-tuple insertion (trigger, conflict, etc.)

These allow a DBA to answer: "is batching working for my subscription, and how often does it fall back?"

### 5.2 Diagnosing Problems

- **Batching not helping:** Check `multi_insert_fallbacks` — if it's high relative to `multi_insert_tuples`, most tables may have BEFORE ROW triggers or unique constraints that force fallback.
- **Apply still slow:** Index insertion remains per-tuple. For tables with many indexes, the throughput improvement from heap batching alone may be modest.

### 5.3 Runtime Control

**Release N:** A per-subscription option controls batching:

```sql
ALTER SUBSCRIPTION mysub SET (multi_insert = on);  -- default: off (pilot); Release N may flip to on
ALTER SUBSCRIPTION mysub SET (multi_insert_size = 10000);  -- default: APPLY_MI_MAX_SLOTS
```

This follows the pattern of existing subscription options (`streaming = on/off/parallel`, `disable_on_error`, etc.) and allows per-subscription control without global GUCs.

**Release N+1:** A publication-level option controls publisher-side batching:

```sql
CREATE PUBLICATION mypub FOR ALL TABLES WITH (multi_insert = true);
```

## 6. Performance Considerations

### 6.1 Expected Benefits

| Metric | Estimated Improvement | Basis |
|--------|----------------------|-------|
| Subscriber WAL volume | ~3x reduction | Benchmark: 21 GB → ~7 GB for 100M rows; ratio stable at 1M/10M/100M |
| Apply throughput (no indexes) | 2–3x faster | Fewer buffer pin/unpin, fewer lock acquisitions, fewer WAL records |
| Apply throughput (with PK index) | 1.5–2x faster (estimated) | Index insertions remain per-tuple; **TODO: benchmark** |
| Initial table sync (tablesync) | ~3x WAL reduction + faster sync | Tablesync COPY phase uses single-insert path; benefits directly from batching |
| Network traffic (Release N+1) | ~25–30% reduction | Amortised per-message headers |

### 6.2 Overhead

- **Memory:** Exactly one active `ApplyMultiInsertBuffer` at a time in the apply worker (§4.3.1 lifetime rule). Peak working-set is bounded by `APPLY_MI_MAX_BYTES = 8 MiB` for buffered tuple data, plus O(natts × sizeof(TupleTableSlot)) × `APPLY_MI_MAX_SLOTS` for slot headers (worst case a few MiB at 10000 slots of wide tuples). Upper bound is in the low tens of MiB regardless of how many distinct relations the remote transaction touches, because relation-change flushes before re-initialising.
- **CPU:** Negligible. The batching logic is a comparison (same relation? buffer full?) per tuple, plus the `table_multi_insert()` call which replaces N `table_tuple_insert()` calls.
- **Latency:** For single-row OLTP transactions, the buffer will typically contain 1 tuple and flush immediately — effectively the same as the current per-tuple path. Batching provides no benefit and no penalty for OLTP workloads.

### 6.3 Scenarios Where Batching May Not Help

- **Tables with many indexes:** Index insertion is per-tuple regardless. For a table with 5 B-tree indexes, index insertion may dominate and cap improvement at ~1.2–1.5x.
- **Highly interleaved multi-table transactions:** If a transaction inserts one row into table A, one into table B, one into A, one into B, etc., the buffer flushes on every relation change and batching provides no benefit.
- **Tables with BEFORE ROW triggers:** Batching is disabled entirely; performance is identical to current behaviour.

## 7. Testing Strategy

### 7.1 Correctness Tests (TAP tests in `src/test/subscription/`)

1. COPY 10,000 rows on publisher → verify all rows arrive on subscriber with identical content.
2. INSERT ... SELECT 10,000 rows → verify same behaviour.
3. Mixed workload: interleave INSERT, UPDATE, DELETE across 3 tables in a single transaction → verify subscriber state matches publisher exactly.
4. Trigger fallback: create BEFORE INSERT trigger on subscriber table → verify single-insert path is used and trigger fires correctly for every row.
5. Mid-batch unique violation: insert batch where one tuple conflicts with existing subscriber data → verify error is reported with correct tuple identification, non-conflicting tuples are applied.
6. Partitioned table: COPY into partitioned table on publisher → verify rows are correctly routed to partitions on subscriber.
7. Streaming transaction: insert 1M rows (exceeding `logical_decoding_work_mem`) → verify streaming + batching work together.
8. Parallel apply: large streamed transaction with parallel apply enabled → verify batching works in parallel workers.
9. Two-phase: `BEGIN; INSERT 10,000 rows; PREPARE TRANSACTION 'x'; COMMIT PREPARED 'x';` → verify batching across prepare/commit.
10. Tablesync: create subscription on a table with 100,000 existing rows → verify initial COPY phase uses batched insert and completes correctly.

### 7.2 Protocol Compatibility Tests (Release N+1)

1. New publisher (v5) + old subscriber (v4): verify fallback to per-row INSERT messages.
2. Old publisher (v4) + new subscriber: verify subscriber-side batching still works (Release N behaviour).
3. Rolling upgrade: publisher upgraded first, subscriber still on old version → verify no disruption.

### 7.3 Failure Mode Tests

1. `pg_terminate_backend()` on apply worker mid-batch → verify clean restart and no data loss.
2. `kill -9` on apply worker → verify restart from correct LSN.
3. Insert batch with one conflicting row + `disable_on_error = on` → verify subscription disables with actionable error message.

### 7.4 Performance Tests

1. Baseline: COPY 10M rows with and without the patch, measure subscriber WAL, apply time. Target: subscriber WAL within 1.5x of publisher COPY WAL.
2. With primary key: repeat baseline with `PRIMARY KEY (id)` on both sides.
3. With 3 indexes: repeat with PK + 2 additional B-tree indexes.
4. OLTP baseline: pgbench single-row inserts → verify no regression.

## 8. Implementation Plan

### Release N-0 — Pilot (`multi_insert` opt-in)

See §4.12.8 for the pilot patch decomposition. Recommended first target for pgsql-hackers review — ~770 LoC including tests, no subxact-per-tuple machinery, no relcache callback, no stats views.

### Release N — Subscriber-Side Batching

| Patch | Description | Est. Lines | Dependencies |
|-------|-------------|-----------|--------------|
| 1 | `ApplyMultiInsertBuffer` inline in `worker.c`: struct, init, add, flush_heap_phase, per-tuple replay, destroy, relcache callback; `apply_mi_relation_is_safe()` classifier computing `needs_subxact` | ~450 | None |
| 2 | Modify `apply_handle_insert()` to buffer tuples; add flush hooks at `apply_handle_{update,delete,truncate,relation,type,message,commit,prepare,stream_{stop,commit,prepare}}`; `apply_mi_buffer_discard()` at stream-abort. Push `ActiveSnapshot` in flush hook when not already set | ~150 | Patch 1 |
| 3 | (merged into Patches 1 + 2 — subxact wiring, deferrable-unique rejection, RLS rejection, FK/trigger/constraint `needs_subxact` classification) | — | — |
| 4 | Extend the pilot's `multi_insert` option with `multi_insert_size` (int, default `APPLY_MI_MAX_SLOTS`): catalog column `submultiinsertsize` on top of the pilot's `submultiinsert`; plumb through `CreateSubscription`, `AlterSubscription`, `pg_dump`, `psql \dRs+`; bump `CATALOG_VERSION_NO` | ~250 | Patch 2 |
| 5 | **(dropped)** Tablesync COPY phase already batches via `CopyMultiInsertBuffer` inside `CopyFrom()`; catch-up phase inherits from Patch 2 automatically. Add a 2-line comment to `tablesync.c::copy_table()` documenting this | ~10 | Patch 2 |
| 6 | `pg_stat_subscription_stats` counters: `multi_insert_count`, `multi_insert_tuples`, `multi_insert_fallbacks`. Reporter `pgstat_report_subscription_multi_insert()` + view/proc updates | ~150 | Patch 2 |
| 7 | TAP tests (correctness — including intra-batch PK collision; failure modes; compatibility; tablesync catch-up; concurrent DDL via relcache inval; parallel apply) | ~600 | Patches 1–6 |

**Patch 1 is fully self-contained and adds no call sites**, so it can be reviewed and committed before Patch 2 wires the buffer into `apply_handle_insert()`. Forward declarations (`apply_handle_buffer_flush_any`, `apply_mi_buffer_discard`, `apply_mi_relcache_callback`) must be added to the file-level static-declaration block in `worker.c` (near `apply_handle_commit_internal`'s forward decl) because flush hooks call them from functions that appear earlier in the file than the batching block.

### Release N+1 — Protocol Extension

| Patch | Description | Est. Lines | Dependencies |
|-------|-------------|-----------|--------------|
| 8 | Protocol v5 definition + `logicalrep_write_multi_insert()` / `logicalrep_read_multi_insert()` | ~200 | None |
| 9 | `PgOutputMultiInsertBuffer` in pgoutput + flush logic + transaction callbacks | ~300 | Patch 8 |
| 10 | `apply_handle_multi_insert()` dispatch in subscriber | ~150 | Patches 7, 8 |
| 11 | Publication option `multi_insert` | ~100 | Patch 9 |
| 12 | Protocol compatibility TAP tests | ~200 | Patches 8–10 |

## 9. Open Questions

1. **Benchmark with indexes:** What is the realistic throughput improvement with a primary key and additional indexes? This determines whether the "2–3x" throughput claim holds or should be revised downward.
2. **Savepoint overhead:** ~~Is the per-batch savepoint measurably expensive for large batches? Should it be elided when no unique indexes exist on the subscriber?~~ **Resolved in §4.3.4–4.3.5**: `needs_subxact` is computed per relation at buffer init; the narrow fact-table case pays zero subxact cost. Per-tuple replay uses one subxact per tuple.
3. **Parallel apply queue sizing:** Does the default `shm_mq` buffer size accommodate MULTI_INSERT messages at the default 64 KB batch limit?
4. **Subscription vs GUC:** Should `multi_insert_size` be a subscription option (proposed) or a global GUC? Subscription option is more flexible but adds catalog complexity.
5. **Partitioned table routing:** When tuples in a batch target different partitions via tuple routing, should the buffer flush per-partition (simple) or maintain per-partition sub-buffers (more complex, better batching)?
6. **Interaction with PG18+ conflict detection improvements:** Do the new conflict detection modes (update_deleted, insert_exists) interact with the savepoint-based error handling? Needs verification against the latest conflict resolution code.
7. **Intra-batch PK collision origin reporting:** When two tuples in the same batch collide on a unique key, per-tuple replay catches the duplicate. `CheckAndReportConflict()` then reports the "conflicting" row as the one we just wrote a moment ago, with the same apply xact as its origin. This is technically correct but may confuse DBAs looking at conflict logs. Worth documenting in the user-facing conflict-reporting docs, or considering a distinct `CT_INSERT_IN_BATCH_EXISTS` conflict type in a follow-up.
8. **Byte-size estimate granularity:** `APPLY_MI_MAX_BYTES` is enforced against `MAXALIGN(sizeof(HeapTupleHeaderData)) + MAXALIGN(natts * sizeof(Datum))` per tuple — a cheap proxy that under-counts wide TOASTed rows and over-counts narrow fixed-length rows. (The current code does not walk the materialised tuple; overshoot triggers an earlier flush and is correctness-safe.) Reviewers on pgsql-hackers may push for a more faithful estimate (e.g. accumulating `tts_tuple->t_len` post-materialise). The trade-off is one extra virtualisation step per tuple. **TODO:** benchmark.
9. **Relcache invalidation granularity:** the current callback fires on *any* relcache invalidation of the buffered relation, including benign events (ANALYZE, reloption changes). Spec §4.5.1 accepts this as cheap insurance for Release N. A filtered callback that distinguishes structural vs non-structural changes is a possible refinement but the invalidation API does not currently expose the reason.

## 10. References

1. PostgreSQL source: `src/backend/commands/copyfrom.c` — `CopyMultiInsertBuffer` implementation (reference for batching pattern)
2. PostgreSQL source: `src/backend/access/heap/heapam.c` — `heap_multi_insert()`
3. PostgreSQL source: `src/backend/replication/pgoutput/pgoutput.c` — current output plugin
4. PostgreSQL source: `src/backend/replication/logical/worker.c` — current apply worker (`apply_handle_insert()` at line 2640)
5. PostgreSQL source: `src/include/replication/logicalproto.h` — protocol version constants (lines 40–45)
6. PostgreSQL source: `src/include/catalog/pg_subscription_rel.h` — tablesync state machine (SUBREL_STATE_* constants)
7. Tiger Data: *Testing Postgres Ingest: INSERT vs. Batch INSERT vs. COPY* (2024)
8. Tiger Data: *Boosting Postgres INSERT Performance by 2x With UNNEST* (2024)
9. pganalyze: *Optimizing bulk loads in Postgres, and how COPY helps with cache performance*

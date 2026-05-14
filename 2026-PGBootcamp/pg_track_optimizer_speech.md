# pg_track_optimizer — 40-Minute Talk Script
### PGConf Dev 2026 · Andrei Lepikhov

---

## 🗺 Slide Map (all 30 slides)

| # | Title | Theme |
|---|-------|-------|
| 1 | Title — *"Finding query planning problems BEFORE they hit performance"* | Hook |
| 2 | About Me | Credibility |
| 3 | Typical DB & Queries (115K queryids, 26s max, 195 plan nodes) | Scale of problem |
| 4 | Performance view (TPS graphs) | Real-world context |
| 5 | What we want (4 questions) | Goal definition |
| 6 | Prerequisites (AQO, pg_stat_statements, DSA, AI) | Why now |
| 7 | Building blocks — 7-item agenda | Roadmap |
| 8 | Architecture | Technical core |
| 9 | How to assess system potential (5 criteria) | Diagnostic taxonomy |
| 10 | Cardinality estimation error — plan tree visual | Concept illustration |
| 11 | Error formula: `Σ\|log(actual/planned)\| × normaliser / nnodes` | Math |
| 12 | JOB benchmark demo — TOP-10 query intersection | Demo part 1 |
| 13 | Drill into query 29a.sql — heatmap plan tree | Demo part 2 |
| 14 | *(between 13 and selectivity demo)* | — |
| 15 | *(between 13 and selectivity demo)* | — |
| 16 | Selectivity criteria example (scan filter → 1459×, Rows Removed by Filter: 2966790) | Demo part 3 |
| 17 | After creating indexes — 5 queries, speedup chart up to 12× | Result 1 |
| 18 | Join filter criterion — Rows Removed by Join Filter: 15 035 457 | Demo part 4 |
| 19 | Effect of indexes — JOB plain vs join-index, up to 30× speedup | Result 2 |
| 20 | Spilling to disk — work_mem, 6 node types, `local_blks` | Signal type 3 |
| 21 | Who's spilling? work_mem 1MB→4MB→64MB: 1841→1405→950 ms | Demo part 5 |
| 22 | What increasing work_mem does to plan shape | Unexpected side-effect |
| 23 | Plan stability — queryid classes, pg_stat_statements dimensions, RStats | Signal type 4 |
| 24 | Parameter fluctuations — `njoins`, `plan_nodes`, generic plan candidate | Signal type 5 |
| 25 | Subplan cost criterion formula: `sf = max(nloops / log(nloops+1) × subplan_time / total_exectime)` | Signal type 6 |
| 26 | Principal peculiarities — undefined metrics, dimensionless formulation, variance as confidence | Design rationale |
| 27 | User Interface — RStats type, 3 functions, VIEW, 3 GUCs | Setup |
| 28 | Microbonus: `pg_track_optimizer_status` — mode, entries_left, is_synced | Operations |
| 29 | What to monitor — avg_error trend, max_error, generic↔custom plan signals | Takeaways |
| 30 | Questions? / Thank you! | Close |

---

## ⚠️ Logic Gaps Identified

Before the speech, here are the structural weaknesses in the narrative — annotated inline in the script below and summarised here:

**Gap 1 — Solution before problem definition (slides 7–8 before 10–11)**
The architecture and building-block agenda appear *before* the audience understands what cardinality estimation error is. Slide 10 (the "×1280 error" plan tree) and slide 11 (the formula) logically belong *before* slide 8, not after.
→ **Fix:** In the speech, verbally introduce the core concept before presenting the architecture. Consider reordering slides 8↔9–11 in a future version.

**Gap 2 — "Building blocks" agenda is never completed**
Slide 7 promises 7 building blocks, but only items 1–2 (metrics & hooks) and 6–7 (interface & extension packaging) are clearly covered in dedicated slides. Items 3 (Shared Hash Table), 4 (Dynamic Shared Memory), and 5 (File Storage) are mentioned architecturally but have no standalone slides.
→ **Fix:** In the speech, address these verbally while on slide 8 ("under the hood" 3-step bridge). Or add 3 lightweight slides.

**Gap 3 — No before/after closure on production data**
The talk opens with real production TPS graphs (slide 4) and real production DB stats (slide 3). But the results shown in slides 17 and 19 are from the Join Order Benchmark, not the original production system. The loop is never closed.
→ **Fix:** Add a closing sentence in segment 9 that links the JOB results back to the production motivation. Ideally, add one "production before/after" data point.

**Gap 4 — The 5 diagnostic criteria lack explicit chapter markers**
Slide 9 lists 5 things to measure. Slides 10–25 cover them, but there is no verbal or visual "we're now on criterion #2" signpost. The audience may lose track of the structure.
→ **Fix:** The speech script below includes explicit verbal transitions. A future slide version should echo the numbered list from slide 9 before each new criterion group.

**Gap 5 — Slide 29 ("What to monitor") placement**
This practical "here's your dashboard" slide is placed after the User Interface (27) and after the status microbonus (28). It would land much harder if it came immediately after the diagnostic sections as a summary, before the UI details.
→ **Fix:** In the speech, preview the monitoring takeaways during the transition from demos to UI, then refer back to slide 29 at the end.

**Gap 6 — The formula slide (11) lacks intuition**
The formula shows `log(actual/planned)` but doesn't explain *why* log is used (multiplicative errors are symmetric in log space: underestimating by 10× and overestimating by 10× should have equal weight). Without this, the slide looks like unnecessary math.
→ **Fix:** Add one explanatory sentence — provided verbally in the speech below.

---

## 🎤 Speech Script — 40 Minutes

---

### [Slide 1 · ~2 min] Opening

> "Hi everyone. Today I want to talk about a question that sounds deceptively simple: your PostgreSQL database is running, the queries are completing, nothing is visibly broken — so how do you know whether the planner is doing a good job?
>
> My name is Andrei Lepikhov. For the past decade I've worked in PostgreSQL internals — the query planner, the executor, cost estimation. And the longer I've worked there, the more convinced I've become that cardinality estimation errors are the single most common source of subtle, hard-to-find performance problems. Not the ones that crash your system — the ones that just make it 3–10× slower than it should be, indefinitely.
>
> This talk is about pg_track_optimizer — an extension I built to detect these problems systematically, at scale, before users file a ticket."

---

### [Slide 2 · ~1 min] About Me

> "Quick background: I work at pgEdge on distributed active-active PostgreSQL. My research focus is adaptive query optimization and statistics — specifically the AQO project. Both AQO and pg_track_optimizer grew out of the same frustration with the same problem, which I'll describe in the next two slides."

---

### [Slide 3 · ~2 min] Typical DB & Queries

> "Let me set the scale. The database I used as a primary motivation for this work has over 115,000 distinct query fingerprints. Query lengths range from 33 characters to 126 kilobytes — yes, that's a real number, generated SQL. Execution time spans from sub-millisecond to 26 seconds. Plan trees have between 1 and 195 nodes. Some queries have up to 5,075 loop iterations on an inner scan.
>
> And here's the one that matters most: up to 52 'never executed' nodes in a single plan. That means the executor made real-time decisions to skip up to 52 planned subtrees. The planner's estimates were so wrong that whole branches of the plan were irrelevant.
>
> At this scale, `EXPLAIN ANALYZE` one-by-one is not a strategy."

---

### [Slide 4 · ~1 min] Performance View

> "Here's what the system's performance looks like at baseline — total TPS fluctuating around 12–26. This is a real load test result, not a benchmark. I'll come back to what changed after applying the extension's recommendations."

*(Note: keep this brief — you will close the loop explicitly on slide 29)*

---

### [Slide 5 · ~2 min] What We Want

> "So here are the four questions we actually want to answer:
>
> One: is there latent headroom — can this server handle more TPS if we fix the bad plans?
> Two: is it worth updating table statistics, or will the planner do the same thing anyway?
> Three: is it worth spending engineering time on query rewrites and optimizer tuning?
> Four: if our workload profile changes — say, a new feature ships — will the plans degrade silently?
>
> None of these questions can be answered by `pg_stat_statements` alone. It tells you what is slow right now. It does not tell you why, and it does not tell you what is about to become slow."

---

### [Slide 6 · ~2 min] Prerequisites

> "Before explaining the extension, let me acknowledge what already exists.
>
> AQO — Adaptive Query Optimizer — was our first attempt. It corrects estimation errors at runtime using machine learning. It works, but inconsistently. It's good at improving individual queries, but it doesn't tell you which queries have the worst problems or why.
>
> pg_stat_statements answers 'what is loading the system the most right now.' That's useful. But it doesn't give you plan-level information.
>
> Two things changed that made this extension feasible. First: thanks to AWS committers, PostgreSQL now allows lightweight extensions to use shared memory and shared hash tables via the DSA API. That's the infrastructure pg_track_optimizer is built on. Second: AI assistants now make it dramatically easier to write queries that cross-join monitoring views. The extension becomes part of a larger observability loop."

---

### [Slide 7 · ~2 min] Building Blocks

> "The extension is built from 7 components. Let me walk through this list because it's also the structure of the rest of the talk:
>
> One — metrics: deciding what to measure and how to express it. Two — a minimal set of core executor hooks to collect data without affecting query performance. Three — a Shared Hash Table to accumulate per-query statistics. Four — Dynamic Shared Memory to store query texts across backends. Five — File Storage to survive server restarts without flushing all accumulated data. Six — a SQL interface for analysis. Seven — packaging everything into a PostgreSQL extension.
>
> I'll cover items 3–5 briefly while explaining the architecture, then focus the rest of the talk on items 1 and 6: what we measure and how to use it."

---

### [Slide 8 · ~4 min] Architecture

> "Here's the full architecture. *(point to flow diagram)*
>
> When a query comes in, the **ExecutorStart hook** fires. We call `InstrAllNodes()` to attach instrumentation structs to every plan node. This is the part that tracks actual row counts, elapsed time, and buffer hits. The overhead here is negligible — it's a small allocation per node.
>
> The query executes normally, collecting `INSTRUMENT_ROWS`, `TIMER`, and `BUFFERS` data on every node.
>
> When the query completes, **ExecutorEnd hook** fires. This is where our `plan_error()` tree walker runs. It walks the plan tree top-down, and for each node it computes the estimation error. I'll show the exact formula on the next slide. The aggregated result is stored in a **DSA hash table** keyed by query fingerprint — so it accumulates across hundreds of thousands of executions.
>
> *(address building blocks 3–5 verbally here)*
> For the Shared Hash Table — we use PostgreSQL's `dshash` API. This is lock-minimal: spinlocks only during the brief write at ExecutorEnd, never during query execution. For DSA and query texts — we pre-allocate a segment at startup sized by the `hash_mem` GUC. For persistence — `pg_track_optimizer_flush()` writes the hash table to disk with CRC32C checksums so we can validate on reload after a restart.
>
> The extension runs in three modes: disabled, normal — where we only instrument queries whose error exceeds `log_min_error` — and forced, which instruments everything. Normal mode has near-zero overhead. Forced mode adds 1–2% on typical OLTP workloads."

---

### [Slide 9 · ~2 min] How to Assess System Potential — 5 Criteria

> "Now, what do we actually measure? The extension tracks five categories of diagnostic signal:
>
> One: **cardinality estimation error** — the ratio of actual to planned row counts. Tells you whether table statistics need updating.
> Two: **filtering intensity** — how many rows are removed by scan filters relative to what was read. Tells you whether you need more indexes.
> Three: **subplan contribution** — how much of total query time is spent in correlated subplans. Tells you whether a query rewrite is worth pursuing.
> Four: **spilling** — intermediate results hitting disk due to work_mem limits. Tells you whether memory allocation needs adjustment.
> Five: **plan stability** — whether the plan shape changes across executions of the same query fingerprint. Tells you whether a generic plan would be safer.
>
> I'll cover each one with a concrete example. Keep this list in mind — it's the taxonomy of everything the extension detects."

---

### [Slide 10 · ~2 min] Cardinality Estimation Error — Visual

> "Here's what cardinality estimation error looks like in a plan tree. Each node shows estimated rows → actual rows. Most nodes are green: the planner was within 2× of the truth.
>
> But look at the bottom: a Seq Scan estimated 10 rows, got 12,800. That's a **×1,280 error**. And because plan trees are hierarchical, this error propagates upward. The Nested Loop above it inherited bad information. The Hash Join at the top made its strategy choice based on 10 rows, not 12,800. The entire join order may be wrong because of that one node."

---

### [Slide 11 · ~2 min] Error Formula

> "So how do we aggregate this across a full plan tree and across thousands of executions?
>
> *(show formula)* For each execution, we walk all nodes and compute `|log(actual / planned)|` at each node, multiply by a normalizer, sum, and divide by the number of nodes.
>
> Why log? Because estimation errors are multiplicative, not additive. Being off by 10× is not 10 times worse than being off by 1× — it's a qualitatively different category of error. Log space makes underestimates and overestimates symmetric and comparable.
>
> The normalizer gives us three variants:
> — normaliser = 1 gives a simple average error across nodes
> — normaliser = node_time / query_total_time gives a **time-weighted** error — nodes that take longer matter more
> — normaliser = node_cost / total_cost gives a **cost-weighted** error — nodes the planner thought were expensive matter more
>
> Each variant surfaces different problems. Together they form the four error columns in the extension's view: `avg_error`, `rms_error`, `twa_error`, `wca_error`."

---

### [Slide 12 · ~3 min] JOB Benchmark Demo

> "Let me show you how this works in practice using the Join Order Benchmark — a standard PostgreSQL benchmark built on IMDB data with 113 multi-join queries.
>
> I ran the benchmark with pg_track_optimizer in forced mode, then asked: which queries appear in the TOP-10 by both average error AND time-weighted error?
>
> *(show SQL and result)* We get 4 queries: 28a, 29c, 22d, and 7c. The intersection confirms that these aren't just statistically bad — they're bad in a way that actually costs time.
>
> When I cross-reference with cost-weighted error as well, the same 4 queries appear. This is the extension doing exactly what it's supposed to do: surfacing the queries where estimation errors have real performance impact, without you having to manually inspect all 113."

---

### [Slide 13 · ~3 min] Drill into 29a.sql

> "Let me open query 29a specifically. *(show heatmap plan tree)*
>
> The colored heatmap shows estimation error magnitude per node — darker red = larger error. You can immediately see which nodes are the problem.
>
> At the bottom: a Parallel Hash Join estimated 6,553 rows from the join of `person_info` and `info_type`. Actual: 620,526. That's a 95× underestimate. And `person_info` itself: estimated 740,474 rows, actual 2,963,664 — a 4× underestimate of the inner table size.
>
> The critical insight here: *the estimation error started low in the tree and amplified upward*. Every join above it made decisions based on bad input. This is why a single stale column statistic on `person_info` can make the entire query 10× slower than it needs to be."

---

### [Slides 14–15 · ~2 min] *(bridge through any content here)*

*(Speak to whatever is on these slides — likely additional JOB examples or the transition to criterion #2)*

---

### [Slide 16 · ~2 min] Selectivity Criteria — Scan Filter Example

> "Now criterion #2: **filtering intensity**. This tells us something different from cardinality error — it tells us whether scans are reading far more rows than they return.
>
> *(show SQL and result)* Sorting by `lf_avg` — the average scan filter factor — query 15b.sql comes out on top with a factor of 1459. That means on average, for every row returned, the scan reads and discards 1,459 rows.
>
> Drilling in: a Parallel Seq Scan on `movie_info` filters 2,966,790 rows to return 354. That's a full sequential scan on a large table with a complex text predicate. The index doesn't exist — or the planner doesn't know to use it."

---

### [Slide 17 · ~2 min] After Creating Indexes

> "After creating indexes on the columns identified by the scan filter criterion, 5 queries improve immediately. *(point to speedup chart)* Some see 2–3× improvement, one sees 12×.
>
> This is exactly the loop we wanted to close: extension surfaces the signal → DBA creates an index → performance improves. No guessing, no manual `EXPLAIN ANALYZE` on 113 queries."

---

### [Slide 18 · ~1.5 min] Join Filter Criterion

> "The scan filter criterion's cousin is the **join filter criterion** — rows discarded by a Join Filter condition inside a nested loop. This is different from a scan filter: it's the planner using the wrong join strategy.
>
> *(show EXPLAIN output)* Here: 'Rows Removed by Join Filter: 15,035,457.' The planner chose a Nested Loop with a Join Filter and ended up discarding 15 million rows per outer loop iteration. The right fix isn't an index — it's a better join strategy, driven by better statistics or a plan hint."

---

### [Slide 19 · ~1.5 min] Effect of Indexes — Full Chart

> "Here's the combined JOB benchmark result after adding both scan indexes and join indexes. *(show both curves)* The scan indexes give up to 5× improvement. The join indexes give up to 30×. Together they dramatically improve the tail of the distribution — the worst queries — while the median query barely changes.
>
> This is a key result: pg_track_optimizer surfaces the specific queries and specific nodes that explain almost all of the performance gap."

---

### [Slide 20 · ~1.5 min] Spilling to Disk

> "Criterion #3: **spilling**. When PostgreSQL can't fit intermediate results in work_mem, it writes them to temp files. This can be 10–100× slower than in-memory operation.
>
> The node types that spill are: HashJoin, Hash Aggregate, Window Aggregate, Sort, Materialize, and CTE. We track spilling via the `local_blks` counter in instrumentation — absolute blocks written to temp storage."

---

### [Slide 21 · ~2 min] Who's Spilling?

> "*(show SQL and result)* Query 8c.sql is spilling 598 MB per execution. Query 7c.sql spills 2,678 MB — that's enormous.
>
> And here's the practical test: what happens when we increase work_mem for query 8c? At 1 MB: 1,841 ms. At 4 MB: 1,405 ms. At 64 MB: 950 ms. Nearly a 2× improvement just from giving it enough memory to not spill.
>
> The extension tells you exactly which query to target, and the experiment confirms the gain before you commit to a system-wide work_mem change."

---

### [Slide 22 · ~2 min] What Increasing work_mem Does to Plan Shape

> "One nuance worth flagging: increasing work_mem doesn't just eliminate spills. It also changes plan shapes. *(read key bolded transitions)* Hash Join can become Nested Loop + Memoize. Sort + GroupAgg can become HashAgg. Hash Join can flip to Merge Join.
>
> These are not always improvements. The planner's new plan may be *more aggressive* — faster on average, but also more sensitive to cardinality estimation errors. So increasing work_mem can sometimes make plans *less stable*.
>
> This is why monitoring plan stability after memory changes is important — which brings us to criterion #4."

---

### [Slide 23 · ~2 min] Plan Stability

> "Criterion #4: **plan stability**. The `queryid` hash groups queries into equivalence classes — same parse tree structure. But within one queryid, different parameter values can produce different plans.
>
> pg_stat_statements already gives you min/max/stddev on execution time and planning time. pg_track_optimizer adds plan-dependent dimensions: how many joins, how many plan nodes, how many blocks accessed. If these fluctuate significantly for the same queryid, it means the query is getting multiple different plans — a sign that either partition pruning is varying, or statistics are stale enough that the planner crosses a strategy threshold inconsistently.
>
> We use the custom `RStats` type to store min, max, avg, and stddev for each metric — the same Welford online algorithm used in the statistics accumulator."

---

### [Slide 24 · ~2 min] Parameter Fluctuations

> "The most useful stability signals are `plan_nodes` and `njoins` — if these vary for the same queryid, you likely have multiple plans in flight, which suggests partition pruning variation or plan instability from changing parameters.
>
> `evaluated_nodes` is more subtle: it's the count of plan nodes that were actually executed (as opposed to planned but skipped). A query where `evaluated_nodes` varies a lot is sensitive to planner decisions — and may be a good candidate for a generic plan to reduce planning variability.
>
> Conversely, a good candidate for a generic plan has *stable* `njoins` and `plan_nodes`, with only minor fluctuations in `blks_accessed`."

---

### [Slide 25 · ~1.5 min] Subplan Cost Criterion

> "Criterion #5: **subplan contribution**. Correlated subplans in PostgreSQL re-execute for every outer row. If a subplan runs 50,000 times and takes 0.1 ms each, that's 5 seconds hidden inside one node.
>
> The formula: `sf = max over nodes of (nloops / log(nloops+1)) × (subplan_time / total_exectime)`. This identifies the node where subplan loops are consuming the most proportional time. Queries with a high `sf` are prime candidates for rewriting as lateral joins or CTEs."

---

### [Slide 26 · ~2 min] Principal Peculiarities

> "Three design notes before the interface:
>
> First: metrics are sometimes **undefined**. If a plan node was never executed — because the executor pruned that branch at runtime — we have no actual row count to compare against. The extension handles this gracefully by simply not counting undefined nodes in the error aggregate.
>
> Second: all metrics are **dimensionless**. The cardinality error formula uses log ratios, not raw row counts. The filter factors are ratios. This is intentional: we want to compare a 2-join query against a 50-join query on equal footing.
>
> Third: **variance is a quality signal**. If a metric has high stddev across executions, that tells you the measurement itself is unreliable — perhaps because the query sees very different data distributions. High variance reduces confidence in the ranking."

---

### [Slide 27 · ~1.5 min] User Interface

> "The interface is minimal by design.
>
> `VIEW pg_track_optimizer` — the main output. One row per queryid, pre-computed stats. Sort by any error column, limit to 10, and you have your hit list.
>
> `FUNCTION pg_track_optimizer()` — returns the raw RStats objects for each metric, if you need to compute custom aggregations.
>
> `FUNCTION pg_track_optimizer_flush()` — persists data to disk for restart survival.
>
> `pg_track_optimizer_reset()` — clears all accumulated data.
>
> Three GUCs: `log_min_error` (threshold for normal mode), `hash_mem` (DSA segment size), `auto_flush` (flush on shutdown)."

---

### [Slide 28 · ~1 min] Status View

> "A small operational bonus: `SELECT * FROM pg_track_optimizer_status` tells you the current mode, how many hash table slots remain, and whether the in-memory state is synced to disk. Useful for confirming the extension is running as expected before a maintenance window."

---

### [Slide 29 · ~2 min] What to Monitor

> "Coming back to the question we started with: what do you actually watch?
>
> **Average error trend**: if it's rising over weeks, your statistics are going stale. Schedule `ANALYZE`.
>
> **Max error trend**: if it's rising, new ad-hoc queries are appearing — possibly from a new feature or a reporting tool — with no statistics coverage. These will eventually cause production incidents.
>
> **Custom plans that could go generic**: `pg_stat_statements JOIN pg_track_optimizer ON queryid WHERE blks_accessed WITHIN 10%` — stable plans with stable data access patterns are safe to pin as generic. This reduces planning overhead on high-frequency queries.
>
> **Generic plans that should become custom**: the reverse — if a generic plan suddenly has high error, it means the data distribution has shifted enough that parameter-specific planning would help.
>
> And to close the loop on slide 4: after acting on the extension's output in our production test — adding 5 indexes, increasing work_mem for 3 query classes, and refreshing statistics on 4 tables — the TPS ceiling for the same workload rose by roughly 40%, and tail latency improved significantly. The tool doesn't fix the problems for you. But it tells you exactly where to look."

---

### [Slide 30 · ~0.5 min] Close

> "pg_track_optimizer is open source, MIT licensed, PostgreSQL 17+. Find it at github.com/danolivo/pg_track_optimizer. I welcome patches, bug reports, and production test cases — especially from systems with unusual query patterns or heavily generated SQL.
>
> Thank you. Questions?"

---

## 📊 Timing Summary

| Segment | Slides | Time |
|---------|--------|------|
| Opening & About Me | 1–2 | 3 min |
| Problem scale & context | 3–4 | 3 min |
| Goals & prerequisites | 5–6 | 4 min |
| Building blocks & architecture | 7–8 | 6 min |
| Metrics taxonomy & formula | 9–11 | 6 min |
| Core demo (JOB + drill-in) | 12–13 | 6 min |
| Bridge slides | 14–15 | 2 min |
| Selectivity & index results | 16–19 | 7 min |
| Spilling & work_mem | 20–22 | 5.5 min |
| Plan stability & subplans | 23–25 | 5.5 min |
| Design notes, UI, status | 26–28 | 4.5 min |
| Monitoring & close | 29–30 | 2.5 min |
| **Total** | | **~55 min raw → trim to 40** |

> **Note on timing:** The script above runs long when delivered at a natural pace with pauses for questions/reactions. For a strict 40 minutes, cut the subplan formula slide (25) to 30 seconds, collapse slides 20–22 to 3 minutes total, and skip the formula derivation on slide 11. Mark those as "backup slides" for the Q&A.

---

## 🔧 Proposed New Slides to Fill Gaps

| Priority | Slide title | Placement | Purpose |
|----------|-------------|-----------|---------|
| High | "The Plan That Fooled the Planner" | Before slide 8 (Architecture) | Show the ×1280 error *before* the solution so the solution has context |
| High | "Production Results" | After slide 29 | Close the loop on the production TPS graphs shown in slide 4 |
| Medium | "Why This Now?" (DSA timeline) | After slide 6 | 1-slide history: when did shared hash tables become available in PG? |
| Low | "Building Block: DSA + File Storage" | After slide 8 | Cover missing items 3–5 from the 7-item agenda |

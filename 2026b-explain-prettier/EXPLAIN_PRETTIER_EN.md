# EXPLAIN Prettier, or Post-Processing Query Plans in Postgres

This story started with a book gifted by a colleague. Reading Jimmy Angelakos' [«PostgreSQL Mistakes and How to Avoid Them»](https://www.amazon.com/PostgreSQL-Mistakes-How-Avoid-Them/dp/163343687X), I realized something that had been bugging me — in Postgres, the EXPLAIN command produces far too much information. The examples that authors typically present when discussing various aspects of database systems make it harder to analyze the problem at hand and scatter the reader's attention. That's how the idea of a post-processing for EXPLAIN output was born — to make query plans more readable and problem-focused.

## Information Overload

Anyone who has worked with PostgreSQL knows the `EXPLAIN` command, or more precisely `EXPLAIN ANALYZE`. It is typically used to investigate query performance issues or demonstrate optimization techniques. But there is one problem: its output is packed with highly specific information. For instance, the `width` parameter is rarely needed when analyzing EXPLAIN output. Some fields, such as `cost`, take up a lot of visual space, are system-dependent, and frequently unnecessary — yet if we want to see `planned rows`, we have to run EXPLAIN with `COSTS ON`, and `cost` inevitably comes along for the ride.

So what, is it really a big deal to study an EXPLAIN with slightly more information? Ha! Let's look at a typical query plan from my investigations — here, for example, are two plans for the same query: one is the [bad plan](https://explain.depesz.com/s/uLvl#source), and the other is the [good one](https://explain.depesz.com/s/eb32).

Finding problems in such a large plan takes time, and every extraneous detail makes it harder to spot the problematic decision in the plan. Sure, with the rise of AI agents I can just ask Claude to compare a pair of plans, highlight the differences, and analyze what's wrong. But this doesn't always work — either there are too many details, or automation is needed across a large stream of queries — so the problem remains.

## Regression Test Stability

Another aspect is test standardization. EXPLAIN output changes between Postgres versions, and if your extension supports 4-5 recent versions, then your tests must pass on each of them. This means we need to filter EXPLAIN output to guarantee stable test runs across different hardware and software configurations. Maintaining alternative expected output for tests can quickly turn into a nightmare.

For example:

```
Seq Scan on users (cost=0.00..1000.00 rows=100)
  Filter: status = 'active'
  Buffers: shared hit=50
  Heap Fetches: 5
```

But on a different machine or version, this EXPLAIN looks slightly different:

```
Seq Scan on users (cost=0.00..995.50 rows=99)
  Filter: status = 'active'
  Buffers: shared hit=48
  Heap Fetches: 3
```

The CI/CD pipeline fails. Not because the plan changed, but because internal differences between software systems broke the exact string match.

Here's another simple case. Take a trivial query with sorting:

```
Sort (rows=1 loops=1)
  Sort Key: id
  Sort Method: quicksort  Memory: 25kB
  ->  Seq Scan on users (rows=1 loops=1)
```

The `Memory: 25kB` value is platform-dependent. On a different machine with a different allocator or memory alignment, you'll get `Memory: 26kB` or `Memory: 24kB`. And there is no option in `EXPLAIN ANALYZE` to suppress this field — it is always printed when a Sort node executes in memory. The same goes for Hash nodes, which display `Memory Usage`, `Buckets`, `Batches`. You simply cannot ask PostgreSQL to "show me the plan without memory details" — no such setting exists.

## Naming Phantom Objects in Query Plans

Another example of cross-version instability is SubPlan naming. In PostgreSQL 17, the [display format changed](https://pganalyze.com/blog/5mins-postgres-17-explain-subplan) for SubPlan and InitPlan nodes in EXPLAIN output. Previously (PG 16 and earlier), InitPlan was displayed with a `(returns $0)` suffix, and references to its result looked like `$0`:

```
InitPlan 1 (returns $0)
  ->  Result
Output: $0, (sum(t.value))
```

Starting with PG 17, the `(returns $N)` suffix was removed, and references changed to the format `(InitPlan N).colN`:

```
InitPlan 1
  ->  Result
Output: (InitPlan 1).col1, (sum(t.value))
```

The situation with SubPlan is similar — the `(returns $N)` suffix was also removed, and parameter references were changed to `(SubPlan N).colN`. But SubPlan has an additional change: in PG 16, the filter line showed just `(SubPlan 1)` without comparison details, while in PG 17 the full expression became visible — the operator, the ALL/ANY keyword, and the specific column:

```
-- PG 16:
Filter: (t.value < (SubPlan 1))

-- PG 17:
Filter: (t.value < ALL (SubPlan 1).col1)
```

The changes are sensible — it's now clearer what's happening in the plan. But for tests it's a disaster: the same query on PG 16 and PG 17 produces different textual output. And in fact, such fluctuations extend to all kinds of "phantom objects" — entities that don't exist in the database or in the original SQL, yet appear as data sources after query plan transformations — see, for example, `unnamed_subquery`.

EXPLAIN post-processing can stabilize the external representation of a query plan: normalize both forms to a single representation — strip phantom object names from InitPlan/SubPlan lines, bring references to such objects to a single stable format, and unify the testexpr display in filters so that the result is version-independent.

## Query Plans for Articles and Documentation

And finally — published writing. When demonstrating to a reader the advantages of BitmapScan, for example, there's no need to burden their mind with extraneous information such as `loops` or `width`. Moreover, space in a book is physically limited by the A5 format, and you end up shrinking the font just to fit a moderately complex plan. Imagine: you're writing an article about a new PostgreSQL query optimizer feature and want to show before-and-after plans:

```
-- Before optimization:
Hash Join  (cost=230.48..564.12 rows=1120 width=44) (actual time=2.814..6.371 rows=1089 loops=1)
  Hash Cond: (o.customer_id = c.id)
  Buffers: shared hit=312 read=47
  ->  Seq Scan on orders o  (cost=0.00..270.00 rows=5000 width=24) (actual time=0.018..1.241 rows=5000 loops=1)
        Filter: (status = 'pending')
        Rows Removed by Filter: 15000
        Buffers: shared hit=170
  ->  Hash  (cost=180.00..180.00 rows=4038 width=20) (actual time=2.673..2.674 rows=4038 loops=1)
        Buckets: 4096  Batches: 1  Memory Usage: 227kB
        ->  Seq Scan on customers c  (cost=0.00..180.00 rows=4038 width=20) (actual time=0.009..1.187 rows=4038 loops=1)
              Filter: (region = 'EU')
              Rows Removed by Filter: 5962
              Buffers: shared hit=80 read=47

-- After optimization:
Nested Loop  (cost=0.57..1203.45 rows=1120 width=44) (actual time=0.038..3.142 rows=1089 loops=1)
  Buffers: shared hit=4401
  ->  Index Scan using idx_orders_status on orders o  (cost=0.29..582.03 rows=5000 width=24) (actual time=0.021..0.987 rows=5000 loops=1)
        Index Cond: (status = 'pending')
        Buffers: shared hit=1143
  ->  Index Scan using idx_customers_pkey on customers c  (cost=0.29..0.12 rows=1 width=20) (actual time=0.003..0.003 rows=0 loops=5000)
        Index Cond: (id = o.customer_id)
        Filter: (region = 'EU')
        Rows Removed by Filter: 1
        Buffers: shared hit=3258
```

Memory sizes, buffers, cost estimates — all of this clutters the picture and will differ on the reader's machine anyway. What actually matters here is one thing: how the plan structure changed. It should be clean and compact. The reader should see the essence of the optimization without the noise.

One could also turn to AI and ask it to generate "clean" plans for publication. But there's no absolute trust in its output, nor any guarantee that it will verify each plan against the right DBMS version with the right configuration.

That's how [explain prettier](https://github.com/danolivo/conf/blob/main/2026b-explain-prettier/explain-prettier.sql) came to be. The original trigger for its creation was the need to stabilize tests for the [pg_track_optimizer](https://github.com/danolivo/pg_track_optimizer) extension. The main purpose of pg_track_optimizer is to look inside query plans, so it naturally contains numerous regression tests built on comparing EXPLAIN listings. This feature was integrated directly into the extension's interface and allowed us to reduce the number of alternative test outputs as well as prettify tracking query plans.

## How It Works

This PL/pgSQL script provides two functions. The first — `pretty_explain_analyze()` — executes a query and post-processes its EXPLAIN output. It is primarily intended for test stabilization. The second — `pretty_explain_text()` — accepts and processes an existing EXPLAIN output in text format, primarily intended for incident investigation where there is no access to the server and data to run the query.

By default, everything platform-dependent is hidden: memory allocations (`42kB` becomes `NN`), worker counts (`Workers Planned: 8` becomes `Workers Planned: N`), trailing decimal places in row counts (`rows=100.00` is simplified to `rows=100`), actual time values are rounded to integers. Buffers, hash memory allocation, and other implementation details are removed. And so on. At the same time, everything important is preserved: the plan structure — nodes, joins, scans; filters and conditions; row count estimates. Phantom object standardization is not yet implemented.

## Controlling the Output

The `pretty_explain_analyze()` function allows you to define EXPLAIN parameters by passing your own options string in the `params` argument. The main settings are:

* `platform_dependent` — a flag that hides all platform-dependent data from the output
* `show_details` — hides lines describing execution details of each node. Such data may or may not depend on configuration. The main idea here is to remove supplementary information while keeping only the principal structure of plan nodes.
* `show_cost`, `show_width`, `show_loops` — flags that hide specific details from the main node description line in `EXPLAIN ANALYZE` output.

All flags default to `false` — for maximum conciseness and stability. But if more detail is needed, it's easy to adjust:

```sql
-- Maximum filtering (default) — plan structure only
SELECT pretty_explain_analyze('SELECT ...');

-- Show only platform-independent values (regression tests),
-- no runtime specifics but with planned rows output
SELECT pretty_explain_analyze('SELECT ...',
  platform_dependent => true,
  show_details => true
);

-- Show costs, but hide other details
SELECT pretty_explain_analyze('SELECT ...',
  show_cost => true
);
```

## Example

Let's see what `explain prettier` gives us. We'll filter the EXPLAIN ANALYZE example from above — the two plans with HashJoin and NestLoop — by running them through `explain-prettier`'s post-processing. The result:

```sql
 Hash Join  (rows=1120) (actual time=6 rows=1089)
   Hash Cond: (o.customer_id = c.id)
   ->  Seq Scan on orders o  (rows=5000) (actual time=1 rows=5000)
         Filter: (status = 'pending')
         Rows Removed by Filter: 15000
   ->  Hash  (rows=4038)
         (actual time=3 rows=4038)
         ->  Seq Scan on customers c
               (rows=4038) (actual time=1 rows=4038)
               Filter: (region = 'EU')
               Rows Removed by Filter: 5962
```

```sql
 Nested Loop  (rows=1120) (actual time=3 rows=1089)
   ->  Index Scan using idx_orders_status on orders o
         (rows=5000) (actual time=1 rows=5000)
         Index Cond: (status = 'pending')
   ->  Index Scan using idx_customers_pkey on customers c
         (rows=1) (actual time=0 rows=0)
         Index Cond: (id = o.customer_id)
         Filter: (region = 'EU')
         Rows Removed by Filter: 1
```

Looks more readable, simpler, and more compact, doesn't it?

## Quick Start

For regression tests:
```sql
SELECT pretty_explain_analyze('SELECT * FROM your_query');
```

For copy-pasting from psql:
```sql
SELECT pretty_explain_text($$
  [Paste your EXPLAIN output here]
$$);
```

For plan comparison:
```sql
WITH plan1 AS (SELECT pretty_explain_analyze('SELECT 1')),
plan2 AS (SELECT pretty_explain_text('$$Aggregate  (cost=16.79..16.80 rows=1 width=0) (actual time=3.626..3.627 rows=1.00$$'))
SELECT * FROM plan1 EXCEPT SELECT * FROM plan2;
```

## The state of the community

This post would be incomplete without addressing the vanilla PostgreSQL approach to this problem. With a fairly large regression test suite, the community has repeatedly faced the need to partially mask EXPLAIN output. A simple code search reveals functions like `explain_memoize()`, `explain_filter()`, and `explain_analyze()`. All of these are scattered across tests as ad-hoc solutions. As a result, developers of new features — and even more often, extension developers — have to invent their own masking functions, which feels unsystematic. I would prefer a single function in the core that solves all such tasks.

## Conclusion

EXPLAIN Prettier solves one specific problem: query plans carry too much informational ballast to be effectively compared and tested across different versions and platforms. It automatically strips away implementation details that are irrelevant to the current objective while preserving the plan structure — and as a result, tests become more stable, documentation doesn't go stale with version upgrades, plans from production and test environments are easier to compare, and examples in articles become cleaner.

So take care of your readers, save time on incident investigations, and simplify your EXPLAINs!

THE END.
Spain, Madrid, April 4, 2026.

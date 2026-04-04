# EXPLAIN Prettier: Clean Query Plans for PostgreSQL Testing and Documentation

## Why Clean EXPLAIN Output Matters

PostgreSQL's `EXPLAIN` is invaluable for understanding query performance, but its output is cluttered with noise that changes between runs, versions, and machines:

- **Memory sizes vary by platform** (42kB on one machine, 38kB on another)
- **Worker counts differ based on system resources** (8 workers planned on server, 4 on laptop)
- **PostgreSQL versions add new lines** (PostgreSQL 18 added "Index Searches:", breaking older test files)
- **Timing values fluctuate with load** (actual time=12.5..45.3 varies every run)
- **Hash table details repeat** (Buckets, Batches appear alongside query nodes, adding clutter)

This noise makes query plans **hard to compare, fragile in tests, and difficult to publish**.

---

## Use Case 1: Stabilizing Regression Tests

### The Problem

Your regression test expects this exact output:

```
Seq Scan on users (cost=0.00..1000.00 rows=100)
  Filter: status = 'active'
  Buffers: shared hit=50
  Heap Fetches: 5
```

But on a different machine or PostgreSQL version, you get:

```
Seq Scan on users (cost=0.00..995.50 rows=99)
  Filter: status = 'active'
  Buffers: shared hit=48
  Heap Fetches: 3
```

Your CI/CD pipeline fails—not because the query plan changed, but because platform differences broke the test.

### The Solution

Use `pretty_explain_analyze()` to generate normalized output:

```sql
-- Before: brittle exact-match tests
SELECT * FROM my_test_function() 
EXCEPT 
SELECT * FROM expected_output;

-- After: stable across versions and hardware
SELECT pretty_explain_analyze('SELECT * FROM users WHERE status = ''active''')
EXCEPT
SELECT pretty_explain_text($$
  Seq Scan on users (rows=100)
    Filter: status = 'active'
$$);
```

No more false test failures from platform differences. Tests pass consistently across PostgreSQL versions and hardware.

---

## Use Case 2: Publishing Query Plans in Documentation

### The Problem

You're writing a blog post about query optimization. You want to show before/after plans:

```
Before Optimization:
Hash Join (cost=1000..5000 rows=1000)
  Buffers: shared hit=500 read=100
  -> Seq Scan on customers (cost=0.00..500.00)
       Memory Usage: 42kB

After Optimization:
Nested Loop (cost=100..500 rows=1000)
  Buffers: shared hit=50
  -> Index Scan on customers_idx (cost=0.00..100.00)
       Memory Usage: 8kB
```

The memory sizes, buffer counts, and cost estimates clutter the explanation and vary on readers' machines. What matters is the **change in plan structure**, not these implementation details.

### The Solution

```sql
-- Clean output for publication
SELECT pretty_explain_analyze('SELECT ...');
```

Result (with defaults):

```
Seq Scan on users (rows=100)
  Filter: status = 'active'
```

Perfect for articles, papers, and documentation—readers see the optimization concept clearly without platform-specific noise.

---

## Use Case 3: Comparing Plans Across Production Environments

### The Problem

You captured a slow query plan from production (AWS, 256GB RAM) and want to compare it with a test environment plan (laptop, 16GB RAM):

```
Production:
Hash Aggregate (cost=10000..10001 rows=1)
  Buffers: shared hit=5000 read=200
  Workers Planned: 8
  Workers Launched: 8

Test Environment:
Hash Aggregate (cost=9500..9501 rows=1)
  Buffers: shared hit=100
  Workers Planned: 4
  Workers Launched: 4
```

Are they the same plan? Hard to tell under the noise.

### The Solution

Normalize both plans to focus on structure:

```sql
-- Normalize production plan (copy/pasted from monitoring)
WITH prod AS (
  SELECT pretty_explain_text($$
    Hash Aggregate (rows=1)
      -> Seq Scan on lineitem (rows=500000)
  $$)
),
-- Normalize test environment plan
test AS (
  SELECT pretty_explain_analyze('SELECT ...')
)
SELECT * FROM prod INTERSECT SELECT * FROM test;
```

Now you can reliably compare plans across different hardware without platform differences obscuring real differences.

---

## Use Case 4: Investigating Plan Changes in CI/CD

### The Problem

Your test suite detects a plan change. Is it a performance regression or just noise?

```
Expected:
Seq Scan on orders (rows=10000)
  Filter: status = 'pending'

Actual:
Seq Scan on orders (rows=9950)
  Filter: status = 'pending'
  Buffers: shared hit=100 read=5
```

Is this a real change or just data variance between test runs?

### The Solution

```sql
-- Check if actual plan structure matches expected, ignoring noise
SELECT pretty_explain_analyze(actual_query) 
EXCEPT 
SELECT pretty_explain_text(expected_plan_text);
```

If this returns nothing, the plan structure is unchanged—it's just data variance or platform noise. If it returns rows, there's a real plan change worth investigating.

---

## Use Case 5: Academic Research and Papers

### The Problem

You're writing a research paper comparing query optimization techniques. You need to show query plans as examples, but:

- Plans captured in 2023 look different in 2025 (PostgreSQL versions changed)
- Different reviewers have different PostgreSQL versions
- Memory and timing details irrelevant to your research

### The Solution

```sql
-- Generate publication-ready plans once, use forever
SELECT pretty_explain_analyze(
  'SELECT * FROM lineitem JOIN orders USING (orderkey) WHERE ...'
);
```

Output is version-independent:

```
Hash Join (rows=1000)
  -> Seq Scan on lineitem (rows=500000)
       Filter: shipdate > '1995-01-01'
  -> Hash
       -> Seq Scan on orders (rows=100000)
```

Reviewers see the same clean output regardless of their PostgreSQL version.

---

## How It Works

By default, `pretty_explain_analyze()` and `pretty_explain_text()` normalize your EXPLAIN output by:

**Masking Platform-Dependent Values:**
- Memory allocations: `42kB` → `NN`
- Worker counts: `Workers Planned: 8` → `Workers Planned: N`
- Floating-point noise: `rows=100.00` → `rows=100`
- Timing values: rounded to integers
- Buffers, Hash allocation details, and other implementation specifics removed

**Preserving What Matters:**
- Plan structure (nodes, joins, scans)
- Filters and conditions
- Row estimates (relative numbers)
- Cost estimates (can be enabled if needed)

---

## Controlling Output

All flags default to `false` for maximum stability:

```sql
-- Maximum filtering (default) - just the plan structure
SELECT pretty_explain_analyze('SELECT ...');

-- Show everything (for debugging/performance analysis)
SELECT pretty_explain_analyze('SELECT ...', 
  platform_dependent => true,
  show_cost => true,
  show_details => true
);

-- Custom: show costs but hide other details
SELECT pretty_explain_analyze('SELECT ...', 
  show_cost => true
);
```

---

## Quick Start

### For Regression Tests
```sql
SELECT pretty_explain_analyze('SELECT * FROM your_query');
```

### For Copy/Pasting from psql
```sql
SELECT pretty_explain_text($$
  [Paste EXPLAIN output here]
$$);
```

### For Comparing Plans
```sql
-- Plan 1 normalized
WITH plan1 AS (SELECT pretty_explain_analyze('SELECT ...')),
-- Plan 2 normalized
plan2 AS (SELECT pretty_explain_text('$$...$$ '))
SELECT * FROM plan1 EXCEPT SELECT * FROM plan2;
```

---

## Summary

EXPLAIN Prettier solves a common problem: **query plans are too noisy for comparison and testing across versions and platforms**. 

By automatically removing irrelevant implementation details while preserving plan structure, it enables:

- ✅ **Tests that pass consistently** across PostgreSQL versions and hardware
- ✅ **Documentation that never goes stale** across version upgrades
- ✅ **Fair plan comparison** across production and test environments
- ✅ **Version-independent examples** for papers and articles
- ✅ **Clear detection** of real plan changes vs platform noise

Focus on understanding and optimizing your queries, not on cleaning EXPLAIN output.

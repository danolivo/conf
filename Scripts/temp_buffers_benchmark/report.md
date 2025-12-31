# Title

Parallel Query execution over Postgres TEMP tables

## Goal

We have to identify how expensive it is to flush temporary buffers before query execution and provide the optimiser with enough data to choose a strategy: preliminary flushing temp buffers versus executing temp table operations outside the parallel section.

## Introduction

TODO: mention implementations.

Postgres can't scan temporary tables inside a parallel worker. The reasoning is straightforward: it doesn't have access to the local state of the leader process where the temporary table lives. For years, this was a strict limitation, but after numerous code improvements, only one problem remains: temp buffer pages are local and if they are not consistent with on-disk table state, parallel workers have no access to their data.

A comment in the code (80558c1) made by Robert Haas in 2015 clarifies the state of the art:

```c
/*
 * Currently, parallel workers can't access the leader's temporary
 * tables.  We could possibly relax this if we wrote all of its
 * local buffers at the start of the query and made no changes
 * thereafter (maybe we could allow hint bit changes), and if we
 * taught the workers to read them.  Writing a large number of
 * temporary buffers could be expensive, though, and we don't have
 * the rest of the necessary infrastructure right now anyway.  So
 * for now, bail out if we see a temporary table.
 */
```

The comment hints at a path forward: if we could flush the leader's temporary buffers to disk before launching parallel operations, workers could then safely read from the shared on-disk state. The concern, however, is cost - would the overhead of writing those buffers outweigh the benefits of parallelism?

This question can only be answered with numbers. If the query optimiser could make intelligent decisions - weighing the cost of flushing temporary buffers - it might lift the restriction cited above. But we need to create a reliable cost model first. Let's take the first step along this path and measure what it actually costs to flush temporary buffers, so we can determine whether this overhead is a real concern or an overblown fear.

## Benchmarking tools

PostgreSQL currently provides no direct access to local buffers for measurement purposes. (_Note:_ in PostgreSQL internals, the term "local" is frequently used as a synonym for "temporary" when referring to buffer pages that cache temporary table data. Here I follow that convention.) To conduct this benchmark, I extended the system with several instrumentation tools and UI functions. The [temp-buffers-sandbox](https://github.com/danolivo/pgdev/tree/temp-buffers-sandbox) branch, based on the current PostgreSQL master, contains all the modifications needed for this work.

The implementation consists of two key commits:

**No.1: Statistics infrastructure**

This commit introduces two new internal statistics that track local buffer state:
- `allocated_localbufs` - tracks the total number of allocated local buffers
- `dirtied_localbufs` - counts how many local buffers contain dirty (unflushed) pages

These statistics potentially provide the foundation for a future cost model, giving the query optimiser visibility into the current state of temporary buffers before deciding whether to flush them.

**No.2: UI functions**

This commit adds SQL-callable functions that allow direct manipulation and inspection of local buffers:
- `pg_allocated_local_buffers()` - returns the count of currently allocated local buffers
- `pg_flush_local_buffers()` - explicitly flushes all dirty local buffers to disk
- `pg_read_temp_relation(relation_name)` - reads all blocks of a temporary table sequentially
- `pg_relpages(relation_name)` - returns the number of disk pages used by a relation

These functions enable precise measurement of flush and read operations at the block level, which is essential for developing accurate cost estimates.

# Methodology

The complete test bench can be found [here](https://github.com/danolivo/conf/tree/main/Scripts/temp_buffers_benchmark).

Fortunately, local buffer operations are quite straightforward: they don't acquire locks, don't require WAL logging, and avoid other costly manipulations. This eliminates concurrency concerns and simplifies the test logic. To build a cost estimation model, we need to measure three things: sequential write speed, sequential read speed, and the overhead of scanning buffers when no I/O is required.

The ratio between read and write speed will allow us to derive a sequential write page cost parameter based on the [DEFAULT_SEQ_PAGE_COST](https://github.com/postgres/postgres/blob/915711c8a4e60f606a8417ad033cea5385364c07/src/include/optimizer/cost.h#L24) value used in core PostgreSQL. The optimiser can use this parameter to estimate the cost of flushing dirty local buffers before parallel operations.

Each test iteration follows this algorithm:
1. Create a temp table and fill it with data that fits within the local buffer pool (all pages will be dirty in memory).
2. Call `pg_flush_local_buffers()` to write all dirty buffers to disk. Measure I/O.
3. Call `pg_flush_local_buffers()` again to measure the overhead of scanning clean buffers.
4. Evict the test table's pages by creating a dummy table that fills the entire buffer pool, then drop it.
5. Call `pg_read_temp_relation()` to read all blocks from disk into buffers. Measure I/O.
6. Call `pg_read_temp_relation()` again to measure the overhead of reading from memory.

I test buffer pool sizes from 1MB to 1GB blocks, with 30 iterations per size for statistical reliability. Higher number of temp buffers causes swapping on my laptop and non-reliable results.
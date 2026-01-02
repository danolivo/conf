# Temporary Buffer Flush Performance: A Cost Model for PostgreSQL Parallel Execution

## Abstract

This work benchmarks sequential write versus read performance for PostgreSQL temporary buffers. PostgreSQL functions are extended with instrumentation to measure buffer flush operations and tests are conducted. The measurements show that sequential writes are approximately 30% slower than reads on NVMe storage. Based on these results, the cost estimation formula has been proposed: `flush_cost = 1.30 × dirtied_localbufs + 0.01 × allocated_localbufs` for the query optimiser.

## Introduction

Temporary tables in PostgreSQL have always been [parallel restricted](https://www.postgresql.org/docs/current/parallel-safety.html). From my perspective, the reasoning is straightforward: temporary tables exist primarily to compensate for the absence of [relational variables](https://en.wikipedia.org/wiki/Relvar), and for performance reasons they should remain as simple as possible. Since PostgreSQL parallel workers behave like separate backends, they don't have access to the leader process's local state where temporary tables reside. Supporting parallel operations on temporary tables would significantly increase the complexity of this machinery.

However, we now have at least two working implementations of parallel temporary table support: [Postgres Pro](https://postgrespro.com/docs/postgrespro/16/runtime-config-query#GUC-ENABLE-PARALLEL-TEMPTABLES) and [Tantor](https://habr.com/ru/companies/tantor/articles/965264/#Параллелизм%20VS%20временные%20таблицы). This suggests it may be time to propose this feature for PostgreSQL core.

After numerous code improvements over the years, only one fundamental problem remains: temporary buffer pages are local to the leader process. If these pages aren't consistent with the on-disk table state, parallel workers cannot access the data.

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

The comment hints at a path forward: if we flush the leader's temporary buffers to disk before launching parallel operations, workers can safely read from the shared on-disk state. The concern, however, is cost—would the overhead of writing those buffers outweigh the benefits of parallelism?

On the path to enabling parallel temporary table scans, this cost argument is fundamental and must be addressed first.
We can resolve this issue by providing the optimiser with proper cost model. In this case it could make a choice between parallel scan with buffer flushing overhead and sequential scan out of parallel workers. Hence, we are looking for a constant like DEFAULT_SEQ_PAGE_COST to estimate writing overhead.
Let's address this question with actual data and measure what it actually costs to flush temporary buffers. My goal is to determine whether this overhead represents a real barrier to parallel execution or simply an overestimated concern that has kept this optimization off the table.

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

These functions enable precise measurement of flush and read operations at the block level, which is essential for developing accurate cost estimates.

## Methodology

The complete test bench can be found [here](https://github.com/danolivo/conf/tree/main/Scripts/temp_buffers_benchmark).

Fortunately, Local buffer operations are quite straightforward: they don't acquire locks, don't require WAL logging, and avoid other costly manipulations. This eliminates concurrency concerns and simplifies the test logic. To build a cost estimation model, we need to measure three things: sequential write speed, sequential read speed, and the overhead of scanning buffers when no I/O is required.

The ratio between read and write speed will allow us to derive a sequential write page cost parameter based on the [DEFAULT_SEQ_PAGE_COST](https://github.com/postgres/postgres/blob/915711c8a4e60f606a8417ad033cea5385364c07/src/include/optimizer/cost.h#L24) value used in core PostgreSQL. The optimiser can use this parameter to estimate the cost of flushing dirty local buffers before parallel operations.

Each test iteration follows this algorithm:
1. Create a temp table and fill it with data that fits within the local buffer pool (all pages will be dirty in memory).
2. Call `pg_flush_local_buffers()` to write all dirty buffers to disk. Measure I/O.
3. Call `pg_flush_local_buffers()` again to measure the overhead of scanning buffers without actual flush (dry-write-run).
4. Evict the test table's pages by creating a dummy table that fills the entire buffer pool, then drop it.
5. Call `pg_read_temp_relation()` to read all blocks from disk into buffers. Measure I/O.
6. Call `pg_read_temp_relation()` again to measure the overhead of scanning buffers without actual read (dry-read-run).

All measurements are captured using `EXPLAIN (ANALYZE, BUFFERS)`, which records execution time in milliseconds and buffer I/O statistics (local read, local written, local hit counts). Planning time is negligible (typically < 0.02ms) and excluded from analysis.
While it's possible to avoid EXPLAIN and instrumentation overhead entirely, I believe this overhead is minimal and consistent between write and read operations. Using EXPLAIN provides a convenient way to verify execution time and confirm the actual number of blocks affected.

The tests cover buffer pool sizes at powers of 2 from 128 to 262,144 blocks (1MB to 2GB), with 30 iterations per size for statistical reliability. Each test allocates 110% of the target block count to accommodate Free Space Map and Visibility Map metadata. Higher buffer counts cause memory swapping and produce unreliable results.

## Benchmark results

On my laptop, the most stable performance occurs in the 4-512 MB range:

| Blocks  | Size   | Write (ms) | Dry-Write (ms) | Read (ms) | Dry-Read (ms) | W/R Ratio | Write CV | Read CV |
|---------|--------|------------|----------------|-----------|---------------|-----------|----------|---------|
| 512     | 4 MB   | 0.54       | 0.002          | 0.58      | 0.016         | 0.93      | 5.0%     | 8.2%    |
| 1,024   | 8 MB   | 1.07       | 0.003          | 1.13      | 0.028         | 0.95      | 7.9%     | 6.5%    |
| 2,048   | 16 MB  | 3.02       | 0.004          | 2.42      | 0.054         | 1.25      | 4.7%     | 5.8%    |
| 4,096   | 32 MB  | 6.36       | 0.007          | 4.81      | 0.107         | 1.33      | 4.5%     | 3.2%    |
| 8,192   | 64 MB  | 12.34      | 0.013          | 9.79      | 0.210         | 1.26      | 3.7%     | 1.9%    |
| 16,384  | 128 MB | 24.63      | 0.026          | 19.35     | 0.421         | 1.27      | 3.1%     | 1.7%    |
| 32,768  | 256 MB | 49.60      | 0.051          | 38.72     | 0.838         | 1.28      | 2.7%     | 1.6%    |
| 65,536  | 512 MB | 98.93      | 0.102          | 77.46     | 1.681         | 1.28      | 2.5%     | 1.6%    |

Large datasets show higher write overhead and variability:

| Blocks  | Size   | Write (ms) | Dry-Write (ms) | Read (ms) | Dry-Read (ms) | W/R Ratio | Write CV  |
|---------|--------|------------|----------------|-----------|---------------|-----------|-----------|
| 131,072 | 1 GB   | 283.15     | 0.204          | 180.06    | 3.353         | 1.46      | 157.3%    |
| 262,144 | 2 GB   | 728.18     | 0.413          | 373.46    | 6.725         | 1.76      | 166.8%    |

Scanning without I/O (Dry-Run) is minimal:
- Clean buffer flush scan: 0.002-0.240 ms
- Cached read scan: 0.007-10 ms

Based on the results I can say that temp table write cost should be close to the sequential page cost. To be more precise I'd use the following formula:

```
DEFAULT_WRITE_TEMP_PAGE_COST = 1.30 × DEFAULT_SEQ_PAGE_COST
```

Write cost is close to the read cost because no WAL logging is required for temporary tables. I'm uncertain what storage type the current default seq_page_cost targets; my measurements were conducted on NVMe SSD. Would the relationship differ on HDD? Additionally, I haven't modelled random page writes in temporary buffers—would random writes have different cost characteristics?

Also, tests say that we can estimate the buffer scanning overhead as approximately 1% of the writing cost. Hence the whole formula for the preliminary temporary buffers flushing may look like (`DEFAULT_SEQ_PAGE_COST = 1`):

```
flush_cost = 1.30 × dirtied_localbufs + 0.01 × allocated_localbufs
```

## Conclusion

* Sequential writes to local buffers are approximately **30% slower** than sequential reads on NVMe storage.
* For the sake of optimisation, default write cost may be hardcoded as 1.3*DEFAULT_SEQ_PAGE_COST.
* 360 measurements with 30 iterations per size. Medium datasets (16-512 MB) show coefficient of variation consistently below 6%, indicating highly stable results. Large datasets (1-2 GB) show higher variability (CV >150% for writes), requiring careful interpretation.
# Title

Parallel Query execution over Postgres TEMP tables

## Goal

We have to identify how expensive is to flush temporary buffers before query execution and provide optimiser with data enough to choose strategy: preliminary flushing temp buffers V/S put temp table operations out of parallel section.

## Introduction

Postgres can't scan temporary tables inside a parallel worker. Reasoning for that is quite obvious: it does't have an access to the local state of the leader process where temporary table lives. It was quite a strict limitation for a while, but after a series of code improvements here and there, we have only one problem: temp buffer pages are local and if they are not consistent with on-disk table state, parallel worker have no access to their data.

Comment in the code (80558c1) made by Robert Haas in 2015 clarifies the state of the art:

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

So, if we flushed leader's temporary buffers before the parallel section start executing, we would read such tables concurrently safely. The argument about IO expensiveness may be resolved if the optimiser had a cost-based estimator for this operation and might incorporate this cost into the plan search machinery.

Let's make the first step along this way and show off how much does it really cost and should we worry about temp buffers flushing overhead.
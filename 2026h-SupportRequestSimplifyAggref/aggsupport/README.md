# agg_support

A minimal demonstration of `SupportRequestSimplifyAggref`: a planner support
function attached to a `sum()`-like aggregate, which removes a redundant
`ORDER BY` from the aggregate call.

## Requirements

A server supporting `CREATE AGGREGATE ... SUPPORT` / `ALTER AGGREGATE ...
SUPPORT`. Stock PostgreSQL has no way to attach a support function to an
aggregate — `SupportRequestSimplifyAggref` (commit 42473b3b31) is reachable
only for `count()`, whose `prosupport` slot is set in `pg_proc.dat`.

Building the extension requires the server headers (`postgresql-server-dev`
or a source install).

## Build

    make PG_CONFIG=/path/to/pg_config
    make install PG_CONFIG=/path/to/pg_config

## Use

    CREATE EXTENSION agg_support;

This creates the support function plus two demo aggregates, `mysum(numeric)`
and `mysum(float8)`. Creating them requires superuser, since `SUPPORT` does.

    EXPLAIN (VERBOSE, COSTS OFF) SELECT mysum(n ORDER BY n) FROM t;

     Aggregate
       Output: mysum(n)              <- ORDER BY dropped, no Sort node
       ->  Seq Scan on public.t

## What it declines, and why

| Case | Reason |
|---|---|
| `mysum(f ORDER BY f)`, `float8` | summation order is observable for inexact types |
| `mysum(DISTINCT n ORDER BY n)` | DISTINCT needs the sort anyway |
| `mysum(n ORDER BY g)` | the ORDER BY column is a `resjunk` argument |
| ordered-set / hypothetical-set | `aggorder` is read at execution time |
| star aggregates, wrong arity | not what this function was written for |

`FILTER` is preserved and does not prevent the rewrite.

## Two implementation notes

**Clear `ressortgroupref`.** After dropping `aggorder`, the argument
`TargetEntry`s keep the sort-group reference the parser assigned. It is not
`equal_ignore`, so `find_compatible_agg()` would consider the simplified call
different from an identical one written without `ORDER BY`, and the same
aggregate would be evaluated twice.

**Use `aggargtypes`, not `aggtranstype`.** `aggtranstype` is only filled in by
`preprocess_aggrefs()`, which runs after `eval_const_expressions()` — at this
point it is still `InvalidOid`. The in-core `int8inc_support` asserts exactly
that.

## Do not attach this to the built-in `sum()`

`ALTER AGGREGATE pg_catalog.sum(numeric) SUPPORT ...` records a dependency
from a pinned catalog object onto the extension's function, which makes the
extension undroppable, and the change does not survive dump/restore or
pg_upgrade because system objects are not dumped. Own your aggregates.

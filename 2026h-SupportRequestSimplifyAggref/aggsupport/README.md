# agg_support

A minimal demonstration of `SupportRequestSimplifyAggref`: a planner support
function attached to a `sum()`-like aggregate, which removes a redundant
`ORDER BY` from the aggregate call.

## Requirements

PostgreSQL 19 or newer. Since commit 42473b3b31 the planner issues
`SupportRequestSimplifyAggref` for any aggregate whose `pg_proc.prosupport`
is set; in core the request is used to turn `count(1)` and
`count(never_null_column)` into `count(*)`.

Stock PostgreSQL has no DDL to attach a support function to an aggregate:
`ALTER FUNCTION ... SUPPORT` rejects aggregates, and `CREATE`/`ALTER
AGGREGATE` know no `SUPPORT` clause (a patch adding both has been
[proposed](https://www.postgresql.org/message-id/8f58c96d-d3c7-4c0f-9898-116f00eeaff6@gmail.com)).
Until then the install script writes `pg_proc.prosupport` directly. Within a
single extension that is tolerable — the aggregates and the support function
are extension members and can only be dropped together, so no dangling
`prosupport` OID can be left behind. It is also why `CREATE EXTENSION`
requires superuser here.

Building the extension requires the server headers (`postgresql-server-dev`
or a source install).

## Build

    make PG_CONFIG=/path/to/pg_config
    make install PG_CONFIG=/path/to/pg_config
    make installcheck PG_CONFIG=/path/to/pg_config   # against a running server

## Use

    CREATE EXTENSION agg_support;   -- superuser

This creates the support function plus two demo aggregates, `mysum(numeric)`
and `mysum(float8)`.

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

Nothing stops a superuser from pointing `pg_catalog.sum(numeric)` at this
support function with the same `UPDATE`. Resist the urge, at least in
production: no dependency is recorded, so the support function can later be
dropped (with the extension) while `prosupport` still points at its OID —
after which every query using `sum(numeric)` fails to plan with `cache lookup
failed for function NNNNN`. The link is also invisible to `pg_dump` and does
not survive `pg_upgrade`. Own your aggregates, or see the proposed
`ALTER AGGREGATE ... SUPPORT` patch, which records a proper dependency.

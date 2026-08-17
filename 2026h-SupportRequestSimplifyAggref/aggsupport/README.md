# agg_support

A minimal demonstration of `SupportRequestSimplifyAggref`: a planner support
function that removes a redundant `ORDER BY` from a `sum()` call.

## Requirements

PostgreSQL 19 or newer. Since commit 42473b3b31 the planner issues
`SupportRequestSimplifyAggref` for any aggregate whose `pg_proc.prosupport`
is set; in core the request is used to turn `count(1)` and
`count(never_null_column)` into `count(*)`.

Stock PostgreSQL has no DDL to attach a support function to an aggregate:
`ALTER FUNCTION ... SUPPORT` rejects aggregates, and `CREATE`/`ALTER
AGGREGATE` know no `SUPPORT` clause (a patch adding both has been
[proposed](https://www.postgresql.org/message-id/8f58c96d-d3c7-4c0f-9898-116f00eeaff6@gmail.com)).
Until then this extension ships a pair of helpers that do the DDL's job by
writing the catalogs directly — which is also why everything here requires
superuser:

- `agg_support_attach(regprocedure)` sets `pg_proc.prosupport` **and**
  records a NORMAL `pg_depend` entry (aggregate depends on the support
  function);
- `agg_support_detach(regprocedure)` undoes both.

The dependency is what makes the attachment survivable: without it, dropping
the support function (e.g. via `DROP EXTENSION`) would leave a dangling
`prosupport` OID, and every query using the aggregate would fail to plan with
`cache lookup failed for function NNNNN`.

Building the extension requires the server headers (`postgresql-server-dev`
or a source install).

## Build

    make PG_CONFIG=/path/to/pg_config
    make install PG_CONFIG=/path/to/pg_config
    make installcheck PG_CONFIG=/path/to/pg_config   # against a running server

## Use

    CREATE EXTENSION agg_support;   -- superuser
    SELECT agg_support_attach('pg_catalog.sum(numeric)'::regprocedure);

    EXPLAIN (VERBOSE, COSTS OFF) SELECT sum(n ORDER BY n) FROM t;

     Aggregate
       Output: sum(n)               <- ORDER BY dropped, no Sort node
       ->  Seq Scan on public.t

While attached, the recorded dependency blocks dropping the support function
from under the aggregate — even with `CASCADE`, since the dependency walk
ends at a pinned object:

    DROP EXTENSION agg_support;
    ERROR:  cannot drop function sum(numeric) because it is required by the database system

Detach first, then drop:

    SELECT agg_support_detach('pg_catalog.sum(numeric)'::regprocedure);
    DROP EXTENSION agg_support;

Caveats. Attaching to a built-in aggregate affects the whole database and
all its users — an administrator's decision, not a library's. The attachment
does not survive pg_dump/restore or pg_upgrade: both catalog records vanish
together on the new cluster, cleanly — `sum()` keeps working as stock, just
re-run the attach. The proposed `ALTER AGGREGATE ... SUPPORT` patch does all
of the above natively, with proper error messages.

## What it declines, and why

| Case | Reason |
|---|---|
| `sum(f ORDER BY f)`, `float8` | summation order is observable for inexact types |
| `sum(DISTINCT n ORDER BY n)` | DISTINCT needs the sort anyway |
| `sum(n ORDER BY g)` | the ORDER BY column is a `resjunk` argument |
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

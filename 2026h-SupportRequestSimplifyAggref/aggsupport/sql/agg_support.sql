CREATE EXTENSION agg_support;

CREATE TABLE aggtest (n numeric, f float8, g int);
INSERT INTO aggtest SELECT i, i, i FROM generate_series(1, 100) i;

-- Attach to the built-in aggregates: sets pg_proc.prosupport and records
-- a NORMAL dependency in pg_depend
SELECT agg_support_attach('pg_catalog.sum(numeric)'::regprocedure);
SELECT agg_support_attach('pg_catalog.sum(float8)'::regprocedure);

-- ORDER BY is dropped: plain sum over an exact type
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(n ORDER BY n) FROM aggtest;

-- Same result with and without the rewrite
SELECT sum(n ORDER BY n) = sum(n) AS equal FROM aggtest;

-- After the rewrite both calls collapse into one aggregate
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(n ORDER BY n), sum(n) FROM aggtest;

-- FILTER does not prevent the rewrite
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(n ORDER BY n) FILTER (WHERE g > 10) FROM aggtest;

-- Declined: inexact type, summation order is observable
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(f ORDER BY f) FROM aggtest;

-- Declined: DISTINCT needs the sort anyway
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(DISTINCT n ORDER BY n) FROM aggtest;

-- Declined: the ORDER BY column is a resjunk argument
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(n ORDER BY g) FROM aggtest;

-- Guards
SELECT agg_support_attach('pg_catalog.sum(numeric)'::regprocedure);
SELECT agg_support_attach('pg_catalog.abs(numeric)'::regprocedure);

-- The dependency blocks DROP EXTENSION while the built-ins are attached
DROP EXTENSION agg_support;

-- Detach: sum() is back to stock behaviour, sort and all
SELECT agg_support_detach('pg_catalog.sum(numeric)'::regprocedure);
SELECT agg_support_detach('pg_catalog.sum(float8)'::regprocedure);

EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(n ORDER BY n) FROM aggtest;

SELECT sum(n ORDER BY n) FROM aggtest;

DROP TABLE aggtest;

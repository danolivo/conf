/*
 * Create a table, partitioned by hash, with a massive number of partitions.
 */

DROP TABLE IF EXISTS test CASCADE;

DO $$
DECLARE
  parts integer := 256;
  i integer;
BEGIN
  -- Remove shreds, if still exists
  FOR i IN 1..parts LOOP
    EXECUTE format('DROP TABLE IF EXISTS l%s', i);
  END LOOP;

  CREATE TABLE test (x integer PRIMARY KEY, y integer DEFAULT -1)
  PARTITION BY HASH (x);
  
  FOR i IN 1..parts LOOP
    EXECUTE format('CREATE TABLE l%s PARTITION OF test FOR VALUES WITH (modulus %s, remainder %s)', i, parts, i-1);
  END LOOP;
  
  -- INSERT INTO parts (x) SELECT x % 100000 FORM generate_series(1,1E7) AS x; 
  CREATE INDEX ON test (y,x);
  CREATE INDEX ON test (x);
  CREATE INDEX ON test (x,y);
  CREATE INDEX ON test (x) WHERE x < 100;
  CREATE INDEX ON test ((x*x)) WHERE x < 100;
END$$;

ANALYZE;
ANALYZE test;

/*
-- EXAMPLES:

\timing on

-- No parameters at all
EXPLAIN (ANALYZE, COSTS OFF, MEMORY, TIMING OFF) SELECT * FROM test;
PREPARE tst AS SELECT * FROM test;
EXPLAIN (ANALYZE, COSTS OFF, MEMORY, TIMING OFF) EXECUTE tst;

DEALLOCATE ALL;

-- Plan depends on an external parameter
EXPLAIN (ANALYZE, COSTS OFF, MEMORY, TIMING OFF) SELECT * FROM test WHERE y = 127;
PREPARE tst2 (integer) AS SELECT * FROM test WHERE y = $1;
EXPLAIN (ANALYZE, COSTS OFF, MEMORY, TIMING OFF) EXECUTE tst2(127);

SET plan_cache_mode = 'force_generic_plan';
EXPLAIN (ANALYZE, COSTS OFF, MEMORY, TIMING OFF) EXECUTE tst2(127);
EXPLAIN (ANALYZE, COSTS OFF, MEMORY, TIMING OFF) EXECUTE tst2(127); -- No time to planning
*/

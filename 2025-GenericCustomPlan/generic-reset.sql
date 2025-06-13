DROP TABLE IF EXISTS test CASCADE;
DEALLOCATE ALL;
CREATE TABLE test(x integer, y integer);
INSERT INTO test (x,y) (SELECT x, 1 FROM generate_series(1,10) AS x);
CREATE INDEX ON test(x);
VACUUM ANALYZE test;

PREPARE tst(integer) AS SELECT * FROM test WHERE x = $1;

-- generic plan after the last execution
EXPLAIN (ANALYZE, COSTS OFF, BUFFERS OFF, TIMING OFF)
EXECUTE tst(1) \watch i=0 c=7

INSERT INTO test (x,y) (SELECT x, 1 FROM generate_series(1,1) AS x);
ANALYZE test;

-- The generic plan has been dropped on the statistic invalidation
EXPLAIN (ANALYZE, COSTS OFF, BUFFERS OFF, TIMING OFF)
EXECUTE tst(1) \watch i=0 c=1


-- Demonstrate how IncrementalSort chooses an index

DROP TABLE IF EXISTS test CASCADE;
CREATE TABLE test (x int, y int, z int);
INSERT INTO test SELECT x%1000,x%1000,x%1000 FROM generate_series(1,1E5) AS x;
CREATE INDEX idx1 ON test (x);
VACUUM ANALYZE test;

EXPLAIN SELECT x,y,z FROM test ORDER BY x,y,z;
CREATE INDEX idx2 ON test (x,y);
EXPLAIN SELECT x,y,z FROM test ORDER BY x,y,z;
SET enable_incremental_sort = 'off';
EXPLAIN SELECT x,y,z FROM test ORDER BY x,y,z;

-- Demonstrate that sort doesn't take into account number of columns to be sorted.

DROP TABLE IF EXISTS test CASCADE;
CREATE TABLE test (x int, y int, z int);
INSERT INTO test SELECT x%200,x%200,x%200 FROM generate_series(1,1E5) AS x;
CREATE INDEX idx1 ON test (x);
VACUUM ANALYZE test;

SET enable_sort = off;
SET enable_incremental_sort = 'on';
EXPLAIN SELECT x,y,z FROM test ORDER BY x,y,z;
EXPLAIN SELECT x,y,z FROM test ORDER BY x,y;
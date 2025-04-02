DROP TABLE IF EXISTS t1,t2,t3;
CREATE TABLE t1 (x numeric, y numeric DEFAULT 3.14159265358979323846);
CREATE TABLE t2 (x numeric, y numeric DEFAULT 3.14159265358979323846);
CREATE TABLE t3 (x numeric, y numeric DEFAULT 3.14159265358979323846);
INSERT INTO t1 (x) (SELECT value FROM generate_series(0,1E4) AS value);
INSERT INTO t2 (x) (SELECT value FROM generate_series(1E4+1,1E5) AS value);
INSERT INTO t3 (x) (SELECT value FROM generate_series(1E4+1,1E4+1000) AS value);
INSERT INTO t2 (x) (VALUES (0));
INSERT INTO t3 (x) (VALUES (0));
CREATE INDEX ON t1(x);
CREATE INDEX ON t2(x);
CREATE INDEX ON t3(x);
VACUUM ANALYZE t1,t2,t3;

-- No limit - no reason for fractional paths at all. 
EXPLAIN (ANALYZE, BUFFERS OFF, TIMING OFF)
SELECT * FROM t1 JOIN t3 LEFT JOIN t2 ON (t2.x=t3.x) ON (t1.x=t3.x);

/*
 Hash Join  (cost=106.80..318.33 rows=1001 width=61) (actual rows=1 loops=1)
   Hash Cond: (t1.x = t3.x)
   ->  Seq Scan on t1  (cost=0.00..164.01 rows=10001 width=19) (actual rows=10001 loops=1)
   ->  Hash  (cost=94.29..94.29 rows=1001 width=42) (actual rows=1001 loops=1)
         Buckets: 1024  Batches: 1  Memory Usage: 83kB
         ->  Merge Left Join  (cost=0.57..94.29 rows=1001 width=42) (actual rows=1001 loops=1)
               Merge Cond: (t3.x = t2.x)
               ->  Index Scan using t3_x_idx on t3  (cost=0.28..45.50 rows=1001 width=21) (actual rows=1001 loops=1)
               ->  Index Scan using t2_x_idx on t2  (cost=0.29..2919.31 rows=90001 width=21) (actual rows=1002 loops=1)
 Planning Time: 1.017 ms
 Execution Time: 9.322 ms
*/

-- Lust add a limit LIMIT - same data, 100 times faster.
EXPLAIN (ANALYZE, BUFFERS OFF, TIMING OFF)
SELECT * FROM t1 JOIN t3 LEFT JOIN t2 ON (t2.x=t3.x) ON (t1.x=t3.x)
LIMIT 1;

/*
 Limit  (cost=0.85..1.23 rows=1 width=61) (actual rows=1 loops=1)
   ->  Merge Join  (cost=0.85..373.84 rows=1001 width=61) (actual rows=1 loops=1)
         Merge Cond: (t3.x = t1.x)
         ->  Merge Left Join  (cost=0.57..94.29 rows=1001 width=42) (actual rows=1 loops=1)
               Merge Cond: (t3.x = t2.x)
               ->  Index Scan using t3_x_idx on t3  (cost=0.28..45.50 rows=1001 width=21) (actual rows=1 loops=1)
               ->  Index Scan using t2_x_idx on t2  (cost=0.29..2919.31 rows=90001 width=21) (actual rows=1 loops=1)
         ->  Index Scan using t1_x_idx on t1  (cost=0.29..337.30 rows=10001 width=19) (actual rows=1 loops=1)
 Planning Time: 1.122 ms
 Execution Time: 0.182 ms
*/

UPDATE pg_proc SET prosupport = '-' WHERE proname = 'int4mul';
CREATE TABLE test (x int);
INSERT INTO test (x) SELECT gs FROM generate_series(1,1000) AS gs;
ANALYZE test;

PREPARE stmt(int) AS SELECT x FROM test WHERE int4mul(x, $1) < 100;
EXPLAIN (ANALYZE, TIMING OFF)
EXECUTE stmt(0);

EXPLAIN (ANALYZE, TIMING OFF)
EXECUTE stmt(1);

EXPLAIN (ANALYZE, TIMING OFF)
EXECUTE stmt(2);

/*
                                    QUERY PLAN                                    
----------------------------------------------------------------------------------
 Seq Scan on test  (cost=0.00..20.00 rows=333 width=4) (actual rows=1000 loops=1)
   Filter: (int4mul(x, 0) < 100)
 Planning Time: 0.536 ms
 Execution Time: 0.294 ms
(4 rows)

danolivo=# 
danolivo=# EXPLAIN (ANALYZE, TIMING OFF)
danolivo-# EXECUTE stmt(1);
                                   QUERY PLAN                                   
--------------------------------------------------------------------------------
 Seq Scan on test  (cost=0.00..20.00 rows=333 width=4) (actual rows=99 loops=1)
   Filter: (int4mul(x, 1) < 100)
   Rows Removed by Filter: 901
 Planning Time: 0.056 ms
 Execution Time: 0.247 ms
(5 rows)

danolivo=# 
danolivo=# EXPLAIN (ANALYZE, TIMING OFF)
danolivo-# EXECUTE stmt(2);
                                   QUERY PLAN                                   
--------------------------------------------------------------------------------
 Seq Scan on test  (cost=0.00..20.00 rows=333 width=4) (actual rows=49 loops=1)
   Filter: (int4mul(x, 2) < 100)
   Rows Removed by Filter: 951
 Planning Time: 0.057 ms
 Execution Time: 0.244 ms
*/

UPDATE pg_proc SET prosupport = 'int4mul_support' WHERE proname = 'int4mul';


EXPLAIN (ANALYZE, TIMING OFF)
EXECUTE stmt(0);

EXPLAIN (ANALYZE, TIMING OFF)
EXECUTE stmt(1);

EXPLAIN (ANALYZE, TIMING OFF)
EXECUTE stmt(2);

/*
                                    QUERY PLAN                                     
-----------------------------------------------------------------------------------
 Seq Scan on test  (cost=0.00..15.00 rows=1000 width=4) (actual rows=1000 loops=1)

                                  QUERY PLAN                                   
-------------------------------------------------------------------------------
 Seq Scan on test  (cost=0.00..17.50 rows=99 width=4) (actual rows=99 loops=1)
   Filter: (x < 100)
   Rows Removed by Filter: 901

                                   QUERY PLAN                                   
--------------------------------------------------------------------------------
 Seq Scan on test  (cost=0.00..20.00 rows=333 width=4) (actual rows=49 loops=1)
   Filter: (int4mul(x, 2) < 100)
   Rows Removed by Filter: 951
*/
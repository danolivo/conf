-- Addition to https://github.com/danolivo/pgdev/tree/temp-bufers-stat

-- temp_buffers = '1GB'
DROP TABLE IF EXISTS test,evicter;
CREATE TEMP TABLE test (id integer, x text STORAGE PLAIN DEFAULT repeat('1234567890ABCDEF', 16));
EXPLAIN ANALYZE
INSERT INTO test (id) (SELECT value FROM generate_series(1, 2194304) AS value);
VACUUM ANALYZE test;
-- Вытесним все страницы тестовой таблицы. Подготовим буфер так, чтобы потом на SELECT не нужно было ничего писать
CREATE TEMP TABLE evicter (id integer, x text STORAGE PLAIN DEFAULT repeat('1234567890ABCDEF', 16));
EXPLAIN ANALYZE
INSERT INTO evicter (id) (SELECT value FROM generate_series(1, 4194304) AS value);
VACUUM VERBOSE evicter;
SELECT pg_flush_local_buffers();
SELECT pg_dirty_local_buffers(); -- Just to be sure ...
EXPLAIN ANALYZE SELECT pg_scan_temp_relation('test'::regclass);
/*
 Result  (cost=0.00..0.01 rows=1 width=4) (actual time=987.370..987.372 rows=1.00 loops=1)
   Buffers: shared hit=8, local read=81271
 Planning Time: 0.053 ms
 Temp Buffers Allocated: 1024 MB
 Dirty temp pages: 0
 Execution Time: 987.388 ms
*/
DROP TABLE IF EXISTS test,evicter;
CREATE TEMP TABLE test (id integer, x text STORAGE PLAIN DEFAULT repeat('1234567890ABCDEF', 16));
EXPLAIN ANALYZE
INSERT INTO test (id) (SELECT value FROM generate_series(1, 2194304) AS value);
VACUUM ANALYZE test;
EXPLAIN ANALYZE SELECT pg_flush_local_buffers();
SELECT pg_dirty_local_buffers();
EXPLAIN ANALYZE SELECT pg_dirty_local_buffers(); -- How much does it cost to pass the buffers without any writings?
/*
 Result  (cost=0.00..0.01 rows=1 width=4) (actual time=873.385..873.386 rows=1.00 loops=1)
   Buffers: local written=81296
 Planning Time: 0.055 ms
 Temp Buffers Allocated: 1024 MB
 Dirty temp pages: 0
 Execution Time: 873.403 ms
 Result  (cost=0.00..0.01 rows=1 width=4) (actual time=0.993..0.994 rows=1.00 loops=1)
 Planning Time: 0.036 ms
 Temp Buffers Allocated: 1024 MB
 Dirty temp pages: 0
 Execution Time: 1.003 ms
*/
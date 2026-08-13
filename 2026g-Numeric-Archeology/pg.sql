SET jit = off;
SET max_parallel_workers_per_gather = 0;
DROP TABLE IF EXISTS t_num, t_money, t_i8, t_f8;
CREATE TABLE t_num   AS SELECT ((hashint8(i)%1000)/100.0)::numeric(18,2) v FROM generate_series(1,20000000) i;
CREATE TABLE t_money AS SELECT (((hashint8(i)%1000)/100.0)::numeric(18,2))::money v FROM generate_series(1,20000000) i;
CREATE TABLE t_i8    AS SELECT (hashint8(i)%1000)::bigint v FROM generate_series(1,20000000) i;
CREATE TABLE t_f8    AS SELECT ((hashint8(i)%1000)/100.0)::float8 v FROM generate_series(1,20000000) i;
VACUUM ANALYZE t_num, t_money, t_i8, t_f8;
SELECT relname, pg_size_pretty(pg_relation_size(oid)) FROM pg_class WHERE relname LIKE 't_%' ORDER BY 1;

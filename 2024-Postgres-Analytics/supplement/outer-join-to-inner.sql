EXPLAIN (COSTS OFF)
SELECT oid, relname FROM pg_class c1
  LEFT JOIN pg_class c2
  ON c1.relname = c2.relname;

/*
 Hash Left Join
   Hash Cond: (c1.relname = c2.relname)
   ->  Seq Scan on pg_class c1
   ->  Hash
         ->  Seq Scan on pg_class c2
 */

EXPLAIN (COSTS OFF)
SELECT c1.oid, c1.relname FROM pg_class c1
  LEFT JOIN pg_class c2 ON true
  WHERE c1.relname = c2.relname;

/*
 Hash Join
   Hash Cond: (c1.relname = c2.relname)
   ->  Seq Scan on pg_class c1
   ->  Hash
         ->  Seq Scan on pg_class c2
 */
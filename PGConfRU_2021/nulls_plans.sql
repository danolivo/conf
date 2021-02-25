 Finalize Aggregate  (cost=2435.60..2435.61 rows=1 width=8) (actual rows=1 loops=1)
   AQO not used
   ->  Gather  (cost=2435.39..2435.60 rows=2 width=8) (actual rows=3 loops=1)
         AQO not used
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate  (cost=1435.39..1435.40 rows=1 width=8) (actual rows=1 loops=3)
               AQO not used
               ->  Parallel Hash Left Join  (cost=224.63..1430.69 rows=1878 width=0) (actual rows=1502 loops=3)
                     AQO: rows=4507, error=0%
                     Hash Cond: (person.id = employees.id)
                     Filter: (employees.cid IS NULL)
                     Rows Removed by Filter: 164
                     ->  Parallel Hash Join  (cost=69.87..1270.47 rows=2083 width=4) (actual rows=1667 loops=3)
                           AQO: rows=5000, error=0%
                           Hash Cond: (person.id = disabled.person_id)
                           ->  Parallel Seq Scan on person  (cost=0.00..1035.67 rows=41667 width=4) (actual rows=33333 loops=3)
                               AQO: rows=100000, error=0%
                           ->  Parallel Hash  (cost=43.83..43.83 rows=2083 width=4) (actual rows=1667 loops=3)
                                 AQO not used
                                 Buckets: 8192  Batches: 1  Memory Usage: 320kB
                                 ->  Parallel Seq Scan on disabled  (cost=0.00..43.83 rows=2083 width=4) (actual rows=1667 loops=3)
                                     AQO: rows=5000, error=0%
                     ->  Parallel Hash  (cost=102.67..102.67 rows=4167 width=8) (actual rows=3333 loops=3)
                         AQO not used
                           Buckets: 16384  Batches: 1  Memory Usage: 576kB
                           ->  Parallel Seq Scan on employees  (cost=0.00..102.67 rows=4167 width=8) (actual rows=3333 loops=3)
                           AQO: rows=10000, error=0%
 Planning Time: 0.744 ms
 Execution Time: 15.843 ms
 Using aqo: true
 AQO mode: FROZEN
 JOINS: 2
(23 rows)

SET
                                                       QUERY PLAN                                                        
-------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=2259.29..2259.30 rows=1 width=8) (actual rows=1 loops=1)
   ->  Hash Join  (cost=2167.52..2259.28 rows=1 width=0) (actual rows=4514 loops=1)
         Hash Cond: (disabled.person_id = person.id)
         ->  Seq Scan on disabled  (cost=0.00..73.00 rows=5000 width=4) (actual rows=5000 loops=1)
         ->  Hash  (cost=2167.51..2167.51 rows=1 width=4) (actual rows=90000 loops=1)
               Buckets: 131072 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 4189kB
               ->  Hash Left Join  (cost=286.00..2167.51 rows=1 width=4) (actual rows=90000 loops=1)
                     Hash Cond: (person.id = employees.id)
                     Filter: (employees.cid IS NULL)
                     Rows Removed by Filter: 10000
                     ->  Seq Scan on person  (cost=0.00..1619.00 rows=100000 width=4) (actual rows=100000 loops=1)
                     ->  Hash  (cost=161.00..161.00 rows=10000 width=8) (actual rows=10000 loops=1)
                           Buckets: 16384  Batches: 1  Memory Usage: 519kB
                           ->  Seq Scan on employees  (cost=0.00..161.00 rows=10000 width=8) (actual rows=10000 loops=1)
 Planning Time: 0.335 ms
 Execution Time: 70.281 ms
(16 rows)


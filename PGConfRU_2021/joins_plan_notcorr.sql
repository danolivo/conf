-- EXPLAIN of query plan where no correlations existed in a join clause variables.

-- 
-- Query
-- 
EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
	SELECT count(*) FROM person JOIN employees USING (id)
	WHERE age>50 AND position='Helper';

-- 
-- EXPLAIN
-- 
 Aggregate  (cost=587.05..587.06 rows=1 width=8) (actual rows=1 loops=1)
   ->  Merge Join  (cost=256.14..586.50 rows=220 width=0) (actual rows=235 loops=1)
         Merge Cond: (person.id = employees.id)
         ->  Index Only Scan using person_id_age_idx on person  (cost=0.29..3157.64 rows=16160 width=4) (actual rows=1566 loops=1)
               Index Cond: (age > 50)
               Heap Fetches: 1566
         ->  Sort  (cost=255.84..259.25 rows=1361 width=4) (actual rows=1361 loops=1)
               Sort Key: employees.id
               Sort Method: quicksort  Memory: 123kB
               ->  Seq Scan on employees  (cost=0.00..185.00 rows=1361 width=4) (actual rows=1361 loops=1)
                     Filter: ("position" = 'Helper'::text)
                     Rows Removed by Filter: 8639
 Planning Time: 0.648 ms
 Execution Time: 4.143 ms
(14 rows)
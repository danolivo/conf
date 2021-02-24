-- EXPLAIN of query plan where join clause has semantic dependencies between variables.

-- 
-- Query
-- 
EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
	SELECT count(*) FROM person JOIN employees USING (id)
	WHERE age<18 AND position='Helper';

-- 
-- EXPLAIN
-- 
 Aggregate  (cost=586.53..586.54 rows=1 width=8) (actual rows=1 loops=1)
   ->  Merge Join  (cost=256.14..585.99 rows=216 width=0) (actual rows=70 loops=1)
         Merge Cond: (person.id = employees.id)
         ->  Index Only Scan using person_id_age_idx on person  (cost=0.29..3153.95 rows=15903 width=4) (actual rows=1580 loops=1)
               Index Cond: (age < 18)
               Heap Fetches: 1580
         ->  Sort  (cost=255.84..259.25 rows=1361 width=4) (actual rows=1361 loops=1)
               Sort Key: employees.id
               Sort Method: quicksort  Memory: 123kB
               ->  Seq Scan on employees  (cost=0.00..185.00 rows=1361 width=4) (actual rows=1361 loops=1)
                     Filter: ("position" = 'Helper'::text)
                     Rows Removed by Filter: 8639
 Planning Time: 0.264 ms
 Execution Time: 4.015 ms
(14 rows)

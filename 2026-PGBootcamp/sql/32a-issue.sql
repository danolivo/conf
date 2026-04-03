EXPLAIN (ANALYZE, BUFFERS OFF)
SELECT MIN(lt.link) AS link_type,
       MIN(t1.title) AS first_movie,
       MIN(t2.title) AS second_movie
FROM keyword AS k,
     link_type AS lt,
     movie_keyword AS mk,
     movie_link AS ml,
     title AS t1,
     title AS t2
WHERE k.keyword ='10,000-mile-club'
  AND mk.keyword_id = k.id
  AND t1.id = mk.movie_id
  AND ml.movie_id = t1.id
  AND ml.linked_movie_id = t2.id
  AND lt.id = ml.link_type_id
  AND mk.movie_id = t1.id;

-- With all additional indexes:
/*
 Aggregate  (cost=4074.75..4074.76 rows=1 width=96) (actual time=163.859..164.050 rows=1.00 loops=1)
   ->  Nested Loop  (cost=2.08..4074.73 rows=3 width=46) (actual time=163.856..164.047 rows=0.00 loops=1)
         ->  Nested Loop  (cost=1.65..4062.13 rows=3 width=33) (actual time=163.856..164.046 rows=0.00 loops=1)
               Join Filter: (lt.id = ml.link_type_id)
               ->  Gather  (cost=0.01..1.12 rows=18 width=16) (actual time=0.468..0.485 rows=18.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     ->  Parallel Seq Scan on link_type lt  (cost=0.00..1.11 rows=11 width=16) (actual time=0.007..0.008 rows=9.00 loops=2)
               ->  Materialize  (cost=1.64..4060.21 rows=3 width=25) (actual time=9.077..9.087 rows=0.00 loops=18)
                     Storage: Memory  Maximum Storage: 17kB
                     ->  Nested Loop  (cost=1.64..4060.20 rows=3 width=25) (actual time=163.380..163.557 rows=0.00 loops=1)
                           ->  Merge Join  (cost=1.21..4058.74 rows=3 width=16) (actual time=163.380..163.556 rows=0.00 loops=1)
                                 Merge Cond: (ml.movie_id = mk.movie_id)
                                 ->  Index Scan using movie_link_movie_id_linked_movie_id_idx on movie_link ml  (cost=0.29..1168.96 rows=29997 width=12) (actual time=0.015..1.365 rows=29997.00 loops=1)
                                       Index Searches: 1
                                 ->  Materialize  (cost=0.92..95671.46 rows=34 width=4) (actual time=161.332..161.509 rows=1.00 loops=1)
                                       Storage: Memory  Maximum Storage: 17kB
                                       ->  Gather Merge  (cost=0.92..95671.38 rows=34 width=4) (actual time=161.331..161.508 rows=1.00 loops=1)
                                             Workers Planned: 4
                                             Workers Launched: 4
                                             ->  Nested Loop  (cost=0.85..95670.83 rows=8 width=4) (actual time=152.266..153.640 rows=0.20 loops=5)
                                                   Join Filter: (k.id = mk.keyword_id)
                                                   Rows Removed by Join Filter: 904786
                                                   ->  Parallel Index Scan using movie_keyword1 on movie_keyword mk  (cost=0.43..78701.66 rows=1130982 width=8) (actual time=0.038..54.381 rows=904786.00 loops=5)
                                                         Index Searches: 1
                                                   ->  Materialize  (cost=0.42..4.44 rows=1 width=4) (actual time=0.000..0.000 rows=1.00 loops=4523930)
                                                         Storage: Memory  Maximum Storage: 17kB
                                                         ->  Index Only Scan using keyword_keyword_id_idx on keyword k  (cost=0.42..4.44 rows=1 width=4) (actual time=0.056..0.056 rows=1.00 loops=5)
                                                               Index Cond: (keyword = '10,000-mile-club'::text)
                                                               Heap Fetches: 0
                                                               Index Searches: 5
                           ->  Index Scan using title_pkey on title t1  (cost=0.43..0.49 rows=1 width=21) (never executed)
                                 Index Cond: (id = mk.movie_id)
                                 Index Searches: 0
         ->  Index Scan using title_pkey on title t2  (cost=0.43..4.20 rows=1 width=21) (never executed)
               Index Cond: (id = ml.linked_movie_id)
               Index Searches: 0
 Planning Time: 2.314 ms
 Execution Time: 164.125 ms
 */

set enable_material = false;

/*
 Finalize Aggregate  (cost=5079.37..5079.38 rows=1 width=96) (actual time=29.988..30.839 rows=1.00 loops=1)
   ->  Gather  (cost=5079.33..5079.34 rows=4 width=96) (actual time=29.983..30.835 rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         ->  Partial Aggregate  (cost=5079.32..5079.33 rows=1 width=96) (actual time=21.815..21.816 rows=1.00 loops=5)
               ->  Nested Loop  (cost=6.16..5079.31 rows=1 width=46) (actual time=21.810..21.811 rows=0.00 loops=5)
                     ->  Nested Loop  (cost=5.73..5075.11 rows=1 width=33) (actual time=21.810..21.811 rows=0.00 loops=5)
                           ->  Nested Loop  (cost=5.30..5074.63 rows=1 width=24) (actual time=21.810..21.811 rows=0.00 loops=5)
                                 ->  Parallel Hash Join  (cost=5.17..5074.47 rows=1 width=16) (actual time=21.810..21.810 rows=0.00 loops=5)
                                       Hash Cond: (mk.keyword_id = k.id)
                                       ->  Merge Join  (cost=0.72..4770.94 rows=113933 width=20) (actual time=0.781..19.731 rows=57638.40 loops=5)
                                             Merge Cond: (ml.movie_id = mk.movie_id)
                                             ->  Parallel Index Scan using movie_link_movie_id_linked_movie_id_idx on movie_link ml  (cost=0.29..943.98 rows=7499 width=12) (actual time=0.022..0.650 rows=5999.40 loops=5)
                                                   Index Searches: 1
                                             ->  Index Scan using movie_keyword1 on movie_keyword mk  (cost=0.43..112631.13 rows=4523930 width=8) (actual time=0.018..11.569 rows=134395.20 loops=5)
                                                   Index Searches: 5
                                       ->  Parallel Hash  (cost=4.43..4.43 rows=1 width=4) (actual time=0.021..0.021 rows=0.20 loops=5)
                                             Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                             ->  Parallel Index Only Scan using keyword_keyword_id_idx on keyword k  (cost=0.42..4.43 rows=1 width=4) (actual time=0.046..0.047 rows=1.00 loops=1)
                                                   Index Cond: (keyword = '10,000-mile-club'::text)
                                                   Heap Fetches: 0
                                                   Index Searches: 1
                                 ->  Index Scan using link_type_pkey on link_type lt  (cost=0.14..0.16 rows=1 width=16) (never executed)
                                       Index Cond: (id = ml.link_type_id)
                                       Index Searches: 0
                           ->  Index Scan using title_pkey on title t1  (cost=0.43..0.49 rows=1 width=21) (never executed)
                                 Index Cond: (id = mk.movie_id)
                                 Index Searches: 0
                     ->  Index Scan using title_pkey on title t2  (cost=0.43..4.20 rows=1 width=21) (never executed)
                           Index Cond: (id = ml.linked_movie_id)
                           Index Searches: 0
 Planning Time: 2.833 ms
 Execution Time: 30.923 ms
(33 rows)
*/

SET parallel_setup_cost = 1000;
SET parallel_tuple_cost = 0.1;

/*
 Aggregate  (cost=5073.38..5073.39 rows=1 width=96) (actual time=165.023..165.453 rows=1.00 loops=1)
   ->  Nested Loop  (cost=1002.20..5073.36 rows=3 width=46) (actual time=165.018..165.449 rows=0.00 loops=1)
         ->  Nested Loop  (cost=1001.77..5060.76 rows=3 width=33) (actual time=165.018..165.448 rows=0.00 loops=1)
               ->  Nested Loop  (cost=1001.34..5059.30 rows=3 width=24) (actual time=165.018..165.448 rows=0.00 loops=1)
                     ->  Merge Join  (cost=1001.20..5058.84 rows=3 width=16) (actual time=165.017..165.447 rows=0.00 loops=1)
                           Merge Cond: (ml.movie_id = mk.movie_id)
                           ->  Index Scan using movie_link_movie_id_linked_movie_id_idx on movie_link ml  (cost=0.29..1168.96 rows=29997 width=12) (actual time=0.018..1.417 rows=29997.00 loops=1)
                                 Index Searches: 1
                           ->  Materialize  (cost=1000.91..96675.02 rows=34 width=4) (actual time=162.897..163.327 rows=1.00 loops=1)
                                 Storage: Memory  Maximum Storage: 17kB
                                 ->  Gather Merge  (cost=1000.91..96674.94 rows=34 width=4) (actual time=162.890..163.320 rows=1.00 loops=1)
                                       Workers Planned: 4
                                       Workers Launched: 4
                                       ->  Nested Loop  (cost=0.85..95670.83 rows=8 width=4) (actual time=154.144..155.610 rows=0.20 loops=5)
                                             Join Filter: (k.id = mk.keyword_id)
                                             Rows Removed by Join Filter: 904786
                                             ->  Parallel Index Scan using movie_keyword1 on movie_keyword mk  (cost=0.43..78701.66 rows=1130982 width=8) (actual time=0.015..56.115 rows=904786.00 loops=5)
                                                   Index Searches: 1
                                             ->  Materialize  (cost=0.42..4.44 rows=1 width=4) (actual time=0.000..0.000 rows=1.00 loops=4523930)
                                                   Storage: Memory  Maximum Storage: 17kB
                                                   ->  Index Only Scan using keyword_keyword_id_idx on keyword k  (cost=0.42..4.44 rows=1 width=4) (actual time=0.068..0.068 rows=1.00 loops=5)
                                                         Index Cond: (keyword = '10,000-mile-club'::text)
                                                         Heap Fetches: 0
                                                         Index Searches: 5
                     ->  Index Scan using link_type_pkey on link_type lt  (cost=0.14..0.16 rows=1 width=16) (never executed)
                           Index Cond: (id = ml.link_type_id)
                           Index Searches: 0
               ->  Index Scan using title_pkey on title t1  (cost=0.43..0.49 rows=1 width=21) (never executed)
                     Index Cond: (id = mk.movie_id)
                     Index Searches: 0
         ->  Index Scan using title_pkey on title t2  (cost=0.43..4.20 rows=1 width=21) (never executed)
               Index Cond: (id = ml.linked_movie_id)
               Index Searches: 0
 Planning Time: 3.672 ms
 Execution Time: 165.588 ms

 Aggregate  (cost=6079.63..6079.64 rows=1 width=96) (actual time=33.080..33.937 rows=1.00 loops=1)
   ->  Gather  (cost=1006.16..6079.61 rows=3 width=46) (actual time=33.076..33.933 rows=0.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         ->  Nested Loop  (cost=6.16..5079.31 rows=1 width=46) (actual time=25.297..25.298 rows=0.00 loops=5)
               ->  Nested Loop  (cost=5.73..5075.11 rows=1 width=33) (actual time=25.297..25.298 rows=0.00 loops=5)
                     ->  Nested Loop  (cost=5.30..5074.63 rows=1 width=24) (actual time=25.297..25.298 rows=0.00 loops=5)
                           ->  Parallel Hash Join  (cost=5.17..5074.47 rows=1 width=16) (actual time=25.297..25.297 rows=0.00 loops=5)
                                 Hash Cond: (mk.keyword_id = k.id)
                                 ->  Merge Join  (cost=0.72..4770.94 rows=113933 width=20) (actual time=1.016..23.154 rows=57638.40 loops=5)
                                       Merge Cond: (ml.movie_id = mk.movie_id)
                                       ->  Parallel Index Scan using movie_link_movie_id_linked_movie_id_idx on movie_link ml  (cost=0.29..943.98 rows=7499 width=12) (actual time=0.068..0.799 rows=5999.40 loops=5)
                                             Index Searches: 1
                                       ->  Index Scan using movie_keyword1 on movie_keyword mk  (cost=0.43..112631.13 rows=4523930 width=8) (actual time=0.018..14.563 rows=134400.40 loops=5)
                                             Index Searches: 5
                                 ->  Parallel Hash  (cost=4.43..4.43 rows=1 width=4) (actual time=0.024..0.025 rows=0.20 loops=5)
                                       Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                       ->  Parallel Index Only Scan using keyword_keyword_id_idx on keyword k  (cost=0.42..4.43 rows=1 width=4) (actual time=0.069..0.070 rows=1.00 loops=1)
                                             Index Cond: (keyword = '10,000-mile-club'::text)
                                             Heap Fetches: 0
                                             Index Searches: 1
                           ->  Index Scan using link_type_pkey on link_type lt  (cost=0.14..0.16 rows=1 width=16) (never executed)
                                 Index Cond: (id = ml.link_type_id)
                                 Index Searches: 0
                     ->  Index Scan using title_pkey on title t1  (cost=0.43..0.49 rows=1 width=21) (never executed)
                           Index Cond: (id = mk.movie_id)
                           Index Searches: 0
               ->  Index Scan using title_pkey on title t2  (cost=0.43..4.20 rows=1 width=21) (never executed)
                     Index Cond: (id = ml.linked_movie_id)
                     Index Searches: 0
 Planning Time: 2.647 ms
 Execution Time: 34.017 ms

*/

-- Exclude 'never executed'


->  Merge Join  (cost=1001.20..5058.84 rows=3 width=16) (actual time=165.017..165.447 rows=0.00 loops=1)
      Merge Cond: (ml.movie_id = mk.movie_id)
      ->  Index Scan using movie_link_movie_id_linked_movie_id_idx on movie_link ml  (cost=0.29..1168.96 rows=29997 width=12) (actual time=0.018..1.417 rows=29997.00 loops=1)
            Index Searches: 1
      ->  Materialize  (cost=1000.91..96675.02 rows=34 width=4) (actual time=162.897..163.327 rows=1.00 loops=1)
            Storage: Memory  Maximum Storage: 17kB
            ->  Gather Merge  (cost=1000.91..96674.94 rows=34 width=4) (actual time=162.890..163.320 rows=1.00 loops=1)
                  Workers Planned: 4
                  Workers Launched: 4
                  ->  Nested Loop  (cost=0.85..95670.83 rows=8 width=4) (actual time=154.144..155.610 rows=0.20 loops=5)
   					  Join Filter: (k.id = mk.keyword_id)
   					  Rows Removed by Join Filter: 904786
   					  ->  Parallel Index Scan using movie_keyword1 on movie_keyword mk  (cost=0.43..78701.66 rows=1130982 width=8) (actual time=0.015..56.115 rows=904786.00 loops=5)
					  	  Index Searches: 1
					  ->  Materialize  (cost=0.42..4.44 rows=1 width=4) (actual time=0.000..0.000 rows=1.00 loops=4523930)
					  	  Storage: Memory  Maximum Storage: 17kB
						  ->  Index Only Scan using keyword_keyword_id_idx on keyword k  (cost=0.42..4.44 rows=1 width=4) (actual time=0.068..0.068 rows=1.00 loops=5)
						      Index Cond: (keyword = '10,000-mile-club'::text)
							  Heap Fetches: 0
							  Index Searches: 5


      ->  Parallel Hash Join  (cost=5.17..5074.47 rows=1 width=16) (actual time=25.297..25.297 rows=0.00 loops=5)
            Hash Cond: (mk.keyword_id = k.id)
            ->  Merge Join  (cost=0.72..4770.94 rows=113933 width=20) (actual time=1.016..23.154 rows=57638.40 loops=5)
                  Merge Cond: (ml.movie_id = mk.movie_id)
                  ->  Parallel Index Scan using movie_link_movie_id_linked_movie_id_idx on movie_link ml  (cost=0.29..943.98 rows=7499 width=12) (actual time=0.068..0.799 rows=5999.40 loops=5)
   					  Index Searches: 1
                  ->  Index Scan using movie_keyword1 on movie_keyword mk  (cost=0.43..112631.13 rows=4523930 width=8) (actual time=0.018..14.563 rows=134400.40 loops=5)
   					  Index Searches: 5
            ->  Parallel Hash  (cost=4.43..4.43 rows=1 width=4) (actual time=0.024..0.025 rows=0.20 loops=5)
                  Buckets: 1024  Batches: 1  Memory Usage: 40kB
                  ->  Parallel Index Only Scan using keyword_keyword_id_idx on keyword k  (cost=0.42..4.43 rows=1 width=4) (actual time=0.069..0.070 rows=1.00 loops=1)
                	  Index Cond: (keyword = '10,000-mile-club'::text)
					  Heap Fetches: 0
					  Index Searches: 1

SET max_parallel_workers_per_gather = 0;

 Aggregate  (cost=6569.54..6569.55 rows=1 width=96) (actual time=533.737..533.739 rows=1.00 loops=1)
   ->  Nested Loop  (cost=2.00..6569.52 rows=3 width=46) (actual time=533.734..533.735 rows=0.00 loops=1)
         ->  Nested Loop  (cost=1.57..6556.93 rows=3 width=33) (actual time=533.734..533.735 rows=0.00 loops=1)
               Join Filter: (lt.id = ml.link_type_id)
               ->  Seq Scan on link_type lt  (cost=0.00..1.18 rows=18 width=16) (actual time=0.017..0.019 rows=18.00 loops=1)
               ->  Materialize  (cost=1.57..6554.95 rows=3 width=25) (actual time=29.651..29.651 rows=0.00 loops=18)
                     Storage: Memory  Maximum Storage: 17kB
                     ->  Nested Loop  (cost=1.57..6554.93 rows=3 width=25) (actual time=533.711..533.712 rows=0.00 loops=1)
                           ->  Merge Join  (cost=1.14..6553.47 rows=3 width=16) (actual time=533.711..533.711 rows=0.00 loops=1)
                                 Merge Cond: (ml.movie_id = mk.movie_id)
                                 ->  Index Scan using movie_link_movie_id_linked_movie_id_idx on movie_link ml  (cost=0.29..1168.96 rows=29997 width=12) (actual time=0.013..1.174 rows=29997.00 loops=1)
                                       Index Searches: 1
                                 ->  Materialize  (cost=0.85..180494.61 rows=34 width=4) (actual time=531.969..531.969 rows=1.00 loops=1)
                                       Storage: Memory  Maximum Storage: 17kB
                                       ->  Nested Loop  (cost=0.85..180494.52 rows=34 width=4) (actual time=531.966..531.967 rows=1.00 loops=1)
                                             Join Filter: (k.id = mk.keyword_id)
                                             Rows Removed by Join Filter: 4307171
                                             ->  Index Scan using movie_keyword1 on movie_keyword mk  (cost=0.43..112631.13 rows=4523930 width=8) (actual time=0.010..162.019 rows=4307172.00 loops=1)
                                                   Index Searches: 1
                                             ->  Materialize  (cost=0.42..4.44 rows=1 width=4) (actual time=0.000..0.000 rows=1.00 loops=4307172)
                                                   Storage: Memory  Maximum Storage: 17kB
                                                   ->  Index Only Scan using keyword_keyword_id_idx on keyword k  (cost=0.42..4.44 rows=1 width=4) (actual time=0.035..0.036 rows=1.00 loops=1)
                                                         Index Cond: (keyword = '10,000-mile-club'::text)
                                                         Heap Fetches: 0
                                                         Index Searches: 1
                           ->  Index Scan using title_pkey on title t1  (cost=0.43..0.49 rows=1 width=21) (never executed)
                                 Index Cond: (id = mk.movie_id)
                                 Index Searches: 0
         ->  Index Scan using title_pkey on title t2  (cost=0.43..4.20 rows=1 width=21) (never executed)
               Index Cond: (id = ml.linked_movie_id)
               Index Searches: 0
 Planning Time: 2.139 ms
 Execution Time: 533.805 ms


 Aggregate  (cost=8770.46..8770.47 rows=1 width=96) (actual time=609.875..609.876 rows=1.00 loops=1)
   ->  Nested Loop  (cost=2.01..8770.44 rows=3 width=46) (actual time=609.871..609.872 rows=0.00 loops=1)
         ->  Nested Loop  (cost=1.58..8757.85 rows=3 width=33) (actual time=609.871..609.871 rows=0.00 loops=1)
               ->  Nested Loop  (cost=1.15..8756.39 rows=3 width=24) (actual time=609.871..609.871 rows=0.00 loops=1)
                     Join Filter: (lt.id = ml.link_type_id)
                     ->  Merge Join  (cost=1.15..8752.17 rows=3 width=16) (actual time=609.870..609.871 rows=0.00 loops=1)
                           Merge Cond: (mk.movie_id = ml.movie_id)
                           ->  Nested Loop  (cost=0.86..255250.09 rows=34 width=4) (actual time=608.065..608.065 rows=1.00 loops=1)
                                 ->  Index Scan using movie_keyword1 on movie_keyword mk  (cost=0.43..112631.13 rows=4523930 width=8) (actual time=0.018..160.250 rows=4307172.00 loops=1)
                                       Index Searches: 1
                                 ->  Memoize  (cost=0.43..0.45 rows=1 width=4) (actual time=0.000..0.000 rows=0.00 loops=4307172)
                                       Cache Key: mk.keyword_id
                                       Cache Mode: logical
                                       Estimates: capacity=67002 distinct keys=67002 lookups=4523930 hit percent=98.52%
                                       Hits: 4175318  Misses: 131854  Evictions: 0  Overflows: 0  Memory Usage: 8756kB
                                       ->  Index Only Scan using keyword_id_keyword_idx on keyword k  (cost=0.42..0.44 rows=1 width=4) (actual time=0.001..0.001 rows=0.00 loops=131854)
                                             Index Cond: ((id = mk.keyword_id) AND (keyword = '10,000-mile-club'::text))
                                             Heap Fetches: 0
                                             Index Searches: 131854
                           ->  Index Scan using movie_link_movie_id_linked_movie_id_idx on movie_link ml  (cost=0.29..1168.96 rows=29997 width=12) (actual time=0.006..1.225 rows=29997.00 loops=1)
                                 Index Searches: 1
                     ->  Seq Scan on link_type lt  (cost=0.00..1.18 rows=18 width=16) (never executed)
               ->  Index Scan using title_pkey on title t1  (cost=0.43..0.49 rows=1 width=21) (never executed)
                     Index Cond: (id = mk.movie_id)
                     Index Searches: 0
         ->  Index Scan using title_pkey on title t2  (cost=0.43..4.20 rows=1 width=21) (never executed)
               Index Cond: (id = ml.linked_movie_id)
               Index Searches: 0
 Planning Time: 2.818 ms
 Execution Time: 609.957 ms

I guess the answer is exactly there:

->  Merge Join  (cost=1001.20..5058.84 rows=3 width=16) (actual time=165.017..165.447 rows=0.00 loops=1)
      Merge Cond: (ml.movie_id = mk.movie_id)
      ->  Index Scan using movie_link_movie_id_linked_movie_id_idx on movie_link ml  (cost=0.29..1168.96 rows=29997 width=12) (actual time=0.018..1.417 rows=29997.00 loops=1)
            Index Searches: 1
      ->  Materialize  (cost=1000.91..96675.02

MergeJoin multuple times cheaper than underlying Materialize: 5000/100k. That means some hypothesis is hidden inside.
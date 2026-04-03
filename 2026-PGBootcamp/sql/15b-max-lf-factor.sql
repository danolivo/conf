EXPLAIN (COSTS OFF, ANALYZE, BUFFERS OFF, TIMING OFF)
SELECT MIN(mi.info) AS release_date,
       MIN(t.title) AS youtube_movie
FROM aka_title AS at,
     company_name AS cn,
     company_type AS ct,
     info_type AS it1,
     keyword AS k,
     movie_companies AS mc,
     movie_info AS mi,
     movie_keyword AS mk,
     title AS t
WHERE cn.country_code = '[us]'
  AND cn.name = 'YouTube'
  AND it1.info = 'release dates'
  AND mc.note LIKE '%(200%)%'
  AND mc.note LIKE '%(worldwide)%'
  AND mi.note LIKE '%internet%'
  AND mi.info LIKE 'USA:% 200%'
  AND t.production_year BETWEEN 2005 AND 2010
  AND t.id = at.movie_id
  AND t.id = mi.movie_id
  AND t.id = mk.movie_id
  AND t.id = mc.movie_id
  AND mk.movie_id = mi.movie_id
  AND mk.movie_id = mc.movie_id
  AND mk.movie_id = at.movie_id
  AND mi.movie_id = mc.movie_id
  AND mi.movie_id = at.movie_id
  AND mc.movie_id = at.movie_id
  AND k.id = mk.keyword_id
  AND it1.id = mi.info_type_id
  AND cn.id = mc.company_id
  AND ct.id = mc.company_type_id;

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               ->  Nested Loop (actual rows=7.40 loops=5)
                     ->  Parallel Hash Join (actual rows=7.40 loops=5)
                           Hash Cond: (mk.movie_id = t.id)
                           ->  Parallel Seq Scan on movie_keyword mk (actual rows=904786.00 loops=5)
                           ->  Parallel Hash (actual rows=0.60 loops=5)
                                 Buckets: 1024  Batches: 1  Memory Usage: 72kB
                                 ->  Nested Loop (actual rows=0.60 loops=5)
                                       ->  Nested Loop (actual rows=0.60 loops=5)
                                             ->  Nested Loop (actual rows=0.60 loops=5)
                                                   ->  Parallel Hash Join (actual rows=15.20 loops=5)
                                                         Hash Cond: (mc.movie_id = at.movie_id)
                                                         ->  Parallel Seq Scan on movie_companies mc (actual rows=12332.80 loops=5)
                                                               Filter: ((note ~~ '%(200%)%'::text) AND (note ~~ '%(worldwide)%'::text))
                                                               Rows Removed by Filter: 509493
                                                         ->  Parallel Hash (actual rows=23.20 loops=5)
                                                               Buckets: 1024  Batches: 1  Memory Usage: 168kB
                                                               ->  Parallel Hash Join (actual rows=23.20 loops=5)
                                                                     Hash Cond: (at.movie_id = mi.movie_id)
                                                                     ->  Parallel Seq Scan on aka_title at (actual rows=72294.40 loops=5)
                                                                     ->  Parallel Hash (actual rows=354.20 loops=5)
                                                                           Buckets: 1024  Batches: 1  Memory Usage: 168kB
                                                                           ->  Parallel Hash Join (actual rows=354.20 loops=5)
                                                                                 Hash Cond: (mi.info_type_id = it1.id)
                                                                                 ->  Parallel Seq Scan on movie_info mi (actual rows=354.20 loops=5)
                                                                                       Filter: ((note ~~ '%internet%'::text) AND (info ~~ 'USA:% 200%'::text))
                                                                                       Rows Removed by Filter: 2966790
                                                                                 ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                       Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                       ->  Parallel Seq Scan on info_type it1 (actual rows=1.00 loops=1)
                                                                                             Filter: ((info)::text = 'release dates'::text)
                                                                                             Rows Removed by Filter: 112
                                                   ->  Index Scan using company_name_pkey on company_name cn (actual rows=0.04 loops=76)
                                                         Index Cond: (id = mc.company_id)
                                                         Filter: (((country_code)::text = '[us]'::text) AND (name = 'YouTube'::text))
                                                         Rows Removed by Filter: 1
                                                         Index Searches: 76
                                             ->  Index Only Scan using company_type_pkey on company_type ct (actual rows=1.00 loops=3)
                                                   Index Cond: (id = mc.company_type_id)
                                                   Heap Fetches: 0
                                                   Index Searches: 3
                                       ->  Index Scan using title_pkey on title t (actual rows=1.00 loops=3)
                                             Index Cond: (id = at.movie_id)
                                             Filter: ((production_year >= 2005) AND (production_year <= 2010))
                                             Index Searches: 3
                     ->  Index Only Scan using keyword_pkey on keyword k (actual rows=1.00 loops=37)
                           Index Cond: (id = mk.keyword_id)
                           Heap Fetches: 0
                           Index Searches: 37
 Planning Time: 11.239 ms
 Execution Time: 943.383 ms
(55 rows)
*/

->  Parallel Hash Join (actual rows=354.20 loops=5)
    Hash Cond: (mi.info_type_id = it1.id)
    ->  Parallel Seq Scan on movie_info mi (actual rows=354.20 loops=5)
        Filter: ((note ~~ '%internet%'::text) AND (info ~~ 'USA:% 200%'::text))
        Rows Removed by Filter: 2966790
    ->  Parallel Hash (actual rows=0.20 loops=5)
	...
EXPLAIN (ANALYZE, BUFFERS OFF, COSTS ON, TIMING OFF)
SELECT MIN(cn.name) AS producing_company,
       MIN(lt.link) AS link_type,
       MIN(t.title) AS complete_western_sequel
FROM complete_cast AS cc,
     comp_cast_type AS cct1,
     comp_cast_type AS cct2,
     company_name AS cn,
     company_type AS ct,
     keyword AS k,
     link_type AS lt,
     movie_companies AS mc,
     movie_info AS mi,
     movie_keyword AS mk,
     movie_link AS ml,
     title AS t
WHERE cct1.kind = 'cast'
  AND cct2.kind LIKE 'complete%'
  AND cn.country_code !='[pl]'
  AND (cn.name LIKE '%Film%'
       OR cn.name LIKE '%Warner%')
  AND ct.kind ='production companies'
  AND k.keyword ='sequel'
  AND lt.link LIKE '%follow%'
  AND mc.note IS NULL
  AND mi.info IN ('Sweden',
                  'Norway',
                  'Germany',
                  'Denmark',
                  'Swedish',
                  'Denish',
                  'Norwegian',
                  'German',
                  'English')
  AND t.production_year BETWEEN 1950 AND 2010
  AND lt.id = ml.link_type_id
  AND ml.movie_id = t.id
  AND t.id = mk.movie_id
  AND mk.keyword_id = k.id
  AND t.id = mc.movie_id
  AND mc.company_type_id = ct.id
  AND mc.company_id = cn.id
  AND mi.movie_id = t.id
  AND t.id = cc.movie_id
  AND cct1.id = cc.subject_id
  AND cct2.id = cc.status_id
  AND ml.movie_id = mk.movie_id
  AND ml.movie_id = mc.movie_id
  AND mk.movie_id = mc.movie_id
  AND ml.movie_id = mi.movie_id
  AND mk.movie_id = mi.movie_id
  AND mc.movie_id = mi.movie_id
  AND ml.movie_id = cc.movie_id
  AND mk.movie_id = cc.movie_id
  AND mc.movie_id = cc.movie_id
  AND mi.movie_id = cc.movie_id;

/*
 Aggregate (actual rows=1.00 loops=1)
   ->  Nested Loop (actual rows=743.00 loops=1)
         Join Filter: (t.id = ml.movie_id)
         ->  Nested Loop (actual rows=743.00 loops=1)
               ->  Nested Loop (actual rows=1808.00 loops=1)
                     ->  Nested Loop (actual rows=1913.00 loops=1)
                           Join Filter: (mc.movie_id = ml.movie_id)
                           ->  Nested Loop (actual rows=251.00 loops=1)
                                 ->  Merge Join (actual rows=270.00 loops=1)
                                       Merge Cond: (mk.movie_id = ml.movie_id)
                                       ->  Nested Loop (actual rows=28.00 loops=1)
                                             ->  Nested Loop (actual rows=28.00 loops=1)
                                                   Join Filter: (mk.movie_id = mi.movie_id)
                                                   Rows Removed by Join Filter: 15035457
                                                   ->  Nested Loop (actual rows=17.00 loops=1)
                                                         ->  Merge Join (actual rows=20.00 loops=1)
                                                               Merge Cond: (mk.movie_id = cc.movie_id)
                                                               ->  Sort (actual rows=53.00 loops=1)
                                                                     Sort Key: mk.movie_id
                                                                     Sort Method: quicksort  Memory: 385kB
                                                                     ->  Gather (actual rows=10544.00 loops=1)
                                                                           Workers Planned: 4
                                                                           Workers Launched: 4
                                                                           ->  Parallel Hash Join (actual rows=2108.80 loops=5)
                                                                                 Hash Cond: (mk.keyword_id = k.id)
                                                                                 ->  Parallel Seq Scan on movie_keyword mk (actual rows=904786.00 loops=5)
                                                                                 ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                       Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                       ->  Parallel Bitmap Heap Scan on keyword k (actual rows=0.20 loops=5)
                                                                                             Recheck Cond: (keyword = 'sequel'::text)
                                                                                             Rows Removed by Index Recheck: 6
                                                                                             Heap Blocks: exact=30
                                                                                             ->  Bitmap Index Scan on keyword_idx_1 (actual rows=30.00 loops=1)
                                                                                                   Index Cond: (keyword = 'sequel'::text)
                                                                                                   Index Searches: 1
                                                               ->  Sort (actual rows=9867.00 loops=1)
                                                                     Sort Key: cc.movie_id
                                                                     Sort Method: quicksort  Memory: 10366kB
                                                                     ->  Gather (actual rows=135086.00 loops=1)
                                                                           Workers Planned: 4
                                                                           Workers Launched: 4
                                                                           ->  Parallel Seq Scan on complete_cast cc (actual rows=27017.20 loops=5)
                                                         ->  Memoize (actual rows=0.85 loops=20)
                                                               Cache Key: cc.subject_id
                                                               Cache Mode: logical
                                                               Hits: 18  Misses: 2  Evictions: 0  Overflows: 0  Memory Usage: 1kB
                                                               ->  Index Scan using comp_cast_type_pkey on comp_cast_type cct1 (actual rows=0.50 loops=2)
                                                                     Index Cond: (id = cc.subject_id)
                                                                     Filter: ((kind)::text = 'cast'::text)
                                                                     Rows Removed by Filter: 0
                                                                     Index Searches: 2
                                                   ->  Materialize (actual rows=884440.29 loops=17)
                                                         Storage: Memory  Maximum Storage: 37449kB
                                                         ->  Gather (actual rows=936223.00 loops=1)
                                                               Workers Planned: 4
                                                               Workers Launched: 4
                                                               ->  Parallel Bitmap Heap Scan on movie_info mi (actual rows=187244.60 loops=5)
                                                                     Recheck Cond: (info = ANY ('{Sweden,Norway,Germany,Denmark,Swedish,Denish,Norwegian,German,English}'::text[]))
                                                                     Rows Removed by Index Recheck: 100352
                                                                     Heap Blocks: exact=26751
                                                                     Worker 0:  Heap Blocks: exact=28750
                                                                     Worker 1:  Heap Blocks: exact=28124
                                                                     Worker 2:  Heap Blocks: exact=28901
                                                                     Worker 3:  Heap Blocks: exact=28746
                                                                     ->  Bitmap Index Scan on idx_movie_info (actual rows=1444032.00 loops=1)
                                                                           Index Cond: (info = ANY ('{Sweden,Norway,Germany,Denmark,Swedish,Denish,Norwegian,German,English}'::text[]))
                                                                           Index Searches: 9
                                             ->  Memoize (actual rows=1.00 loops=28)
                                                   Cache Key: cc.status_id
                                                   Cache Mode: logical
                                                   Hits: 26  Misses: 2  Evictions: 0  Overflows: 0  Memory Usage: 1kB
                                                   ->  Index Scan using comp_cast_type_pkey on comp_cast_type cct2 (actual rows=1.00 loops=2)
                                                         Index Cond: (id = cc.status_id)
                                                         Filter: ((kind)::text ~~ 'complete%'::text)
                                                         Index Searches: 2
                                       ->  Sort (actual rows=30172.00 loops=1)
                                             Sort Key: ml.movie_id
                                             Sort Method: quicksort  Memory: 1472kB
                                             ->  Gather (actual rows=29997.00 loops=1)
                                                   Workers Planned: 4
                                                   Workers Launched: 3
                                                   ->  Parallel Seq Scan on movie_link ml (actual rows=7499.25 loops=4)
                                 ->  Index Scan using link_type_pkey on link_type lt (actual rows=0.93 loops=270)
                                       Index Cond: (id = ml.link_type_id)
                                       Filter: ((link)::text ~~ '%follow%'::text)
                                       Rows Removed by Filter: 0
                                       Index Searches: 270
                           ->  Index Scan using movie_companies_movie_id_idx on movie_companies mc (actual rows=7.62 loops=251)
                                 Index Cond: (movie_id = mk.movie_id)
                                 Filter: (note IS NULL)
                                 Rows Removed by Filter: 1
                                 Index Searches: 251
                     ->  Index Scan using company_type_pkey on company_type ct (actual rows=0.95 loops=1913)
                           Index Cond: (id = mc.company_type_id)
                           Filter: ((kind)::text = 'production companies'::text)
                           Rows Removed by Filter: 0
                           Index Searches: 1913
               ->  Index Scan using company_name_pkey on company_name cn (actual rows=0.41 loops=1808)
                     Index Cond: (id = mc.company_id)
                     Filter: (((country_code)::text <> '[pl]'::text) AND ((name ~~ '%Film%'::text) OR (name ~~ '%Warner%'::text)))
                     Rows Removed by Filter: 1
                     Index Searches: 1808
         ->  Index Scan using title_pkey on title t (actual rows=1.00 loops=743)
               Index Cond: (id = mk.movie_id)
               Filter: ((production_year >= 1950) AND (production_year <= 2010))
               Index Searches: 743
 Planning Time: 33.065 ms
 Execution Time: 2302.026 ms
(108 rows)
 */

/*
 Aggregate (actual rows=1.00 loops=1)
   ->  Nested Loop (actual rows=743.00 loops=1)
         Join Filter: (t.id = ml.movie_id)
         ->  Nested Loop (actual rows=743.00 loops=1)
               ->  Gather (actual rows=1808.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     ->  Nested Loop (actual rows=361.60 loops=5)
                           ->  Parallel Hash Join (actual rows=382.60 loops=5)
                                 Hash Cond: (mc.movie_id = ml.movie_id)
                                 ->  Parallel Seq Scan on movie_companies mc (actual rows=254397.80 loops=5)
                                       Filter: (note IS NULL)
                                       Rows Removed by Filter: 267428
                                 ->  Parallel Hash (actual rows=50.20 loops=5)
                                       Buckets: 1024  Batches: 1  Memory Usage: 104kB
                                       ->  Parallel Hash Join (actual rows=50.20 loops=5)
                                             Hash Cond: (mi.movie_id = ml.movie_id)
                                             ->  Parallel Bitmap Heap Scan on movie_info mi (actual rows=187244.60 loops=5)
                                                   Recheck Cond: (info = ANY ('{Sweden,Norway,Germany,Denmark,Swedish,Denish,Norwegian,German,English}'::text[]))
                                                   Rows Removed by Index Recheck: 100352
                                                   Heap Blocks: exact=28705
                                                   Worker 0:  Heap Blocks: exact=27947
                                                   Worker 1:  Heap Blocks: exact=28375
                                                   Worker 2:  Heap Blocks: exact=28088
                                                   Worker 3:  Heap Blocks: exact=28157
                                                   ->  Bitmap Index Scan on idx_movie_info (actual rows=1444032.00 loops=1)
                                                         Index Cond: (info = ANY ('{Sweden,Norway,Germany,Denmark,Swedish,Denish,Norwegian,German,English}'::text[]))
                                                         Index Searches: 9
                                             ->  Parallel Hash (actual rows=15.60 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 168kB
                                                   ->  Parallel Hash Join (actual rows=15.60 loops=5)
                                                         Hash Cond: (mk.keyword_id = k.id)
                                                         ->  Nested Loop (actual rows=646.20 loops=5)
                                                               Join Filter: (mk.movie_id = ml.movie_id)
                                                               ->  Parallel Hash Join (actual rows=45.60 loops=5)
                                                                     Hash Cond: (ml.link_type_id = lt.id)
                                                                     ->  Parallel Hash Join (actual rows=712.80 loops=5)
                                                                           Hash Cond: (ml.movie_id = cc.movie_id)
                                                                           ->  Parallel Seq Scan on movie_link ml (actual rows=5999.40 loops=5)
                                                                           ->  Parallel Hash (actual rows=17188.20 loops=5)
                                                                                 Buckets: 131072 (originally 16384)  Batches: 1 (originally 1)  Memory Usage: 5344kB
                                                                                 ->  Parallel Hash Join (actual rows=17188.20 loops=5)
                                                                                       Hash Cond: (cc.status_id = cct2.id)
                                                                                       ->  Parallel Hash Join (actual rows=17188.20 loops=5)
                                                                                             Hash Cond: (cc.subject_id = cct1.id)
                                                                                             ->  Parallel Seq Scan on complete_cast cc (actual rows=27017.20 loops=5)
                                                                                             ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                                   ->  Parallel Seq Scan on comp_cast_type cct1 (actual rows=1.00 loops=1)
                                                                                                         Filter: ((kind)::text = 'cast'::text)
                                                                                                         Rows Removed by Filter: 3
                                                                                       ->  Parallel Hash (actual rows=0.40 loops=5)
                                                                                             Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                             ->  Parallel Seq Scan on comp_cast_type cct2 (actual rows=2.00 loops=1)
                                                                                                   Filter: ((kind)::text ~~ 'complete%'::text)
                                                                                                   Rows Removed by Filter: 2
                                                                     ->  Parallel Hash (actual rows=0.40 loops=5)
                                                                           Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                           ->  Parallel Seq Scan on link_type lt (actual rows=2.00 loops=1)
                                                                                 Filter: ((link)::text ~~ '%follow%'::text)
                                                                                 Rows Removed by Filter: 16
                                                               ->  Index Scan using movie_keyword1 on movie_keyword mk (actual rows=14.17 loops=228)
                                                                     Index Cond: (movie_id = cc.movie_id)
                                                                     Index Searches: 228
                                                         ->  Parallel Hash (actual rows=0.20 loops=5)
                                                               Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                               ->  Parallel Bitmap Heap Scan on keyword k (actual rows=1.00 loops=1)
                                                                     Recheck Cond: (keyword = 'sequel'::text)
                                                                     Rows Removed by Index Recheck: 29
                                                                     Heap Blocks: exact=30
                                                                     ->  Bitmap Index Scan on keyword_idx_1 (actual rows=30.00 loops=1)
                                                                           Index Cond: (keyword = 'sequel'::text)
                                                                           Index Searches: 1
                           ->  Index Scan using company_type_pkey on company_type ct (actual rows=0.95 loops=1913)
                                 Index Cond: (id = mc.company_type_id)
                                 Filter: ((kind)::text = 'production companies'::text)
                                 Rows Removed by Filter: 0
                                 Index Searches: 1913
               ->  Index Scan using company_name_pkey on company_name cn (actual rows=0.41 loops=1808)
                     Index Cond: (id = mc.company_id)
                     Filter: (((country_code)::text <> '[pl]'::text) AND ((name ~~ '%Film%'::text) OR (name ~~ '%Warner%'::text)))
                     Rows Removed by Filter: 1
                     Index Searches: 1808
         ->  Index Scan using title_pkey on title t (actual rows=1.00 loops=743)
               Index Cond: (id = mk.movie_id)
               Filter: ((production_year >= 1950) AND (production_year <= 2010))
               Index Searches: 743
 Planning Time: 15.542 ms
 Execution Time: 425.860 ms
(89 rows)

*/

/*
 Aggregate  (cost=1679.26..1679.27 rows=1 width=96) (actual rows=1.00 loops=1)
   ->  Nested Loop  (cost=1334.66..1679.26 rows=1 width=48) (actual rows=743.00 loops=1)
         Join Filter: (ml.movie_id = t.id)
         ->  Nested Loop  (cost=1334.23..1678.75 rows=1 width=51) (actual rows=743.00 loops=1)
               ->  Gather  (cost=1333.81..1678.30 rows=1 width=36) (actual rows=1808.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     ->  Nested Loop  (cost=1333.80..1678.29 rows=1 width=36) (actual rows=361.60 loops=5)
                           ->  Nested Loop  (cost=1333.66..1678.12 rows=1 width=40) (actual rows=382.60 loops=5)
                                 Join Filter: (mc.movie_id = ml.movie_id)
                                 ->  Nested Loop  (cost=1333.23..1677.59 rows=1 width=28) (actual rows=50.20 loops=5)
                                       Join Filter: (mi.movie_id = ml.movie_id)
                                       ->  Parallel Hash Join  (cost=1331.44..1671.55 rows=1 width=24) (actual rows=15.60 loops=5)
                                             Hash Cond: (mk.keyword_id = k.id)
                                             ->  Nested Loop  (cost=1326.99..1665.61 rows=570 width=28) (actual rows=646.20 loops=5)
                                                   Join Filter: (mk.movie_id = ml.movie_id)
                                                   ->  Parallel Hash Join  (cost=1326.56..1596.56 rows=38 width=20) (actual rows=45.60 loops=5)
                                                         Hash Cond: (ml.link_type_id = lt.id)
                                                         ->  Parallel Hash Join  (cost=1325.41..1593.22 rows=676 width=12) (actual rows=712.80 loops=5)
                                                               Hash Cond: (ml.movie_id = cc.movie_id)
                                                               ->  Parallel Seq Scan on movie_link ml  (cost=0.00..237.99 rows=7499 width=8) (actual rows=5999.40 loops=5)
                                                               ->  Parallel Hash  (cost=1299.03..1299.03 rows=2111 width=4) (actual rows=17188.20 loops=5)
                                                                     Buckets: 131072 (originally 16384)  Batches: 1 (originally 1)  Memory Usage: 5376kB
                                                                     ->  Parallel Hash Join  (cost=2.08..1299.03 rows=2111 width=4) (actual rows=17188.20 loops=5)
                                                                           Hash Cond: (cc.status_id = cct2.id)
                                                                           ->  Parallel Hash Join  (cost=1.04..1252.34 rows=8443 width=8) (actual rows=17188.20 loops=5)
                                                                                 Hash Cond: (cc.subject_id = cct1.id)
                                                                                 ->  Parallel Seq Scan on complete_cast cc  (cost=0.00..1068.72 rows=33772 width=12) (actual rows=27017.20 loops=5)
                                                                                 ->  Parallel Hash  (cost=1.03..1.03 rows=1 width=4) (actual rows=0.20 loops=5)
                                                                                       Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                       ->  Parallel Seq Scan on comp_cast_type cct1  (cost=0.00..1.03 rows=1 width=4) (actual rows=1.00 loops=1)
                                                                                             Filter: ((kind)::text = 'cast'::text)
                                                                                             Rows Removed by Filter: 3
                                                                           ->  Parallel Hash  (cost=1.03..1.03 rows=1 width=4) (actual rows=0.40 loops=5)
                                                                                 Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                 ->  Parallel Seq Scan on comp_cast_type cct2  (cost=0.00..1.03 rows=1 width=4) (actual rows=2.00 loops=1)
                                                                                       Filter: ((kind)::text ~~ 'complete%'::text)
                                                                                       Rows Removed by Filter: 2
                                                         ->  Parallel Hash  (cost=1.13..1.13 rows=1 width=16) (actual rows=0.40 loops=5)
                                                               Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                               ->  Parallel Seq Scan on link_type lt  (cost=0.00..1.13 rows=1 width=16) (actual rows=2.00 loops=1)
                                                                     Filter: ((link)::text ~~ '%follow%'::text)
                                                                     Rows Removed by Filter: 16
                                                   ->  Index Scan using movie_keyword1 on movie_keyword mk  (cost=0.43..1.60 rows=17 width=8) (actual rows=14.17 loops=228)
                                                         Index Cond: (movie_id = cc.movie_id)
                                                         Index Searches: 228
                                             ->  Parallel Hash  (cost=4.43..4.43 rows=1 width=4) (actual rows=0.20 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                   ->  Parallel Index Only Scan using keyword_keyword_id_idx on keyword k  (cost=0.42..4.43 rows=1 width=4) (actual rows=1.00 loops=1)
                                                         Index Cond: (keyword = 'sequel'::text)
                                                         Heap Fetches: 0
                                                         Index Searches: 1
                                       ->  Bitmap Heap Scan on movie_info mi  (cost=1.80..6.02 rows=1 width=4) (actual rows=3.22 loops=78)
                                             Recheck Cond: (movie_id = mk.movie_id)
                                             Filter: (info = ANY ('{Sweden,Norway,Germany,Denmark,Swedish,Denish,Norwegian,German,English}'::text[]))
                                             Rows Removed by Filter: 16
                                             Heap Blocks: exact=19
                                             ->  Bitmap Index Scan on idx_movie_info2  (cost=0.00..1.77 rows=13 width=0) (actual rows=18.96 loops=78)
                                                   Index Cond: (movie_id = mk.movie_id)
                                                   Index Searches: 78
                                 ->  Index Scan using movie_companies_movie_id_idx on movie_companies mc  (cost=0.43..0.50 rows=2 width=12) (actual rows=7.62 loops=251)
                                       Index Cond: (movie_id = mk.movie_id)
                                       Filter: (note IS NULL)
                                       Rows Removed by Filter: 1
                                       Index Searches: 251
                           ->  Memoize  (cost=0.14..0.16 rows=1 width=4) (actual rows=0.95 loops=1913)
                                 Cache Key: mc.company_type_id
                                 Cache Mode: logical
                                 Estimates: capacity=1 distinct keys=1 lookups=1 hit percent=0.00%
                                 Hits: 5  Misses: 1  Evictions: 0  Overflows: 0  Memory Usage: 1kB
                                 Worker 0:  Hits: 12  Misses: 2  Evictions: 0  Overflows: 0  Memory Usage: 1kB
                                 Worker 1:  Hits: 3  Misses: 1  Evictions: 0  Overflows: 0  Memory Usage: 1kB
                                 Worker 2:  Hits: 1111  Misses: 2  Evictions: 0  Overflows: 0  Memory Usage: 1kB
                                 Worker 3:  Hits: 775  Misses: 1  Evictions: 0  Overflows: 0  Memory Usage: 1kB
                                 ->  Index Scan using company_type_pkey on company_type ct  (cost=0.13..0.15 rows=1 width=4) (actual rows=0.71 loops=7)
                                       Index Cond: (id = mc.company_type_id)
                                       Filter: ((kind)::text = 'production companies'::text)
                                       Rows Removed by Filter: 0
                                       Index Searches: 7
               ->  Index Scan using company_name_pkey on company_name cn  (cost=0.42..0.46 rows=1 width=23) (actual rows=0.41 loops=1808)
                     Index Cond: (id = mc.company_id)
                     Filter: (((country_code)::text <> '[pl]'::text) AND ((name ~~ '%Film%'::text) OR (name ~~ '%Warner%'::text)))
                     Rows Removed by Filter: 1
                     Index Searches: 1808
         ->  Index Scan using title_pkey on title t  (cost=0.43..0.49 rows=1 width=21) (actual rows=1.00 loops=743)
               Index Cond: (id = mk.movie_id)
               Filter: ((production_year >= 1950) AND (production_year <= 2010))
               Index Searches: 743
 Planning Time: 19.278 ms
 Execution Time: 11.845 ms
(90 rows)
*/
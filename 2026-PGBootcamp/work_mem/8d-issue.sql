EXPLAIN (ANALYZE, COSTS OFF, BUFFERS ON, TIMING OFF)
SELECT MIN(an1.name) AS costume_designer_pseudo,
       MIN(t.title) AS movie_with_costumes
FROM aka_name AS an1,
     cast_info AS ci,
     company_name AS cn,
     movie_companies AS mc,
     name AS n1,
     role_type AS rt,
     title AS t
WHERE cn.country_code ='[us]'
  AND rt.role ='costume designer'
  AND an1.person_id = n1.id
  AND n1.id = ci.person_id
  AND ci.movie_id = t.id
  AND t.id = mc.movie_id
  AND mc.company_id = cn.id
  AND ci.role_id = rt.id
  AND an1.person_id = ci.person_id
  AND ci.movie_id = mc.movie_id;

SET work_mem='1MB';
 
/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=151002 read=227434, temp read=45414 written=48744
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=151002 read=227434, temp read=45414 written=48744
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=151002 read=227434, temp read=45414 written=48744
               ->  Parallel Hash Join (actual rows=64601.00 loops=5)
                     Hash Cond: (an1.person_id = n1.id)
                     Buffers: shared hit=151002 read=227434, temp read=45414 written=48744
                     ->  Parallel Seq Scan on aka_name an1 (actual rows=180268.60 loops=5)
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=57107.60 loops=5)
                           Buckets: 32768  Batches: 128  Memory Usage: 608kB
                           Buffers: shared hit=139606 read=227434, temp read=38540 written=43608
                           ->  Parallel Hash Join (actual rows=57107.60 loops=5)
                                 Hash Cond: (ci.movie_id = t.id)
                                 Buffers: shared hit=139606 read=227434, temp read=38540 written=40848
                                 ->  Parallel Hash Join (actual rows=55280.60 loops=5)
                                       Hash Cond: (ci.person_id = n1.id)
                                       Buffers: shared hit=81687 read=227434, temp read=13718 written=15328
                                       ->  Parallel Hash Join (actual rows=55280.60 loops=5)
                                             Hash Cond: (ci.role_id = rt.id)
                                             Buffers: shared hit=25943 read=227434
                                             ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                   Buffers: shared hit=25942 read=227434
                                             ->  Parallel Hash (actual rows=0.20 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                   Buffers: shared hit=1
                                                   ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                         Filter: ((role)::text = 'costume designer'::text)
                                                         Rows Removed by Filter: 11
                                                         Buffers: shared hit=1
                                       ->  Parallel Hash (actual rows=833498.20 loops=5)
                                             Buckets: 65536  Batches: 128  Memory Usage: 1856kB
                                             Buffers: shared hit=55744, temp written=12700
                                             ->  Parallel Seq Scan on name n1 (actual rows=833498.20 loops=5)
                                                   Buffers: shared hit=55744
                                 ->  Parallel Hash (actual rows=230759.60 loops=5)
                                       Buckets: 32768  Batches: 64  Memory Usage: 1408kB
                                       Buffers: shared hit=57919, temp read=16725 written=24240
                                       ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                             Hash Cond: (t.id = mc.movie_id)
                                             Buffers: shared hit=57919, temp read=16725 written=17300
                                             ->  Parallel Seq Scan on title t (actual rows=505662.40 loops=5)
                                                   Buffers: shared hit=36100
                                             ->  Parallel Hash (actual rows=230759.60 loops=5)
                                                   Buckets: 65536  Batches: 32  Memory Usage: 1984kB
                                                   Buffers: shared hit=21819, temp written=3720
                                                   ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                                         Hash Cond: (mc.company_id = cn.id)
                                                         Buffers: shared hit=21819
                                                         ->  Parallel Seq Scan on movie_companies mc (actual rows=521825.80 loops=5)
                                                               Buffers: shared hit=18824
                                                         ->  Parallel Hash (actual rows=16968.60 loops=5)
                                                               Buckets: 131072  Batches: 1  Memory Usage: 4416kB
                                                               Buffers: shared hit=2995
                                                               ->  Parallel Seq Scan on company_name cn (actual rows=16968.60 loops=5)
                                                                     Filter: ((country_code)::text = '[us]'::text)
                                                                     Rows Removed by Filter: 30031
                                                                     Buffers: shared hit=2995
 Planning:
   Buffers: shared hit=40
 Planning Time: 7.451 ms
 Execution Time: 3947.828 ms
(66 rows)

*/

SET work_mem='4MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=200689 read=224553, temp read=30071 written=30988
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=200689 read=224553, temp read=30071 written=30988
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=200689 read=224553, temp read=30071 written=30988
               ->  Parallel Hash Join (actual rows=64601.00 loops=5)
                     Hash Cond: (an1.person_id = n1.id)
                     Buffers: shared hit=200689 read=224553, temp read=30071 written=30988
                     ->  Parallel Seq Scan on aka_name an1 (actual rows=180268.60 loops=5)
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=57107.60 loops=5)
                           Buckets: 131072  Batches: 32  Memory Usage: 1856kB
                           Buffers: shared hit=189293 read=224553, temp read=23740 written=25892
                           ->  Nested Loop (actual rows=57107.60 loops=5)
                                 Buffers: shared hit=189293 read=224553, temp read=23740 written=24064
                                 ->  Parallel Hash Join (actual rows=57107.60 loops=5)
                                       Hash Cond: (ci.movie_id = t.id)
                                       Buffers: shared hit=86743 read=224553, temp read=23740 written=24064
                                       ->  Parallel Hash Join (actual rows=55280.60 loops=5)
                                             Hash Cond: (ci.role_id = rt.id)
                                             Buffers: shared hit=28824 read=224553
                                             ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                   Buffers: shared hit=28823 read=224553
                                             ->  Parallel Hash (actual rows=0.20 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                   Buffers: shared hit=1
                                                   ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                         Filter: ((role)::text = 'costume designer'::text)
                                                         Rows Removed by Filter: 11
                                                         Buffers: shared hit=1
                                       ->  Parallel Hash (actual rows=230759.60 loops=5)
                                             Buckets: 131072  Batches: 16  Memory Usage: 5504kB
                                             Buffers: shared hit=57919, temp read=16288 written=22932
                                             ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                                   Hash Cond: (t.id = mc.movie_id)
                                                   Buffers: shared hit=57919, temp read=16288 written=16420
                                                   ->  Parallel Seq Scan on title t (actual rows=505662.40 loops=5)
                                                         Buffers: shared hit=36100
                                                   ->  Parallel Hash (actual rows=230759.60 loops=5)
                                                         Buckets: 262144  Batches: 8  Memory Usage: 7744kB
                                                         Buffers: shared hit=21819, temp written=3048
                                                         ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                                               Hash Cond: (mc.company_id = cn.id)
                                                               Buffers: shared hit=21819
                                                               ->  Parallel Seq Scan on movie_companies mc (actual rows=521825.80 loops=5)
                                                                     Buffers: shared hit=18824
                                                               ->  Parallel Hash (actual rows=16968.60 loops=5)
                                                                     Buckets: 131072  Batches: 1  Memory Usage: 4448kB
                                                                     Buffers: shared hit=2995
                                                                     ->  Parallel Seq Scan on company_name cn (actual rows=16968.60 loops=5)
                                                                           Filter: ((country_code)::text = '[us]'::text)
                                                                           Rows Removed by Filter: 30031
                                                                           Buffers: shared hit=2995
                                 ->  Memoize (actual rows=1.00 loops=285538)
                                       Cache Key: ci.person_id
                                       Cache Mode: logical
                                       Hits: 54272  Misses: 6349  Evictions: 0  Overflows: 0  Memory Usage: 645kB
                                       Buffers: shared hit=102550
                                       Worker 0:  Hits: 49633  Misses: 6098  Evictions: 0  Overflows: 0  Memory Usage: 620kB
                                       Worker 1:  Hits: 50164  Misses: 6225  Evictions: 0  Overflows: 0  Memory Usage: 633kB
                                       Worker 2:  Hits: 49871  Misses: 6077  Evictions: 0  Overflows: 0  Memory Usage: 618kB
                                       Worker 3:  Hits: 50597  Misses: 6252  Evictions: 0  Overflows: 0  Memory Usage: 635kB
                                       ->  Index Only Scan using name_pkey on name n1 (actual rows=1.00 loops=31001)
                                             Index Cond: (id = ci.person_id)
                                             Heap Fetches: 0
                                             Index Searches: 31001
                                             Buffers: shared hit=102550
 Planning:
   Buffers: shared hit=40
 Planning Time: 8.632 ms
 Execution Time: 3326.353 ms
 (74 rows)
*/

SET work_mem='64MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=159615 read=221673
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=159615 read=221673
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=159615 read=221673
               ->  Parallel Hash Join (actual rows=64601.00 loops=5)
                     Hash Cond: (an1.person_id = n1.id)
                     Buffers: shared hit=159615 read=221673
                     ->  Parallel Seq Scan on aka_name an1 (actual rows=180268.60 loops=5)
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=57107.60 loops=5)
                           Buckets: 4194304  Batches: 1  Memory Usage: 49792kB
                           Buffers: shared hit=148219 read=221673
                           ->  Nested Loop (actual rows=57107.60 loops=5)
                                 Buffers: shared hit=148219 read=221673
                                 ->  Parallel Hash Join (actual rows=57107.60 loops=5)
                                       Hash Cond: (ci.movie_id = t.id)
                                       Buffers: shared hit=89623 read=221673
                                       ->  Parallel Hash Join (actual rows=55280.60 loops=5)
                                             Hash Cond: (ci.role_id = rt.id)
                                             Buffers: shared hit=31704 read=221673
                                             ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                   Buffers: shared hit=31703 read=221673
                                             ->  Parallel Hash (actual rows=0.20 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                   Buffers: shared hit=1
                                                   ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                         Filter: ((role)::text = 'costume designer'::text)
                                                         Rows Removed by Filter: 11
                                                         Buffers: shared hit=1
                                       ->  Parallel Hash (actual rows=230759.60 loops=5)
                                             Buckets: 2097152 (originally 1048576)  Batches: 1 (originally 1)  Memory Usage: 95456kB
                                             Buffers: shared hit=57919
                                             ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                                   Hash Cond: (t.id = mc.movie_id)
                                                   Buffers: shared hit=57919
                                                   ->  Parallel Seq Scan on title t (actual rows=505662.40 loops=5)
                                                         Buffers: shared hit=36100
                                                   ->  Parallel Hash (actual rows=230759.60 loops=5)
                                                         Buckets: 2097152 (originally 1048576)  Batches: 1 (originally 1)  Memory Usage: 69760kB
                                                         Buffers: shared hit=21819
                                                         ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                                               Hash Cond: (mc.company_id = cn.id)
                                                               Buffers: shared hit=21819
                                                               ->  Parallel Seq Scan on movie_companies mc (actual rows=521825.80 loops=5)
                                                                     Buffers: shared hit=18824
                                                               ->  Parallel Hash (actual rows=16968.60 loops=5)
                                                                     Buckets: 131072  Batches: 1  Memory Usage: 4416kB
                                                                     Buffers: shared hit=2995
                                                                     ->  Parallel Seq Scan on company_name cn (actual rows=16968.60 loops=5)
                                                                           Filter: ((country_code)::text = '[us]'::text)
                                                                           Rows Removed by Filter: 30031
                                                                           Buffers: shared hit=2995
                                 ->  Memoize (actual rows=1.00 loops=285538)
                                       Cache Key: ci.person_id
                                       Cache Mode: logical
                                       Hits: 68208  Misses: 4026  Evictions: 0  Overflows: 0  Memory Usage: 409kB
                                       Buffers: shared hit=58596
                                       Worker 0:  Hits: 44689  Misses: 3547  Evictions: 0  Overflows: 0  Memory Usage: 361kB
                                       Worker 1:  Hits: 45522  Misses: 2923  Evictions: 0  Overflows: 0  Memory Usage: 297kB
                                       Worker 2:  Hits: 62640  Misses: 4338  Evictions: 0  Overflows: 0  Memory Usage: 441kB
                                       Worker 3:  Hits: 46690  Misses: 2955  Evictions: 0  Overflows: 0  Memory Usage: 301kB
                                       ->  Index Only Scan using name_pkey on name n1 (actual rows=1.00 loops=17789)
                                             Index Cond: (id = ci.person_id)
                                             Heap Fetches: 0
                                             Index Searches: 17789
                                             Buffers: shared hit=58596
 Planning:
   Buffers: shared hit=40
 Planning Time: 8.686 ms
 Execution Time: 3013.693 ms
(74 rows)

*/
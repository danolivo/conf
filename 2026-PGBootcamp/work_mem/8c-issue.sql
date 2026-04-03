
EXPLAIN (ANALYZE, COSTS OFF, BUFFERS ON, TIMING OFF)
SELECT MIN(a1.name) AS writer_pseudo_name,
       MIN(t.title) AS movie_title
FROM aka_name AS a1,
     cast_info AS ci,
     company_name AS cn,
     movie_companies AS mc,
     name AS n1,
     role_type AS rt,
     title AS t
WHERE cn.country_code ='[us]'
  AND rt.role ='writer'
  AND a1.person_id = n1.id
  AND n1.id = ci.person_id
  AND ci.movie_id = t.id
  AND t.id = mc.movie_id
  AND mc.company_id = cn.id
  AND ci.role_id = rt.id
  AND a1.person_id = ci.person_id
  AND ci.movie_id = mc.movie_id;

SET work_mem='4MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=1039651 read=243276, temp read=47830 written=48668
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=1039651 read=243276, temp read=47830 written=48668
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=1039651 read=243276, temp read=47830 written=48668
               ->  Parallel Hash Join (actual rows=497522.20 loops=5)
                     Hash Cond: (a1.person_id = n1.id)
                     Buffers: shared hit=1039651 read=243276, temp read=47830 written=48668
                     ->  Parallel Seq Scan on aka_name a1 (actual rows=180268.60 loops=5)
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=394131.60 loops=5)
                           Buckets: 131072  Batches: 32  Memory Usage: 5376kB
                           Buffers: shared hit=1028255 read=243276, temp read=32131 written=43664
                           ->  Nested Loop (actual rows=394131.60 loops=5)
                                 Buffers: shared hit=1028255 read=243276, temp read=32131 written=32460
                                 ->  Parallel Hash Join (actual rows=394131.60 loops=5)
                                       Hash Cond: (ci.movie_id = t.id)
                                       Buffers: shared hit=68020 read=243276, temp read=32131 written=32460
                                       ->  Parallel Hash Join (actual rows=545788.60 loops=5)
                                             Hash Cond: (ci.role_id = rt.id)
                                             Buffers: shared hit=10101 read=243276
                                             ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                   Buffers: shared hit=10100 read=243276
                                             ->  Parallel Hash (actual rows=0.20 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                   Buffers: shared hit=1
                                                   ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                         Filter: ((role)::text = 'writer'::text)
                                                         Rows Removed by Filter: 11
                                                         Buffers: shared hit=1
                                       ->  Parallel Hash (actual rows=230759.60 loops=5)
                                             Buckets: 131072  Batches: 16  Memory Usage: 5504kB
                                             Buffers: shared hit=57919, temp read=16291 written=22936
                                             ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                                   Hash Cond: (t.id = mc.movie_id)
                                                   Buffers: shared hit=57919, temp read=16291 written=16408
                                                   ->  Parallel Seq Scan on title t (actual rows=505662.40 loops=5)
                                                         Buffers: shared hit=36100
                                                   ->  Parallel Hash (actual rows=230759.60 loops=5)
                                                         Buckets: 262144  Batches: 8  Memory Usage: 7744kB
                                                         Buffers: shared hit=21819, temp written=3032
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
                                 ->  Memoize (actual rows=1.00 loops=1970658)
                                       Cache Key: ci.person_id
                                       Cache Mode: logical
                                       Hits: 369543  Misses: 58565  Evictions: 0  Overflows: 0  Memory Usage: 5949kB
                                       Buffers: shared hit=960235
                                       Worker 0:  Hits: 340955  Misses: 55467  Evictions: 0  Overflows: 0  Memory Usage: 5634kB
                                       Worker 1:  Hits: 342391  Misses: 55209  Evictions: 0  Overflows: 0  Memory Usage: 5608kB
                                       Worker 2:  Hits: 321421  Misses: 52842  Evictions: 0  Overflows: 0  Memory Usage: 5367kB
                                       Worker 3:  Hits: 321254  Misses: 53011  Evictions: 0  Overflows: 0  Memory Usage: 5384kB
                                       ->  Index Only Scan using name_pkey on name n1 (actual rows=1.00 loops=275094)
                                             Index Cond: (id = ci.person_id)
                                             Heap Fetches: 0
                                             Index Searches: 275094
                                             Buffers: shared hit=960235
 Planning:
   Buffers: shared hit=40
 Planning Time: 1.948 ms
 Execution Time: 1405.516 ms
(74 rows)
*/

SET work_mem='64MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=622620 read=240395
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=622620 read=240395
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=622620 read=240395
               ->  Parallel Hash Join (actual rows=497522.20 loops=5)
                     Hash Cond: (a1.person_id = n1.id)
                     Buffers: shared hit=622620 read=240395
                     ->  Parallel Seq Scan on aka_name a1 (actual rows=180268.60 loops=5)
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=394131.60 loops=5)
                           Buckets: 4194304  Batches: 1  Memory Usage: 152544kB
                           Buffers: shared hit=611224 read=240395
                           ->  Nested Loop (actual rows=394131.60 loops=5)
                                 Buffers: shared hit=611224 read=240395
                                 ->  Parallel Hash Join (actual rows=394131.60 loops=5)
                                       Hash Cond: (ci.movie_id = t.id)
                                       Buffers: shared hit=70901 read=240395
                                       ->  Parallel Hash Join (actual rows=545788.60 loops=5)
                                             Hash Cond: (ci.role_id = rt.id)
                                             Buffers: shared hit=12982 read=240395
                                             ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                   Buffers: shared hit=12981 read=240395
                                             ->  Parallel Hash (actual rows=0.20 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                   Buffers: shared hit=1
                                                   ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                         Filter: ((role)::text = 'writer'::text)
                                                         Rows Removed by Filter: 11
                                                         Buffers: shared hit=1
                                       ->  Parallel Hash (actual rows=230759.60 loops=5)
                                             Buckets: 2097152 (originally 1048576)  Batches: 1 (originally 1)  Memory Usage: 95488kB
                                             Buffers: shared hit=57919
                                             ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                                   Hash Cond: (t.id = mc.movie_id)
                                                   Buffers: shared hit=57919
                                                   ->  Parallel Seq Scan on title t (actual rows=505662.40 loops=5)
                                                         Buffers: shared hit=36100
                                                   ->  Parallel Hash (actual rows=230759.60 loops=5)
                                                         Buckets: 2097152 (originally 1048576)  Batches: 1 (originally 1)  Memory Usage: 69824kB
                                                         Buffers: shared hit=21819
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
                                 ->  Memoize (actual rows=1.00 loops=1970658)
                                       Cache Key: ci.person_id
                                       Cache Mode: logical
                                       Hits: 389012  Misses: 32750  Evictions: 0  Overflows: 0  Memory Usage: 3327kB
                                       Buffers: shared hit=540323
                                       Worker 0:  Hits: 347806  Misses: 30274  Evictions: 0  Overflows: 0  Memory Usage: 3075kB
                                       Worker 1:  Hits: 351705  Misses: 30726  Evictions: 0  Overflows: 0  Memory Usage: 3121kB
                                       Worker 2:  Hits: 367593  Misses: 30906  Evictions: 0  Overflows: 0  Memory Usage: 3139kB
                                       Worker 3:  Hits: 359191  Misses: 30695  Evictions: 0  Overflows: 0  Memory Usage: 3118kB
                                       ->  Index Only Scan using name_pkey on name n1 (actual rows=1.00 loops=155351)
                                             Index Cond: (id = ci.person_id)
                                             Heap Fetches: 0
                                             Index Searches: 155351
                                             Buffers: shared hit=540323
 Planning:
   Buffers: shared hit=40
 Planning Time: 2.753 ms
 Execution Time: 950.918 ms
(74 rows)
*/

SET work_mem='1MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=121681 read=256755, temp read=72927 written=77092
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=121681 read=256755, temp read=72927 written=77092
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=121681 read=256755, temp read=72927 written=77092
               ->  Parallel Hash Join (actual rows=497522.20 loops=5)
                     Hash Cond: (a1.person_id = n1.id)
                     Buffers: shared hit=121681 read=256755, temp read=72927 written=77092
                     ->  Parallel Seq Scan on aka_name a1 (actual rows=180268.60 loops=5)
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=394131.60 loops=5)
                           Buckets: 32768  Batches: 128  Memory Usage: 1600kB
                           Buffers: shared hit=110285 read=256755, temp read=56507 written=71836
                           ->  Parallel Hash Join (actual rows=394131.60 loops=5)
                                 Hash Cond: (ci.movie_id = t.id)
                                 Buffers: shared hit=110285 read=256755, temp read=56507 written=59456
                                 ->  Parallel Hash Join (actual rows=545788.60 loops=5)
                                       Hash Cond: (ci.person_id = n1.id)
                                       Buffers: shared hit=52366 read=256755, temp read=22139 written=23700
                                       ->  Parallel Hash Join (actual rows=545788.60 loops=5)
                                             Hash Cond: (ci.role_id = rt.id)
                                             Buffers: shared hit=14422 read=238955
                                             ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                   Buffers: shared hit=14421 read=238955
                                             ->  Parallel Hash (actual rows=0.20 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                   Buffers: shared hit=1
                                                   ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                         Filter: ((role)::text = 'writer'::text)
                                                         Rows Removed by Filter: 11
                                                         Buffers: shared hit=1
                                       ->  Parallel Hash (actual rows=833498.20 loops=5)
                                             Buckets: 65536  Batches: 128  Memory Usage: 1856kB
                                             Buffers: shared hit=37944 read=17800, temp written=13164
                                             ->  Parallel Seq Scan on name n1 (actual rows=833498.20 loops=5)
                                                   Buffers: shared hit=37944 read=17800
                                 ->  Parallel Hash (actual rows=230759.60 loops=5)
                                       Buckets: 32768  Batches: 64  Memory Usage: 1408kB
                                       Buffers: shared hit=57919, temp read=16721 written=24256
                                       ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                             Hash Cond: (t.id = mc.movie_id)
                                             Buffers: shared hit=57919, temp read=16721 written=17332
                                             ->  Parallel Seq Scan on title t (actual rows=505662.40 loops=5)
                                                   Buffers: shared hit=36100
                                             ->  Parallel Hash (actual rows=230759.60 loops=5)
                                                   Buckets: 65536  Batches: 32  Memory Usage: 1984kB
                                                   Buffers: shared hit=21819, temp written=3656
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
 Planning Time: 1.216 ms
 Execution Time: 1841.449 ms
(66 rows)
*/

                                 ->  Parallel Hash Join (actual rows=545788.60 loops=5)
                                       Hash Cond: (ci.person_id = n1.id)
                                       Buffers: shared hit=52366 read=256755, temp read=22139 written=23700
                                       ->  Parallel Hash Join (actual rows=545788.60 loops=5)
                                             Hash Cond: (ci.role_id = rt.id)
                                             Buffers: shared hit=14422 read=238955
                                             ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                   Buffers: shared hit=14421 read=238955
                                             ->  Parallel Hash (actual rows=0.20 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                   Buffers: shared hit=1
                                                   ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                         Filter: ((role)::text = 'writer'::text)
                                                         Rows Removed by Filter: 11
                                                         Buffers: shared hit=1
                                       ->  Parallel Hash (actual rows=833498.20 loops=5)
                                             Buckets: 65536  Batches: 128  Memory Usage: 1856kB
                                             Buffers: shared hit=37944 read=17800, temp written=13164
                                             ->  Parallel Seq Scan on name n1 (actual rows=833498.20 loops=5)
                                                   Buffers: shared hit=37944 read=17800



                           ->  Nested Loop (actual rows=394131.60 loops=5)
                                 Buffers: shared hit=611224 read=240395
                                 ->  Parallel Hash Join (actual rows=394131.60 loops=5)
                                       Hash Cond: (ci.movie_id = t.id)
                                       Buffers: shared hit=70901 read=240395
                                       ->  Parallel Hash Join (actual rows=545788.60 loops=5)
                                             Hash Cond: (ci.role_id = rt.id)
                                             Buffers: shared hit=12982 read=240395
                                             ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                   Buffers: shared hit=12981 read=240395
                                             ->  Parallel Hash (actual rows=0.20 loops=5)
                                                   Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                   Buffers: shared hit=1
                                                   ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                         Filter: ((role)::text = 'writer'::text)
                                                         Rows Removed by Filter: 11
                                                         Buffers: shared hit=1
                                       ->  Parallel Hash (actual rows=230759.60 loops=5)
                                             Buckets: 2097152 (originally 1048576)  Batches: 1 (originally 1)  Memory Usage: 95488kB
                                             Buffers: shared hit=57919
                                             ->  Parallel Hash Join (actual rows=230759.60 loops=5)
                                                   Hash Cond: (t.id = mc.movie_id)
                                                   Buffers: shared hit=57919
                                                   ->  Parallel Seq Scan on title t (actual rows=505662.40 loops=5)
                                                         Buffers: shared hit=36100
                                                   ->  Parallel Hash (actual rows=230759.60 loops=5)
                                                         Buckets: 2097152 (originally 1048576)  Batches: 1 (originally 1)  Memory Usage: 69824kB
                                                         Buffers: shared hit=21819
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
                                 ->  Memoize (actual rows=1.00 loops=1970658)
                                       Cache Key: ci.person_id
                                       Cache Mode: logical
                                       Hits: 389012  Misses: 32750  Evictions: 0  Overflows: 0  Memory Usage: 3327kB
                                       Buffers: shared hit=540323
                                       Worker 0:  Hits: 347806  Misses: 30274  Evictions: 0  Overflows: 0  Memory Usage: 3075kB
                                       Worker 1:  Hits: 351705  Misses: 30726  Evictions: 0  Overflows: 0  Memory Usage: 3121kB
                                       Worker 2:  Hits: 367593  Misses: 30906  Evictions: 0  Overflows: 0  Memory Usage: 3139kB
                                       Worker 3:  Hits: 359191  Misses: 30695  Evictions: 0  Overflows: 0  Memory Usage: 3118kB
                                       ->  Index Only Scan using name_pkey on name n1 (actual rows=1.00 loops=155351)
                                             Index Cond: (id = ci.person_id)
                                             Heap Fetches: 0
                                             Index Searches: 155351
                                             Buffers: shared hit=540323
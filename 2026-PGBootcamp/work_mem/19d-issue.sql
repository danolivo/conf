EXPLAIN (ANALYZE, COSTS OFF, BUFFERS ON, TIMING OFF)
SELECT MIN(n.name) AS voicing_actress,
       MIN(t.title) AS jap_engl_voiced_movie
FROM aka_name AS an,
     char_name AS chn,
     cast_info AS ci,
     company_name AS cn,
     info_type AS it,
     movie_companies AS mc,
     movie_info AS mi,
     name AS n,
     role_type AS rt,
     title AS t
WHERE ci.note IN ('(voice)',
                  '(voice: Japanese version)',
                  '(voice) (uncredited)',
                  '(voice: English version)')
  AND cn.country_code ='[us]'
  AND it.info = 'release dates'
  AND n.gender ='f'
  AND rt.role ='actress'
  AND t.production_year > 2000
  AND t.id = mi.movie_id
  AND t.id = mc.movie_id
  AND t.id = ci.movie_id
  AND mc.movie_id = ci.movie_id
  AND mc.movie_id = mi.movie_id
  AND mi.movie_id = ci.movie_id
  AND cn.id = mc.company_id
  AND it.id = mi.info_type_id
  AND n.id = ci.person_id
  AND rt.id = ci.role_id
  AND n.id = an.person_id
  AND ci.person_id = an.person_id
  AND chn.id = ci.person_role_id;

SET work_mem='1MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=18531999 read=400035, temp read=63093 written=68908
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=18531999 read=400035, temp read=63093 written=68908
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=18531999 read=400035, temp read=63093 written=68908
               ->  Parallel Hash Join (actual rows=352129.00 loops=5)
                     Hash Cond: (an.person_id = n.id)
                     Buffers: shared hit=18531999 read=400035, temp read=63093 written=68908
                     ->  Parallel Seq Scan on aka_name an (actual rows=180268.60 loops=5)
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=157408.60 loops=5)
                           Buckets: 16384 (originally 2048)  Batches: 256 (originally 1)  Memory Usage: 1920kB
                           Buffers: shared hit=18520603 read=400035, temp read=45659 written=56832
                           ->  Nested Loop (actual rows=157408.60 loops=5)
                                 Buffers: shared hit=18520603 read=400035, temp read=30570 written=31292
                                 ->  Parallel Hash Join (actual rows=645811.20 loops=5)
                                       Hash Cond: (mc.movie_id = t.id)
                                       Buffers: shared hit=5604375 read=400035, temp read=30570 written=31292
                                       ->  Parallel Seq Scan on movie_companies mc (actual rows=521825.80 loops=5)
                                             Buffers: shared hit=18824
                                       ->  Parallel Hash (actual rows=68367.20 loops=5)
                                             Buckets: 16384 (originally 1024)  Batches: 32 (originally 1)  Memory Usage: 1440kB
                                             Buffers: shared hit=5585551 read=400035, temp read=11720 written=15496
                                             ->  Nested Loop (actual rows=68367.20 loops=5)
                                                   Buffers: shared hit=5585551 read=400035, temp read=9979 written=10232
                                                   ->  Nested Loop (actual rows=99609.60 loops=5)
                                                         Buffers: shared hit=3593355 read=400035, temp read=9979 written=10232
                                                         ->  Nested Loop (actual rows=99687.20 loops=5)
                                                               Buffers: shared hit=1599607 read=400035, temp read=9979 written=10232
                                                               ->  Parallel Hash Join (actual rows=109423.40 loops=5)
                                                                     Hash Cond: (mi.movie_id = ci.movie_id)
                                                                     Buffers: shared hit=17319 read=400035, temp read=9979 written=10232
                                                                     ->  Parallel Hash Join (actual rows=607343.80 loops=5)
                                                                           Hash Cond: (mi.info_type_id = it.id)
                                                                           Buffers: shared hit=2898 read=161079
                                                                           ->  Parallel Seq Scan on movie_info mi (actual rows=2967144.00 loops=5)
                                                                                 Buffers: shared hit=2897 read=161079
                                                                           ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                 Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                 Buffers: shared hit=1
                                                                                 ->  Parallel Seq Scan on info_type it (actual rows=1.00 loops=1)
                                                                                       Filter: ((info)::text = 'release dates'::text)
                                                                                       Rows Removed by Filter: 112
                                                                                       Buffers: shared hit=1
                                                                     ->  Parallel Hash (actual rows=55233.20 loops=5)
                                                                           Buckets: 32768 (originally 131072)  Batches: 16 (originally 1)  Memory Usage: 1152kB
                                                                           Buffers: shared hit=14421 read=238956, temp written=1152
                                                                           ->  Parallel Hash Join (actual rows=55233.20 loops=5)
                                                                                 Hash Cond: (ci.role_id = rt.id)
                                                                                 Buffers: shared hit=14421 read=238956
                                                                                 ->  Parallel Seq Scan on cast_info ci (actual rows=173495.40 loops=5)
                                                                                       Filter: (note = ANY ('{(voice),"(voice: Japanese version)","(voice) (uncredited)","(voice: English version)"}'::text[]))
                                                                                       Rows Removed by Filter: 7075373
                                                                                       Buffers: shared hit=14420 read=238956
                                                                                 ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                       Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                       Buffers: shared hit=1
                                                                                       ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                                                             Filter: ((role)::text = 'actress'::text)
                                                                                             Rows Removed by Filter: 11
                                                                                             Buffers: shared hit=1
                                                               ->  Index Only Scan using char_name_pkey on char_name chn (actual rows=0.91 loops=547117)
                                                                     Index Cond: (id = ci.person_role_id)
                                                                     Heap Fetches: 0
                                                                     Index Searches: 498436
                                                                     Buffers: shared hit=1582288
                                                         ->  Index Scan using name_pkey on name n (actual rows=1.00 loops=498436)
                                                               Index Cond: (id = ci.person_id)
                                                               Filter: ((gender)::text = 'f'::text)
                                                               Rows Removed by Filter: 0
                                                               Index Searches: 498436
                                                               Buffers: shared hit=1993748
                                                   ->  Index Scan using title_pkey on title t (actual rows=0.69 loops=498048)
                                                         Index Cond: (id = mi.movie_id)
                                                         Filter: (production_year > 2000)
                                                         Rows Removed by Filter: 0
                                                         Index Searches: 498048
                                                         Buffers: shared hit=1992196
                                 ->  Index Scan using company_name_pkey on company_name cn (actual rows=0.24 loops=3229056)
                                       Index Cond: (id = mc.company_id)
                                       Filter: ((country_code)::text = '[us]'::text)
                                       Rows Removed by Filter: 1
                                       Index Searches: 3229056
                                       Buffers: shared hit=12916228
 Planning:
   Buffers: shared hit=60
 Planning Time: 16.416 ms
 Execution Time: 8656.003 ms
(91 rows)
*/

SET work_mem='4MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=18531548 read=391388, temp read=15917 written=16148
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=18531548 read=391388, temp read=15917 written=16148
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=18531548 read=391388, temp read=15917 written=16148
               ->  Parallel Hash Join (actual rows=352129.00 loops=5)
                     Hash Cond: (an.person_id = n.id)
                     Buffers: shared hit=18531548 read=391388, temp read=15917 written=16148
                     ->  Parallel Seq Scan on aka_name an (actual rows=180268.60 loops=5)
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=157408.60 loops=5)
                           Buckets: 65536 (originally 2048)  Batches: 16 (originally 1)  Memory Usage: 6304kB
                           Buffers: shared hit=18520152 read=391388, temp written=5936
                           ->  Nested Loop (actual rows=157408.60 loops=5)
                                 Buffers: shared hit=18520152 read=391388
                                 ->  Parallel Hash Join (actual rows=645811.20 loops=5)
                                       Hash Cond: (mc.movie_id = t.id)
                                       Buffers: shared hit=5603924 read=391388
                                       ->  Parallel Seq Scan on movie_companies mc (actual rows=521825.80 loops=5)
                                             Buffers: shared hit=18824
                                       ->  Parallel Hash (actual rows=68367.20 loops=5)
                                             Buckets: 524288 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 39960kB
                                             Buffers: shared hit=5585100 read=391388
                                             ->  Nested Loop (actual rows=68367.20 loops=5)
                                                   Buffers: shared hit=5585100 read=391388
                                                   ->  Nested Loop (actual rows=99609.60 loops=5)
                                                         Buffers: shared hit=3592904 read=391388
                                                         ->  Nested Loop (actual rows=99687.20 loops=5)
                                                               Buffers: shared hit=1599156 read=391388
                                                               ->  Parallel Hash Join (actual rows=109423.40 loops=5)
                                                                     Hash Cond: (mi.movie_id = ci.movie_id)
                                                                     Buffers: shared hit=25966 read=391388
                                                                     ->  Parallel Hash Join (actual rows=607343.80 loops=5)
                                                                           Hash Cond: (mi.info_type_id = it.id)
                                                                           Buffers: shared hit=7224 read=156753
                                                                           ->  Parallel Seq Scan on movie_info mi (actual rows=2967144.00 loops=5)
                                                                                 Buffers: shared hit=7223 read=156753
                                                                           ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                 Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                 Buffers: shared hit=1
                                                                                 ->  Parallel Seq Scan on info_type it (actual rows=1.00 loops=1)
                                                                                       Filter: ((info)::text = 'release dates'::text)
                                                                                       Rows Removed by Filter: 112
                                                                                       Buffers: shared hit=1
                                                                     ->  Parallel Hash (actual rows=55233.20 loops=5)
                                                                           Buckets: 524288 (originally 131072)  Batches: 1 (originally 1)  Memory Usage: 20064kB
                                                                           Buffers: shared hit=18742 read=234635
                                                                           ->  Parallel Hash Join (actual rows=55233.20 loops=5)
                                                                                 Hash Cond: (ci.role_id = rt.id)
                                                                                 Buffers: shared hit=18742 read=234635
                                                                                 ->  Parallel Seq Scan on cast_info ci (actual rows=173495.40 loops=5)
                                                                                       Filter: (note = ANY ('{(voice),"(voice: Japanese version)","(voice) (uncredited)","(voice: English version)"}'::text[]))
                                                                                       Rows Removed by Filter: 7075373
                                                                                       Buffers: shared hit=18741 read=234635
                                                                                 ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                       Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                       Buffers: shared hit=1
                                                                                       ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                                                             Filter: ((role)::text = 'actress'::text)
                                                                                             Rows Removed by Filter: 11
                                                                                             Buffers: shared hit=1
                                                               ->  Index Only Scan using char_name_pkey on char_name chn (actual rows=0.91 loops=547117)
                                                                     Index Cond: (id = ci.person_role_id)
                                                                     Heap Fetches: 0
                                                                     Index Searches: 498436
                                                                     Buffers: shared hit=1573190
                                                         ->  Index Scan using name_pkey on name n (actual rows=1.00 loops=498436)
                                                               Index Cond: (id = ci.person_id)
                                                               Filter: ((gender)::text = 'f'::text)
                                                               Rows Removed by Filter: 0
                                                               Index Searches: 498436
                                                               Buffers: shared hit=1993748
                                                   ->  Index Scan using title_pkey on title t (actual rows=0.69 loops=498048)
                                                         Index Cond: (id = mi.movie_id)
                                                         Filter: (production_year > 2000)
                                                         Rows Removed by Filter: 0
                                                         Index Searches: 498048
                                                         Buffers: shared hit=1992196
                                 ->  Index Scan using company_name_pkey on company_name cn (actual rows=0.24 loops=3229056)
                                       Index Cond: (id = mc.company_id)
                                       Filter: ((country_code)::text = '[us]'::text)
                                       Rows Removed by Filter: 1
                                       Index Searches: 3229056
                                       Buffers: shared hit=12916228
 Planning:
   Buffers: shared hit=60
 Planning Time: 16.272 ms
 Execution Time: 7804.410 ms
(91 rows)
*/

SET work_mem='64MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=18537096 read=385624
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=18537096 read=385624
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=18537096 read=385624
               ->  Parallel Hash Join (actual rows=352129.00 loops=5)
                     Hash Cond: (an.person_id = n.id)
                     Buffers: shared hit=18537096 read=385624
                     ->  Parallel Seq Scan on aka_name an (actual rows=180268.60 loops=5)
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=157408.60 loops=5)
                           Buckets: 1048576 (originally 2048)  Batches: 1 (originally 1)  Memory Usage: 77488kB
                           Buffers: shared hit=18525700 read=385624
                           ->  Nested Loop (actual rows=157408.60 loops=5)
                                 Buffers: shared hit=18525700 read=385624
                                 ->  Parallel Hash Join (actual rows=645811.20 loops=5)
                                       Hash Cond: (mc.movie_id = t.id)
                                       Buffers: shared hit=5609472 read=385624
                                       ->  Parallel Seq Scan on movie_companies mc (actual rows=521825.80 loops=5)
                                             Buffers: shared hit=18824
                                       ->  Parallel Hash (actual rows=68367.20 loops=5)
                                             Buckets: 524288 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 39928kB
                                             Buffers: shared hit=5590648 read=385624
                                             ->  Nested Loop (actual rows=68367.20 loops=5)
                                                   Buffers: shared hit=5590648 read=385624
                                                   ->  Nested Loop (actual rows=99609.60 loops=5)
                                                         Buffers: shared hit=3598452 read=385624
                                                         ->  Nested Loop (actual rows=99687.20 loops=5)
                                                               Buffers: shared hit=1604704 read=385624
                                                               ->  Parallel Hash Join (actual rows=109423.40 loops=5)
                                                                     Hash Cond: (mi.movie_id = ci.movie_id)
                                                                     Buffers: shared hit=31730 read=385624
                                                                     ->  Parallel Hash Join (actual rows=607343.80 loops=5)
                                                                           Hash Cond: (mi.info_type_id = it.id)
                                                                           Buffers: shared hit=10108 read=153869
                                                                           ->  Parallel Seq Scan on movie_info mi (actual rows=2967144.00 loops=5)
                                                                                 Buffers: shared hit=10107 read=153869
                                                                           ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                 Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                 Buffers: shared hit=1
                                                                                 ->  Parallel Seq Scan on info_type it (actual rows=1.00 loops=1)
                                                                                       Filter: ((info)::text = 'release dates'::text)
                                                                                       Rows Removed by Filter: 112
                                                                                       Buffers: shared hit=1
                                                                     ->  Parallel Hash (actual rows=55233.20 loops=5)
                                                                           Buckets: 524288 (originally 131072)  Batches: 1 (originally 1)  Memory Usage: 20032kB
                                                                           Buffers: shared hit=21622 read=231755
                                                                           ->  Parallel Hash Join (actual rows=55233.20 loops=5)
                                                                                 Hash Cond: (ci.role_id = rt.id)
                                                                                 Buffers: shared hit=21622 read=231755
                                                                                 ->  Parallel Seq Scan on cast_info ci (actual rows=173495.40 loops=5)
                                                                                       Filter: (note = ANY ('{(voice),"(voice: Japanese version)","(voice) (uncredited)","(voice: English version)"}'::text[]))
                                                                                       Rows Removed by Filter: 7075373
                                                                                       Buffers: shared hit=21621 read=231755
                                                                                 ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                       Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                       Buffers: shared hit=1
                                                                                       ->  Parallel Seq Scan on role_type rt (actual rows=1.00 loops=1)
                                                                                             Filter: ((role)::text = 'actress'::text)
                                                                                             Rows Removed by Filter: 11
                                                                                             Buffers: shared hit=1
                                                               ->  Index Only Scan using char_name_pkey on char_name chn (actual rows=0.91 loops=547117)
                                                                     Index Cond: (id = ci.person_role_id)
                                                                     Heap Fetches: 0
                                                                     Index Searches: 498436
                                                                     Buffers: shared hit=1572974
                                                         ->  Index Scan using name_pkey on name n (actual rows=1.00 loops=498436)
                                                               Index Cond: (id = ci.person_id)
                                                               Filter: ((gender)::text = 'f'::text)
                                                               Rows Removed by Filter: 0
                                                               Index Searches: 498436
                                                               Buffers: shared hit=1993748
                                                   ->  Index Scan using title_pkey on title t (actual rows=0.69 loops=498048)
                                                         Index Cond: (id = mi.movie_id)
                                                         Filter: (production_year > 2000)
                                                         Rows Removed by Filter: 0
                                                         Index Searches: 498048
                                                         Buffers: shared hit=1992196
                                 ->  Index Scan using company_name_pkey on company_name cn (actual rows=0.24 loops=3229056)
                                       Index Cond: (id = mc.company_id)
                                       Filter: ((country_code)::text = '[us]'::text)
                                       Rows Removed by Filter: 1
                                       Index Searches: 3229056
                                       Buffers: shared hit=12916228
 Planning:
   Buffers: shared hit=60
 Planning Time: 15.763 ms
 Execution Time: 7587.409 ms
(91 rows)
*/
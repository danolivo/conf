EXPLAIN (ANALYZE, COSTS OFF, BUFFERS ON, TIMING OFF)
SELECT MIN(n.name) AS cast_member_name,
       MIN(pi.info) AS cast_member_info
FROM aka_name AS an,
     cast_info AS ci,
     info_type AS it,
     link_type AS lt,
     movie_link AS ml,
     name AS n,
     person_info AS pi,
     title AS t
WHERE an.name IS NOT NULL
  AND (an.name LIKE '%a%'
       OR an.name LIKE 'A%')
  AND it.info ='mini biography'
  AND lt.link IN ('references',
                  'referenced in',
                  'features',
                  'featured in')
  AND n.name_pcode_cf BETWEEN 'A' AND 'F'
  AND (n.gender='m'
       OR (n.gender = 'f'
           AND n.name LIKE 'A%'))
  AND pi.note IS NOT NULL
  AND t.production_year BETWEEN 1980 AND 2010
  AND n.id = an.person_id
  AND n.id = pi.person_id
  AND ci.person_id = n.id
  AND t.id = ci.movie_id
  AND ml.linked_movie_id = t.id
  AND lt.id = ml.link_type_id
  AND it.id = pi.info_type_id
  AND pi.person_id = an.person_id
  AND pi.person_id = ci.person_id
  AND an.person_id = ci.person_id
  AND ci.movie_id = ml.linked_movie_id;

SET work_mem='1MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=4237567 read=250478, temp read=334722 written=343104
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=4237567 read=250478, temp read=334722 written=343104
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=4237567 read=250478, temp read=334722 written=343104
               ->  Parallel Hash Join (actual rows=13637.00 loops=5)
                     Hash Cond: (an.person_id = n.id)
                     Buffers: shared hit=4163696 read=250478, temp read=334722 written=343104
                     ->  Parallel Seq Scan on aka_name an (actual rows=137219.00 loops=5)
                           Filter: ((name ~~ '%a%'::text) OR (name ~~ 'A%'::text))
                           Rows Removed by Filter: 43050
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=8031.40 loops=5)
                           Buckets: 2048 (originally 1024)  Batches: 32 (originally 1)  Memory Usage: 1424kB
                           Buffers: shared hit=4152300 read=250478, temp read=322989 written=334976
                           ->  Nested Loop (actual rows=8031.40 loops=5)
                                 Buffers: shared hit=4152300 read=250478, temp read=319695 written=327448
                                 ->  Parallel Hash Join (actual rows=9094.20 loops=5)
                                       Hash Cond: (ml.linked_movie_id = t.id)
                                       Buffers: shared hit=4061354 read=250478, temp read=319695 written=327448
                                       ->  Parallel Seq Scan on movie_link ml (actual rows=5999.40 loops=5)
                                             Buffers: shared hit=163
                                       ->  Parallel Hash (actual rows=105873.00 loops=5)
                                             Buckets: 2048 (originally 1024)  Batches: 256 (originally 1)  Memory Usage: 2000kB
                                             Buffers: shared hit=4061191 read=250478, temp read=263458 written=322336
                                             ->  Nested Loop (actual rows=105873.00 loops=5)
                                                   Buffers: shared hit=4061191 read=250478, temp read=210226 written=210452
                                                   ->  Parallel Hash Join (actual rows=183458.20 loops=5)
                                                         Hash Cond: (ci.person_id = n.id)
                                                         Buffers: shared hit=392023 read=250478, temp read=210226 written=210452
                                                         ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                               Buffers: shared hit=2898 read=250478
                                                         ->  Parallel Hash (actual rows=2612.60 loops=5)
                                                               Buckets: 2048 (originally 1024)  Batches: 16 (originally 1)  Memory Usage: 816kB
                                                               Buffers: shared hit=389125, temp written=1416
                                                               ->  Nested Loop (actual rows=2612.60 loops=5)
                                                                     Buffers: shared hit=389125
                                                                     ->  Parallel Hash Join (actual rows=16836.60 loops=5)
                                                                           Hash Cond: (pi.info_type_id = it.id)
                                                                           Buffers: shared hit=52389
                                                                           ->  Parallel Seq Scan on person_info pi (actual rows=16836.60 loops=5)
                                                                                 Filter: (note IS NOT NULL)
                                                                                 Rows Removed by Filter: 575896
                                                                                 Buffers: shared hit=52388
                                                                           ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                 Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                 Buffers: shared hit=1
                                                                                 ->  Parallel Seq Scan on info_type it (actual rows=1.00 loops=1)
                                                                                       Filter: ((info)::text = 'mini biography'::text)
                                                                                       Rows Removed by Filter: 112
                                                                                       Buffers: shared hit=1
                                                                     ->  Index Scan using name_pkey on name n (actual rows=0.16 loops=84183)
                                                                           Index Cond: (id = pi.person_id)
                                                                           Filter: (((name_pcode_cf)::text >= 'A'::text) AND ((name_pcode_cf)::text <= 'F'::text) AND (((gender)::text = 'm'::text) OR (((gender)::text = 'f'::text) AND (name ~~ 'A%'::text))))
                                                                           Rows Removed by Filter: 1
                                                                           Index Searches: 84183
                                                                           Buffers: shared hit=336736
                                                   ->  Index Scan using title_pkey on title t (actual rows=0.58 loops=917291)
                                                         Index Cond: (id = ci.movie_id)
                                                         Filter: ((production_year >= 1980) AND (production_year <= 2010))
                                                         Rows Removed by Filter: 0
                                                         Index Searches: 917291
                                                         Buffers: shared hit=3669168
                                 ->  Index Scan using link_type_pkey on link_type lt (actual rows=0.88 loops=45471)
                                       Index Cond: (id = ml.link_type_id)
                                       Filter: ((link)::text = ANY ('{references,"referenced in",features,"featured in"}'::text[]))
                                       Rows Removed by Filter: 0
                                       Index Searches: 45471
                                       Buffers: shared hit=90946
 Planning:
   Buffers: shared hit=40
 Planning Time: 4.856 ms
 Execution Time: 6388.429 ms
(76 rows)

*/

SET work_mem='4MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=4241888 read=246157, temp read=98858 written=100648
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=4241888 read=246157, temp read=98858 written=100648
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=4241888 read=246157, temp read=98858 written=100648
               ->  Parallel Hash Join (actual rows=13637.00 loops=5)
                     Hash Cond: (an.person_id = n.id)
                     Buffers: shared hit=4168017 read=246157, temp read=98858 written=100648
                     ->  Parallel Seq Scan on aka_name an (actual rows=137219.00 loops=5)
                           Filter: ((name ~~ '%a%'::text) OR (name ~~ 'A%'::text))
                           Rows Removed by Filter: 43050
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=8031.40 loops=5)
                           Buckets: 65536 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 33240kB
                           Buffers: shared hit=4156621 read=246157, temp read=98858 written=100648
                           ->  Nested Loop (actual rows=8031.40 loops=5)
                                 Buffers: shared hit=4156621 read=246157, temp read=98858 written=100648
                                 ->  Parallel Hash Join (actual rows=9094.20 loops=5)
                                       Hash Cond: (ml.linked_movie_id = t.id)
                                       Buffers: shared hit=4065675 read=246157, temp read=98858 written=100648
                                       ->  Parallel Seq Scan on movie_link ml (actual rows=5999.40 loops=5)
                                             Buffers: shared hit=163
                                       ->  Parallel Hash (actual rows=105873.00 loops=5)
                                             Buckets: 8192 (originally 1024)  Batches: 64 (originally 1)  Memory Usage: 7424kB
                                             Buffers: shared hit=4065512 read=246157, temp read=44651 written=99368
                                             ->  Nested Loop (actual rows=105873.00 loops=5)
                                                   Buffers: shared hit=4065512 read=246157
                                                   ->  Parallel Hash Join (actual rows=183458.20 loops=5)
                                                         Hash Cond: (ci.person_id = n.id)
                                                         Buffers: shared hit=396344 read=246157
                                                         ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                               Buffers: shared hit=7219 read=246157
                                                         ->  Parallel Hash (actual rows=2612.60 loops=5)
                                                               Buckets: 16384 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 11448kB
                                                               Buffers: shared hit=389125
                                                               ->  Nested Loop (actual rows=2612.60 loops=5)
                                                                     Buffers: shared hit=389125
                                                                     ->  Parallel Hash Join (actual rows=16836.60 loops=5)
                                                                           Hash Cond: (pi.info_type_id = it.id)
                                                                           Buffers: shared hit=52389
                                                                           ->  Parallel Seq Scan on person_info pi (actual rows=16836.60 loops=5)
                                                                                 Filter: (note IS NOT NULL)
                                                                                 Rows Removed by Filter: 575896
                                                                                 Buffers: shared hit=52388
                                                                           ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                 Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                 Buffers: shared hit=1
                                                                                 ->  Parallel Seq Scan on info_type it (actual rows=1.00 loops=1)
                                                                                       Filter: ((info)::text = 'mini biography'::text)
                                                                                       Rows Removed by Filter: 112
                                                                                       Buffers: shared hit=1
                                                                     ->  Index Scan using name_pkey on name n (actual rows=0.16 loops=84183)
                                                                           Index Cond: (id = pi.person_id)
                                                                           Filter: (((name_pcode_cf)::text >= 'A'::text) AND ((name_pcode_cf)::text <= 'F'::text) AND (((gender)::text = 'm'::text) OR (((gender)::text = 'f'::text) AND (name ~~ 'A%'::text))))
                                                                           Rows Removed by Filter: 1
                                                                           Index Searches: 84183
                                                                           Buffers: shared hit=336736
                                                   ->  Index Scan using title_pkey on title t (actual rows=0.58 loops=917291)
                                                         Index Cond: (id = ci.movie_id)
                                                         Filter: ((production_year >= 1980) AND (production_year <= 2010))
                                                         Rows Removed by Filter: 0
                                                         Index Searches: 917291
                                                         Buffers: shared hit=3669168
                                 ->  Index Scan using link_type_pkey on link_type lt (actual rows=0.88 loops=45471)
                                       Index Cond: (id = ml.link_type_id)
                                       Filter: ((link)::text = ANY ('{references,"referenced in",features,"featured in"}'::text[]))
                                       Rows Removed by Filter: 0
                                       Index Searches: 45471
                                       Buffers: shared hit=90946
 Planning:
   Buffers: shared hit=40
 Planning Time: 4.429 ms
 Execution Time: 3675.070 ms
(76 rows)
*/

SET work_mem='64MB';

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=4241888 read=246157
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=4241888 read=246157
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=4241888 read=246157
               ->  Parallel Hash Join (actual rows=13637.00 loops=5)
                     Hash Cond: (an.person_id = n.id)
                     Buffers: shared hit=4168017 read=246157
                     ->  Parallel Seq Scan on aka_name an (actual rows=137219.00 loops=5)
                           Filter: ((name ~~ '%a%'::text) OR (name ~~ 'A%'::text))
                           Rows Removed by Filter: 43050
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=8031.40 loops=5)
                           Buckets: 65536 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 33240kB
                           Buffers: shared hit=4156621 read=246157
                           ->  Nested Loop (actual rows=8031.40 loops=5)
                                 Buffers: shared hit=4156621 read=246157
                                 ->  Parallel Hash Join (actual rows=9094.20 loops=5)
                                       Hash Cond: (ml.linked_movie_id = t.id)
                                       Buffers: shared hit=4065675 read=246157
                                       ->  Parallel Seq Scan on movie_link ml (actual rows=5999.40 loops=5)
                                             Buffers: shared hit=163
                                       ->  Parallel Hash (actual rows=105873.00 loops=5)
                                             Buckets: 1048576 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 460696kB
                                             Buffers: shared hit=4065512 read=246157
                                             ->  Nested Loop (actual rows=105873.00 loops=5)
                                                   Buffers: shared hit=4065512 read=246157
                                                   ->  Parallel Hash Join (actual rows=183458.20 loops=5)
                                                         Hash Cond: (ci.person_id = n.id)
                                                         Buffers: shared hit=396344 read=246157
                                                         ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                               Buffers: shared hit=7219 read=246157
                                                         ->  Parallel Hash (actual rows=2612.60 loops=5)
                                                               Buckets: 16384 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 11416kB
                                                               Buffers: shared hit=389125
                                                               ->  Nested Loop (actual rows=2612.60 loops=5)
                                                                     Buffers: shared hit=389125
                                                                     ->  Parallel Hash Join (actual rows=16836.60 loops=5)
                                                                           Hash Cond: (pi.info_type_id = it.id)
                                                                           Buffers: shared hit=52389
                                                                           ->  Parallel Seq Scan on person_info pi (actual rows=16836.60 loops=5)
                                                                                 Filter: (note IS NOT NULL)
                                                                                 Rows Removed by Filter: 575896
                                                                                 Buffers: shared hit=52388
                                                                           ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                 Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                 Buffers: shared hit=1
                                                                                 ->  Parallel Seq Scan on info_type it (actual rows=1.00 loops=1)
                                                                                       Filter: ((info)::text = 'mini biography'::text)
                                                                                       Rows Removed by Filter: 112
                                                                                       Buffers: shared hit=1
                                                                     ->  Index Scan using name_pkey on name n (actual rows=0.16 loops=84183)
                                                                           Index Cond: (id = pi.person_id)
                                                                           Filter: (((name_pcode_cf)::text >= 'A'::text) AND ((name_pcode_cf)::text <= 'F'::text) AND (((gender)::text = 'm'::text) OR (((gender)::text = 'f'::text) AND (name ~~ 'A%'::text))))
                                                                           Rows Removed by Filter: 1
                                                                           Index Searches: 84183
                                                                           Buffers: shared hit=336736
                                                   ->  Index Scan using title_pkey on title t (actual rows=0.58 loops=917291)
                                                         Index Cond: (id = ci.movie_id)
                                                         Filter: ((production_year >= 1980) AND (production_year <= 2010))
                                                         Rows Removed by Filter: 0
                                                         Index Searches: 917291
                                                         Buffers: shared hit=3669168
                                 ->  Index Scan using link_type_pkey on link_type lt (actual rows=0.88 loops=45471)
                                       Index Cond: (id = ml.link_type_id)
                                       Filter: ((link)::text = ANY ('{references,"referenced in",features,"featured in"}'::text[]))
                                       Rows Removed by Filter: 0
                                       Index Searches: 45471
                                       Buffers: shared hit=90946
 Planning:
   Buffers: shared hit=40
 Planning Time: 1.005 ms
 Execution Time: 959.755 ms
(76 rows)
*/

/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=4244769 read=243276
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=4244769 read=243276
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               Buffers: shared hit=4244769 read=243276
               ->  Parallel Hash Join (actual rows=13637.00 loops=5)
                     Hash Cond: (an.person_id = n.id)
                     Buffers: shared hit=4170898 read=243276
                     ->  Parallel Seq Scan on aka_name an (actual rows=137219.00 loops=5)
                           Filter: ((name ~~ '%a%'::text) OR (name ~~ 'A%'::text))
                           Rows Removed by Filter: 43050
                           Buffers: shared hit=11396
                     ->  Parallel Hash (actual rows=8031.40 loops=5)
                           Buckets: 65536 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 33272kB
                           Buffers: shared hit=4159502 read=243276
                           ->  Nested Loop (actual rows=8031.40 loops=5)
                                 Buffers: shared hit=4159502 read=243276
                                 ->  Parallel Hash Join (actual rows=9094.20 loops=5)
                                       Hash Cond: (ml.linked_movie_id = t.id)
                                       Buffers: shared hit=4068556 read=243276
                                       ->  Parallel Seq Scan on movie_link ml (actual rows=5999.40 loops=5)
                                             Buffers: shared hit=163
                                       ->  Parallel Hash (actual rows=105873.00 loops=5)
                                             Buckets: 1048576 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 460728kB
                                             Buffers: shared hit=4068393 read=243276
                                             ->  Nested Loop (actual rows=105873.00 loops=5)
                                                   Buffers: shared hit=4068393 read=243276
                                                   ->  Parallel Hash Join (actual rows=183458.20 loops=5)
                                                         Hash Cond: (ci.person_id = n.id)
                                                         Buffers: shared hit=399225 read=243276
                                                         ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                                               Buffers: shared hit=10100 read=243276
                                                         ->  Parallel Hash (actual rows=2612.60 loops=5)
                                                               Buckets: 16384 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 11448kB
                                                               Buffers: shared hit=389125
                                                               ->  Nested Loop (actual rows=2612.60 loops=5)
                                                                     Buffers: shared hit=389125
                                                                     ->  Parallel Hash Join (actual rows=16836.60 loops=5)
                                                                           Hash Cond: (pi.info_type_id = it.id)
                                                                           Buffers: shared hit=52389
                                                                           ->  Parallel Seq Scan on person_info pi (actual rows=16836.60 loops=5)
                                                                                 Filter: (note IS NOT NULL)
                                                                                 Rows Removed by Filter: 575896
                                                                                 Buffers: shared hit=52388
                                                                           ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                                 Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                                 Buffers: shared hit=1
                                                                                 ->  Parallel Seq Scan on info_type it (actual rows=1.00 loops=1)
                                                                                       Filter: ((info)::text = 'mini biography'::text)
                                                                                       Rows Removed by Filter: 112
                                                                                       Buffers: shared hit=1
                                                                     ->  Index Scan using name_pkey on name n (actual rows=0.16 loops=84183)
                                                                           Index Cond: (id = pi.person_id)
                                                                           Filter: (((name_pcode_cf)::text >= 'A'::text) AND ((name_pcode_cf)::text <= 'F'::text) AND (((gender)::text = 'm'::text) OR (((gender)::text = 'f'::text) AND (name ~~ 'A%'::text))))
                                                                           Rows Removed by Filter: 1
                                                                           Index Searches: 84183
                                                                           Buffers: shared hit=336736
                                                   ->  Index Scan using title_pkey on title t (actual rows=0.58 loops=917291)
                                                         Index Cond: (id = ci.movie_id)
                                                         Filter: ((production_year >= 1980) AND (production_year <= 2010))
                                                         Rows Removed by Filter: 0
                                                         Index Searches: 917291
                                                         Buffers: shared hit=3669168
                                 ->  Index Scan using link_type_pkey on link_type lt (actual rows=0.88 loops=45471)
                                       Index Cond: (id = ml.link_type_id)
                                       Filter: ((link)::text = ANY ('{references,"referenced in",features,"featured in"}'::text[]))
                                       Rows Removed by Filter: 0
                                       Index Searches: 45471
                                       Buffers: shared hit=90946
 Planning:
   Buffers: shared hit=40
 Planning Time: 4.269 ms
 Execution Time: 3351.249 ms
(76 rows)
*/
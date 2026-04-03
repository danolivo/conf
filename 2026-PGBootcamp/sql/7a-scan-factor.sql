EXPLAIN (ANALYZE, COSTS ON, BUFFERS OFF, TIMING OFF)
SELECT MIN(n.name) AS of_person,
       MIN(t.title) AS biography_movie
FROM aka_name AS an,
     cast_info AS ci,
     info_type AS it,
     link_type AS lt,
     movie_link AS ml,
     name AS n,
     person_info AS pi,
     title AS t
WHERE an.name LIKE '%a%'
  AND it.info ='mini biography'
  AND lt.link ='features'
  AND n.name_pcode_cf BETWEEN 'A' AND 'F'
  AND (n.gender='m'
       OR (n.gender = 'f'
           AND n.name LIKE 'B%'))
  AND pi.note ='Volker Boehm'
  AND t.production_year BETWEEN 1980 AND 1995
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

EXPLAIN
SELECT * FROM person_info
WHERE note ='Volker Boehm';
CREATE INDEX person_info_note ON person_info (note);
CREATE INDEX movie_info_note ON movie_info USING gin (note gin_trgm_ops);

DROP TABLE IF EXISTS track_data;
CREATE TABLE track_data AS SELECT * FROM pg_track_optimizer;
/*
 Finalize Aggregate (actual rows=1.00 loops=1)
   ->  Gather (actual rows=5.00 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         ->  Partial Aggregate (actual rows=1.00 loops=5)
               ->  Parallel Hash Join (actual rows=6.40 loops=5)
                     Hash Cond: (ml.linked_movie_id = t.id)
                     ->  Parallel Hash Join (actual rows=1037.20 loops=5)
                           Hash Cond: (ml.link_type_id = lt.id)
                           ->  Parallel Seq Scan on movie_link ml (actual rows=5999.40 loops=5)
                           ->  Parallel Hash (actual rows=0.20 loops=5)
                                 Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                 ->  Parallel Seq Scan on link_type lt (actual rows=0.20 loops=5)
                                       Filter: ((link)::text = 'features'::text)
                                       Rows Removed by Filter: 3
                     ->  Parallel Hash (actual rows=110.40 loops=5)
                           Buckets: 1024  Batches: 1  Memory Usage: 168kB
                           ->  Nested Loop (actual rows=110.40 loops=5)
                                 ->  Parallel Hash Join (actual rows=670.80 loops=5)
                                       Hash Cond: (ci.person_id = n.id)
                                       ->  Parallel Seq Scan on cast_info ci (actual rows=7248868.80 loops=5)
                                       ->  Parallel Hash (actual rows=4.00 loops=5)
                                             Buckets: 1024  Batches: 1  Memory Usage: 168kB
                                             ->  Nested Loop (actual rows=4.00 loops=5)
                                                   ->  Parallel Hash Join (actual rows=19.60 loops=5)
                                                         Hash Cond: (an.person_id = pi.person_id)
                                                         ->  Parallel Seq Scan on aka_name an (actual rows=134938.40 loops=5)
                                                               Filter: (name ~~ '%a%'::text)
                                                               Rows Removed by Filter: 45330
                                                         ->  Parallel Hash (actual rows=12.80 loops=5)
                                                               Buckets: 1024  Batches: 1  Memory Usage: 168kB
                                                               ->  Parallel Hash Join (actual rows=12.80 loops=5)
                                                                     Hash Cond: (pi.info_type_id = it.id)
                                                                     ->  Parallel Seq Scan on person_info pi (actual rows=12.80 loops=5)
                                                                           Filter: (note = 'Volker Boehm'::text)
                                                                           Rows Removed by Filter: 592720
                                                                     ->  Parallel Hash (actual rows=0.20 loops=5)
                                                                           Buckets: 1024  Batches: 1  Memory Usage: 40kB
                                                                           ->  Parallel Seq Scan on info_type it (actual rows=1.00 loops=1)
                                                                                 Filter: ((info)::text = 'mini biography'::text)
                                                                                 Rows Removed by Filter: 112
                                                   ->  Index Scan using name_pkey on name n (actual rows=0.20 loops=98)
                                                         Index Cond: (id = an.person_id)
                                                         Filter: (((name_pcode_cf)::text >= 'A'::text) AND ((name_pcode_cf)::text <= 'F'::text) AND (((gender)::text = 'm'::text) OR (((gender)::text = 'f'::text) AND (name ~~ 'B%'::text))))
                                                         Rows Removed by Filter: 1
                                                         Index Searches: 98
                                 ->  Index Scan using title_pkey on title t (actual rows=0.16 loops=3354)
                                       Index Cond: (id = ci.movie_id)
                                       Filter: ((production_year >= 1980) AND (production_year <= 1995))
                                       Rows Removed by Filter: 1
                                       Index Searches: 3354
 Planning Time: 19.751 ms
 Execution Time: 1479.923 ms

->  Parallel Seq Scan on person_info pi (actual rows=12.80 loops=5)
    Filter: (note = 'Volker Boehm'::text)
    Rows Removed by Filter: 592720
																		   
 */

EXPLAIN (ANALYZE, COSTS ON, BUFFERS OFF, TIMING OFF)
SELECT MIN(at.title) AS aka_title,
       MIN(t.title) AS internet_movie_title
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
  AND it1.info = 'release dates'
  AND mi.note LIKE '%internet%'
  AND t.production_year > 1990
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


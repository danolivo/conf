#
#
# pg_track_optimizer statistics (an old version) on 1C benchmark
#
#

SELECT count(*) FROM job_tracking_data_pass1;
 count  
--------
 115502
(1 строка)

SELECT min(length(query)) FROM job_tracking_data_pass1;
 min 
-----
  33
(1 строка)

SELECT max(length(query)) FROM job_tracking_data_pass1;
  max   
--------
 126389
(1 строка)

SELECT max(plan_nodes) FROM job_tracking_data_pass1;
 max 
-----
 195

SELECT max(plan_nodes-evaluated_nodes) FROM job_tracking_data_pass1;
 max 
-----
  52

SELECT queryid,local_min,local_max,local_cnt,local_avg
FROM job_tracking_data_pass1 ORDER BY local_avg DESC LIMIT 10;

       queryid        | local_min | local_max | local_cnt | local_avg 
----------------------+-----------+-----------+-----------+-----------
   966610446470385238 |    103287 |    103287 |         1 |    103287
  3584289357255619195 |    103287 |    103287 |         1 |    103287
   860753599416110081 |    103287 |    103287 |         1 |    103287
  8003622400238294987 |    103287 |    103287 |         1 |    103287
 -6047936271506867968 |    103287 |    103287 |         1 |    103287
  4751111382114082879 |    103287 |    103287 |         1 |    103287
  6832010316141559612 |    103287 |    103287 |         1 |    103287
  7901687307344054980 |    103286 |    103286 |         1 |    103286
  3757892468513627288 |    103286 |    103286 |         1 |    103286
  9181447765538987061 |    103286 |    103286 |         1 |    103286
  
SELECT queryid,LEFT(query,40),local_min,local_max,local_cnt,local_avg,time_avg
FROM job_tracking_data_pass1 ORDER BY local_avg DESC LIMIT 10;

      queryid        |                   left                   | local_min | local_max | local_cnt |     local_avg      |      time_avg      
----------------------+------------------------------------------+-----------+-----------+-----------+--------------------+--------------------
  8003622400238294987 | SELECT                                  +|    103287 |    103287 |         1 |             103287 |        3555.033536
                      | CAST('ТоварыОрганизаций'::mvarcha        |           |           |           |                    | 
   966610446470385238 | SELECT                                  +|    103287 |    103287 |         1 |             103287 |          3304.7077

SELECT query FROM job_tracking_data_pass1 WHERE queryid=8003622400238294987;

/*
The two queries are structurally identical — the only difference is the names of the temporary tables used as data sources:
Query 1 (localblk-1.sql): reads from pg_temp.tt2198 (line 69) and pg_temp.tt2199 (line 158).
Query 2 (localblk-2.sql): reads from pg_temp.tt50 (line 69) and pg_temp.tt51 (line 158).
Everything else — the SELECT list, all JOINs, the WHERE clauses, the UNION ALL structure, the CASE expressions, the bytea constants — is exactly the same. These are clearly two executions of the same 1C:Enterprise report/query with different temp table numbering, which is typical for 1C — temp table names are assigned sequentially within a session, so a fresh session or different execution context produces lower numbers (tt50/tt51) versus a session that has already created many temp tables (tt2198/tt2199).
 */
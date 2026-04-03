SELECT * FROM pg_track_optimizer_status;
   mode   | entries_left | is_synced 
----------+--------------+-----------
 disabled |         8642 | t
 
 
SELECT queryid,avg_avg
FROM pg_track_optimizer
ORDER BY avg_avg ;

SELECT avg.*,twa_err FROM (
  SELECT queryid,LEFT(query, 14) AS query,
	ROUND(avg_avg::numeric,2) AS avg_err
  FROM pg_track_optimizer
  ORDER BY avg_avg DESC LIMIT 10) AS avg
JOIN
(
  SELECT queryid,
	ROUND(twa_avg::numeric,2) AS twa_err
  FROM pg_track_optimizer
  ORDER BY twa_avg DESC LIMIT 10) AS twa
USING (queryid);

/*
       queryid        |      query     | avg_err | twa_err 
----------------------+----------------+---------+---------
 -6836119621424365027 | /* 28a.sql */  |    3.91 |    2.16
  3631768377448547020 | /* 29c.sql */  |    3.77 |    2.51
 -8544699698054799639 | /* 22d.sql */  |    3.48 |    2.09
  4682104415514032107 | /* 7c.sql */   |    3.48 |    2.18
(4 rows)
*/

SELECT avg.*,wca_err FROM (
  SELECT queryid,LEFT(query, 14) AS query,
	ROUND(avg_avg::numeric,2) AS avg_err
  FROM pg_track_optimizer
  ORDER BY avg_avg DESC LIMIT 10) AS avg
JOIN
(
  SELECT queryid,ROUND(wca_avg::numeric,2) AS wca_err
  FROM pg_track_optimizer
  ORDER BY wca_avg DESC LIMIT 10) AS twa
USING (queryid);

/*
       queryid        |     query      | avg_err | wca_err 
----------------------+----------------+---------+---------
 -6836119621424365027 | /* 28a.sql */  |    3.91 |    2.81
  3631768377448547020 | /* 29c.sql */  |    3.77 |    2.71
 -8544699698054799639 | /* 22d.sql */  |    3.48 |    2.49
 -3799596786824522319 | /* 17b.sql */  |    3.48 |    2.23
  4682104415514032107 | /* 7c.sql */   |    3.48 |    2.61
(5 rows)
*/

SELECT avg.*,twa_err,wca_err FROM (
  SELECT queryid,LEFT(query, 14) AS query,
	ROUND(avg_avg::numeric,2) AS avg_err
  FROM pg_track_optimizer
  ORDER BY avg_avg DESC LIMIT 10) AS avg
JOIN
(
  SELECT queryid,
	ROUND(twa_avg::numeric,2) AS twa_err
  FROM pg_track_optimizer
  ORDER BY twa_avg DESC LIMIT 10) AS twa
USING (queryid)
JOIN
(
  SELECT queryid,ROUND(wca_avg::numeric,2) AS wca_err
  FROM pg_track_optimizer
  ORDER BY wca_avg DESC LIMIT 10) AS wca
USING (queryid);

/*
       queryid        |     query      | avg_err | twa_err | wca_err 
----------------------+----------------+---------+---------+---------
 -8544699698054799639 | /* 22d.sql */  |    3.48 |    2.09 |    2.49
 -6836119621424365027 | /* 28a.sql */  |    3.91 |    2.16 |    2.81
  3631768377448547020 | /* 29c.sql */  |    3.77 |    2.51 |    2.71
  4682104415514032107 | /* 7c.sql */   |    3.48 |    2.18 |    2.61
(4 rows)
*/

/* *****************************************************************************
 *
 * INDEXES
 *
 * ************************************************************************** */
 
SELECT queryid,LEFT(query, 13) AS query,
  ROUND(avg_avg::numeric,2) AS error,
  ROUND(lf_avg::numeric,2) AS scan_f,
  ROUND(lf_dev::numeric,2) AS stddev
FROM track_data
ORDER BY lf_avg DESC LIMIT 10;

SELECT queryid,LEFT(query, 13) AS query,
  ROUND(avg_avg::numeric,2) AS error,
  ROUND(lf_avg::numeric,2) AS scan_f,
  ROUND(lf_dev::numeric,2) AS stddev
FROM track_data
ORDER BY lf_avg DESC LIMIT 5;

       queryid        |     query     | error | scan_f | stddev 
----------------------+---------------+-------+--------+--------
   969606574527514143 | /* 2a.sql */  |  2.99 |   0.40 |   0.79
 -3752195902401095348 | /* 1c.sql */  |  1.35 |   0.11 |   0.00
 -5865862719849412788 | /* 33a.sql */ |  0.84 |   0.04 |   0.00
 -7718801079997731049 | /* 1d.sql */  |  2.40 |   0.03 |   0.00
 -5419519412498458412 | /* 33b.sql */ |  1.47 |   0.03 |   0.00
(5 rows)

SELECT queryid,LEFT(query, 13) AS query,
  ROUND(avg_avg::numeric,2) AS error,
  ROUND(lf_avg::numeric,2) AS scan_f,
  ROUND(jf_avg::numeric,2) AS join_f
FROM track_data
ORDER BY jf_avg DESC LIMIT 5;

       queryid        |     query     | error | scan_f |  join_f   
----------------------+---------------+-------+--------+-----------
  6389747766960672879 | /* 27c.sql */ |  1.84 |   0.00 | 532519.50
 -5419519412498458412 | /* 33b.sql */ |  1.47 |   0.03 |     53.25
 -5865862719849412788 | /* 33a.sql */ |  0.84 |   0.04 |      1.34
  8307542826537749406 | /* 5a.sql */  |  3.07 |   0.00 |      0.00
 -3799596786824522319 | /* 17b.sql */ |  3.43 |   0.00 |      0.00
(5 rows)

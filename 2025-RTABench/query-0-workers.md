-- Q0: Does number of workers speed up?

-- max_parallel_workers_per_gather = '16'

 WindowAgg  (cost=3467563.63..3468966.39 rows=70139 width=80) (actual time=16467.430..16472.305 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=5552 read=3128656
   ->  Sort  (cost=3467563.61..3467738.96 rows=70139 width=48) (actual time=16467.405..16467.709 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=5552 read=3128656
         ->  GroupAggregate  (cost=3458706.19..3461918.15 rows=70139 width=48) (actual time=16325.222..16464.553 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=5552 read=3128656
               ->  Gather Merge  (cost=3458706.19..3460339.49 rows=70210 width=40) (actual time=16325.187..16420.835 rows=204053.00 loops=1)
                     Workers Planned: 14
                     Workers Launched: 8
                     Buffers: shared hit=5552 read=3128656
                     ->  Sort  (cost=3458704.90..3458717.44 rows=5015 width=40) (actual time=16309.890..16312.986 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1631kB
                           Buffers: shared hit=5552 read=3128656
                           Worker 0:  Sort Method: quicksort  Memory: 1379kB
                           Worker 1:  Sort Method: quicksort  Memory: 1368kB
                           Worker 2:  Sort Method: quicksort  Memory: 1368kB
                           Worker 3:  Sort Method: quicksort  Memory: 1395kB
                           Worker 4:  Sort Method: quicksort  Memory: 1556kB
                           Worker 5:  Sort Method: quicksort  Memory: 1594kB
                           Worker 6:  Sort Method: quicksort  Memory: 1378kB
                           Worker 7:  Sort Method: quicksort  Memory: 1623kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3458396.68 rows=5015 width=40) (actual time=0.373..16284.815 rows=22672.56 loops=9)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 20170404
                                 Buffers: shared hit=5184 read=3128656
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '16'
 Planning Time: 1.088 ms
 Execution Time: 16473.247 ms

-- 12

 WindowAgg  (cost=3521643.86..3523046.62 rows=70139 width=80) (actual time=16109.508..16114.365 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=8144 read=3126064
   ->  Sort  (cost=3521643.84..3521819.19 rows=70139 width=48) (actual time=16109.483..16109.771 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=8144 read=3126064
         ->  GroupAggregate  (cost=3512856.81..3515998.38 rows=70139 width=48) (actual time=15966.334..16106.589 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=8144 read=3126064
               ->  Gather Merge  (cost=3512856.81..3514419.72 rows=70210 width=40) (actual time=15966.302..16062.180 rows=204053.00 loops=1)
                     Workers Planned: 12
                     Workers Launched: 8
                     Buffers: shared hit=8144 read=3126064
                     ->  Sort  (cost=3512855.57..3512870.19 rows=5851 width=40) (actual time=15952.984..15955.802 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1620kB
                           Buffers: shared hit=8144 read=3126064
                           Worker 0:  Sort Method: quicksort  Memory: 1370kB
                           Worker 1:  Sort Method: quicksort  Memory: 1370kB
                           Worker 2:  Sort Method: quicksort  Memory: 1357kB
                           Worker 3:  Sort Method: quicksort  Memory: 1642kB
                           Worker 4:  Sort Method: quicksort  Memory: 1370kB
                           Worker 5:  Sort Method: quicksort  Memory: 1375kB
                           Worker 6:  Sort Method: quicksort  Memory: 1577kB
                           Worker 7:  Sort Method: quicksort  Memory: 1613kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3512489.46 rows=5851 width=40) (actual time=0.377..15928.493 rows=22672.56 loops=9)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 20170404
                                 Buffers: shared hit=7776 read=3126064
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '12'
 Planning Time: 0.880 ms
 Execution Time: 16115.270 ms
 
-- 10

 WindowAgg  (cost=3597374.46..3598777.22 rows=70139 width=80) (actual time=15947.804..15952.665 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=10736 read=3123472
   ->  Sort  (cost=3597374.44..3597549.79 rows=70139 width=48) (actual time=15947.779..15948.056 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=10736 read=3123472
         ->  GroupAggregate  (cost=3588669.09..3591728.98 rows=70139 width=48) (actual time=15806.332..15944.914 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=10736 read=3123472
               ->  Gather Merge  (cost=3588669.09..3590150.32 rows=70210 width=40) (actual time=15806.298..15901.308 rows=204053.00 loops=1)
                     Workers Planned: 10
                     Workers Launched: 8
                     Buffers: shared hit=10736 read=3123472
                     ->  Sort  (cost=3588667.90..3588685.45 rows=7021 width=40) (actual time=15791.398..15793.967 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1378kB
                           Buffers: shared hit=10736 read=3123472
                           Worker 0:  Sort Method: quicksort  Memory: 1358kB
                           Worker 1:  Sort Method: quicksort  Memory: 1374kB
                           Worker 2:  Sort Method: quicksort  Memory: 1617kB
                           Worker 3:  Sort Method: quicksort  Memory: 1570kB
                           Worker 4:  Sort Method: quicksort  Memory: 1375kB
                           Worker 5:  Sort Method: quicksort  Memory: 1640kB
                           Worker 6:  Sort Method: quicksort  Memory: 1363kB
                           Worker 7:  Sort Method: quicksort  Memory: 1618kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3588219.35 rows=7021 width=40) (actual time=0.333..15766.376 rows=22672.56 loops=9)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 20170404
                                 Buffers: shared hit=10368 read=3123472
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '10'
 Planning Time: 0.915 ms
 Execution Time: 15953.308 ms

-- 9

 WindowAgg  (cost=3647870.47..3649273.23 rows=70139 width=80) (actual time=15969.281..15974.140 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=13328 read=3120880
   ->  Sort  (cost=3647870.45..3648045.80 rows=70139 width=48) (actual time=15969.254..15969.527 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=13328 read=3120880
         ->  GroupAggregate  (cost=3639211.42..3642224.99 rows=70139 width=48) (actual time=15827.501..15966.383 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=13328 read=3120880
               ->  Gather Merge  (cost=3639211.42..3640646.33 rows=70210 width=40) (actual time=15827.461..15922.633 rows=204053.00 loops=1)
                     Workers Planned: 9
                     Workers Launched: 8
                     Buffers: shared hit=13328 read=3120880
                     ->  Sort  (cost=3639210.25..3639229.75 rows=7801 width=40) (actual time=15812.763..15815.421 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1378kB
                           Buffers: shared hit=13328 read=3120880
                           Worker 0:  Sort Method: quicksort  Memory: 1340kB
                           Worker 1:  Sort Method: quicksort  Memory: 1630kB
                           Worker 2:  Sort Method: quicksort  Memory: 1533kB
                           Worker 3:  Sort Method: quicksort  Memory: 1373kB
                           Worker 4:  Sort Method: quicksort  Memory: 1373kB
                           Worker 5:  Sort Method: quicksort  Memory: 1575kB
                           Worker 6:  Sort Method: quicksort  Memory: 1636kB
                           Worker 7:  Sort Method: quicksort  Memory: 1457kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3638705.94 rows=7801 width=40) (actual time=0.232..15788.128 rows=22672.56 loops=9)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 20170404
                                 Buffers: shared hit=12960 read=3120880
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '9'
 Planning Time: 0.828 ms
 Execution Time: 15974.784 ms

-- 8

 WindowAgg  (cost=3710998.25..3712401.01 rows=70139 width=80) (actual time=16181.373..16186.330 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=15920 read=3118288
   ->  Sort  (cost=3710998.23..3711173.58 rows=70139 width=48) (actual time=16181.347..16181.622 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=15920 read=3118288
         ->  GroupAggregate  (cost=3702390.12..3705352.77 rows=70139 width=48) (actual time=16036.298..16178.400 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=15920 read=3118288
               ->  Gather Merge  (cost=3702390.12..3703774.11 rows=70210 width=40) (actual time=16036.254..16133.284 rows=204053.00 loops=1)
                     Workers Planned: 8
                     Workers Launched: 8
                     Buffers: shared hit=15920 read=3118288
                     ->  Sort  (cost=3702388.98..3702410.92 rows=8776 width=40) (actual time=16025.117..16027.817 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1351kB
                           Buffers: shared hit=15920 read=3118288
                           Worker 0:  Sort Method: quicksort  Memory: 1358kB
                           Worker 1:  Sort Method: quicksort  Memory: 1525kB
                           Worker 2:  Sort Method: quicksort  Memory: 1373kB
                           Worker 3:  Sort Method: quicksort  Memory: 1348kB
                           Worker 4:  Sort Method: quicksort  Memory: 1589kB
                           Worker 5:  Sort Method: quicksort  Memory: 1487kB
                           Worker 6:  Sort Method: quicksort  Memory: 1624kB
                           Worker 7:  Sort Method: quicksort  Memory: 1639kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3701814.18 rows=8776 width=40) (actual time=0.201..16000.336 rows=22672.56 loops=9)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 20170404
                                 Buffers: shared hit=15552 read=3118288
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '8'
 Planning Time: 1.119 ms
 Execution Time: 16187.014 ms

-- 7

 WindowAgg  (cost=3792172.68..3793575.44 rows=70139 width=80) (actual time=16496.251..16501.299 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=18466 read=3115696
   ->  Sort  (cost=3792172.66..3792348.01 rows=70139 width=48) (actual time=16496.225..16496.503 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=18466 read=3115696
         ->  GroupAggregate  (cost=3783621.07..3786527.20 rows=70139 width=48) (actual time=16353.129..16493.174 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=18466 read=3115696
               ->  Gather Merge  (cost=3783621.07..3784948.54 rows=70210 width=40) (actual time=16353.085..16448.614 rows=204053.00 loops=1)
                     Workers Planned: 7
                     Workers Launched: 7
                     Buffers: shared hit=18466 read=3115696
                     ->  Sort  (cost=3783619.95..3783645.02 rows=10030 width=40) (actual time=16343.782..16346.791 rows=25506.62 loops=8)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1427kB
                           Buffers: shared hit=18466 read=3115696
                           Worker 0:  Sort Method: quicksort  Memory: 1414kB
                           Worker 1:  Sort Method: quicksort  Memory: 1424kB
                           Worker 2:  Sort Method: quicksort  Memory: 1415kB
                           Worker 3:  Sort Method: quicksort  Memory: 1722kB
                           Worker 4:  Sort Method: quicksort  Memory: 1689kB
                           Worker 5:  Sort Method: quicksort  Memory: 1705kB
                           Worker 6:  Sort Method: quicksort  Memory: 1729kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3782953.35 rows=10030 width=40) (actual time=0.238..16317.338 rows=25506.62 loops=8)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 22691705
                                 Buffers: shared hit=18144 read=3115696
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '7'
 Planning Time: 0.302 ms
 Execution Time: 16502.277 ms

-- 6

 WindowAgg  (cost=3900418.91..3901821.67 rows=70139 width=80) (actual time=17422.160..17426.884 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=20724 read=3113392
   ->  Sort  (cost=3900418.89..3900594.23 rows=70139 width=48) (actual time=17422.133..17422.396 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=20724 read=3113392
         ->  GroupAggregate  (cost=3891930.74..3894773.42 rows=70139 width=48) (actual time=17287.411..17419.335 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=20724 read=3113392
               ->  Gather Merge  (cost=3891930.74..3893194.76 rows=70210 width=40) (actual time=17287.368..17376.702 rows=204053.00 loops=1)
                     Workers Planned: 6
                     Workers Launched: 6
                     Buffers: shared hit=20724 read=3113392
                     ->  Sort  (cost=3891929.64..3891958.90 rows=11702 width=40) (actual time=17274.645..17277.658 rows=29150.43 loops=7)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1484kB
                           Buffers: shared hit=20724 read=3113392
                           Worker 0:  Sort Method: quicksort  Memory: 1493kB
                           Worker 1:  Sort Method: quicksort  Memory: 1492kB
                           Worker 2:  Sort Method: quicksort  Memory: 2577kB
                           Worker 3:  Sort Method: quicksort  Memory: 2582kB
                           Worker 4:  Sort Method: quicksort  Memory: 2597kB
                           Worker 5:  Sort Method: quicksort  Memory: 2604kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3891138.91 rows=11702 width=40) (actual time=0.385..17246.613 rows=29150.43 loops=7)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 25933377
                                 Buffers: shared hit=20448 read=3113392
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '6'
 Planning Time: 0.735 ms
 Execution Time: 17427.810 ms

-- 5

 WindowAgg  (cost=4024077.99..4025480.75 rows=70139 width=80) (actual time=26464.005..26820.043 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=180 read=3182778
   ->  Sort  (cost=4024077.97..4024253.32 rows=70139 width=48) (actual time=26463.980..26815.859 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=180 read=3182778
         ->  GroupAggregate  (cost=4015662.05..4018432.51 rows=70139 width=48) (actual time=26353.822..26812.955 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=180 read=3182778
               ->  Gather Merge  (cost=4015662.05..4016853.85 rows=70210 width=40) (actual time=26353.788..26778.378 rows=204053.00 loops=1)
                     Workers Planned: 5
                     Workers Launched: 5
                     Buffers: shared hit=180 read=3182778
                     ->  Sort  (cost=4015660.97..4015696.07 rows=14042 width=40) (actual time=26340.539..26343.520 rows=34008.83 loops=6)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2626kB
                           Buffers: shared hit=180 read=3182778
                           Worker 0:  Sort Method: quicksort  Memory: 2587kB
                           Worker 1:  Sort Method: quicksort  Memory: 1760kB
                           Worker 2:  Sort Method: quicksort  Memory: 2669kB
                           Worker 3:  Sort Method: quicksort  Memory: 1769kB
                           Worker 4:  Sort Method: quicksort  Memory: 2648kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4014693.65 rows=14042 width=40) (actual time=4924.376..26310.873 rows=34008.83 loops=6)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 9535008
                                 Heap Blocks: exact=526644
                                 Buffers: shared hit=100 read=3182778
                                 Worker 0:  Heap Blocks: exact=523250
                                 Worker 1:  Heap Blocks: exact=516740
                                 Worker 2:  Heap Blocks: exact=520574
                                 Worker 3:  Heap Blocks: exact=523764
                                 Worker 4:  Heap Blocks: exact=522860
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=3789.680..3789.682 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '5'
 Planning Time: 0.742 ms
 Execution Time: 26830.905 ms

-- 4

 WindowAgg  (cost=4095182.42..4096585.18 rows=70139 width=80) (actual time=27322.163..27455.647 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=135 read=3182787
   ->  Sort  (cost=4095182.40..4095357.75 rows=70139 width=48) (actual time=27322.144..27451.837 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=135 read=3182787
         ->  GroupAggregate  (cost=4086850.04..4089536.94 rows=70139 width=48) (actual time=27218.677..27449.312 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=135 read=3182787
               ->  Gather Merge  (cost=4086850.04..4087958.28 rows=70210 width=40) (actual time=27218.652..27416.588 rows=204053.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     Buffers: shared hit=135 read=3182787
                     ->  Sort  (cost=4086848.98..4086892.86 rows=17552 width=40) (actual time=27204.828..27207.974 rows=40810.60 loops=5)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2950kB
                           Buffers: shared hit=135 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 2673kB
                           Worker 1:  Sort Method: quicksort  Memory: 2893kB
                           Worker 2:  Sort Method: quicksort  Memory: 2707kB
                           Worker 3:  Sort Method: quicksort  Memory: 2836kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4085611.62 rows=17552 width=40) (actual time=4740.953..27174.628 rows=40810.60 loops=5)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 11442010
                                 Heap Blocks: exact=637573
                                 Buffers: shared hit=77 read=3182781
                                 Worker 0:  Heap Blocks: exact=615916
                                 Worker 1:  Heap Blocks: exact=627978
                                 Worker 2:  Heap Blocks: exact=626989
                                 Worker 3:  Heap Blocks: exact=625376
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=3641.800..3641.800 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '4'
 Planning Time: 1.016 ms
 Execution Time: 27458.219 ms

-- 3

 WindowAgg  (cost=4198428.47..4199831.23 rows=70139 width=80) (actual time=29424.259..29545.570 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=99 read=3182787
   ->  Sort  (cost=4198428.45..4198603.79 rows=70139 width=48) (actual time=29424.235..29541.621 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=99 read=3182787
         ->  GroupAggregate  (cost=4190196.36..4192782.98 rows=70139 width=48) (actual time=29322.321..29539.044 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=99 read=3182787
               ->  Gather Merge  (cost=4190196.36..4191204.32 rows=70210 width=40) (actual time=29322.297..29506.552 rows=204053.00 loops=1)
                     Workers Planned: 3
                     Workers Launched: 3
                     Buffers: shared hit=99 read=3182787
                     ->  Sort  (cost=4190195.32..4190251.94 rows=22648 width=40) (actual time=29306.431..29310.321 rows=51013.25 loops=4)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3208kB
                           Buffers: shared hit=99 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 3086kB
                           Worker 1:  Sort Method: quicksort  Memory: 3101kB
                           Worker 2:  Sort Method: quicksort  Memory: 3127kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4188557.06 rows=22648 width=40) (actual time=4840.678..29271.345 rows=51013.25 loops=4)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 14302512
                                 Heap Blocks: exact=792189
                                 Buffers: shared hit=57 read=3182781
                                 Worker 0:  Heap Blocks: exact=786247
                                 Worker 1:  Heap Blocks: exact=775344
                                 Worker 2:  Heap Blocks: exact=780052
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=3711.008..3711.009 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '3'
 Planning Time: 0.958 ms
 Execution Time: 29547.009 ms

-- 2

 WindowAgg  (cost=4332278.92..4333681.68 rows=70139 width=80) (actual time=29566.901..29702.015 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=63 read=3182787
   ->  Sort  (cost=4332278.90..4332454.25 rows=70139 width=48) (actual time=29566.879..29698.181 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=63 read=3182787
         ->  GroupAggregate  (cost=4324176.00..4326633.44 rows=70139 width=48) (actual time=29466.420..29695.676 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=63 read=3182787
               ->  Gather Merge  (cost=4324176.00..4325054.78 rows=70210 width=40) (actual time=29466.393..29663.216 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=63 read=3182787
                     ->  Sort  (cost=4324174.97..4324248.11 rows=29254 width=40) (actual time=29450.161..29455.221 rows=68017.67 loops=3)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 5231kB
                           Buffers: shared hit=63 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 5198kB
                           Worker 1:  Sort Method: quicksort  Memory: 5165kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4322004.86 rows=29254 width=40) (actual time=4866.328..29404.791 rows=68017.67 loops=3)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 19070016
                                 Heap Blocks: exact=1044963
                                 Buffers: shared hit=37 read=3182781
                                 Worker 0:  Heap Blocks: exact=1041745
                                 Worker 1:  Heap Blocks: exact=1047124
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=3740.005..3740.006 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001'
 Planning Time: 1.084 ms
 Execution Time: 29703.519 ms

-- 1

 WindowAgg  (cost=4576445.98..4577848.74 rows=70139 width=80) (actual time=29601.941..29733.562 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=27 read=3182787
   ->  Sort  (cost=4576445.96..4576621.31 rows=70139 width=48) (actual time=29601.917..29729.743 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=27 read=3182787
         ->  GroupAggregate  (cost=4568518.29..4570800.50 rows=70139 width=48) (actual time=29512.478..29727.208 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=27 read=3182787
               ->  Gather Merge  (cost=4568518.29..4569221.84 rows=70210 width=40) (actual time=29512.454..29695.009 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=27 read=3182787
                     ->  Sort  (cost=4568517.28..4568620.53 rows=41300 width=40) (actual time=29499.219..29506.828 rows=102026.50 loops=2)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 6319kB
                           Buffers: shared hit=27 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 6203kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4565350.84 rows=41300 width=40) (actual time=4862.293..29437.961 rows=102026.50 loops=2)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 28605024
                                 Heap Blocks: exact=1574026
                                 Buffers: shared hit=17 read=3182781
                                 Worker 0:  Heap Blocks: exact=1559806
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=3741.559..3741.560 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1'
 Planning Time: 1.331 ms
 Execution Time: 29736.359 ms


-- 0

 WindowAgg  (cost=5162432.55..5163835.31 rows=70139 width=80) (actual time=38070.777..38074.343 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared read=3182778
   ->  Sort  (cost=5162432.53..5162607.88 rows=70139 width=48) (actual time=38070.744..38070.867 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared read=3182778
         ->  GroupAggregate  (cost=5155032.88..5156787.07 rows=70139 width=48) (actual time=38017.344..38068.624 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared read=3182778
               ->  Sort  (cost=5155032.88..5155208.41 rows=70210 width=40) (actual time=38017.318..38031.129 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared read=3182778
                     ->  Bitmap Heap Scan on order_events  (cost=597181.77..5149381.19 rows=70210 width=40) (actual time=4633.035..37912.493 rows=204053.00 loops=1)
                           Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                           Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                           Rows Removed by Filter: 57210049
                           Heap Blocks: exact=3133832
                           Buffers: shared read=3182778
                           ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=3446.188..3446.188 rows=57414102.00 loops=1)
                                 Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Index Searches: 1
                                 Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0'
 Planning Time: 0.958 ms
 Execution Time: 38107.065 ms


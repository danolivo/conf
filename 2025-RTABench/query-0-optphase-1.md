CREATE INDEX idx_1 ON order_events (event_created);
```
-- 0

 WindowAgg  (cost=821441.55..822846.03 rows=70225 width=80) (actual time=6591.242..6591.920 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317527
   ->  Sort  (cost=821441.53..821617.09 rows=70225 width=48) (actual time=6591.235..6591.279 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317527
         ->  GroupAggregate  (cost=814032.19..815788.52 rows=70225 width=48) (actual time=6577.920..6590.700 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317527
               ->  Sort  (cost=814032.19..814207.93 rows=70296 width=40) (actual time=6577.911..6581.917 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=14317527
                     ->  Index Scan using idx1 on order_events  (cost=0.57..808372.95 rows=70296 width=40) (actual time=0.046..6555.122 rows=204053.00 loops=1)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                           Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                           Rows Removed by Filter: 14099758
                           Index Searches: 1
                           Buffers: shared hit=14317527
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.288 ms
 Execution Time: 6591.995 ms

-- 1

 WindowAgg  (cost=695680.09..697084.57 rows=70225 width=80) (actual time=3240.677..3265.796 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317549 read=1
   ->  Sort  (cost=695680.07..695855.63 rows=70225 width=48) (actual time=3240.668..3265.137 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317549 read=1
         ->  GroupAggregate  (cost=687742.06..690027.06 rows=70225 width=48) (actual time=3219.376..3264.529 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317549 read=1
               ->  Gather Merge  (cost=687742.06..688446.47 rows=70296 width=40) (actual time=3219.367..3256.689 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=14317549 read=1
                     ->  Sort  (cost=687741.05..687844.43 rows=41351 width=40) (actual time=3217.291..3219.336 rows=102026.50 loops=2)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 6310kB
                           Buffers: shared hit=14317549 read=1
                           Worker 0:  Sort Method: quicksort  Memory: 6211kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..684570.33 rows=41351 width=40) (actual time=0.055..3204.657 rows=102026.50 loops=2)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 7049879
                                 Index Searches: 1
                                 Buffers: shared hit=14317533 read=1
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.305 ms
 Execution Time: 3265.883 ms

-- 2

 WindowAgg  (cost=643273.45..644677.93 rows=70225 width=80) (actual time=2331.158..2425.291 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317568
   ->  Sort  (cost=643273.43..643448.99 rows=70225 width=48) (actual time=2331.150..2424.573 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317568
         ->  GroupAggregate  (cost=635159.97..637620.42 rows=70225 width=48) (actual time=2305.618..2423.915 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317568
               ->  Gather Merge  (cost=635159.97..636039.83 rows=70296 width=40) (actual time=2305.610..2415.352 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=14317568
                     ->  Sort  (cost=635158.94..635232.17 rows=29290 width=40) (actual time=2302.569..2304.054 rows=68017.67 loops=3)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 5237kB
                           Buffers: shared hit=14317568
                           Worker 0:  Sort Method: quicksort  Memory: 5187kB
                           Worker 1:  Sort Method: quicksort  Memory: 5170kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..632985.90 rows=29290 width=40) (actual time=0.260..2292.864 rows=68017.67 loops=3)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 4699919
                                 Index Searches: 1
                                 Buffers: shared hit=14317536
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.270 ms
 Execution Time: 2425.377 ms

-- 3

 WindowAgg  (cost=614582.01..615986.49 rows=70225 width=80) (actual time=1800.368..1833.457 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317584
   ->  Sort  (cost=614581.99..614757.55 rows=70225 width=48) (actual time=1800.358..1832.727 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317584
         ->  GroupAggregate  (cost=606339.19..608928.98 rows=70225 width=48) (actual time=1774.220..1832.064 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317584
               ->  Gather Merge  (cost=606339.19..607348.39 rows=70296 width=40) (actual time=1774.211..1822.698 rows=204053.00 loops=1)
                     Workers Planned: 3
                     Workers Launched: 3
                     Buffers: shared hit=14317584
                     ->  Sort  (cost=606338.15..606394.84 rows=22676 width=40) (actual time=1770.192..1771.290 rows=51013.25 loops=4)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3174kB
                           Buffers: shared hit=14317584
                           Worker 0:  Sort Method: quicksort  Memory: 3133kB
                           Worker 1:  Sort Method: quicksort  Memory: 3115kB
                           Worker 2:  Sort Method: quicksort  Memory: 3101kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..604697.67 rows=22676 width=40) (actual time=0.159..1762.651 rows=51013.25 loops=4)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 3524940
                                 Index Searches: 1
                                 Buffers: shared hit=14317536
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '3', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.432 ms
 Execution Time: 1833.563 ms

-- 4

 WindowAgg  (cost=592458.66..593863.14 rows=70225 width=80) (actual time=1526.527..1554.071 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317600
   ->  Sort  (cost=592458.64..592634.20 rows=70225 width=48) (actual time=1526.517..1553.354 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317600
         ->  GroupAggregate  (cost=584115.44..586805.63 rows=70225 width=48) (actual time=1501.176..1552.716 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317600
               ->  Gather Merge  (cost=584115.44..585225.04 rows=70296 width=40) (actual time=1501.146..1544.170 rows=204053.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     Buffers: shared hit=14317600
                     ->  Sort  (cost=584114.38..584158.32 rows=17574 width=40) (actual time=1496.359..1497.379 rows=40810.60 loops=5)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2912kB
                           Buffers: shared hit=14317600
                           Worker 0:  Sort Method: quicksort  Memory: 2633kB
                           Worker 1:  Sort Method: quicksort  Memory: 2855kB
                           Worker 2:  Sort Method: quicksort  Memory: 2821kB
                           Worker 3:  Sort Method: quicksort  Memory: 2839kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..582875.31 rows=17574 width=40) (actual time=0.157..1489.494 rows=40810.60 loops=5)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 2819952
                                 Index Searches: 1
                                 Buffers: shared hit=14317536
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '4', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.429 ms
 Execution Time: 1554.178 ms

-- 5

 WindowAgg  (cost=577238.71..578643.19 rows=70225 width=80) (actual time=1344.097..1370.208 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317618
   ->  Sort  (cost=577238.69..577414.25 rows=70225 width=48) (actual time=1344.088..1369.487 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317618
         ->  GroupAggregate  (cost=568811.82..571585.68 rows=70225 width=48) (actual time=1318.569..1368.829 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317618
               ->  Gather Merge  (cost=568811.82..570005.08 rows=70296 width=40) (actual time=1318.540..1360.220 rows=204053.00 loops=1)
                     Workers Planned: 5
                     Workers Launched: 5
                     Buffers: shared hit=14317618
                     ->  Sort  (cost=568810.75..568845.89 rows=14059 width=40) (actual time=1313.801..1314.725 rows=34008.83 loops=6)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2714kB
                           Buffers: shared hit=14317618
                           Worker 0:  Sort Method: quicksort  Memory: 1721kB
                           Worker 1:  Sort Method: quicksort  Memory: 1665kB
                           Worker 2:  Sort Method: quicksort  Memory: 2667kB
                           Worker 3:  Sort Method: quicksort  Memory: 2625kB
                           Worker 4:  Sort Method: quicksort  Memory: 2667kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..567842.14 rows=14059 width=40) (actual time=0.190..1307.469 rows=34008.83 loops=6)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 2349960
                                 Index Searches: 1
                                 Buffers: shared hit=14317538
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '5', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.392 ms
 Execution Time: 1370.313 ms

-- 6

 WindowAgg  (cost=567112.09..568516.57 rows=70225 width=80) (actual time=1216.478..1244.110 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317634
   ->  Sort  (cost=567112.07..567287.63 rows=70225 width=48) (actual time=1216.469..1243.394 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317634
         ->  GroupAggregate  (cost=558612.90..561459.06 rows=70225 width=48) (actual time=1191.188..1242.751 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317634
               ->  Gather Merge  (cost=558612.90..559878.47 rows=70296 width=40) (actual time=1191.179..1234.262 rows=204053.00 loops=1)
                     Workers Planned: 6
                     Workers Launched: 6
                     Buffers: shared hit=14317634
                     ->  Sort  (cost=558611.80..558641.09 rows=11716 width=40) (actual time=1185.983..1186.860 rows=29150.43 loops=7)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1597kB
                           Buffers: shared hit=14317634
                           Worker 0:  Sort Method: quicksort  Memory: 1739kB
                           Worker 1:  Sort Method: quicksort  Memory: 1561kB
                           Worker 2:  Sort Method: quicksort  Memory: 1745kB
                           Worker 3:  Sort Method: quicksort  Memory: 1759kB
                           Worker 4:  Sort Method: quicksort  Memory: 1766kB
                           Worker 5:  Sort Method: quicksort  Memory: 1591kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..557820.02 rows=11716 width=40) (actual time=0.248..1180.158 rows=29150.43 loops=7)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 2014251
                                 Index Searches: 1
                                 Buffers: shared hit=14317538
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '6', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.475 ms
 Execution Time: 1244.223 ms

-- 7

 WindowAgg  (cost=559892.68..561297.16 rows=70225 width=80) (actual time=1103.640..1131.986 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317648
   ->  Sort  (cost=559892.66..560068.22 rows=70225 width=48) (actual time=1103.630..1131.235 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317648
         ->  GroupAggregate  (cost=551329.96..554239.65 rows=70225 width=48) (actual time=1076.200..1130.561 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317648
               ->  Gather Merge  (cost=551329.96..552659.06 rows=70296 width=40) (actual time=1076.188..1121.183 rows=204053.00 loops=1)
                     Workers Planned: 7
                     Workers Launched: 7
                     Buffers: shared hit=14317648
                     ->  Sort  (cost=551328.84..551353.95 rows=10042 width=40) (actual time=1070.032..1070.949 rows=25506.62 loops=8)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1523kB
                           Buffers: shared hit=14317648
                           Worker 0:  Sort Method: quicksort  Memory: 1495kB
                           Worker 1:  Sort Method: quicksort  Memory: 1471kB
                           Worker 2:  Sort Method: quicksort  Memory: 1641kB
                           Worker 3:  Sort Method: quicksort  Memory: 1652kB
                           Worker 4:  Sort Method: quicksort  Memory: 1476kB
                           Worker 5:  Sort Method: quicksort  Memory: 1622kB
                           Worker 6:  Sort Method: quicksort  Memory: 1644kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..550661.36 rows=10042 width=40) (actual time=0.169..1064.465 rows=25506.62 loops=8)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 1762470
                                 Index Searches: 1
                                 Buffers: shared hit=14317536
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '7', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.562 ms
 Execution Time: 1132.110 ms

-- 8

 WindowAgg  (cost=554488.42..555892.90 rows=70225 width=80) (actual time=1015.093..1045.919 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317664
   ->  Sort  (cost=554488.40..554663.96 rows=70225 width=48) (actual time=1015.083..1045.196 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317664
         ->  GroupAggregate  (cost=545869.12..548835.39 rows=70225 width=48) (actual time=988.951..1044.543 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317664
               ->  Gather Merge  (cost=545869.12..547254.80 rows=70296 width=40) (actual time=988.940..1035.930 rows=204053.00 loops=1)
                     Workers Planned: 8
                     Workers Launched: 8
                     Buffers: shared hit=14317664
                     ->  Sort  (cost=545867.97..545889.94 rows=8787 width=40) (actual time=982.516..983.268 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1450kB
                           Buffers: shared hit=14317664
                           Worker 0:  Sort Method: quicksort  Memory: 1546kB
                           Worker 1:  Sort Method: quicksort  Memory: 1402kB
                           Worker 2:  Sort Method: quicksort  Memory: 1397kB
                           Worker 3:  Sort Method: quicksort  Memory: 1403kB
                           Worker 4:  Sort Method: quicksort  Memory: 1520kB
                           Worker 5:  Sort Method: quicksort  Memory: 1566kB
                           Worker 6:  Sort Method: quicksort  Memory: 1570kB
                           Worker 7:  Sort Method: quicksort  Memory: 1439kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..545292.37 rows=8787 width=40) (actual time=0.312..977.315 rows=22672.56 loops=9)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 1566640
                                 Index Searches: 1
                                 Buffers: shared hit=14317536
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '8', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.510 ms
 Execution Time: 1046.033 ms

-- 9

 WindowAgg  (cost=550292.98..551697.46 rows=70225 width=80) (actual time=940.842..968.708 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317680
   ->  Sort  (cost=550292.96..550468.52 rows=70225 width=48) (actual time=940.832..967.961 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317680
         ->  GroupAggregate  (cost=541622.69..544639.96 rows=70225 width=48) (actual time=913.857..967.289 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317680
               ->  Gather Merge  (cost=541622.69..543059.36 rows=70296 width=40) (actual time=913.848..958.679 rows=204053.00 loops=1)
                     Workers Planned: 9
                     Workers Launched: 9
                     Buffers: shared hit=14317680
                     ->  Sort  (cost=541621.52..541641.05 rows=7811 width=40) (actual time=908.047..908.742 rows=20405.30 loops=10)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1543kB
                           Buffers: shared hit=14317680
                           Worker 0:  Sort Method: quicksort  Memory: 1346kB
                           Worker 1:  Sort Method: quicksort  Memory: 1338kB
                           Worker 2:  Sort Method: quicksort  Memory: 1340kB
                           Worker 3:  Sort Method: quicksort  Memory: 1335kB
                           Worker 4:  Sort Method: quicksort  Memory: 1333kB
                           Worker 5:  Sort Method: quicksort  Memory: 1339kB
                           Worker 6:  Sort Method: quicksort  Memory: 1494kB
                           Worker 7:  Sort Method: quicksort  Memory: 1496kB
                           Worker 8:  Sort Method: quicksort  Memory: 1498kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..541116.49 rows=7811 width=40) (actual time=0.138..903.243 rows=20405.30 loops=10)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 1409976
                                 Index Searches: 1
                                 Buffers: shared hit=14317536
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '9', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.529 ms
 Execution Time: 968.825 ms

-- 10

 WindowAgg  (cost=546942.84..548347.32 rows=70225 width=80) (actual time=891.207..917.014 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317698
   ->  Sort  (cost=546942.82..547118.38 rows=70225 width=48) (actual time=891.197..916.293 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317698
         ->  GroupAggregate  (cost=538226.17..541289.81 rows=70225 width=48) (actual time=863.094..915.616 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317698
               ->  Gather Merge  (cost=538226.17..539709.22 rows=70296 width=40) (actual time=863.083..906.423 rows=204053.00 loops=1)
                     Workers Planned: 10
                     Workers Launched: 10
                     Buffers: shared hit=14317698
                     ->  Sort  (cost=538224.98..538242.56 rows=7030 width=40) (actual time=857.229..857.830 rows=18550.27 loops=11)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1334kB
                           Buffers: shared hit=14317698
                           Worker 0:  Sort Method: quicksort  Memory: 1285kB
                           Worker 1:  Sort Method: quicksort  Memory: 1300kB
                           Worker 2:  Sort Method: quicksort  Memory: 1300kB
                           Worker 3:  Sort Method: quicksort  Memory: 1292kB
                           Worker 4:  Sort Method: quicksort  Memory: 1298kB
                           Worker 5:  Sort Method: quicksort  Memory: 1292kB
                           Worker 6:  Sort Method: quicksort  Memory: 1429kB
                           Worker 7:  Sort Method: quicksort  Memory: 1436kB
                           Worker 8:  Sort Method: quicksort  Memory: 1430kB
                           Worker 9:  Sort Method: quicksort  Memory: 1434kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..537775.79 rows=7030 width=40) (actual time=0.118..852.539 rows=18550.27 loops=11)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 1281796
                                 Index Searches: 1
                                 Buffers: shared hit=14317538
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '10', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.578 ms
 Execution Time: 917.137 ms

-- 12

 WindowAgg  (cost=546942.84..548347.32 rows=70225 width=80) (actual time=895.098..922.761 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317696
   ->  Sort  (cost=546942.82..547118.38 rows=70225 width=48) (actual time=895.088..922.044 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317696
         ->  GroupAggregate  (cost=538226.17..541289.81 rows=70225 width=48) (actual time=867.155..921.375 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317696
               ->  Gather Merge  (cost=538226.17..539709.22 rows=70296 width=40) (actual time=867.146..912.166 rows=204053.00 loops=1)
                     Workers Planned: 10
                     Workers Launched: 10
                     Buffers: shared hit=14317696
                     ->  Sort  (cost=538224.98..538242.56 rows=7030 width=40) (actual time=861.619..862.221 rows=18550.27 loops=11)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1357kB
                           Buffers: shared hit=14317696
                           Worker 0:  Sort Method: quicksort  Memory: 1291kB
                           Worker 1:  Sort Method: quicksort  Memory: 1291kB
                           Worker 2:  Sort Method: quicksort  Memory: 1294kB
                           Worker 3:  Sort Method: quicksort  Memory: 1298kB
                           Worker 4:  Sort Method: quicksort  Memory: 1428kB
                           Worker 5:  Sort Method: quicksort  Memory: 1287kB
                           Worker 6:  Sort Method: quicksort  Memory: 1428kB
                           Worker 7:  Sort Method: quicksort  Memory: 1437kB
                           Worker 8:  Sort Method: quicksort  Memory: 1426kB
                           Worker 9:  Sort Method: quicksort  Memory: 1292kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..537775.79 rows=7030 width=40) (actual time=0.147..856.959 rows=18550.27 loops=11)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 1281796
                                 Index Searches: 1
                                 Buffers: shared hit=14317536
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '12', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.409 ms
 Execution Time: 922.861 ms

-- 16

 WindowAgg  (cost=546942.84..548347.32 rows=70225 width=80) (actual time=889.270..917.873 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317696
   ->  Sort  (cost=546942.82..547118.38 rows=70225 width=48) (actual time=889.260..917.083 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317696
         ->  GroupAggregate  (cost=538226.17..541289.81 rows=70225 width=48) (actual time=861.669..916.413 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317696
               ->  Gather Merge  (cost=538226.17..539709.22 rows=70296 width=40) (actual time=861.660..907.386 rows=204053.00 loops=1)
                     Workers Planned: 10
                     Workers Launched: 10
                     Buffers: shared hit=14317696
                     ->  Sort  (cost=538224.98..538242.56 rows=7030 width=40) (actual time=855.912..856.520 rows=18550.27 loops=11)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1478kB
                           Buffers: shared hit=14317696
                           Worker 0:  Sort Method: quicksort  Memory: 1284kB
                           Worker 1:  Sort Method: quicksort  Memory: 1292kB
                           Worker 2:  Sort Method: quicksort  Memory: 1417kB
                           Worker 3:  Sort Method: quicksort  Memory: 1291kB
                           Worker 4:  Sort Method: quicksort  Memory: 1297kB
                           Worker 5:  Sort Method: quicksort  Memory: 1289kB
                           Worker 6:  Sort Method: quicksort  Memory: 1298kB
                           Worker 7:  Sort Method: quicksort  Memory: 1433kB
                           Worker 8:  Sort Method: quicksort  Memory: 1314kB
                           Worker 9:  Sort Method: quicksort  Memory: 1437kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..537775.79 rows=7030 width=40) (actual time=0.232..851.132 rows=18550.27 loops=11)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 1281796
                                 Index Searches: 1
                                 Buffers: shared hit=14317536
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '16', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.368 ms
 Execution Time: 917.974 ms
```

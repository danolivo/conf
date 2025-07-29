CREATE INDEX idx_2 ON order_events (event_created, event_type);
```
-- 0

 WindowAgg  (cost=3789837.03..3791241.51 rows=70225 width=80) (actual time=1322.517..1323.204 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=313925
   ->  Sort  (cost=3789837.01..3790012.58 rows=70225 width=48) (actual time=1322.508..1322.553 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=313925
         ->  GroupAggregate  (cost=3782427.67..3784184.01 rows=70225 width=48) (actual time=1308.099..1321.960 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=313925
               ->  Sort  (cost=3782427.67..3782603.41 rows=70296 width=40) (actual time=1308.090..1313.073 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=313925
                     ->  Bitmap Heap Scan on order_events  (cost=374561.17..3776768.44 rows=70296 width=40) (actual time=647.180..1280.627 rows=204053.00 loops=1)
                           Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                           Rows Removed by Filter: 4292642
                           Heap Blocks: exact=269237
                           Buffers: shared hit=313925
                           ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=616.781..616.782 rows=4496695.00 loops=1)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Index Searches: 1
                                 Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.409 ms
 Execution Time: 1323.291 ms

-- 1

 WindowAgg  (cost=3739491.43..3740895.91 rows=70225 width=80) (actual time=1093.891..1126.949 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=313961
   ->  Sort  (cost=3739491.41..3739666.97 rows=70225 width=48) (actual time=1093.882..1126.297 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=313961
         ->  GroupAggregate  (cost=3731553.40..3733838.40 rows=70225 width=48) (actual time=1071.307..1125.692 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=313961
               ->  Gather Merge  (cost=3731553.40..3732257.81 rows=70296 width=40) (actual time=1071.298..1117.682 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=313961
                     ->  Sort  (cost=3731552.39..3731655.77 rows=41351 width=40) (actual time=1067.798..1070.400 rows=102026.50 loops=2)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 6500kB
                           Buffers: shared hit=313961
                           Worker 0:  Sort Method: quicksort  Memory: 6022kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3728381.67 rows=41351 width=40) (actual time=686.436..1053.073 rows=102026.50 loops=2)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 2146321
                                 Heap Blocks: exact=145337
                                 Buffers: shared hit=313945
                                 Worker 0:  Heap Blocks: exact=123900
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=650.914..650.914 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.513 ms
 Execution Time: 1127.069 ms

-- 2

 WindowAgg  (cost=3718508.06..3719912.54 rows=70225 width=80) (actual time=1037.060..1075.406 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=313997
   ->  Sort  (cost=3718508.04..3718683.60 rows=70225 width=48) (actual time=1037.051..1074.688 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=313997
         ->  GroupAggregate  (cost=3710394.58..3712855.03 rows=70225 width=48) (actual time=1010.534..1074.028 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=313997
               ->  Gather Merge  (cost=3710394.58..3711274.44 rows=70296 width=40) (actual time=1010.525..1065.132 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=313997
                     ->  Sort  (cost=3710393.56..3710466.78 rows=29290 width=40) (actual time=1006.658..1008.427 rows=68017.67 loops=3)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 5528kB
                           Buffers: shared hit=313997
                           Worker 0:  Sort Method: quicksort  Memory: 3493kB
                           Worker 1:  Sort Method: quicksort  Memory: 3501kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3708220.51 rows=29290 width=40) (actual time=708.280..995.741 rows=68017.67 loops=3)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 1430881
                                 Heap Blocks: exact=104880
                                 Buffers: shared hit=313965
                                 Worker 0:  Heap Blocks: exact=82038
                                 Worker 1:  Heap Blocks: exact=82319
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=672.444..672.445 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.322 ms
 Execution Time: 1075.500 ms

-- 3

 WindowAgg  (cost=3707048.74..3708453.22 rows=70225 width=80) (actual time=985.553..1014.027 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314033
   ->  Sort  (cost=3707048.72..3707224.28 rows=70225 width=48) (actual time=985.544..1013.305 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314033
         ->  GroupAggregate  (cost=3698805.92..3701395.71 rows=70225 width=48) (actual time=960.058..1012.644 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314033
               ->  Gather Merge  (cost=3698805.92..3699815.12 rows=70296 width=40) (actual time=960.049..1004.170 rows=204053.00 loops=1)
                     Workers Planned: 3
                     Workers Launched: 3
                     Buffers: shared hit=314033
                     ->  Sort  (cost=3698804.88..3698861.57 rows=22676 width=40) (actual time=955.065..956.318 rows=51013.25 loops=4)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3488kB
                           Buffers: shared hit=314033
                           Worker 0:  Sort Method: quicksort  Memory: 2970kB
                           Worker 1:  Sort Method: quicksort  Memory: 3022kB
                           Worker 2:  Sort Method: quicksort  Memory: 3042kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3697164.40 rows=22676 width=40) (actual time=707.963..946.585 rows=51013.25 loops=4)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 1073160
                                 Heap Blocks: exact=84004
                                 Buffers: shared hit=313985
                                 Worker 0:  Heap Blocks: exact=59853
                                 Worker 1:  Heap Blocks: exact=62593
                                 Worker 2:  Heap Blocks: exact=62787
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=673.116..673.117 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '3', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.501 ms
 Execution Time: 1014.134 ms

-- 4

 WindowAgg  (cost=3698218.74..3699623.22 rows=70225 width=80) (actual time=943.824..973.702 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314069
   ->  Sort  (cost=3698218.72..3698394.28 rows=70225 width=48) (actual time=943.815..972.973 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314069
         ->  GroupAggregate  (cost=3689875.52..3692565.71 rows=70225 width=48) (actual time=917.874..972.326 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314069
               ->  Gather Merge  (cost=3689875.52..3690985.12 rows=70296 width=40) (actual time=917.863..963.626 rows=204053.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     Buffers: shared hit=314069
                     ->  Sort  (cost=3689874.46..3689918.40 rows=17574 width=40) (actual time=911.488..912.652 rows=40810.60 loops=5)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3330kB
                           Buffers: shared hit=314069
                           Worker 0:  Sort Method: quicksort  Memory: 2850kB
                           Worker 1:  Sort Method: quicksort  Memory: 1431kB
                           Worker 2:  Sort Method: quicksort  Memory: 2842kB
                           Worker 3:  Sort Method: quicksort  Memory: 2840kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3688635.39 rows=17574 width=40) (actual time=681.727..904.083 rows=40810.60 loops=5)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 858528
                                 Heap Blocks: exact=76568
                                 Buffers: shared hit=314005
                                 Worker 0:  Heap Blocks: exact=54612
                                 Worker 1:  Heap Blocks: exact=28780
                                 Worker 2:  Heap Blocks: exact=54581
                                 Worker 3:  Heap Blocks: exact=54696
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=647.856..647.856 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '4', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.530 ms
 Execution Time: 973.824 ms

-- 5

 WindowAgg  (cost=3692156.42..3693560.90 rows=70225 width=80) (actual time=918.358..945.216 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314105
   ->  Sort  (cost=3692156.40..3692331.97 rows=70225 width=48) (actual time=918.350..944.469 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314105
         ->  GroupAggregate  (cost=3683729.54..3686503.40 rows=70225 width=48) (actual time=891.775..943.790 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314105
               ->  Gather Merge  (cost=3683729.54..3684922.80 rows=70296 width=40) (actual time=891.765..935.273 rows=204053.00 loops=1)
                     Workers Planned: 5
                     Workers Launched: 5
                     Buffers: shared hit=314105
                     ->  Sort  (cost=3683728.46..3683763.61 rows=14059 width=40) (actual time=888.252..889.397 rows=34008.83 loops=6)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3193kB
                           Buffers: shared hit=314105
                           Worker 0:  Sort Method: quicksort  Memory: 1385kB
                           Worker 1:  Sort Method: quicksort  Memory: 2599kB
                           Worker 2:  Sort Method: quicksort  Memory: 1382kB
                           Worker 3:  Sort Method: quicksort  Memory: 2744kB
                           Worker 4:  Sort Method: quicksort  Memory: 2756kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3682759.85 rows=14059 width=40) (actual time=668.893..881.676 rows=34008.83 loops=6)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 715440
                                 Heap Blocks: exact=70484
                                 Buffers: shared hit=314025
                                 Worker 0:  Heap Blocks: exact=25932
                                 Worker 1:  Heap Blocks: exact=45057
                                 Worker 2:  Heap Blocks: exact=26106
                                 Worker 3:  Heap Blocks: exact=50802
                                 Worker 4:  Heap Blocks: exact=50856
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=632.773..632.773 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '5', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.125 ms
 Execution Time: 945.285 ms

-- 6

 WindowAgg  (cost=3688134.90..3689539.38 rows=70225 width=80) (actual time=922.413..955.951 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314141
   ->  Sort  (cost=3688134.88..3688310.44 rows=70225 width=48) (actual time=922.403..955.218 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314141
         ->  GroupAggregate  (cost=3679635.71..3682481.87 rows=70225 width=48) (actual time=896.204..954.568 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314141
               ->  Gather Merge  (cost=3679635.71..3680901.28 rows=70296 width=40) (actual time=896.194..946.146 rows=204053.00 loops=1)
                     Workers Planned: 6
                     Workers Launched: 6
                     Buffers: shared hit=314141
                     ->  Sort  (cost=3679634.61..3679663.90 rows=11716 width=40) (actual time=890.078..891.076 rows=29150.43 loops=7)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3005kB
                           Buffers: shared hit=314141
                           Worker 0:  Sort Method: quicksort  Memory: 2574kB
                           Worker 1:  Sort Method: quicksort  Memory: 1325kB
                           Worker 2:  Sort Method: quicksort  Memory: 1322kB
                           Worker 3:  Sort Method: quicksort  Memory: 2628kB
                           Worker 4:  Sort Method: quicksort  Memory: 1694kB
                           Worker 5:  Sort Method: quicksort  Memory: 1512kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3678842.83 rows=11716 width=40) (actual time=682.329..884.100 rows=29150.43 loops=7)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 613235
                                 Heap Blocks: exact=62535
                                 Buffers: shared hit=314045
                                 Worker 0:  Heap Blocks: exact=43822
                                 Worker 1:  Heap Blocks: exact=23547
                                 Worker 2:  Heap Blocks: exact=23465
                                 Worker 3:  Heap Blocks: exact=45731
                                 Worker 4:  Heap Blocks: exact=39279
                                 Worker 5:  Heap Blocks: exact=30858
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=648.606..648.606 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '6', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.429 ms
 Execution Time: 956.056 ms

-- 7

 WindowAgg  (cost=3685276.27..3686680.75 rows=70225 width=80) (actual time=907.887..935.123 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314177
   ->  Sort  (cost=3685276.25..3685451.81 rows=70225 width=48) (actual time=907.876..934.401 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314177
         ->  GroupAggregate  (cost=3676713.56..3679623.25 rows=70225 width=48) (actual time=881.331..933.730 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314177
               ->  Gather Merge  (cost=3676713.56..3678042.65 rows=70296 width=40) (actual time=881.319..925.126 rows=204053.00 loops=1)
                     Workers Planned: 7
                     Workers Launched: 7
                     Buffers: shared hit=314177
                     ->  Sort  (cost=3676712.44..3676737.54 rows=10042 width=40) (actual time=874.386..875.321 rows=25506.62 loops=8)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1779kB
                           Buffers: shared hit=314177
                           Worker 0:  Sort Method: quicksort  Memory: 1772kB
                           Worker 1:  Sort Method: quicksort  Memory: 1308kB
                           Worker 2:  Sort Method: quicksort  Memory: 1310kB
                           Worker 3:  Sort Method: quicksort  Memory: 1467kB
                           Worker 4:  Sort Method: quicksort  Memory: 1308kB
                           Worker 5:  Sort Method: quicksort  Memory: 1792kB
                           Worker 6:  Sort Method: quicksort  Memory: 1789kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3676044.96 rows=10042 width=40) (actual time=668.668..868.664 rows=25506.62 loops=8)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 536580
                                 Heap Blocks: exact=42416
                                 Buffers: shared hit=314065
                                 Worker 0:  Heap Blocks: exact=42351
                                 Worker 1:  Heap Blocks: exact=22705
                                 Worker 2:  Heap Blocks: exact=23277
                                 Worker 3:  Heap Blocks: exact=30105
                                 Worker 4:  Heap Blocks: exact=22690
                                 Worker 5:  Heap Blocks: exact=42856
                                 Worker 6:  Heap Blocks: exact=42837
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=634.936..634.936 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '7', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.463 ms
 Execution Time: 935.231 ms

-- 8

 WindowAgg  (cost=3683142.60..3684547.08 rows=70225 width=80) (actual time=940.463..963.994 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314213
   ->  Sort  (cost=3683142.58..3683318.14 rows=70225 width=48) (actual time=940.449..962.788 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314213
         ->  GroupAggregate  (cost=3674523.29..3677489.57 rows=70225 width=48) (actual time=912.104..961.929 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314213
               ->  Gather Merge  (cost=3674523.29..3675908.98 rows=70296 width=40) (actual time=912.094..952.537 rows=204053.00 loops=1)
                     Workers Planned: 8
                     Workers Launched: 8
                     Buffers: shared hit=314213
                     ->  Sort  (cost=3674522.15..3674544.12 rows=8787 width=40) (actual time=905.567..906.381 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1448kB
                           Buffers: shared hit=314213
                           Worker 0:  Sort Method: quicksort  Memory: 1682kB
                           Worker 1:  Sort Method: quicksort  Memory: 1529kB
                           Worker 2:  Sort Method: quicksort  Memory: 1679kB
                           Worker 3:  Sort Method: quicksort  Memory: 1282kB
                           Worker 4:  Sort Method: quicksort  Memory: 1343kB
                           Worker 5:  Sort Method: quicksort  Memory: 1616kB
                           Worker 6:  Sort Method: quicksort  Memory: 1439kB
                           Worker 7:  Sort Method: quicksort  Memory: 891kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3673946.55 rows=8787 width=40) (actual time=700.153..900.212 rows=22672.56 loops=9)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 476960
                                 Heap Blocks: exact=29506
                                 Buffers: shared hit=314085
                                 Worker 0:  Heap Blocks: exact=38576
                                 Worker 1:  Heap Blocks: exact=31724
                                 Worker 2:  Heap Blocks: exact=38295
                                 Worker 3:  Heap Blocks: exact=21654
                                 Worker 4:  Heap Blocks: exact=24072
                                 Worker 5:  Heap Blocks: exact=34477
                                 Worker 6:  Heap Blocks: exact=29600
                                 Worker 7:  Heap Blocks: exact=21333
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=664.297..664.297 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '8', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.552 ms
 Execution Time: 964.145 ms

-- 9

 WindowAgg  (cost=3681490.95..3682895.43 rows=70225 width=80) (actual time=911.864..943.048 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314249
   ->  Sort  (cost=3681490.93..3681666.49 rows=70225 width=48) (actual time=911.853..942.327 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314249
         ->  GroupAggregate  (cost=3672820.66..3675837.92 rows=70225 width=48) (actual time=885.033..941.648 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314249
               ->  Gather Merge  (cost=3672820.66..3674257.33 rows=70296 width=40) (actual time=885.020..933.094 rows=204053.00 loops=1)
                     Workers Planned: 9
                     Workers Launched: 9
                     Buffers: shared hit=314249
                     ->  Sort  (cost=3672819.49..3672839.02 rows=7811 width=40) (actual time=877.750..878.544 rows=20405.30 loops=10)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1421kB
                           Buffers: shared hit=314249
                           Worker 0:  Sort Method: quicksort  Memory: 1631kB
                           Worker 1:  Sort Method: quicksort  Memory: 861kB
                           Worker 2:  Sort Method: quicksort  Memory: 1629kB
                           Worker 3:  Sort Method: quicksort  Memory: 1325kB
                           Worker 4:  Sort Method: quicksort  Memory: 1459kB
                           Worker 5:  Sort Method: quicksort  Memory: 864kB
                           Worker 6:  Sort Method: quicksort  Memory: 859kB
                           Worker 7:  Sort Method: quicksort  Memory: 1604kB
                           Worker 8:  Sort Method: quicksort  Memory: 873kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3672314.46 rows=7811 width=40) (actual time=681.578..872.696 rows=20405.30 loops=10)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 429264
                                 Heap Blocks: exact=28177
                                 Buffers: shared hit=314105
                                 Worker 0:  Heap Blocks: exact=36601
                                 Worker 1:  Heap Blocks: exact=20169
                                 Worker 2:  Heap Blocks: exact=35639
                                 Worker 3:  Heap Blocks: exact=23199
                                 Worker 4:  Heap Blocks: exact=28970
                                 Worker 5:  Heap Blocks: exact=20157
                                 Worker 6:  Heap Blocks: exact=20039
                                 Worker 7:  Heap Blocks: exact=34957
                                 Worker 8:  Heap Blocks: exact=21329
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=647.547..647.547 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '9', max_parallel_workers = '16', enable_seqscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.588 ms
 Execution Time: 943.180 ms

-- 10

 WindowAgg  (cost=3680175.84..3681580.32 rows=70225 width=80) (actual time=934.420..965.027 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314285
   ->  Sort  (cost=3680175.82..3680351.38 rows=70225 width=48) (actual time=934.405..963.915 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314285
         ->  GroupAggregate  (cost=3671459.17..3674522.81 rows=70225 width=48) (actual time=906.780..963.075 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314285
               ->  Gather Merge  (cost=3671459.17..3672942.21 rows=70296 width=40) (actual time=906.765..954.304 rows=204053.00 loops=1)
                     Workers Planned: 10
                     Workers Launched: 10
                     Buffers: shared hit=314285
                     ->  Sort  (cost=3671457.98..3671475.55 rows=7030 width=40) (actual time=899.986..900.709 rows=18550.27 loops=11)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1368kB
                           Buffers: shared hit=314285
                           Worker 0:  Sort Method: quicksort  Memory: 1346kB
                           Worker 1:  Sort Method: quicksort  Memory: 876kB
                           Worker 2:  Sort Method: quicksort  Memory: 1568kB
                           Worker 3:  Sort Method: quicksort  Memory: 832kB
                           Worker 4:  Sort Method: quicksort  Memory: 1431kB
                           Worker 5:  Sort Method: quicksort  Memory: 1491kB
                           Worker 6:  Sort Method: quicksort  Memory: 826kB
                           Worker 7:  Sort Method: quicksort  Memory: 1361kB
                           Worker 8:  Sort Method: quicksort  Memory: 818kB
                           Worker 9:  Sort Method: quicksort  Memory: 1377kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3671008.78 rows=7030 width=40) (actual time=709.412..895.177 rows=18550.27 loops=11)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 390240
                                 Heap Blocks: exact=25612
                                 Buffers: shared hit=314125
                                 Worker 0:  Heap Blocks: exact=23467
                                 Worker 1:  Heap Blocks: exact=21815
                                 Worker 2:  Heap Blocks: exact=33719
                                 Worker 3:  Heap Blocks: exact=18744
                                 Worker 4:  Heap Blocks: exact=26963
                                 Worker 5:  Heap Blocks: exact=30649
                                 Worker 6:  Heap Blocks: exact=18824
                                 Worker 7:  Heap Blocks: exact=25474
                                 Worker 8:  Heap Blocks: exact=18599
                                 Worker 9:  Heap Blocks: exact=25371
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=674.941..674.942 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '10', max_parallel_workers = '16', enable_seqscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.578 ms
 Execution Time: 965.176 ms

-- 12

WindowAgg  (cost=3678216.56..3679621.04 rows=70225 width=80) (actual time=906.059..926.161 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314357
   ->  Sort  (cost=3678216.54..3678392.10 rows=70225 width=48) (actual time=906.047..925.422 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314357
         ->  GroupAggregate  (cost=3669418.11..3672563.53 rows=70225 width=48) (actual time=878.359..924.693 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314357
               ->  Gather Merge  (cost=3669418.11..3670982.94 rows=70296 width=40) (actual time=878.344..915.908 rows=204053.00 loops=1)
                     Workers Planned: 12
                     Workers Launched: 12
                     Buffers: shared hit=314357
                     ->  Sort  (cost=3669416.87..3669431.51 rows=5858 width=40) (actual time=870.322..870.904 rows=15696.38 loops=13)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1357kB
                           Buffers: shared hit=314357
                           Worker 0:  Sort Method: quicksort  Memory: 871kB
                           Worker 1:  Sort Method: quicksort  Memory: 874kB
                           Worker 2:  Sort Method: quicksort  Memory: 802kB
                           Worker 3:  Sort Method: quicksort  Memory: 823kB
                           Worker 4:  Sort Method: quicksort  Memory: 887kB
                           Worker 5:  Sort Method: quicksort  Memory: 879kB
                           Worker 6:  Sort Method: quicksort  Memory: 817kB
                           Worker 7:  Sort Method: quicksort  Memory: 801kB
                           Worker 8:  Sort Method: quicksort  Memory: 870kB
                           Worker 9:  Sort Method: quicksort  Memory: 896kB
                           Worker 10:  Sort Method: quicksort  Memory: 1335kB
                           Worker 11:  Sort Method: quicksort  Memory: 1315kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3669050.27 rows=5858 width=40) (actual time=682.164..865.800 rows=15696.38 loops=13)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 330203
                                 Heap Blocks: exact=25336
                                 Buffers: shared hit=314165
                                 Worker 0:  Heap Blocks: exact=20361
                                 Worker 1:  Heap Blocks: exact=20647
                                 Worker 2:  Heap Blocks: exact=17600
                                 Worker 3:  Heap Blocks: exact=18514
                                 Worker 4:  Heap Blocks: exact=20890
                                 Worker 5:  Heap Blocks: exact=20230
                                 Worker 6:  Heap Blocks: exact=18686
                                 Worker 7:  Heap Blocks: exact=17606
                                 Worker 8:  Heap Blocks: exact=20677
                                 Worker 9:  Heap Blocks: exact=21393
                                 Worker 10:  Heap Blocks: exact=23903
                                 Worker 11:  Heap Blocks: exact=23394
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=649.510..649.510 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '12', max_parallel_workers = '16', enable_seqscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.641 ms
 Execution Time: 926.292 ms

-- 16

 WindowAgg  (cost=3676830.18..3678234.66 rows=70225 width=80) (actual time=911.906..927.024 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=314429
   ->  Sort  (cost=3676830.16..3677005.72 rows=70225 width=48) (actual time=911.890..925.821 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=314429
         ->  GroupAggregate  (cost=3667961.26..3671177.15 rows=70225 width=48) (actual time=881.672..924.987 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=314429
               ->  Gather Merge  (cost=3667961.26..3669596.56 rows=70296 width=40) (actual time=881.657..915.420 rows=204053.00 loops=1)
                     Workers Planned: 14
                     Workers Launched: 14
                     Buffers: shared hit=314429
                     ->  Sort  (cost=3667959.97..3667972.52 rows=5021 width=40) (actual time=875.049..875.569 rows=13603.53 loops=15)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1333kB
                           Buffers: shared hit=314429
                           Worker 0:  Sort Method: quicksort  Memory: 789kB
                           Worker 1:  Sort Method: quicksort  Memory: 804kB
                           Worker 2:  Sort Method: quicksort  Memory: 779kB
                           Worker 3:  Sort Method: quicksort  Memory: 797kB
                           Worker 4:  Sort Method: quicksort  Memory: 832kB
                           Worker 5:  Sort Method: quicksort  Memory: 800kB
                           Worker 6:  Sort Method: quicksort  Memory: 803kB
                           Worker 7:  Sort Method: quicksort  Memory: 792kB
                           Worker 8:  Sort Method: quicksort  Memory: 782kB
                           Worker 9:  Sort Method: quicksort  Memory: 822kB
                           Worker 10:  Sort Method: quicksort  Memory: 803kB
                           Worker 11:  Sort Method: quicksort  Memory: 797kB
                           Worker 12:  Sort Method: quicksort  Memory: 787kB
                           Worker 13:  Sort Method: quicksort  Memory: 808kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=374561.17..3667651.33 rows=5021 width=40) (actual time=677.223..870.697 rows=13603.53 loops=15)
                                 Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 286176
                                 Heap Blocks: exact=23746
                                 Buffers: shared hit=314205
                                 Worker 0:  Heap Blocks: exact=17313
                                 Worker 1:  Heap Blocks: exact=17675
                                 Worker 2:  Heap Blocks: exact=16917
                                 Worker 3:  Heap Blocks: exact=17649
                                 Worker 4:  Heap Blocks: exact=18567
                                 Worker 5:  Heap Blocks: exact=17701
                                 Worker 6:  Heap Blocks: exact=17639
                                 Worker 7:  Heap Blocks: exact=17549
                                 Worker 8:  Heap Blocks: exact=16887
                                 Worker 9:  Heap Blocks: exact=18282
                                 Worker 10:  Heap Blocks: exact=17146
                                 Worker 11:  Heap Blocks: exact=17480
                                 Worker 12:  Heap Blocks: exact=16903
                                 Worker 13:  Heap Blocks: exact=17783
                                 ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=643.544..643.545 rows=4496695.00 loops=1)
                                       Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                       Index Searches: 1
                                       Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '16', max_parallel_workers = '16', enable_seqscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.463 ms
 Execution Time: 927.164 ms
```

# IndexScan scalability (0..20)
`SET enable_bitmapscan = 'off';`

```
-- 0

 WindowAgg  (cost=7610680.89..7612085.37 rows=70225 width=80) (actual time=2888.819..2889.497 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4509185
   ->  Sort  (cost=7610680.87..7610856.43 rows=70225 width=48) (actual time=2888.811..2888.855 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4509185
         ->  GroupAggregate  (cost=7603271.52..7605027.86 rows=70225 width=48) (actual time=2875.738..2888.265 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4509185
               ->  Sort  (cost=7603271.52..7603447.26 rows=70296 width=40) (actual time=2875.731..2879.594 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=4509185
                     ->  Index Scan using idx_2 on order_events  (cost=0.57..7597612.29 rows=70296 width=40) (actual time=0.145..2854.308 rows=204053.00 loops=1)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                           Rows Removed by Filter: 4292642
                           Index Searches: 1
                           Buffers: shared hit=4509185
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.367 ms
 Execution Time: 2889.583 ms

-- 1

 WindowAgg  (cost=7577220.00..7578624.48 rows=70225 width=80) (actual time=1413.383..1446.596 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4509795
   ->  Sort  (cost=7577219.98..7577395.54 rows=70225 width=48) (actual time=1413.376..1445.929 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4509795
         ->  GroupAggregate  (cost=7569281.97..7571566.97 rows=70225 width=48) (actual time=1392.233..1445.309 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4509795
               ->  Gather Merge  (cost=7569281.97..7569986.37 rows=70296 width=40) (actual time=1392.225..1437.556 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=4509795
                     ->  Sort  (cost=7569280.96..7569384.33 rows=41351 width=40) (actual time=1389.687..1391.721 rows=102026.50 loops=2)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 6337kB
                           Buffers: shared hit=4509795
                           Worker 0:  Sort Method: quicksort  Memory: 6184kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7566110.24 rows=41351 width=40) (actual time=0.258..1377.574 rows=102026.50 loops=2)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 2146321
                                 Index Searches: 1
                                 Buffers: shared hit=4509779
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.383 ms
 Execution Time: 1446.690 ms

-- 2

 WindowAgg  (cost=7563271.92..7564676.40 rows=70225 width=80) (actual time=1024.663..1072.765 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4509928
   ->  Sort  (cost=7563271.90..7563447.47 rows=70225 width=48) (actual time=1024.655..1072.046 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4509928
         ->  GroupAggregate  (cost=7555158.44..7557618.90 rows=70225 width=48) (actual time=998.535..1071.391 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4509928
               ->  Gather Merge  (cost=7555158.44..7556038.30 rows=70296 width=40) (actual time=998.526..1062.368 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=4509928
                     ->  Sort  (cost=7555157.42..7555230.65 rows=29290 width=40) (actual time=996.082..997.529 rows=68017.67 loops=3)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 5288kB
                           Buffers: shared hit=4509928
                           Worker 0:  Sort Method: quicksort  Memory: 5153kB
                           Worker 1:  Sort Method: quicksort  Memory: 5153kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7552984.38 rows=29290 width=40) (actual time=0.280..986.812 rows=68017.67 loops=3)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 1430881
                                 Index Searches: 1
                                 Buffers: shared hit=4509896
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.295 ms
 Execution Time: 1072.861 ms

 -- 3

  WindowAgg  (cost=7555670.67..7557075.15 rows=70225 width=80) (actual time=817.639..854.188 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4509989
   ->  Sort  (cost=7555670.65..7555846.21 rows=70225 width=48) (actual time=817.630..853.473 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4509989
         ->  GroupAggregate  (cost=7547427.85..7550017.64 rows=70225 width=48) (actual time=791.465..852.810 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4509989
               ->  Gather Merge  (cost=7547427.85..7548437.05 rows=70296 width=40) (actual time=791.456..843.666 rows=204053.00 loops=1)
                     Workers Planned: 3
                     Workers Launched: 3
                     Buffers: shared hit=4509989
                     ->  Sort  (cost=7547426.81..7547483.50 rows=22676 width=40) (actual time=786.703..787.812 rows=51013.25 loops=4)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3233kB
                           Buffers: shared hit=4509989
                           Worker 0:  Sort Method: quicksort  Memory: 3101kB
                           Worker 1:  Sort Method: quicksort  Memory: 3098kB
                           Worker 2:  Sort Method: quicksort  Memory: 3091kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7545786.33 rows=22676 width=40) (actual time=0.335..779.569 rows=51013.25 loops=4)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 1073160
                                 Index Searches: 1
                                 Buffers: shared hit=4509941
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '3', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.544 ms
 Execution Time: 854.301 ms

-- 4

 WindowAgg  (cost=7549816.89..7551221.37 rows=70225 width=80) (actual time=710.911..752.515 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4510067
   ->  Sort  (cost=7549816.87..7549992.43 rows=70225 width=48) (actual time=710.902..751.795 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4510067
         ->  GroupAggregate  (cost=7541473.67..7544163.86 rows=70225 width=48) (actual time=685.183..751.138 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4510067
               ->  Gather Merge  (cost=7541473.67..7542583.27 rows=70296 width=40) (actual time=685.174..742.476 rows=204053.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     Buffers: shared hit=4510067
                     ->  Sort  (cost=7541472.61..7541516.55 rows=17574 width=40) (actual time=680.793..681.805 rows=40810.60 loops=5)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2993kB
                           Buffers: shared hit=4510067
                           Worker 0:  Sort Method: quicksort  Memory: 1710kB
                           Worker 1:  Sort Method: quicksort  Memory: 2866kB
                           Worker 2:  Sort Method: quicksort  Memory: 2865kB
                           Worker 3:  Sort Method: quicksort  Memory: 2857kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7540233.55 rows=17574 width=40) (actual time=0.289..674.407 rows=40810.60 loops=5)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 858528
                                 Index Searches: 1
                                 Buffers: shared hit=4510003
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '4', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.404 ms
 Execution Time: 752.616 ms

-- 5

 WindowAgg  (cost=7545804.86..7547209.34 rows=70225 width=80) (actual time=644.529..686.634 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4510157
   ->  Sort  (cost=7545804.84..7545980.41 rows=70225 width=48) (actual time=644.520..685.907 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4510157
         ->  GroupAggregate  (cost=7537377.98..7540151.84 rows=70225 width=48) (actual time=618.484..685.242 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4510157
               ->  Gather Merge  (cost=7537377.98..7538571.24 rows=70296 width=40) (actual time=618.475..676.594 rows=204053.00 loops=1)
                     Workers Planned: 5
                     Workers Launched: 5
                     Buffers: shared hit=4510157
                     ->  Sort  (cost=7537376.90..7537412.05 rows=14059 width=40) (actual time=614.375..615.278 rows=34008.83 loops=6)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2650kB
                           Buffers: shared hit=4510157
                           Worker 0:  Sort Method: quicksort  Memory: 2688kB
                           Worker 1:  Sort Method: quicksort  Memory: 1746kB
                           Worker 2:  Sort Method: quicksort  Memory: 1591kB
                           Worker 3:  Sort Method: quicksort  Memory: 2689kB
                           Worker 4:  Sort Method: quicksort  Memory: 2696kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7536408.30 rows=14059 width=40) (actual time=0.306..608.437 rows=34008.83 loops=6)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 715440
                                 Index Searches: 1
                                 Buffers: shared hit=4510077
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '5', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.284 ms
 Execution Time: 686.722 ms

-- 6

 WindowAgg  (cost=7543150.20..7544554.68 rows=70225 width=80) (actual time=588.712..623.720 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4510223
   ->  Sort  (cost=7543150.18..7543325.74 rows=70225 width=48) (actual time=588.702..622.992 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4510223
         ->  GroupAggregate  (cost=7534651.01..7537497.17 rows=70225 width=48) (actual time=562.620..622.325 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4510223
               ->  Gather Merge  (cost=7534651.01..7535916.58 rows=70296 width=40) (actual time=562.610..613.659 rows=204053.00 loops=1)
                     Workers Planned: 6
                     Workers Launched: 6
                     Buffers: shared hit=4510223
                     ->  Sort  (cost=7534649.91..7534679.20 rows=11716 width=40) (actual time=557.341..558.206 rows=29150.43 loops=7)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2684kB
                           Buffers: shared hit=4510223
                           Worker 0:  Sort Method: quicksort  Memory: 1499kB
                           Worker 1:  Sort Method: quicksort  Memory: 1491kB
                           Worker 2:  Sort Method: quicksort  Memory: 1777kB
                           Worker 3:  Sort Method: quicksort  Memory: 1777kB
                           Worker 4:  Sort Method: quicksort  Memory: 1503kB
                           Worker 5:  Sort Method: quicksort  Memory: 2562kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7533858.13 rows=11716 width=40) (actual time=0.288..551.931 rows=29150.43 loops=7)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 613235
                                 Index Searches: 1
                                 Buffers: shared hit=4510127
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '6', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.498 ms
 Execution Time: 623.831 ms

-- 7

 WindowAgg  (cost=7541267.90..7542672.38 rows=70225 width=80) (actual time=557.139..597.826 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4510298
   ->  Sort  (cost=7541267.88..7541443.44 rows=70225 width=48) (actual time=557.129..597.108 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4510298
         ->  GroupAggregate  (cost=7532705.18..7535614.87 rows=70225 width=48) (actual time=531.074..596.449 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4510298
               ->  Gather Merge  (cost=7532705.18..7534034.28 rows=70296 width=40) (actual time=531.065..587.842 rows=204053.00 loops=1)
                     Workers Planned: 7
                     Workers Launched: 7
                     Buffers: shared hit=4510298
                     ->  Sort  (cost=7532704.06..7532729.17 rows=10042 width=40) (actual time=525.549..526.350 rows=25506.62 loops=8)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2584kB
                           Buffers: shared hit=4510298
                           Worker 0:  Sort Method: quicksort  Memory: 1637kB
                           Worker 1:  Sort Method: quicksort  Memory: 1408kB
                           Worker 2:  Sort Method: quicksort  Memory: 1406kB
                           Worker 3:  Sort Method: quicksort  Memory: 1403kB
                           Worker 4:  Sort Method: quicksort  Memory: 1451kB
                           Worker 5:  Sort Method: quicksort  Memory: 1700kB
                           Worker 6:  Sort Method: quicksort  Memory: 1702kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7532036.58 rows=10042 width=40) (actual time=0.290..520.317 rows=25506.62 loops=8)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 536580
                                 Index Searches: 1
                                 Buffers: shared hit=4510186
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '7', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.450 ms
 Execution Time: 597.929 ms

-- 8

 WindowAgg  (cost=7539866.47..7541270.95 rows=70225 width=80) (actual time=526.075..564.039 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4510375 read=1
   ->  Sort  (cost=7539866.45..7540042.01 rows=70225 width=48) (actual time=526.064..563.317 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4510375 read=1
         ->  GroupAggregate  (cost=7531247.16..7534213.44 rows=70225 width=48) (actual time=499.721..562.653 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4510375 read=1
               ->  Gather Merge  (cost=7531247.16..7532632.85 rows=70296 width=40) (actual time=499.710..554.091 rows=204053.00 loops=1)
                     Workers Planned: 8
                     Workers Launched: 8
                     Buffers: shared hit=4510375 read=1
                     ->  Sort  (cost=7531246.02..7531267.99 rows=8787 width=40) (actual time=485.896..486.638 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1679kB
                           Buffers: shared hit=4510375 read=1
                           Worker 0:  Sort Method: quicksort  Memory: 1609kB
                           Worker 1:  Sort Method: quicksort  Memory: 1380kB
                           Worker 2:  Sort Method: quicksort  Memory: 1340kB
                           Worker 3:  Sort Method: quicksort  Memory: 1342kB
                           Worker 4:  Sort Method: quicksort  Memory: 1482kB
                           Worker 5:  Sort Method: quicksort  Memory: 1333kB
                           Worker 6:  Sort Method: quicksort  Memory: 1617kB
                           Worker 7:  Sort Method: quicksort  Memory: 1511kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7530670.42 rows=8787 width=40) (actual time=0.481..481.039 rows=22672.56 loops=9)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 476960
                                 Index Searches: 1
                                 Buffers: shared hit=4510247 read=1
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '8', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.517 ms
 Execution Time: 564.151 ms

 -- 9

  WindowAgg  (cost=7538784.34..7540188.82 rows=70225 width=80) (actual time=492.195..532.191 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4510451
   ->  Sort  (cost=7538784.32..7538959.89 rows=70225 width=48) (actual time=492.185..531.466 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4510451
         ->  GroupAggregate  (cost=7530114.05..7533131.32 rows=70225 width=48) (actual time=462.713..530.771 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4510451
               ->  Gather Merge  (cost=7530114.05..7531550.72 rows=70296 width=40) (actual time=462.702..521.062 rows=204053.00 loops=1)
                     Workers Planned: 9
                     Workers Launched: 9
                     Buffers: shared hit=4510451
                     ->  Sort  (cost=7530112.89..7530132.41 rows=7811 width=40) (actual time=456.649..457.339 rows=20405.30 loops=10)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1399kB
                           Buffers: shared hit=4510451
                           Worker 0:  Sort Method: quicksort  Memory: 1465kB
                           Worker 1:  Sort Method: quicksort  Memory: 1305kB
                           Worker 2:  Sort Method: quicksort  Memory: 1398kB
                           Worker 3:  Sort Method: quicksort  Memory: 1546kB
                           Worker 4:  Sort Method: quicksort  Memory: 1282kB
                           Worker 5:  Sort Method: quicksort  Memory: 1297kB
                           Worker 6:  Sort Method: quicksort  Memory: 1550kB
                           Worker 7:  Sort Method: quicksort  Memory: 1291kB
                           Worker 8:  Sort Method: quicksort  Memory: 1529kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7529607.85 rows=7811 width=40) (actual time=0.199..452.025 rows=20405.30 loops=10)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 429264
                                 Index Searches: 1
                                 Buffers: shared hit=4510307
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '9', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.472 ms
 Execution Time: 532.309 ms

-- 10

 WindowAgg  (cost=7537924.85..7539329.33 rows=70225 width=80) (actual time=468.783..508.355 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4510536
   ->  Sort  (cost=7537924.83..7538100.39 rows=70225 width=48) (actual time=468.772..507.632 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4510536
         ->  GroupAggregate  (cost=7529208.18..7532271.82 rows=70225 width=48) (actual time=441.745..506.968 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4510536
               ->  Gather Merge  (cost=7529208.18..7530691.23 rows=70296 width=40) (actual time=441.728..498.293 rows=204053.00 loops=1)
                     Workers Planned: 10
                     Workers Launched: 10
                     Buffers: shared hit=4510536
                     ->  Sort  (cost=7529206.99..7529224.57 rows=7030 width=40) (actual time=435.217..435.856 rows=18550.27 loops=11)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1542kB
                           Buffers: shared hit=4510536
                           Worker 0:  Sort Method: quicksort  Memory: 869kB
                           Worker 1:  Sort Method: quicksort  Memory: 862kB
                           Worker 2:  Sort Method: quicksort  Memory: 866kB
                           Worker 3:  Sort Method: quicksort  Memory: 864kB
                           Worker 4:  Sort Method: quicksort  Memory: 866kB
                           Worker 5:  Sort Method: quicksort  Memory: 862kB
                           Worker 6:  Sort Method: quicksort  Memory: 1411kB
                           Worker 7:  Sort Method: quicksort  Memory: 1497kB
                           Worker 8:  Sort Method: quicksort  Memory: 1441kB
                           Worker 9:  Sort Method: quicksort  Memory: 1447kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7528757.80 rows=7030 width=40) (actual time=0.281..430.796 rows=18550.27 loops=11)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 390240
                                 Index Searches: 1
                                 Buffers: shared hit=4510376
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '10', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.508 ms
 Execution Time: 508.466 ms

-- 12

 WindowAgg  (cost=7536649.00..7538053.48 rows=70225 width=80) (actual time=445.165..483.177 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4510683
   ->  Sort  (cost=7536648.98..7536824.54 rows=70225 width=48) (actual time=445.155..482.439 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4510683
         ->  GroupAggregate  (cost=7527850.55..7530995.98 rows=70225 width=48) (actual time=418.125..481.778 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4510683
               ->  Gather Merge  (cost=7527850.55..7529415.38 rows=70296 width=40) (actual time=418.116..473.370 rows=204053.00 loops=1)
                     Workers Planned: 12
                     Workers Launched: 12
                     Buffers: shared hit=4510683
                     ->  Sort  (cost=7527849.31..7527863.96 rows=5858 width=40) (actual time=411.216..411.720 rows=15696.38 loops=13)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1473kB
                           Buffers: shared hit=4510683
                           Worker 0:  Sort Method: quicksort  Memory: 824kB
                           Worker 1:  Sort Method: quicksort  Memory: 818kB
                           Worker 2:  Sort Method: quicksort  Memory: 836kB
                           Worker 3:  Sort Method: quicksort  Memory: 820kB
                           Worker 4:  Sort Method: quicksort  Memory: 1405kB
                           Worker 5:  Sort Method: quicksort  Memory: 828kB
                           Worker 6:  Sort Method: quicksort  Memory: 879kB
                           Worker 7:  Sort Method: quicksort  Memory: 1373kB
                           Worker 8:  Sort Method: quicksort  Memory: 819kB
                           Worker 9:  Sort Method: quicksort  Memory: 813kB
                           Worker 10:  Sort Method: quicksort  Memory: 817kB
                           Worker 11:  Sort Method: quicksort  Memory: 822kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7527482.71 rows=5858 width=40) (actual time=0.235..407.025 rows=15696.38 loops=13)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 330203
                                 Index Searches: 1
                                 Buffers: shared hit=4510491
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '12', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.544 ms
 Execution Time: 483.293 ms

-- 16

 WindowAgg  (cost=7535086.89..7536491.37 rows=70225 width=80) (actual time=454.555..492.728 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4510987
   ->  Sort  (cost=7535086.87..7535262.44 rows=70225 width=48) (actual time=454.541..491.605 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4510987
         ->  GroupAggregate  (cost=7526156.08..7529433.87 rows=70225 width=48) (actual time=411.881..490.795 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4510987
               ->  Gather Merge  (cost=7526156.08..7527853.27 rows=70296 width=40) (actual time=411.863..481.637 rows=204053.00 loops=1)
                     Workers Planned: 16
                     Workers Launched: 16
                     Buffers: shared hit=4510987
                     ->  Sort  (cost=7526154.73..7526165.71 rows=4394 width=40) (actual time=402.219..402.614 rows=12003.12 loops=17)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 856kB
                           Buffers: shared hit=4510987
                           Worker 0:  Sort Method: quicksort  Memory: 748kB
                           Worker 1:  Sort Method: quicksort  Memory: 765kB
                           Worker 2:  Sort Method: quicksort  Memory: 768kB
                           Worker 3:  Sort Method: quicksort  Memory: 749kB
                           Worker 4:  Sort Method: quicksort  Memory: 706kB
                           Worker 5:  Sort Method: quicksort  Memory: 774kB
                           Worker 6:  Sort Method: quicksort  Memory: 766kB
                           Worker 7:  Sort Method: quicksort  Memory: 752kB
                           Worker 8:  Sort Method: quicksort  Memory: 758kB
                           Worker 9:  Sort Method: quicksort  Memory: 761kB
                           Worker 10:  Sort Method: quicksort  Memory: 749kB
                           Worker 11:  Sort Method: quicksort  Memory: 718kB
                           Worker 12:  Sort Method: quicksort  Memory: 763kB
                           Worker 13:  Sort Method: quicksort  Memory: 762kB
                           Worker 14:  Sort Method: quicksort  Memory: 760kB
                           Worker 15:  Sort Method: quicksort  Memory: 760kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7525888.86 rows=4394 width=40) (actual time=0.490..398.321 rows=12003.12 loops=17)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 252508
                                 Index Searches: 1
                                 Buffers: shared hit=4510731
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '16', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.563 ms
 Execution Time: 492.875 ms

-- 20

 WindowAgg  (cost=7534176.80..7535581.28 rows=70225 width=80) (actual time=479.159..525.107 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4511291
   ->  Sort  (cost=7534176.78..7534352.34 rows=70225 width=48) (actual time=479.145..523.972 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4511291
         ->  GroupAggregate  (cost=7525141.03..7528523.78 rows=70225 width=48) (actual time=431.758..523.143 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4511291
               ->  Gather Merge  (cost=7525141.03..7526943.18 rows=70296 width=40) (actual time=431.747..513.656 rows=204053.00 loops=1)
                     Workers Planned: 20
                     Workers Launched: 20
                     Buffers: shared hit=4511291
                     ->  Sort  (cost=7525139.57..7525148.36 rows=3515 width=40) (actual time=423.494..423.801 rows=9716.81 loops=21)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 738kB
                           Buffers: shared hit=4511291
                           Worker 0:  Sort Method: quicksort  Memory: 662kB
                           Worker 1:  Sort Method: quicksort  Memory: 687kB
                           Worker 2:  Sort Method: quicksort  Memory: 675kB
                           Worker 3:  Sort Method: quicksort  Memory: 675kB
                           Worker 4:  Sort Method: quicksort  Memory: 694kB
                           Worker 5:  Sort Method: quicksort  Memory: 696kB
                           Worker 6:  Sort Method: quicksort  Memory: 670kB
                           Worker 7:  Sort Method: quicksort  Memory: 676kB
                           Worker 8:  Sort Method: quicksort  Memory: 683kB
                           Worker 9:  Sort Method: quicksort  Memory: 696kB
                           Worker 10:  Sort Method: quicksort  Memory: 696kB
                           Worker 11:  Sort Method: quicksort  Memory: 696kB
                           Worker 12:  Sort Method: quicksort  Memory: 688kB
                           Worker 13:  Sort Method: quicksort  Memory: 689kB
                           Worker 14:  Sort Method: quicksort  Memory: 680kB
                           Worker 15:  Sort Method: quicksort  Memory: 684kB
                           Worker 16:  Sort Method: quicksort  Memory: 716kB
                           Worker 17:  Sort Method: quicksort  Memory: 702kB
                           Worker 18:  Sort Method: quicksort  Memory: 668kB
                           Worker 19:  Sort Method: quicksort  Memory: 682kB
                           ->  Parallel Index Scan using idx_2 on order_events  (cost=0.57..7524932.55 rows=3515 width=40) (actual time=0.273..420.297 rows=9716.81 loops=21)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 204412
                                 Index Searches: 1
                                 Buffers: shared hit=4510971
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '20', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.483 ms
 Execution Time: 525.243 ms
```

# IndexOnlyScan (0..20)

```
SET enable_indexscan = 'off';
CREATE INDEX idx_3 ON order_events (event_created, event_type) INCLUDE (event_payload);
```

```
-- 0

 WindowAgg  (cost=1053915.66..1055320.14 rows=70225 width=80) (actual time=1712.271..1712.953 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2558314
   ->  Sort  (cost=1053915.64..1054091.20 rows=70225 width=48) (actual time=1712.263..1712.307 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2558314
         ->  GroupAggregate  (cost=1046506.30..1048262.63 rows=70225 width=48) (actual time=1698.980..1711.699 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2558314
               ->  Sort  (cost=1046506.30..1046682.04 rows=70296 width=40) (actual time=1698.972..1702.986 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=2558314
                     ->  Index Only Scan using idx_3 on order_events  (cost=0.57..1040847.06 rows=70296 width=40) (actual time=0.071..1676.445 rows=204053.00 loops=1)
                           Disabled: true
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                           Rows Removed by Filter: 4292642
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=2558314
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan
 = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.436 ms
 Execution Time: 1713.047 ms

-- 1

 WindowAgg  (cost=1020454.77..1021859.25 rows=70225 width=80) (actual time=915.531..932.465 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555232
   ->  Sort  (cost=1020454.75..1020630.31 rows=70225 width=48) (actual time=915.522..931.805 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555232
         ->  GroupAggregate  (cost=1012516.74..1014801.74 rows=70225 width=48) (actual time=893.436..931.167 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555232
               ->  Gather Merge  (cost=1012516.74..1013221.15 rows=70296 width=40) (actual time=893.427..923.131 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=2555232
                     ->  Sort  (cost=1012515.73..1012619.10 rows=41351 width=40) (actual time=890.756..892.800 rows=102026.50 loops=2)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 6322kB
                           Buffers: shared hit=2555232
                           Worker 0:  Sort Method: quicksort  Memory: 6199kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..1009345.01 rows=41351 width=40) (actual time=0.189..878.782 rows=102026.50 loops=2)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 2146321
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555216
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan
 = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.432 ms
 Execution Time: 932.574 ms

-- 2

 WindowAgg  (cost=1006506.70..1007911.18 rows=70225 width=80) (actual time=710.623..736.068 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555004
   ->  Sort  (cost=1006506.68..1006682.24 rows=70225 width=48) (actual time=710.613..735.336 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555004
         ->  GroupAggregate  (cost=998393.22..1000853.67 rows=70225 width=48) (actual time=684.635..734.664 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555004
               ->  Gather Merge  (cost=998393.22..999273.07 rows=70296 width=40) (actual time=684.626..725.646 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=2555004
                     ->  Sort  (cost=998392.19..998465.42 rows=29290 width=40) (actual time=680.623..682.040 rows=68017.67 loops=3)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 5233kB
                           Buffers: shared hit=2555004
                           Worker 0:  Sort Method: quicksort  Memory: 5172kB
                           Worker 1:  Sort Method: quicksort  Memory: 5189kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..996219.15 rows=29290 width=40) (actual time=0.213..671.467 rows=68017.67 loops=3)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 1430881
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2554972
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.563 ms
 Execution Time: 736.187 ms

-- 3

 WindowAgg  (cost=998905.44..1000309.92 rows=70225 width=80) (actual time=570.691..588.628 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555524
   ->  Sort  (cost=998905.42..999080.98 rows=70225 width=48) (actual time=570.682..587.903 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555524
         ->  GroupAggregate  (cost=990662.62..993252.42 rows=70225 width=48) (actual time=545.153..587.238 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555524
               ->  Gather Merge  (cost=990662.62..991671.82 rows=70296 width=40) (actual time=545.145..578.573 rows=204053.00 loops=1)
                     Workers Planned: 3
                     Workers Launched: 3
                     Buffers: shared hit=2555524
                     ->  Sort  (cost=990661.58..990718.27 rows=22676 width=40) (actual time=541.393..542.469 rows=51013.25 loops=4)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3147kB
                           Buffers: shared hit=2555524
                           Worker 0:  Sort Method: quicksort  Memory: 3106kB
                           Worker 1:  Sort Method: quicksort  Memory: 3125kB
                           Worker 2:  Sort Method: quicksort  Memory: 3145kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..989021.10 rows=22676 width=40) (actual time=0.232..534.335 rows=51013.25 loops=4)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 1073160
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555476
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '3', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan
 = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.410 ms
 Execution Time: 588.729 ms

-- 4

 WindowAgg  (cost=993051.66..994456.14 rows=70225 width=80) (actual time=575.581..595.245 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555403
   ->  Sort  (cost=993051.64..993227.20 rows=70225 width=48) (actual time=575.571..594.517 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555403
         ->  GroupAggregate  (cost=984708.44..987398.64 rows=70225 width=48) (actual time=550.482..593.867 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555403
               ->  Gather Merge  (cost=984708.44..985818.04 rows=70296 width=40) (actual time=550.461..585.468 rows=204053.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     Buffers: shared hit=2555403
                     ->  Sort  (cost=984707.39..984751.32 rows=17574 width=40) (actual time=544.631..545.620 rows=40810.60 loops=5)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2901kB
                           Buffers: shared hit=2555403
                           Worker 0:  Sort Method: quicksort  Memory: 2729kB
                           Worker 1:  Sort Method: quicksort  Memory: 2749kB
                           Worker 2:  Sort Method: quicksort  Memory: 2888kB
                           Worker 3:  Sort Method: quicksort  Memory: 2792kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..983468.32 rows=17574 width=40) (actual time=0.132..538.078 rows=40810.60 loops=5)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 858528
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555339
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '4', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan
 = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.522 ms
 Execution Time: 595.362 ms

-- 5

 WindowAgg  (cost=989039.64..990444.12 rows=70225 width=80) (actual time=575.521..592.483 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555346
   ->  Sort  (cost=989039.62..989215.18 rows=70225 width=48) (actual time=575.511..591.763 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555346
         ->  GroupAggregate  (cost=980612.75..983386.61 rows=70225 width=48) (actual time=550.227..591.106 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555346
               ->  Gather Merge  (cost=980612.75..981806.01 rows=70296 width=40) (actual time=550.218..582.633 rows=204053.00 loops=1)
                     Workers Planned: 5
                     Workers Launched: 5
                     Buffers: shared hit=2555346
                     ->  Sort  (cost=980611.68..980646.82 rows=14059 width=40) (actual time=544.209..545.116 rows=34008.83 loops=6)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2685kB
                           Buffers: shared hit=2555346
                           Worker 0:  Sort Method: quicksort  Memory: 1746kB
                           Worker 1:  Sort Method: quicksort  Memory: 2628kB
                           Worker 2:  Sort Method: quicksort  Memory: 2593kB
                           Worker 3:  Sort Method: quicksort  Memory: 1718kB
                           Worker 4:  Sort Method: quicksort  Memory: 2689kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..979643.07 rows=14059 width=40) (actual time=0.200..537.902 rows=34008.83 loops=6)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 715440
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555266
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '5', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan
 = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.485 ms
 Execution Time: 592.595 ms

-- 6

 WindowAgg  (cost=986384.97..987789.45 rows=70225 width=80) (actual time=624.703..641.493 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555498
   ->  Sort  (cost=986384.95..986560.51 rows=70225 width=48) (actual time=624.694..640.770 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555498
         ->  GroupAggregate  (cost=977885.78..980731.94 rows=70225 width=48) (actual time=597.393..640.100 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555498
               ->  Gather Merge  (cost=977885.78..979151.35 rows=70296 width=40) (actual time=597.383..631.087 rows=204053.00 loops=1)
                     Workers Planned: 6
                     Workers Launched: 6
                     Buffers: shared hit=2555498
                     ->  Sort  (cost=977884.68..977913.97 rows=11716 width=40) (actual time=591.618..592.464 rows=29150.43 loops=7)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1723kB
                           Buffers: shared hit=2555498
                           Worker 0:  Sort Method: quicksort  Memory: 1749kB
                           Worker 1:  Sort Method: quicksort  Memory: 1653kB
                           Worker 2:  Sort Method: quicksort  Memory: 1678kB
                           Worker 3:  Sort Method: quicksort  Memory: 1632kB
                           Worker 4:  Sort Method: quicksort  Memory: 1623kB
                           Worker 5:  Sort Method: quicksort  Memory: 1698kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..977092.90 rows=11716 width=40) (actual time=0.457..585.399 rows=29150.43 loops=7)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 613235
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555402
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '6', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan
 = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.438 ms
 Execution Time: 641.609 ms

-- 7

 WindowAgg  (cost=984502.67..985907.15 rows=70225 width=80) (actual time=649.472..663.780 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555381
   ->  Sort  (cost=984502.65..984678.21 rows=70225 width=48) (actual time=649.462..663.054 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555381
         ->  GroupAggregate  (cost=975939.95..978849.64 rows=70225 width=48) (actual time=623.743..662.378 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555381
               ->  Gather Merge  (cost=975939.95..977269.05 rows=70296 width=40) (actual time=623.734..653.888 rows=204053.00 loops=1)
                     Workers Planned: 7
                     Workers Launched: 7
                     Buffers: shared hit=2555381
                     ->  Sort  (cost=975938.83..975963.94 rows=10042 width=40) (actual time=618.019..618.931 rows=25506.62 loops=8)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1548kB
                           Buffers: shared hit=2555381
                           Worker 0:  Sort Method: quicksort  Memory: 1559kB
                           Worker 1:  Sort Method: quicksort  Memory: 1575kB
                           Worker 2:  Sort Method: quicksort  Memory: 1585kB
                           Worker 3:  Sort Method: quicksort  Memory: 1567kB
                           Worker 4:  Sort Method: quicksort  Memory: 1570kB
                           Worker 5:  Sort Method: quicksort  Memory: 1572kB
                           Worker 6:  Sort Method: quicksort  Memory: 1550kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..975271.35 rows=10042 width=40) (actual time=0.255..612.019 rows=25506.62 loops=8)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 536580
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555269
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '7', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan
 = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.449 ms
 Execution Time: 663.887 ms

-- 8

WindowAgg  (cost=983101.24..984505.72 rows=70225 width=80) (actual time=673.834..687.121 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555532
   ->  Sort  (cost=983101.22..983276.78 rows=70225 width=48) (actual time=673.822..686.387 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555532
         ->  GroupAggregate  (cost=974481.93..977448.21 rows=70225 width=48) (actual time=646.509..685.721 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555532
               ->  Gather Merge  (cost=974481.93..975867.62 rows=70296 width=40) (actual time=646.497..676.482 rows=204053.00 loops=1)
                     Workers Planned: 8
                     Workers Launched: 8
                     Buffers: shared hit=2555532
                     ->  Sort  (cost=974480.79..974502.76 rows=8787 width=40) (actual time=639.685..640.481 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1501kB
                           Buffers: shared hit=2555532
                           Worker 0:  Sort Method: quicksort  Memory: 1470kB
                           Worker 1:  Sort Method: quicksort  Memory: 1463kB
                           Worker 2:  Sort Method: quicksort  Memory: 1457kB
                           Worker 3:  Sort Method: quicksort  Memory: 1476kB
                           Worker 4:  Sort Method: quicksort  Memory: 1501kB
                           Worker 5:  Sort Method: quicksort  Memory: 1460kB
                           Worker 6:  Sort Method: quicksort  Memory: 1489kB
                           Worker 7:  Sort Method: quicksort  Memory: 1476kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..973905.19 rows=8787 width=40) (actual time=0.333..634.035 rows=22672.56 loops=9)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 476960
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555404
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '8', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan
 = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.512 ms
 Execution Time: 687.242 ms

-- 9

 WindowAgg  (cost=982019.11..983423.59 rows=70225 width=80) (actual time=674.929..686.736 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555474
   ->  Sort  (cost=982019.09..982194.66 rows=70225 width=48) (actual time=674.918..686.016 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555474
         ->  GroupAggregate  (cost=973348.82..976366.09 rows=70225 width=48) (actual time=649.317..685.361 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555474
               ->  Gather Merge  (cost=973348.82..974785.49 rows=70296 width=40) (actual time=649.309..677.040 rows=204053.00 loops=1)
                     Workers Planned: 9
                     Workers Launched: 9
                     Buffers: shared hit=2555474
                     ->  Sort  (cost=973347.66..973367.18 rows=7811 width=40) (actual time=642.648..643.311 rows=20405.30 loops=10)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1387kB
                           Buffers: shared hit=2555474
                           Worker 0:  Sort Method: quicksort  Memory: 1404kB
                           Worker 1:  Sort Method: quicksort  Memory: 1401kB
                           Worker 2:  Sort Method: quicksort  Memory: 1414kB
                           Worker 3:  Sort Method: quicksort  Memory: 1408kB
                           Worker 4:  Sort Method: quicksort  Memory: 1407kB
                           Worker 5:  Sort Method: quicksort  Memory: 1409kB
                           Worker 6:  Sort Method: quicksort  Memory: 1414kB
                           Worker 7:  Sort Method: quicksort  Memory: 1403kB
                           Worker 8:  Sort Method: quicksort  Memory: 1415kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..972842.63 rows=7811 width=40) (actual time=0.394..637.454 rows=20405.30 loops=10)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 429264
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555330
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '9', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexscan
 = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.508 ms
 Execution Time: 686.856 ms

-- 10

 WindowAgg  (cost=981159.62..982564.10 rows=70225 width=80) (actual time=692.163..703.234 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555452
   ->  Sort  (cost=981159.60..981335.16 rows=70225 width=48) (actual time=692.150..702.499 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555452
         ->  GroupAggregate  (cost=972442.95..975506.59 rows=70225 width=48) (actual time=666.160..701.840 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555452
               ->  Gather Merge  (cost=972442.95..973926.00 rows=70296 width=40) (actual time=666.151..693.475 rows=204053.00 loops=1)
                     Workers Planned: 10
                     Workers Launched: 10
                     Buffers: shared hit=2555452
                     ->  Sort  (cost=972441.76..972459.34 rows=7030 width=40) (actual time=659.779..660.396 rows=18550.27 loops=11)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1350kB
                           Buffers: shared hit=2555452
                           Worker 0:  Sort Method: quicksort  Memory: 1345kB
                           Worker 1:  Sort Method: quicksort  Memory: 1354kB
                           Worker 2:  Sort Method: quicksort  Memory: 1344kB
                           Worker 3:  Sort Method: quicksort  Memory: 1348kB
                           Worker 4:  Sort Method: quicksort  Memory: 1354kB
                           Worker 5:  Sort Method: quicksort  Memory: 1347kB
                           Worker 6:  Sort Method: quicksort  Memory: 1344kB
                           Worker 7:  Sort Method: quicksort  Memory: 1353kB
                           Worker 8:  Sort Method: quicksort  Memory: 1345kB
                           Worker 9:  Sort Method: quicksort  Memory: 1346kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..971992.57 rows=7030 width=40) (actual time=0.209..655.000 rows=18550.27 loops=11)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 390240
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555292
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '10', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexsca
n = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.567 ms
 Execution Time: 703.356 ms

-- 12

 WindowAgg  (cost=979883.77..981288.25 rows=70225 width=80) (actual time=720.754..730.211 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2556018
   ->  Sort  (cost=979883.75..980059.31 rows=70225 width=48) (actual time=720.740..729.488 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2556018
         ->  GroupAggregate  (cost=971085.32..974230.75 rows=70225 width=48) (actual time=694.006..728.831 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2556018
               ->  Gather Merge  (cost=971085.32..972650.15 rows=70296 width=40) (actual time=693.997..720.235 rows=204053.00 loops=1)
                     Workers Planned: 12
                     Workers Launched: 12
                     Buffers: shared hit=2556018
                     ->  Sort  (cost=971084.08..971098.73 rows=5858 width=40) (actual time=686.451..686.922 rows=15696.38 loops=13)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 872kB
                           Buffers: shared hit=2556018
                           Worker 0:  Sort Method: quicksort  Memory: 879kB
                           Worker 1:  Sort Method: quicksort  Memory: 873kB
                           Worker 2:  Sort Method: quicksort  Memory: 875kB
                           Worker 3:  Sort Method: quicksort  Memory: 878kB
                           Worker 4:  Sort Method: quicksort  Memory: 875kB
                           Worker 5:  Sort Method: quicksort  Memory: 872kB
                           Worker 6:  Sort Method: quicksort  Memory: 872kB
                           Worker 7:  Sort Method: quicksort  Memory: 867kB
                           Worker 8:  Sort Method: quicksort  Memory: 868kB
                           Worker 9:  Sort Method: quicksort  Memory: 882kB
                           Worker 10:  Sort Method: quicksort  Memory: 881kB
                           Worker 11:  Sort Method: quicksort  Memory: 880kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..970717.48 rows=5858 width=40) (actual time=0.241..682.191 rows=15696.38 loops=13)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 330203
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555826
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '12', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexsca
n = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.596 ms
 Execution Time: 730.464 ms

-- 16

 WindowAgg  (cost=978321.67..979726.15 rows=70225 width=80) (actual time=851.128..863.714 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2556342
   ->  Sort  (cost=978321.65..978497.21 rows=70225 width=48) (actual time=851.114..862.537 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2556342
         ->  GroupAggregate  (cost=969390.85..972668.64 rows=70225 width=48) (actual time=821.720..861.718 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2556342
               ->  Gather Merge  (cost=969390.85..971088.04 rows=70296 width=40) (actual time=821.711..852.300 rows=204053.00 loops=1)
                     Workers Planned: 16
                     Workers Launched: 16
                     Buffers: shared hit=2556342
                     ->  Sort  (cost=969389.50..969400.48 rows=4394 width=40) (actual time=814.508..814.878 rows=12003.12 loops=17)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 761kB
                           Buffers: shared hit=2556342
                           Worker 0:  Sort Method: quicksort  Memory: 763kB
                           Worker 1:  Sort Method: quicksort  Memory: 754kB
                           Worker 2:  Sort Method: quicksort  Memory: 752kB
                           Worker 3:  Sort Method: quicksort  Memory: 760kB
                           Worker 4:  Sort Method: quicksort  Memory: 762kB
                           Worker 5:  Sort Method: quicksort  Memory: 762kB
                           Worker 6:  Sort Method: quicksort  Memory: 757kB
                           Worker 7:  Sort Method: quicksort  Memory: 765kB
                           Worker 8:  Sort Method: quicksort  Memory: 759kB
                           Worker 9:  Sort Method: quicksort  Memory: 765kB
                           Worker 10:  Sort Method: quicksort  Memory: 760kB
                           Worker 11:  Sort Method: quicksort  Memory: 752kB
                           Worker 12:  Sort Method: quicksort  Memory: 766kB
                           Worker 13:  Sort Method: quicksort  Memory: 760kB
                           Worker 14:  Sort Method: quicksort  Memory: 760kB
                           Worker 15:  Sort Method: quicksort  Memory: 755kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..969123.63 rows=4394 width=40) (actual time=0.577..810.903 rows=12003.12 loops=17)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 252508
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2556086
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '16', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexsca
n = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.270 ms
 Execution Time: 863.829 ms

-- 20

 WindowAgg  (cost=977411.57..978816.05 rows=70225 width=80) (actual time=785.327..794.230 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2556606
   ->  Sort  (cost=977411.55..977587.12 rows=70225 width=48) (actual time=785.314..793.273 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2556606
         ->  GroupAggregate  (cost=968375.80..971758.55 rows=70225 width=48) (actual time=750.207..792.540 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2556606
               ->  Gather Merge  (cost=968375.80..970177.95 rows=70296 width=40) (actual time=750.196..783.236 rows=204053.00 loops=1)
                     Workers Planned: 20
                     Workers Launched: 20
                     Buffers: shared hit=2556606
                     ->  Sort  (cost=968374.34..968383.13 rows=3515 width=40) (actual time=742.311..742.600 rows=9716.81 loops=21)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 695kB
                           Buffers: shared hit=2556606
                           Worker 0:  Sort Method: quicksort  Memory: 688kB
                           Worker 1:  Sort Method: quicksort  Memory: 687kB
                           Worker 2:  Sort Method: quicksort  Memory: 681kB
                           Worker 3:  Sort Method: quicksort  Memory: 678kB
                           Worker 4:  Sort Method: quicksort  Memory: 689kB
                           Worker 5:  Sort Method: quicksort  Memory: 687kB
                           Worker 6:  Sort Method: quicksort  Memory: 681kB
                           Worker 7:  Sort Method: quicksort  Memory: 693kB
                           Worker 8:  Sort Method: quicksort  Memory: 694kB
                           Worker 9:  Sort Method: quicksort  Memory: 689kB
                           Worker 10:  Sort Method: quicksort  Memory: 689kB
                           Worker 11:  Sort Method: quicksort  Memory: 693kB
                           Worker 12:  Sort Method: quicksort  Memory: 688kB
                           Worker 13:  Sort Method: quicksort  Memory: 685kB
                           Worker 14:  Sort Method: quicksort  Memory: 688kB
                           Worker 15:  Sort Method: quicksort  Memory: 695kB
                           Worker 16:  Sort Method: quicksort  Memory: 685kB
                           Worker 17:  Sort Method: quicksort  Memory: 685kB
                           Worker 18:  Sort Method: quicksort  Memory: 688kB
                           Worker 19:  Sort Method: quicksort  Memory: 692kB
                           ->  Parallel Index Only Scan using idx_3 on order_events  (cost=0.57..968167.32 rows=3515 width=40) (actual time=0.452..739.316 rows=9716.81 loops=21)
                                 Disabled: true
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 204412
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2556286
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '20', max_parallel_workers = '32', enable_seqscan = 'off', enable_bitmapscan = 'off', enable_indexsca
n = 'off'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.313 ms
 Execution Time: 794.334 ms
```



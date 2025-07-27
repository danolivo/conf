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




-- IndexOnlyScan:

-- 12

 WindowAgg  (cost=979883.77..981288.25 rows=70225 width=80) (actual time=733.047..742.942 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555958 read=1
   ->  Sort  (cost=979883.75..980059.31 rows=70225 width=48) (actual time=733.036..742.203 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555958 read=1
         ->  GroupAggregate  (cost=971085.32..974230.75 rows=70225 width=48) (actual time=706.518..741.554 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555958 read=1
               ->  Gather Merge  (cost=971085.32..972650.15 rows=70296 width=40) (actual time=706.506..733.148 rows=204053.00 loops=1)
                     Workers Planned: 12
                     Workers Launched: 12
                     Buffers: shared hit=2555958 read=1
                     ->  Sort  (cost=971084.08..971098.73 rows=5858 width=40) (actual time=698.094..698.607 rows=15696.38 loops=13)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 881kB
                           Buffers: shared hit=2555958 read=1
                           Worker 0:  Sort Method: quicksort  Memory: 883kB
                           Worker 1:  Sort Method: quicksort  Memory: 878kB
                           Worker 2:  Sort Method: quicksort  Memory: 871kB
                           Worker 3:  Sort Method: quicksort  Memory: 863kB
                           Worker 4:  Sort Method: quicksort  Memory: 880kB
                           Worker 5:  Sort Method: quicksort  Memory: 872kB
                           Worker 6:  Sort Method: quicksort  Memory: 880kB
                           Worker 7:  Sort Method: quicksort  Memory: 871kB
                           Worker 8:  Sort Method: quicksort  Memory: 871kB
                           Worker 9:  Sort Method: quicksort  Memory: 874kB
                           Worker 10:  Sort Method: quicksort  Memory: 879kB
                           Worker 11:  Sort Method: quicksort  Memory: 872kB
                           ->  Parallel Index Only Scan using idx_2 on order_events  (cost=0.57..970717.48 rows=5858 width=40) (actual time=0.243..693.757 rows=15696.38 loops=13)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 330203
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555766 read=1
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '16', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.486 ms
 Execution Time: 743.057 ms

-- 8

 WindowAgg  (cost=983101.24..984505.72 rows=70225 width=80) (actual time=671.289..685.399 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555399
   ->  Sort  (cost=983101.22..983276.78 rows=70225 width=48) (actual time=671.279..684.676 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555399
         ->  GroupAggregate  (cost=974481.93..977448.21 rows=70225 width=48) (actual time=642.884..683.993 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555399
               ->  Gather Merge  (cost=974481.93..975867.62 rows=70296 width=40) (actual time=642.873..674.905 rows=204053.00 loops=1)
                     Workers Planned: 8
                     Workers Launched: 8
                     Buffers: shared hit=2555399
                     ->  Sort  (cost=974480.79..974502.76 rows=8787 width=40) (actual time=637.144..637.882 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1461kB
                           Buffers: shared hit=2555399
                           Worker 0:  Sort Method: quicksort  Memory: 1470kB
                           Worker 1:  Sort Method: quicksort  Memory: 1458kB
                           Worker 2:  Sort Method: quicksort  Memory: 1464kB
                           Worker 3:  Sort Method: quicksort  Memory: 1483kB
                           Worker 4:  Sort Method: quicksort  Memory: 1479kB
                           Worker 5:  Sort Method: quicksort  Memory: 1480kB
                           Worker 6:  Sort Method: quicksort  Memory: 1512kB
                           Worker 7:  Sort Method: quicksort  Memory: 1486kB
                           ->  Parallel Index Only Scan using idx_2 on order_events  (cost=0.57..973905.19 rows=8787 width=40) (actual time=0.123..631.484 rows=22672.56 loops=9)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 476960
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555271
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '8', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.545 ms
 Execution Time: 685.523 ms

-- 4

 WindowAgg  (cost=993051.66..994456.14 rows=70225 width=80) (actual time=571.753..594.390 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555132
   ->  Sort  (cost=993051.64..993227.20 rows=70225 width=48) (actual time=571.742..593.670 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555132
         ->  GroupAggregate  (cost=984708.44..987398.64 rows=70225 width=48) (actual time=546.452..593.011 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555132
               ->  Gather Merge  (cost=984708.44..985818.04 rows=70296 width=40) (actual time=546.442..584.441 rows=204053.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     Buffers: shared hit=2555132
                     ->  Sort  (cost=984707.39..984751.32 rows=17574 width=40) (actual time=540.334..541.337 rows=40810.60 loops=5)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2761kB
                           Buffers: shared hit=2555132
                           Worker 0:  Sort Method: quicksort  Memory: 2831kB
                           Worker 1:  Sort Method: quicksort  Memory: 2880kB
                           Worker 2:  Sort Method: quicksort  Memory: 2718kB
                           Worker 3:  Sort Method: quicksort  Memory: 2869kB
                           ->  Parallel Index Only Scan using idx_2 on order_events  (cost=0.57..983468.32 rows=17574 width=40) (actual time=0.272..533.679 rows=40810.60 loops=5)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 858528
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555068
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '4', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.707 ms
 Execution Time: 594.519 ms

-- 2

 WindowAgg  (cost=1006506.70..1007911.18 rows=70225 width=80) (actual time=704.969..729.243 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2554867
   ->  Sort  (cost=1006506.68..1006682.24 rows=70225 width=48) (actual time=704.960..728.550 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2554867
         ->  GroupAggregate  (cost=998393.22..1000853.67 rows=70225 width=48) (actual time=679.956..727.958 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2554867
               ->  Gather Merge  (cost=998393.22..999273.07 rows=70296 width=40) (actual time=679.947..719.452 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=2554867
                     ->  Sort  (cost=998392.19..998465.42 rows=29290 width=40) (actual time=676.201..677.706 rows=68017.67 loops=3)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 5221kB
                           Buffers: shared hit=2554867
                           Worker 0:  Sort Method: quicksort  Memory: 5183kB
                           Worker 1:  Sort Method: quicksort  Memory: 5190kB
                           ->  Parallel Index Only Scan using idx_2 on order_events  (cost=0.57..996219.15 rows=29290 width=40) (actual time=0.123..667.177 rows=68017.67 loops=3)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 1430881
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2554835
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.569 ms
 Execution Time: 729.355 ms

-- 1

 WindowAgg  (cost=1020454.77..1021859.25 rows=70225 width=80) (actual time=949.519..967.934 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2555273
   ->  Sort  (cost=1020454.75..1020630.31 rows=70225 width=48) (actual time=949.511..967.241 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2555273
         ->  GroupAggregate  (cost=1012516.74..1014801.74 rows=70225 width=48) (actual time=926.491..966.632 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2555273
               ->  Gather Merge  (cost=1012516.74..1013221.15 rows=70296 width=40) (actual time=926.483..958.232 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=2555273
                     ->  Sort  (cost=1012515.73..1012619.10 rows=41351 width=40) (actual time=923.170..925.356 rows=102026.50 loops=2)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 6303kB
                           Buffers: shared hit=2555273
                           Worker 0:  Sort Method: quicksort  Memory: 6218kB
                           ->  Parallel Index Only Scan using idx_2 on order_events  (cost=0.57..1009345.01 rows=41351 width=40) (actual time=0.187..910.634 rows=102026.50 loops=2)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                                 Rows Removed by Filter: 2146321
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=2555257
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.553 ms
 Execution Time: 968.050 ms
```



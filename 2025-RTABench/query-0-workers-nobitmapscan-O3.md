SET enable_bitmapscan = 'off';
```
-- 0

 WindowAgg  (cost=7690684.81..7692087.57 rows=70139 width=80) (actual time=15183.708..15184.392 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=1152 read=3132688
   ->  Sort  (cost=7690684.79..7690860.14 rows=70139 width=48) (actual time=15183.698..15183.745 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=1152 read=3132688
         ->  GroupAggregate  (cost=7683285.14..7685039.33 rows=70139 width=48) (actual time=15169.139..15183.139 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=1152 read=3132688
               ->  Sort  (cost=7683285.14..7683460.67 rows=70210 width=40) (actual time=15169.129..15173.966 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=1152 read=3132688
                     ->  Seq Scan on order_events  (cost=0.00..7677633.45 rows=70210 width=40) (actual time=0.352..15137.466 rows=204053.00 loops=1)
                           Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{
Berlin,Hamburg,Munich}'::text[])))
                           Rows Removed by Filter: 181533639
                           Buffers: shared hit=1152 read=3132688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', enable_bitmapscan = 'off'
 Planning Time: 0.361 ms
 Execution Time: 15184.975 ms

-- 1

 WindowAgg  (cost=5817754.82..5819157.58 rows=70139 width=80) (actual time=12469.667..12472.027 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=1486 read=3132400
   ->  Sort  (cost=5817754.80..5817930.14 rows=70139 width=48) (actual time=12469.657..12471.382 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=1486 read=3132400
         ->  GroupAggregate  (cost=5809827.13..5812109.33 rows=70139 width=48) (actual time=12447.883..12470.778 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=1486 read=3132400
               ->  Gather Merge  (cost=5809827.13..5810530.67 rows=70210 width=40) (actual time=12447.871..12462.918 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=1486 read=3132400
                     ->  Sort  (cost=5809826.12..5809929.37 rows=41300 width=40) (actual time=12444.199..12446.749 rows=102026.50 loops=2)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 6266kB
                           Buffers: shared hit=1486 read=3132400
                           Worker 0:  Sort Method: quicksort  Memory: 6255kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..5806659.68 rows=41300 width=40) (actual time=0.346..12424.861 rows=102026.50 loops=2)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 90766820
                                 Buffers: shared hit=1440 read=3132400
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1', enable_bitmapscan = 'off'
 Planning:
   Buffers: shared hit=2 read=1
 Planning Time: 9.885 ms
 Execution Time: 12472.119 ms

-- 2

 WindowAgg  (cost=5037361.33..5038764.09 rows=70139 width=80) (actual time=9730.497..9740.643 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2108 read=3131824
   ->  Sort  (cost=5037361.31..5037536.66 rows=70139 width=48) (actual time=9730.487..9739.977 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2108 read=3131824
         ->  GroupAggregate  (cost=5029258.41..5031715.85 rows=70139 width=48) (actual time=9703.550..9739.372 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2108 read=3131824
               ->  Gather Merge  (cost=5029258.41..5030137.19 rows=70210 width=40) (actual time=9703.540..9729.881 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=2108 read=3131824
                     ->  Sort  (cost=5029257.38..5029330.52 rows=29254 width=40) (actual time=9693.270..9694.954 rows=68017.67 loops=3)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 5212kB
                           Buffers: shared hit=2108 read=3131824
                           Worker 0:  Sort Method: quicksort  Memory: 5201kB
                           Worker 1:  Sort Method: quicksort  Memory: 5182kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..5027087.27 rows=29254 width=40) (actual time=5.391..9680.767 rows=68017.67 loops=3)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 60511213
                                 Buffers: shared hit=2016 read=3131824
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', enable_bitmapscan = 'off'
 Planning Time: 0.516 ms
 Execution Time: 9740.750 ms

-- 3

 WindowAgg  (cost=4609451.22..4610853.98 rows=70139 width=80) (actual time=9963.606..9964.449 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=3018 read=3130960
   ->  Sort  (cost=4609451.20..4609626.55 rows=70139 width=48) (actual time=9963.595..9963.686 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=3018 read=3130960
         ->  GroupAggregate  (cost=4601219.11..4603805.74 rows=70139 width=48) (actual time=9937.685..9962.993 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=3018 read=3130960
               ->  Gather Merge  (cost=4601219.11..4602227.08 rows=70210 width=40) (actual time=9937.674..9954.260 rows=204053.00 loops=1)
                     Workers Planned: 3
                     Workers Launched: 3
                     Buffers: shared hit=3018 read=3130960
                     ->  Sort  (cost=4601218.07..4601274.69 rows=22648 width=40) (actual time=9925.588..9926.976 rows=51013.25 loops=4)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3173kB
                           Buffers: shared hit=3018 read=3130960
                           Worker 0:  Sort Method: quicksort  Memory: 3091kB
                           Worker 1:  Sort Method: quicksort  Memory: 3155kB
                           Worker 2:  Sort Method: quicksort  Memory: 3103kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..4599579.82 rows=22648 width=40) (actual time=0.224..9915.644 rows=51013.25 loops=4)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 45383410
                                 Buffers: shared hit=2880 read=3130960
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '3', enable_bitmapscan = 'off'
 Planning Time: 0.457 ms
 Execution Time: 9964.561 ms

-- 4

 WindowAgg  (cost=4279359.16..4280761.92 rows=70139 width=80) (actual time=10310.762..10312.973 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4216 read=3129808
   ->  Sort  (cost=4279359.14..4279534.49 rows=70139 width=48) (actual time=10310.751..10312.244 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=4216 read=3129808
         ->  GroupAggregate  (cost=4271026.78..4273713.68 rows=70139 width=48) (actual time=10279.080..10311.528 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=4216 read=3129808
               ->  Gather Merge  (cost=4271026.78..4272135.02 rows=70210 width=40) (actual time=10279.069..10300.788 rows=204053.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     Buffers: shared hit=4216 read=3129808
                     ->  Sort  (cost=4271025.72..4271069.60 rows=17552 width=40) (actual time=10273.063..10274.504 rows=40810.60 loops=5)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2796kB
                           Buffers: shared hit=4216 read=3129808
                           Worker 0:  Sort Method: quicksort  Memory: 2789kB
                           Worker 1:  Sort Method: quicksort  Memory: 2835kB
                           Worker 2:  Sort Method: quicksort  Memory: 2821kB
                           Worker 3:  Sort Method: quicksort  Memory: 2818kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..4269788.36 rows=17552 width=40) (actual time=1.715..10263.819 rows=40810.60 loops=5)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 36306728
                                 Buffers: shared hit=4032 read=3129808
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '4', enable_bitmapscan = 'off'
 Planning Time: 0.489 ms
 Execution Time: 10313.080 ms

-- 5

 WindowAgg  (cost=4051983.03..4053385.79 rows=70139 width=80) (actual time=9507.009..9507.780 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=5702 read=3128368
   ->  Sort  (cost=4051983.01..4052158.36 rows=70139 width=48) (actual time=9507.000..9507.097 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=5702 read=3128368
         ->  GroupAggregate  (cost=4043567.08..4046337.54 rows=70139 width=48) (actual time=9481.796..9506.474 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=5702 read=3128368
               ->  Gather Merge  (cost=4043567.08..4044758.88 rows=70210 width=40) (actual time=9481.768..9498.001 rows=204053.00 loops=1)
                     Workers Planned: 5
                     Workers Launched: 5
                     Buffers: shared hit=5702 read=3128368
                     ->  Sort  (cost=4043566.01..4043601.11 rows=14042 width=40) (actual time=9474.880..9476.072 rows=34008.83 loops=6)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2647kB
                           Buffers: shared hit=5702 read=3128368
                           Worker 0:  Sort Method: quicksort  Memory: 1739kB
                           Worker 1:  Sort Method: quicksort  Memory: 2571kB
                           Worker 2:  Sort Method: quicksort  Memory: 2645kB
                           Worker 3:  Sort Method: quicksort  Memory: 1792kB
                           Worker 4:  Sort Method: quicksort  Memory: 2665kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..4042598.69 rows=14042 width=40) (actual time=0.289..9466.479 rows=34008.83 loops=6)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 30255606
                                 Buffers: shared hit=5472 read=3128368
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '5', enable_bitmapscan = 'off'
 Planning Time: 0.497 ms
 Execution Time: 9507.894 ms

-- 6

 WindowAgg  (cost=3900418.91..3901821.67 rows=70139 width=80) (actual time=9819.123..9819.891 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=7476 read=3126640
   ->  Sort  (cost=3900418.89..3900594.23 rows=70139 width=48) (actual time=9819.114..9819.218 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=7476 read=3126640
         ->  GroupAggregate  (cost=3891930.74..3894773.42 rows=70139 width=48) (actual time=9791.841..9818.587 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=7476 read=3126640
               ->  Gather Merge  (cost=3891930.74..3893194.76 rows=70210 width=40) (actual time=9791.829..9809.717 rows=204053.00 loops=1)
                     Workers Planned: 6
                     Workers Launched: 6
                     Buffers: shared hit=7476 read=3126640
                     ->  Sort  (cost=3891929.64..3891958.90 rows=11702 width=40) (actual time=9788.064..9789.248 rows=29150.43 loops=7)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1692kB
                           Buffers: shared hit=7476 read=3126640
                           Worker 0:  Sort Method: quicksort  Memory: 1686kB
                           Worker 1:  Sort Method: quicksort  Memory: 1675kB
                           Worker 2:  Sort Method: quicksort  Memory: 1685kB
                           Worker 3:  Sort Method: quicksort  Memory: 1650kB
                           Worker 4:  Sort Method: quicksort  Memory: 1693kB
                           Worker 5:  Sort Method: quicksort  Memory: 1674kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3891138.91 rows=11702 width=40) (actual time=2.634..9779.899 rows=29150.43 loops=7)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 25933377
                                 Buffers: shared hit=7200 read=3126640
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '6', enable_bitmapscan = 'off'
 Planning Time: 0.384 ms
 Execution Time: 9819.980 ms

-- 7

 WindowAgg  (cost=3792172.68..3793575.44 rows=70139 width=80) (actual time=9868.153..9868.907 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=9538 read=3124624
   ->  Sort  (cost=3792172.66..3792348.01 rows=70139 width=48) (actual time=9868.142..9868.249 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=9538 read=3124624
         ->  GroupAggregate  (cost=3783621.07..3786527.20 rows=70139 width=48) (actual time=9842.971..9867.587 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=9538 read=3124624
               ->  Gather Merge  (cost=3783621.07..3784948.54 rows=70210 width=40) (actual time=9842.959..9859.272 rows=204053.00 loops=1)
                     Workers Planned: 7
                     Workers Launched: 7
                     Buffers: shared hit=9538 read=3124624
                     ->  Sort  (cost=3783619.95..3783645.02 rows=10030 width=40) (actual time=9835.764..9836.791 rows=25506.62 loops=8)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1586kB
                           Buffers: shared hit=9538 read=3124624
                           Worker 0:  Sort Method: quicksort  Memory: 1554kB
                           Worker 1:  Sort Method: quicksort  Memory: 1562kB
                           Worker 2:  Sort Method: quicksort  Memory: 1537kB
                           Worker 3:  Sort Method: quicksort  Memory: 1583kB
                           Worker 4:  Sort Method: quicksort  Memory: 1561kB
                           Worker 5:  Sort Method: quicksort  Memory: 1582kB
                           Worker 6:  Sort Method: quicksort  Memory: 1559kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3782953.35 rows=10030 width=40) (actual time=3.545..9823.234 rows=25506.62 loops=8)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 22691705
                                 Buffers: shared hit=9216 read=3124624
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '7', enable_bitmapscan = 'off'
 Planning Time: 0.582 ms
 Execution Time: 9869.021 ms

-- 8

 WindowAgg  (cost=3710998.25..3712401.01 rows=70139 width=80) (actual time=9609.815..9610.586 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=11888 read=3122320
   ->  Sort  (cost=3710998.23..3711173.58 rows=70139 width=48) (actual time=9609.805..9609.914 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=11888 read=3122320
         ->  GroupAggregate  (cost=3702390.12..3705352.77 rows=70139 width=48) (actual time=9584.020..9609.300 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=11888 read=3122320
               ->  Gather Merge  (cost=3702390.12..3703774.11 rows=70210 width=40) (actual time=9584.008..9600.926 rows=204053.00 loops=1)
                     Workers Planned: 8
                     Workers Launched: 8
                     Buffers: shared hit=11888 read=3122320
                     ->  Sort  (cost=3702388.98..3702410.92 rows=8776 width=40) (actual time=9576.531..9577.420 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1497kB
                           Buffers: shared hit=11888 read=3122320
                           Worker 0:  Sort Method: quicksort  Memory: 1473kB
                           Worker 1:  Sort Method: quicksort  Memory: 1463kB
                           Worker 2:  Sort Method: quicksort  Memory: 1484kB
                           Worker 3:  Sort Method: quicksort  Memory: 1492kB
                           Worker 4:  Sort Method: quicksort  Memory: 1460kB
                           Worker 5:  Sort Method: quicksort  Memory: 1447kB
                           Worker 6:  Sort Method: quicksort  Memory: 1495kB
                           Worker 7:  Sort Method: quicksort  Memory: 1481kB
                           ->  Parallel Seq Scan on order_events  (cost=0.00..3701814.18 rows=8776 width=40) (actual time=4.132..9565.431 rows=22672.56 loops=9)
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = A
NY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 20170404
                                 Buffers: shared hit=11520 read=3122320
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '8', enable_bitmapscan = 'off'
 Planning Time: 0.506 ms
 Execution Time: 9610.689 ms
```

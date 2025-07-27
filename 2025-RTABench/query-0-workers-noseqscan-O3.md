SET enable_seqscan = 'off';
```
-- 0

 WindowAgg  (cost=5162432.55..5163835.31 rows=70139 width=80) (actual time=20237.347..20238.123 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared read=3182778
   ->  Sort  (cost=5162432.53..5162607.88 rows=70139 width=48) (actual time=20237.336..20237.467 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared read=3182778
         ->  GroupAggregate  (cost=5155032.88..5156787.07 rows=70139 width=48) (actual time=20222.700..20236.879 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared read=3182778
               ->  Sort  (cost=5155032.88..5155208.41 rows=70210 width=40) (actual time=20222.500..20227.542 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared read=3182778
                     ->  Bitmap Heap Scan on order_events  (cost=597181.77..5149381.19 rows=70210 width=40) (actual time=2334.814..20185.343 rows=204053.00 loops=1)
                           Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                           Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                           Rows Removed by Filter: 57210049
                           Heap Blocks: exact=3133832
                           Buffers: shared read=3182778
                           ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=1740.827..1740.913 rows=57414102.00 loops=1)
                                 Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Index Searches: 1
                                 Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', enable_seqscan = 'off'
 Planning Time: 9.243 ms
 Execution Time: 20248.490 ms

-- 1

 WindowAgg  (cost=4576445.98..4577848.74 rows=70139 width=80) (actual time=21982.647..22107.067 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=27 read=3182787
   ->  Sort  (cost=4576445.96..4576621.31 rows=70139 width=48) (actual time=21982.637..22106.423 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=27 read=3182787
         ->  GroupAggregate  (cost=4568518.29..4570800.50 rows=70139 width=48) (actual time=21960.225..22105.789 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=27 read=3182787
               ->  Gather Merge  (cost=4568518.29..4569221.84 rows=70210 width=40) (actual time=21960.213..22097.763 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=27 read=3182787
                     ->  Sort  (cost=4568517.28..4568620.53 rows=41300 width=40) (actual time=21949.670..21952.207 rows=102026.50 loops=2)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 6267kB
                           Buffers: shared hit=27 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 6254kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4565350.84 rows=41300 width=40) (actual time=2522.450..21931.003 rows=102026.50 loops=2)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 28605024
                                 Heap Blocks: exact=1570035
                                 Buffers: shared hit=17 read=3182781
                                 Worker 0:  Heap Blocks: exact=1563797
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=1798.923..1798.923 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1', enable_seqscan = 'off'
 Planning Time: 0.510 ms
 Execution Time: 22107.194 ms

-- 2

 WindowAgg  (cost=4332278.92..4333681.68 rows=70139 width=80) (actual time=21993.028..22254.037 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=63 read=3182787
   ->  Sort  (cost=4332278.90..4332454.25 rows=70139 width=48) (actual time=21993.018..22253.332 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=63 read=3182787
         ->  GroupAggregate  (cost=4324176.00..4326633.44 rows=70139 width=48) (actual time=21968.835..22252.727 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=63 read=3182787
               ->  Gather Merge  (cost=4324176.00..4325054.78 rows=70210 width=40) (actual time=21968.821..22244.498 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=63 read=3182787
                     ->  Sort  (cost=4324174.97..4324248.11 rows=29254 width=40) (actual time=21962.707..21964.510 rows=68017.67 loops=3)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 5221kB
                           Buffers: shared hit=63 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 5172kB
                           Worker 1:  Sort Method: quicksort  Memory: 5201kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4322004.86 rows=29254 width=40) (actual time=2602.596..21944.215 rows=68017.67 loops=3)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 19070016
                                 Heap Blocks: exact=1052066
                                 Buffers: shared hit=37 read=3182781
                                 Worker 0:  Heap Blocks: exact=1041378
                                 Worker 1:  Heap Blocks: exact=1040388
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=1883.818..1883.818 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', enable_seqscan = 'off'
 Planning Time: 0.482 ms
 Execution Time: 22254.160 ms

-- 3

 WindowAgg  (cost=4198428.47..4199831.23 rows=70139 width=80) (actual time=23460.658..23572.474 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=99 read=3182787
   ->  Sort  (cost=4198428.45..4198603.79 rows=70139 width=48) (actual time=23460.647..23571.754 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=99 read=3182787
         ->  GroupAggregate  (cost=4190196.36..4192782.98 rows=70139 width=48) (actual time=23435.192..23571.103 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=99 read=3182787
               ->  Gather Merge  (cost=4190196.36..4191204.32 rows=70210 width=40) (actual time=23435.168..23562.499 rows=204053.00 loops=1)
                     Workers Planned: 3
                     Workers Launched: 3
                     Buffers: shared hit=99 read=3182787
                     ->  Sort  (cost=4190195.32..4190251.94 rows=22648 width=40) (actual time=23422.386..23423.816 rows=51013.25 loops=4)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 3263kB
                           Buffers: shared hit=99 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 3180kB
                           Worker 1:  Sort Method: quicksort  Memory: 3044kB
                           Worker 2:  Sort Method: quicksort  Memory: 3035kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4188557.06 rows=22648 width=40) (actual time=2581.762..23411.673 rows=51013.25 loops=4)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 14302512
                                 Heap Blocks: exact=785399
                                 Buffers: shared hit=57 read=3182781
                                 Worker 0:  Heap Blocks: exact=773298
                                 Worker 1:  Heap Blocks: exact=791383
                                 Worker 2:  Heap Blocks: exact=783752
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=1852.311..1852.311 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '3', enable_seqscan = 'off'
 Planning Time: 0.471 ms
 Execution Time: 23572.604 ms

-- 4

 WindowAgg  (cost=4095182.42..4096585.18 rows=70139 width=80) (actual time=21159.938..21258.114 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=135 read=3182787
   ->  Sort  (cost=4095182.40..4095357.75 rows=70139 width=48) (actual time=21159.929..21257.394 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=135 read=3182787
         ->  GroupAggregate  (cost=4086850.04..4089536.94 rows=70139 width=48) (actual time=21135.595..21256.746 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=135 read=3182787
               ->  Gather Merge  (cost=4086850.04..4087958.28 rows=70210 width=40) (actual time=21135.585..21248.671 rows=204053.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     Buffers: shared hit=135 read=3182787
                     ->  Sort  (cost=4086848.98..4086892.86 rows=17552 width=40) (actual time=21124.998..21126.466 rows=40810.60 loops=5)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2896kB
                           Buffers: shared hit=135 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 2787kB
                           Worker 1:  Sort Method: quicksort  Memory: 2823kB
                           Worker 2:  Sort Method: quicksort  Memory: 2799kB
                           Worker 3:  Sort Method: quicksort  Memory: 2755kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4085611.62 rows=17552 width=40) (actual time=2495.151..21115.965 rows=40810.60 loops=5)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 11442010
                                 Heap Blocks: exact=633656
                                 Buffers: shared hit=77 read=3182781
                                 Worker 0:  Heap Blocks: exact=631175
                                 Worker 1:  Heap Blocks: exact=622921
                                 Worker 2:  Heap Blocks: exact=625167
                                 Worker 3:  Heap Blocks: exact=620913
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=1774.146..1774.146 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '4', enable_seqscan = 'off'
 Planning Time: 0.401 ms
 Execution Time: 21258.223 ms

-- 5

 WindowAgg  (cost=4024077.99..4025480.75 rows=70139 width=80) (actual time=19218.508..19335.042 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=171 read=3182787
   ->  Sort  (cost=4024077.97..4024253.32 rows=70139 width=48) (actual time=19218.499..19334.316 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=171 read=3182787
         ->  GroupAggregate  (cost=4015662.05..4018432.51 rows=70139 width=48) (actual time=19189.580..19333.649 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=171 read=3182787
               ->  Gather Merge  (cost=4015662.05..4016853.85 rows=70210 width=40) (actual time=19189.569..19323.805 rows=204053.00 loops=1)
                     Workers Planned: 5
                     Workers Launched: 5
                     Buffers: shared hit=171 read=3182787
                     ->  Sort  (cost=4015660.97..4015696.07 rows=14042 width=40) (actual time=19181.356..19182.529 rows=34008.83 loops=6)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 2680kB
                           Buffers: shared hit=171 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 2599kB
                           Worker 1:  Sort Method: quicksort  Memory: 2638kB
                           Worker 2:  Sort Method: quicksort  Memory: 1742kB
                           Worker 3:  Sort Method: quicksort  Memory: 2585kB
                           Worker 4:  Sort Method: quicksort  Memory: 2585kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..4014693.65 rows=14042 width=40) (actual time=2585.403..19173.721 rows=34008.83 loops=6)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 9535008
                                 Heap Blocks: exact=534757
                                 Buffers: shared hit=97 read=3182781
                                 Worker 0:  Heap Blocks: exact=525818
                                 Worker 1:  Heap Blocks: exact=520070
                                 Worker 2:  Heap Blocks: exact=514870
                                 Worker 3:  Heap Blocks: exact=516053
                                 Worker 4:  Heap Blocks: exact=522264
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=1854.658..1854.658 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '5', enable_seqscan = 'off'
 Planning Time: 0.115 ms
 Execution Time: 19335.117 ms

-- 6

 WindowAgg  (cost=3976695.00..3978097.76 rows=70139 width=80) (actual time=17560.893..17682.002 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=207 read=3182787
   ->  Sort  (cost=3976694.98..3976870.33 rows=70139 width=48) (actual time=17560.883..17681.173 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=207 read=3182787
         ->  GroupAggregate  (cost=3968206.84..3971049.52 rows=70139 width=48) (actual time=17531.499..17680.422 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=207 read=3182787
               ->  Gather Merge  (cost=3968206.84..3969470.86 rows=70210 width=40) (actual time=17531.489..17670.652 rows=204053.00 loops=1)
                     Workers Planned: 6
                     Workers Launched: 6
                     Buffers: shared hit=207 read=3182787
                     ->  Sort  (cost=3968205.74..3968234.99 rows=11702 width=40) (actual time=17515.372..17516.589 rows=29150.43 loops=7)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1778kB
                           Buffers: shared hit=207 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 1660kB
                           Worker 1:  Sort Method: quicksort  Memory: 1637kB
                           Worker 2:  Sort Method: quicksort  Memory: 1672kB
                           Worker 3:  Sort Method: quicksort  Memory: 1669kB
                           Worker 4:  Sort Method: quicksort  Memory: 1690kB
                           Worker 5:  Sort Method: quicksort  Memory: 1649kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..3967415.01 rows=11702 width=40) (actual time=2611.154..17507.822 rows=29150.43 loops=7)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 8172864
                                 Heap Blocks: exact=459743
                                 Buffers: shared hit=117 read=3182781
                                 Worker 0:  Heap Blocks: exact=450286
                                 Worker 1:  Heap Blocks: exact=442868
                                 Worker 2:  Heap Blocks: exact=448454
                                 Worker 3:  Heap Blocks: exact=443126
                                 Worker 4:  Heap Blocks: exact=445616
                                 Worker 5:  Heap Blocks: exact=443739
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=1863.789..1863.789 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '6', enable_seqscan = 'off'
 Planning Time: 0.483 ms
 Execution Time: 17682.138 ms

-- 7

 WindowAgg  (cost=3942863.87..3944266.63 rows=70139 width=80) (actual time=16576.992..16711.374 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=243 read=3182787
   ->  Sort  (cost=3942863.85..3943039.20 rows=70139 width=48) (actual time=16576.981..16710.484 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=243 read=3182787
         ->  GroupAggregate  (cost=3934312.26..3937218.39 rows=70139 width=48) (actual time=16544.308..16709.680 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=243 read=3182787
               ->  Gather Merge  (cost=3934312.26..3935639.73 rows=70210 width=40) (actual time=16544.294..16698.703 rows=204053.00 loops=1)
                     Workers Planned: 7
                     Workers Launched: 7
                     Buffers: shared hit=243 read=3182787
                     ->  Sort  (cost=3934311.14..3934336.21 rows=10030 width=40) (actual time=16527.233..16528.387 rows=25506.62 loops=8)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1668kB
                           Buffers: shared hit=243 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 1567kB
                           Worker 1:  Sort Method: quicksort  Memory: 1594kB
                           Worker 2:  Sort Method: quicksort  Memory: 1534kB
                           Worker 3:  Sort Method: quicksort  Memory: 1565kB
                           Worker 4:  Sort Method: quicksort  Memory: 1542kB
                           Worker 5:  Sort Method: quicksort  Memory: 1501kB
                           Worker 6:  Sort Method: quicksort  Memory: 1553kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..3933644.54 rows=10030 width=40) (actual time=2638.921..16518.911 rows=25506.62 loops=8)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 7151256
                                 Heap Blocks: exact=403985
                                 Buffers: shared hit=137 read=3182781
                                 Worker 0:  Heap Blocks: exact=392208
                                 Worker 1:  Heap Blocks: exact=393054
                                 Worker 2:  Heap Blocks: exact=387882
                                 Worker 3:  Heap Blocks: exact=391117
                                 Worker 4:  Heap Blocks: exact=386345
                                 Worker 5:  Heap Blocks: exact=390853
                                 Worker 6:  Heap Blocks: exact=388388
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=1888.440..1888.440 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '7', enable_seqscan = 'off'
 Planning Time: 0.468 ms
 Execution Time: 16711.503 ms

-- 8

 WindowAgg  (cost=3917500.77..3918903.53 rows=70139 width=80) (actual time=16130.139..16247.815 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=279 read=3182787
   ->  Sort  (cost=3917500.75..3917676.09 rows=70139 width=48) (actual time=16130.129..16247.026 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=279 read=3182787
         ->  GroupAggregate  (cost=3908892.64..3911855.28 rows=70139 width=48) (actual time=16098.910..16246.290 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=279 read=3182787
               ->  Gather Merge  (cost=3908892.64..3910276.62 rows=70210 width=40) (actual time=16098.885..16236.080 rows=204053.00 loops=1)
                     Workers Planned: 8
                     Workers Launched: 8
                     Buffers: shared hit=279 read=3182787
                     ->  Sort  (cost=3908891.49..3908913.43 rows=8776 width=40) (actual time=16077.737..16078.901 rows=22672.56 loops=9)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1550kB
                           Buffers: shared hit=279 read=3182787
                           Worker 0:  Sort Method: quicksort  Memory: 1444kB
                           Worker 1:  Sort Method: quicksort  Memory: 1474kB
                           Worker 2:  Sort Method: quicksort  Memory: 1446kB
                           Worker 3:  Sort Method: quicksort  Memory: 1430kB
                           Worker 4:  Sort Method: quicksort  Memory: 1484kB
                           Worker 5:  Sort Method: quicksort  Memory: 1480kB
                           Worker 6:  Sort Method: quicksort  Memory: 1503kB
                           Worker 7:  Sort Method: quicksort  Memory: 1483kB
                           ->  Parallel Bitmap Heap Scan on order_events  (cost=597181.77..3908316.69 rows=8776 width=40) (actual time=2640.011..16063.601 rows=22672.56 loops=9)
                                 Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 6356672
                                 Heap Blocks: exact=358568
                                 Buffers: shared hit=157 read=3182781
                                 Worker 0:  Heap Blocks: exact=349184
                                 Worker 1:  Heap Blocks: exact=347429
                                 Worker 2:  Heap Blocks: exact=345760
                                 Worker 3:  Heap Blocks: exact=352673
                                 Worker 4:  Heap Blocks: exact=348936
                                 Worker 5:  Heap Blocks: exact=342263
                                 Worker 6:  Heap Blocks: exact=347354
                                 Worker 7:  Heap Blocks: exact=341665
                                 ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=1894.782..1894.783 rows=57414102.00 loops=1)
                                       Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                       Index Searches: 1
                                       Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '8', enable_seqscan = 'off'
 Planning Time: 0.474 ms
 Execution Time: 16247.952 ms
```

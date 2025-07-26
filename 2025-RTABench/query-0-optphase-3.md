-- BitmapOr:

 WindowAgg  (cost=263601.27..264997.05 rows=69790 width=80) (actual time=204.832..205.515 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=129335
   ->  Sort  (cost=263601.25..263775.72 rows=69790 width=48) (actual time=204.821..204.866 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=129335
         ->  HashAggregate  (cost=256939.53..257986.38 rows=69790 width=48) (actual time=203.988..204.256 rows=2232.00 loops=1)
               Group Key: date_trunc('hour'::text, order_events.event_created), (order_events.event_payload ->> 'terminal'::text)
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=129335
               ->  Bitmap Heap Scan on order_events  (cost=6969.70..256415.58 rows=69860 width=40) (actual time=79.494..185.493 rows=204053.00 loops=1)
                     Recheck Cond: (((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = 'Berli
n'::text)) OR ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = 'Hamburg'::text)) OR ((event
_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = 'Munich'::text)))
                     Filter: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                     Heap Blocks: exact=126384
                     Buffers: shared hit=129335
                     ->  BitmapOr  (cost=6969.70..6969.70 rows=70210 width=0) (actual time=66.140..66.141 rows=0.00 loops=1)
                           Buffers: shared hit=2951
                           ->  Bitmap Index Scan on idx_4_1  (cost=0.00..2305.77 rows=23403 width=0) (actual time=29.985..29.985 rows=67804.00 loops=1)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Index Searches: 1
                                 Buffers: shared hit=980
                           ->  Bitmap Index Scan on idx_4_2  (cost=0.00..2305.77 rows=23403 width=0) (actual time=18.022..18.022 rows=67751.00 loops=1)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Index Searches: 1
                                 Buffers: shared hit=980
                           ->  Bitmap Index Scan on idx_4_3  (cost=0.00..2305.77 rows=23403 width=0) (actual time=18.131..18.131 rows=68498.00 loops=1)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Index Searches: 1
                                 Buffers: shared hit=991
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '16'
 Planning Time: 0.570 ms
 Execution Time: 205.994 ms

-- IndexOnlyScan on all filters:

-- 0

 WindowAgg  (cost=12222.27..13625.03 rows=70139 width=80) (actual time=53.271..53.960 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=110862
   ->  Sort  (cost=12222.25..12397.60 rows=70139 width=48) (actual time=53.261..53.305 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=110862
         ->  HashAggregate  (cost=5524.70..6576.79 rows=70139 width=48) (actual time=52.459..52.701 rows=2232.00 loops=1)
               Group Key: date_trunc('hour'::text, order_events.event_created), (order_events.event_payload ->> 'terminal'::text)
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=110862
               ->  Index Only Scan using idx_5 on order_events  (cost=0.42..4998.13 rows=70210 width=40) (actual time=0.014..34.718 rows=204053.00 loops=1)
                     Heap Fetches: 0
                     Index Searches: 1
                     Buffers: shared hit=110862
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '16'
 Planning Time: 0.123 ms
 Execution Time: 54.117 ms

-- 1

 WindowAgg  (cost=11859.83..13262.59 rows=70139 width=80) (actual time=58.442..59.185 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=110853
   ->  Sort  (cost=11859.81..12035.16 rows=70139 width=48) (actual time=58.432..58.509 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=110853
         ->  HashAggregate  (cost=5162.26..6214.35 rows=70139 width=48) (actual time=57.594..57.882 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=110853
               ->  Gather  (cost=1.42..4635.69 rows=70210 width=40) (actual time=9.419..35.381 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=110853
                     ->  Parallel Index Only Scan using idx_5 on order_events  (cost=0.42..4564.48 rows=41300 width=40) (actual time=0.044..25.019 rows=102026.50 loops=2)
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=110853
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1', max_parallel_workers = '16'
 Planning Time: 0.704 ms
 Execution Time: 59.616 ms

-- 2

 WindowAgg  (cost=11679.14..13081.90 rows=70139 width=80) (actual time=31.966..32.856 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=110863
   ->  Sort  (cost=11679.12..11854.47 rows=70139 width=48) (actual time=31.957..32.135 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=110863
         ->  HashAggregate  (cost=4981.57..6033.66 rows=70139 width=48) (actual time=31.076..31.478 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=110863
               ->  Gather  (cost=1.42..4455.00 rows=70210 width=40) (actual time=0.329..12.329 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=110863
                     ->  Parallel Index Only Scan using idx_5 on order_events  (cost=0.42..4383.79 rows=29254 width=40) (actual time=0.055..15.301 rows=68017.67 loops=3)
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=110863
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers = '16'
 Planning Time: 0.496 ms
 Execution Time: 33.182 ms

-- 3

 WindowAgg  (cost=11580.05..12982.81 rows=70139 width=80) (actual time=29.106..29.871 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=110914
   ->  Sort  (cost=11580.03..11755.38 rows=70139 width=48) (actual time=29.096..29.193 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=110914
         ->  HashAggregate  (cost=4882.49..5934.57 rows=70139 width=48) (actual time=28.237..28.532 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=110914
               ->  Gather  (cost=1.42..4355.91 rows=70210 width=40) (actual time=0.508..9.570 rows=204053.00 loops=1)
                     Workers Planned: 3
                     Workers Launched: 3
                     Buffers: shared hit=110914
                     ->  Parallel Index Only Scan using idx_5 on order_events  (cost=0.42..4284.70 rows=22648 width=40) (actual time=0.052..12.145 rows=51013.25 loops=4)
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=110914
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '3', max_parallel_workers = '16'
 Planning Time: 0.687 ms
 Execution Time: 30.343 ms

-- 4

 WindowAgg  (cost=11503.62..12906.38 rows=70139 width=80) (actual time=31.234..31.971 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=110856
   ->  Sort  (cost=11503.60..11678.94 rows=70139 width=48) (actual time=31.225..31.314 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=110856
         ->  HashAggregate  (cost=4806.05..5858.13 rows=70139 width=48) (actual time=30.332..30.627 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=110856
               ->  Gather  (cost=1.42..4279.47 rows=70210 width=40) (actual time=0.539..10.258 rows=204053.00 loops=1)
                     Workers Planned: 4
                     Workers Launched: 4
                     Buffers: shared hit=110856
                     ->  Parallel Index Only Scan using idx_5 on order_events  (cost=0.42..4208.26 rows=17552 width=40) (actual time=0.072..12.801 rows=40810.60 loops=5)
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=110856
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '4', max_parallel_workers = '16'
 Planning Time: 0.653 ms
 Execution Time: 32.419 ms

-- 8

 WindowAgg  (cost=11390.78..12793.54 rows=70139 width=80) (actual time=35.803..36.554 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=110866
   ->  Sort  (cost=11390.76..11566.11 rows=70139 width=48) (actual time=35.791..35.904 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=110866
         ->  HashAggregate  (cost=4693.21..5745.30 rows=70139 width=48) (actual time=34.914..35.281 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=110866
               ->  Gather  (cost=1.42..4166.64 rows=70210 width=40) (actual time=0.583..11.389 rows=204053.00 loops=1)
                     Workers Planned: 7
                     Workers Launched: 7
                     Buffers: shared hit=110866
                     ->  Parallel Index Only Scan using idx_5 on order_events  (cost=0.42..4095.43 rows=10030 width=40) (actual time=0.250..13.219 rows=25506.62 loops=8)
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=110866
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '8', max_parallel_workers = '16'
 Planning Time: 0.564 ms
 Execution Time: 36.938 ms
 
-- 0

 WindowAgg  (cost=22635.37..24038.13 rows=70139 width=80) (actual time=99.048..99.726 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=116561
   ->  Sort  (cost=22635.35..22810.70 rows=70139 width=48) (actual time=99.040..99.085 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=116561
         ->  HashAggregate  (cost=15937.80..16989.89 rows=70139 width=48) (actual time=98.255..98.488 rows=2232.00 loops=1)
               Group Key: date_trunc('hour'::text, order_events.event_created), (order_events.event_payload ->> 'terminal'::text)
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=116561
               ->  Index Only Scan using idx_4 on order_events  (cost=0.56..15411.23 rows=70210 width=40) (actual time=0.029..80.766 rows=204053.00 loops=1)
                     Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                     Heap Fetches: 0
                     Index Searches: 1
                     Buffers: shared hit=116561
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '16'
 Planning Time: 0.104 ms
 Execution Time: 99.879 ms

-- 1

 WindowAgg  (cost=22272.93..23675.69 rows=70139 width=80) (actual time=73.308..74.416 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=116653
   ->  Sort  (cost=22272.91..22448.26 rows=70139 width=48) (actual time=73.299..73.773 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=116653
         ->  HashAggregate  (cost=15575.36..16627.45 rows=70139 width=48) (actual time=72.446..73.161 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=116653
               ->  Gather  (cost=1.56..15048.79 rows=70210 width=40) (actual time=0.311..53.273 rows=204053.00 loops=1)
                     Workers Planned: 1
                     Workers Launched: 1
                     Buffers: shared hit=116653
                     ->  Parallel Index Only Scan using idx_4 on order_events  (cost=0.56..14977.58 rows=41300 width=40) (actual time=0.162..52.459 rows=102026.50 loops=2)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=116653
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '1', max_parallel_workers = '16'
 Planning Time: 0.296 ms
 Execution Time: 74.695 ms

-- 2

 WindowAgg  (cost=22092.24..23495.00 rows=70139 width=80) (actual time=52.774..54.429 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=116564
   ->  Sort  (cost=22092.22..22267.57 rows=70139 width=48) (actual time=52.764..53.709 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=116564
         ->  HashAggregate  (cost=15394.67..16446.76 rows=70139 width=48) (actual time=51.890..53.049 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=116564
               ->  Gather  (cost=1.56..14868.10 rows=70210 width=40) (actual time=0.563..34.032 rows=204053.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=116564
                     ->  Parallel Index Only Scan using idx_4 on order_events  (cost=0.56..14796.89 rows=29254 width=40) (actual time=0.237..35.670 rows=68017.67 loops=3)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=116564
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers = '16'
 Planning Time: 0.541 ms
 Execution Time: 54.914 ms

-- 16

 WindowAgg  (cost=21785.07..23187.83 rows=70139 width=80) (actual time=55.820..56.691 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=116877
   ->  Sort  (cost=21785.05..21960.40 rows=70139 width=48) (actual time=55.808..55.965 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=116877
         ->  HashAggregate  (cost=15087.50..16139.59 rows=70139 width=48) (actual time=54.917..55.294 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Batches: 1  Memory Usage: 2201kB
               Buffers: shared hit=116877
               ->  Gather  (cost=1.56..14560.93 rows=70210 width=40) (actual time=0.829..33.511 rows=204053.00 loops=1)
                     Workers Planned: 8
                     Workers Launched: 8
                     Buffers: shared hit=116877
                     ->  Parallel Index Only Scan using idx_4 on order_events  (cost=0.56..14489.72 rows=8776 width=40) (actual time=0.164..43.807 rows=22672.56 loops=9)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=116877
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '16', max_parallel_workers = '16'
 Planning Time: 0.536 ms
 Execution Time: 57.154 ms


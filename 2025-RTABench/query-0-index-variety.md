CREATE INDEX idx_1 ON order_events (event_created);

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

CREATE INDEX idx_2 ON order_events (event_created, event_type) INCLUDE (event_payload);

 WindowAgg  (cost=821441.55..822846.03 rows=70225 width=80) (actual time=7229.016..7229.755 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317527
   ->  Sort  (cost=821441.53..821617.09 rows=70225 width=48) (actual time=7229.007..7229.065 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317527
         ->  GroupAggregate  (cost=814032.19..815788.52 rows=70225 width=48) (actual time=7215.038..7228.438 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317527
               ->  Sort  (cost=814032.19..814207.93 rows=70296 width=40) (actual time=7215.026..7219.375 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=14317527
                     ->  Index Scan using idx1 on order_events  (cost=0.57..808372.95 rows=70296 width=40) (actual time=0.071..7186.828 rows=204053.00 loops=1)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                           Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                           Rows Removed by Filter: 14099758
                           Index Searches: 1
                           Buffers: shared hit=14317527
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=27 read=5 dirtied=2
 Planning Time: 2.646 ms
 Execution Time: 7229.858 ms

-- Disable index idx1

 WindowAgg  (cost=1053915.66..1055320.14 rows=70225 width=80) (actual time=1624.555..1625.240 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2558314
   ->  Sort  (cost=1053915.64..1054091.20 rows=70225 width=48) (actual time=1624.547..1624.591 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2558314
         ->  GroupAggregate  (cost=1046506.30..1048262.63 rows=70225 width=48) (actual time=1611.325..1624.014 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2558314
               ->  Sort  (cost=1046506.30..1046682.04 rows=70296 width=40) (actual time=1611.317..1615.189 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=2558314
                     ->  Index Only Scan using idx_2 on order_events  (cost=0.57..1040847.06 rows=70296 width=40) (actual time=0.060..1586.097 rows=204053.00 loops=1)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                           Rows Removed by Filter: 4292642
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=2558314
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=24 read=5 dirtied=2
 Planning Time: 0.960 ms
 Execution Time: 1625.320 ms

CREATE INDEX idx_2 ON order_events (event_created, event_type);

 WindowAgg  (cost=3789837.03..3791241.51 rows=70225 width=80) (actual time=1328.340..1329.023 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=313925
   ->  Sort  (cost=3789837.01..3790012.58 rows=70225 width=48) (actual time=1328.331..1328.376 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=313925
         ->  GroupAggregate  (cost=3782427.67..3784184.01 rows=70225 width=48) (actual time=1314.138..1327.801 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=313925
               ->  Sort  (cost=3782427.67..3782603.41 rows=70296 width=40) (actual time=1314.129..1318.947 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=313925
                     ->  Bitmap Heap Scan on order_events  (cost=374561.17..3776768.44 rows=70296 width=40) (actual time=655.432..1286.430 rows=204053.00 loops=1)
                           Recheck Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                           Rows Removed by Filter: 4292642
                           Heap Blocks: exact=269237
                           Buffers: shared hit=313925
                           ->  Bitmap Index Scan on idx_3  (cost=0.00..374543.60 rows=4686370 width=0) (actual time=625.170..625.170 rows=4496695.00 loops=1)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                                 Index Searches: 1
                                 Buffers: shared hit=44688
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.432 ms
 Execution Time: 1329.114 ms

SET enable_bitmapscan = f;

 WindowAgg  (cost=1053915.66..1055320.14 rows=70225 width=80) (actual time=1624.555..1625.240 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=2558314
   ->  Sort  (cost=1053915.64..1054091.20 rows=70225 width=48) (actual time=1624.547..1624.591 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=2558314
         ->  GroupAggregate  (cost=1046506.30..1048262.63 rows=70225 width=48) (actual time=1611.325..1624.014 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=2558314
               ->  Sort  (cost=1046506.30..1046682.04 rows=70296 width=40) (actual time=1611.317..1615.189 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=2558314
                     ->  Index Only Scan using idx_2 on order_events  (cost=0.57..1040847.06 rows=70296 width=40) (actual time=0.060..1586.097 rows=204053.00 loops=1)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                           Rows Removed by Filter: 4292642
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=2558314
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=24 read=5 dirtied=2
 Planning Time: 0.960 ms
 Execution Time: 1625.320 ms


# (1)

```
 WindowAgg  (cost=488.50..264985.22 rows=64475 width=104) (actual time=116.688..388.288 rows=6409.00 loops=1)
   Output: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text)), ((order_events.event_payload ->> 'status'::text)), avg((count(*))) OVER w1
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=204566
   ->  GroupAggregate  (cost=484.39..263856.91 rows=64475 width=80) (actual time=116.667..381.503 rows=6409.00 loops=1)
         Output: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text)), ((order_events.event_payload ->> 'status'::text)), count(*)
         Group Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'status'::text))
         Buffers: shared hit=204566
         ->  Incremental Sort  (cost=484.39..262083.20 rows=64540 width=72) (actual time=116.655..343.929 rows=204053.00 loops=1)
               Output: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text)), ((order_events.event_payload ->> 'status'::text))
               Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'status'::text))
               Presorted Key: ((order_events.event_payload ->> 'terminal'::text))
               Full-sort Groups: 3  Sort Method: quicksort  Average Memory: 28kB  Peak Memory: 28kB
               Pre-sorted Groups: 3  Sort Method: quicksort  Average Memory: 6261kB  Peak Memory: 6283kB
               Buffers: shared hit=204566
               ->  Index Scan using order_events_expr_event_type_event_created_idx on public.order_events  (cost=0.57..259038.66 rows=64540 width=72) (actual time=0.095..232.855 rows=204053.00 loops=1)
                     Output: date_trunc('hour'::text, order_events.event_created), (order_events.event_payload ->> 'terminal'::text), (order_events.event_payload ->> 'status'::text)
                     Index Cond: (((order_events.event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])) AND (order_events.event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND (order_events.event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (order_events.event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                     Index Searches: 9
                     Buffers: shared hit=204566
 Settings: parallel_setup_cost = '1e-05', parallel_tuple_cost = '1e-05', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', work_mem = '1GB', enable_bitmapscan = 'off', max_parallel_workers_per_gather = '0'
 Planning:
   Buffers: shared hit=5
 Planning Time: 1.876 ms
 Execution Time: 388.957 ms
```

# The BitmapScan effect:

```
 WindowAgg  (cost=239284.93..240572.69 rows=64389 width=104) (actual time=315.372..320.555 rows=6409.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=127507
   ->  Sort  (cost=239284.91..239445.88 rows=64389 width=80) (actual time=315.362..315.795 rows=6409.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 543kB
         Buffers: shared hit=127507
         ->  HashAggregate  (cost=233015.19..234141.99 rows=64389 width=80) (actual time=309.338..310.670 rows=6409.00 loops=1)
               Group Key: date_trunc('hour'::text, order_events.event_created), (order_events.event_payload ->> 'terminal'::text), (order_events.event_payload ->> 'status'::text)
               Batches: 1  Memory Usage: 2585kB
               Buffers: shared hit=127507
               ->  Bitmap Heap Scan on order_events  (cost=2392.11..232370.65 rows=64454 width=72) (actual time=58.685..245.272 rows=204053.00 loops=1)
                     Recheck Cond: (((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND (event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                     Heap Blocks: exact=126384
                     Buffers: shared hit=127507
                     ->  Bitmap Index Scan on order_events_expr_event_type_event_created_idx  (cost=0.00..2376.00 rows=64454 width=0) (actual time=28.088..28.089 rows=204053.00 loops=1)
                           Index Cond: (((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND (event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                           Index Searches: 9
                           Buffers: shared hit=1123
 Settings: parallel_setup_cost = '1e-05', parallel_tuple_cost = '1e-05', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', work_mem = '1GB'
 Planning Time: 0.725 ms
 Execution Time: 322.497 ms
```
# (2)
```
WindowAgg  (cost=627133.78..628423.26 rows=64475 width=104) (actual time=14482.640..14486.968 rows=6409.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=279131
   ->  Sort  (cost=627133.76..627294.95 rows=64475 width=80) (actual time=14482.576..14482.912 rows=6409.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 543kB
         Buffers: shared hit=279131
         ->  GroupAggregate  (cost=620048.29..621983.35 rows=64475 width=80) (actual time=14438.008..14478.248 rows=6409.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text)), ((order_events.event_payload ->> 'status'::text))
               Buffers: shared hit=279131
               ->  Sort  (cost=620048.29..620209.64 rows=64540 width=72) (actual time=14437.976..14449.936 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text)), ((order_events.event_payload ->> 'status'::text))
                     Sort Method: quicksort  Memory: 15709kB
                     Buffers: shared hit=279131
                     ->  Index Scan using order_events_event_created_event_type_expr_idx on order_events  (cost=0.57..614892.22 rows=64540 width=72) (actual time=0.499..14303.685 rows=204053.00 loops=1)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                           Index Searches: 1
                           Buffers: shared hit=279131
 Settings: parallel_setup_cost = '1e-05', parallel_tuple_cost = '1e-05', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', work_mem = '1GB'
 Planning:
   Buffers: shared hit=5
 Planning Time: 2.314 ms
 Execution Time: 14488.326 ms
```
# (3)
```
 WindowAgg  (cost=6991250.18..6992539.66 rows=64475 width=104) (actual time=8980.705..8985.116 rows=6409.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=4509185
   ->  Sort  (cost=6991250.16..6991411.35 rows=64475 width=80) (actual time=8980.695..8981.066 rows=6409.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 543kB
         Buffers: shared hit=4509185
         ->  GroupAggregate  (cost=6984164.69..6986099.75 rows=64475 width=80) (actual time=8925.821..8976.008 rows=6409.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text)), ((order_events.event_payload ->> 'status'::text))
               Buffers: shared hit=4509185
               ->  Sort  (cost=6984164.69..6984326.04 rows=64540 width=72) (actual time=8925.804..8940.746 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text)), ((order_events.event_payload ->> 'status'::text))
                     Sort Method: quicksort  Memory: 15709kB
                     Buffers: shared hit=4509185
                     ->  Index Scan using idx_3 on order_events  (cost=0.57..6979008.62 rows=64540 width=72) (actual time=0.238..8777.846 rows=204053.00 loops=1)
                           Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
                           Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
                           Rows Removed by Filter: 4292642
                           Index Searches: 1
                           Buffers: shared hit=4509185
 Settings: parallel_setup_cost = '1e-05', parallel_tuple_cost = '1e-05', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', work_mem = '1GB', enable_bitmapscan = 'off', max_parallel_workers_per_gather = '0'
 Planning:
   Buffers: shared hit=5
 Planning Time: 1.178 ms
 Execution Time: 8986.287 ms
```

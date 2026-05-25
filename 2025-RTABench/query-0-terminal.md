WITH hourly_stats AS (
  SELECT 
    date_trunc('hour', event_created) as hour,
    event_payload->>'terminal' as terminal,
    count(*) as event_count
  FROM order_events
  WHERE 
    event_created >= '2024-01-01' and event_created < '2024-02-01'
    AND event_type IN ('Created', 'Departed', 'Delivered')
  GROUP BY hour, terminal
)
SELECT 
  hour,
  terminal,
  event_count,
  AVG(event_count) OVER (
    PARTITION BY terminal
    ORDER BY hour
    ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
  ) as moving_avg_events
FROM hourly_stats
WHERE terminal IN ('Berlin')
ORDER BY terminal, hour;

EXPLAIN (ANALYZE, VERBOSE, BUFFERS ON, TIMING ON, SETTINGS ON)
WITH hourly_stats AS (
  SELECT 
    date_trunc('hour', event_created) as hour,
    event_payload->>'terminal' as terminal,
    count(*) as event_count
  FROM order_events
  WHERE 
    event_created >= '2024-01-01' and event_created < '2024-02-01'
    AND event_type IN ('Created', 'Departed', 'Delivered')
  GROUP BY hour, terminal
)
SELECT 
  hour,
  terminal,
  event_count,
  AVG(event_count) OVER (
    PARTITION BY terminal
    ORDER BY hour
    ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
  ) as moving_avg_events
FROM hourly_stats
WHERE terminal >= 'Berlin' AND terminal < 'Berlina'
ORDER BY terminal, hour;

 WindowAgg  (cost=232.47..123277.14 rows=21506 width=80) (actual time=86.516..102.090 rows=744.00 loops=1)
   Output: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text)), (count(*)), avg((count(*))) OVER w1
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=67977
   ->  GroupAggregate  (cost=226.75..122900.78 rows=21506 width=48) (actual time=86.500..101.397 rows=744.00 loops=1)
         Output: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text)), count(*)
         Group Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Buffers: shared hit=67977
         ->  Incremental Sort  (cost=226.75..122416.84 rows=21513 width=40) (actual time=86.487..91.842 rows=67804.00 loops=1)
               Output: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
               Presorted Key: ((order_events.event_payload ->> 'terminal'::text))
               Full-sort Groups: 1  Sort Method: quicksort  Average Memory: 27kB  Peak Memory: 27kB
               Pre-sorted Groups: 1  Sort Method: quicksort  Average Memory: 5191kB  Peak Memory: 5191kB
               Buffers: shared hit=67977
               ->  Index Scan using order_events_expr_event_type_event_created_idx on public.order_events  (cost=0.57..121565.31 rows=21513 width=40) (actual time=0.078..68.211 rows=67804.00 loops=1)
                     Output: date_trunc('hour'::text, order_events.event_created), (order_events.event_payload ->> 'terminal'::text)
                     Index Cond: (((order_events.event_payload ->> 'terminal'::text) >= 'Berlin'::text) AND ((order_events.event_payload ->> 'terminal'::text) < 'Berlina'::text) AND (order_events.event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND (order_events.event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (order_events.event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                     Index Searches: 4
                     Buffers: shared hit=67977
 Settings: parallel_setup_cost = '1e-05', parallel_tuple_cost = '1e-05', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', work_mem = '1GB', enable_bitmapscan = 'off', max_parallel_workers_per_gather = '0'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.653 ms
 Execution Time: 102.393 ms
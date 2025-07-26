#  Задача
Исследовать запрос 0, найти на его примере какие-то особенности, поднастроить систему.

Начальное выполнение без каких-то донастроек:

```
 WindowAgg  (cost=5162432.55..5163835.31 rows=70139 width=80) (actual time=40849.960..40853.715 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared read=3182778
   ->  Sort  (cost=5162432.53..5162607.88 rows=70139 width=48) (actual time=40849.940..40850.069 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared read=3182778
         ->  GroupAggregate  (cost=5155032.88..5156787.07 rows=70139 width=48) (actual time=40794.333..40847.727 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared read=3182778
               ->  Sort  (cost=5155032.88..5155208.41 rows=70210 width=40) (actual time=40794.311..40808.829 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared read=3182778
                     ->  Bitmap Heap Scan on order_events  (cost=597181.77..5149381.19 rows=70210 width=40) (actual time=5220.825..40684.674 rows=204053.00 loops=1)
                           Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                           Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                           Rows Removed by Filter: 57210049
                           Heap Blocks: exact=3133832
                           Buffers: shared read=3182778
                           ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=3721.638..3721.639 rows=57414102.00 loops=1)
                                 Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
                                 Index Searches: 1
                                 Buffers: shared read=48946
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0'
 Planning Time: 0.218 ms
 Execution Time: 40892.508 ms
```

# Загадка No.1: Unstable execution time in Bitmap Heap Scan
Посмотрим в два HeapScan'a:
```
->  Bitmap Heap Scan on order_events  (cost=597181.77..5149381.19 rows=70210 width=40) (actual time=5220.825..40684.674 rows=204053.00 loops=1)
      Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
      Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
      Rows Removed by Filter: 57210049
      Heap Blocks: exact=3133832
      Buffers: shared read=3182778
      ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=3721.638..3721.639 rows=57414102.00 loops=1)
            Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
            Index Searches: 1
            Buffers: shared read=48946

->  Bitmap Heap Scan on order_events  (cost=597181.77..5149381.19 rows=70210 width=40) (actual time=4962.018..34551.302 rows=204053.00 loops=1)
      Recheck Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
      Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
      Rows Removed by Filter: 57210049
      Heap Blocks: exact=3133832
      Buffers: shared read=3182778
      ->  Bitmap Index Scan on order_events_event_type_index  (cost=0.00..597164.21 rows=56720335 width=0) (actual time=3652.216..3652.216 rows=57414102.00 loops=1)
            Index Cond: (event_type = ANY ('{Created,Departed,Delivered}'::text[]))
            Index Searches: 1
            Buffers: shared read=48946
```
Они сделаны с разницей в 30 секунд на одной и той же машине. При том, что Bitmap Index Scan выполняется примерно одинаково (actual time= 3721.639 и 3652.216), время выполнения самой ноды отличается разительно: 40684.674 и 34551.302. Интересно, а в чем причина разницы? И раз так долго, то не было бы эффективнее использовать  IndexScan?

Выключение BitmapScan не ускоряет, но делает выполнение стабильным
```
 WindowAgg  (cost=7690684.81..7692087.57 rows=70139 width=80) (actual time=48553.084..48556.150 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=1048251 read=2085589
   ->  Sort  (cost=7690684.79..7690860.14 rows=70139 width=48) (actual time=48553.066..48553.168 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=1048251 read=2085589
         ->  GroupAggregate  (cost=7683285.14..7685039.33 rows=70139 width=48) (actual time=48510.665..48551.298 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=1048251 read=2085589
               ->  Sort  (cost=7683285.14..7683460.67 rows=70210 width=40) (actual time=48510.643..48521.400 rows=204053.00 loops=1)
                     Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                     Sort Method: quicksort  Memory: 12521kB
                     Buffers: shared hit=1048251 read=2085589
                     ->  Seq Scan on order_events  (cost=0.00..7677633.45 rows=70210 width=40) (actual time=30.416..48425.798 rows=204053.00 loops=1)
                           Filter: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{
Berlin,Hamburg,Munich}'::text[])))
                           Rows Removed by Filter: 181533639
                           Buffers: shared hit=1048251 read=2085589
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1', parallel_tuple_cost = '0.001', max_parallel_workers_per_gather = '0', enable_bitmapscan = 'off'
 Planning Time: 0.753 ms
 Execution Time: 48557.945 ms
```
Здесь видимо действует лимит на размер буфера для одной таблицы - мы же не можем заполнить весь shared_buffers?

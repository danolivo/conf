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

## А где конкретно в коде ограничение на размер буфера?
Вроде бы коммит d526575 и структура BufferAccessStrategyData ответственны за это. Также см. GetAccessStrategyWithSize:
```
ring_buffers = ring_size_kb / (BLCKSZ / 1024);
```
Есть стратегия для простого сканирования и для вакуума. В нашем случае используется тип BAS_BULKREAD и ring_size_kb == 2304. Вычисления там не очень тривиальны, но исходно отсчитываются от величины `NBuffers / (MaxBackends`.

Хм, а может у нас много всяких проверок? Нужно отключить все лишние вставки кода и скомпилировать с усиленной компиляцией.
Заработало, хотя и эффект параллелелизма стал сильно меньше.
Следующий вопрос: я снизил косты, однако executor почему-то решает использовать сильно меньшее количество воркеров. С какой стати?

вижу, что поле num_workers ноды Gather и nworkers_to_launch содержат то же, что и 'workers planned'. Что-то случилось в LaunchParallelWorkers? Ларчик открывался просто - нужно было корректно выставить ешё и max_parallel_workers.

Хм, имею индексы:
CREATE INDEX idx_1 ON order_events (event_created);
CREATE INDEX idx_2 ON order_events (event_created, event_type) INCLUDE (event_payload);

Запрос почему-то выбрал idx_1:
```
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
```

Может быть дело в том, что кост модель игнорирует что-то, например то, что не нужно будет ходить в саму таблицу?
CREATE INDEX idx_3 ON order_events (event_created, event_type);
```
->  Index Scan using idx_3 on order_events  (cost=0.57..7597612.29 rows=70296 width=40) (actual time=0.199..2759.684 rows=204053.00 loops=1)
      Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone) AND (event_type = ANY ('{Created,Departed,Delivered}'::text[])))
      Filter: ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[]))
      Rows Removed by Filter: 4292642
      Index Searches: 1
      Buffers: shared hit=4509185
```
Выглядит так, как будто ширина индекса (дополнительная колонка) весит слишком много. Возможно именно поэтому, на многоколоночном индексе охотнее используется BitmapScan.

# Загадка: Почему не работает объединение частичных индексов?
Интересно, пытаюсь сделать покрытие частичными индексами, но постгрес его не подхватил:

```
CREATE INDEX idx_4_1 ON order_events (event_created, event_type)
WHERE (event_payload ->> 'terminal' = 'Berlin');
CREATE INDEX idx_4_2 ON order_events (event_created, event_type)
WHERE (event_payload ->> 'terminal' = 'Hamburg');
CREATE INDEX idx_4_3 ON order_events (event_created, event_type)
WHERE (event_payload ->> 'terminal' = 'Munich');
```
# Загадка: Верхний лимит по количеству воркеров
Имеем индексное сканирование, масштабируемое. Что мешает оптимизатору перешагнуть рубеж в 10 воркеров?
```
 WindowAgg  (cost=546868.03..548272.51 rows=70225 width=80) (actual time=976.510..1008.237 rows=2232.00 loops=1)
   Window: w1 AS (PARTITION BY ((order_events.event_payload ->> 'terminal'::text)) ORDER BY (date_trunc('hour'::text, order_events.event_created)) ROWS BETWEEN '3'::bigint PRECEDING AND CURRENT ROW)
   Storage: Memory  Maximum Storage: 17kB
   Buffers: shared hit=14317696
   ->  Sort  (cost=546868.01..547043.57 rows=70225 width=48) (actual time=976.499..1007.454 rows=2232.00 loops=1)
         Sort Key: ((order_events.event_payload ->> 'terminal'::text)), (date_trunc('hour'::text, order_events.event_created))
         Sort Method: quicksort  Memory: 184kB
         Buffers: shared hit=14317696
         ->  GroupAggregate  (cost=538225.17..541215.00 rows=70225 width=48) (actual time=943.115..1006.704 rows=2232.00 loops=1)
               Group Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
               Buffers: shared hit=14317696
               ->  Gather Merge  (cost=538225.17..539634.41 rows=70296 width=40) (actual time=943.103..996.099 rows=204053.00 loops=1)
                     Workers Planned: 10
                     Workers Launched: 10
                     Buffers: shared hit=14317696
                     ->  Sort  (cost=538224.98..538242.56 rows=7030 width=40) (actual time=936.860..937.606 rows=18550.27 loops=11)
                           Sort Key: (date_trunc('hour'::text, order_events.event_created)), ((order_events.event_payload ->> 'terminal'::text))
                           Sort Method: quicksort  Memory: 1482kB
                           Buffers: shared hit=14317696
                           Worker 0:  Sort Method: quicksort  Memory: 1295kB
                           Worker 1:  Sort Method: quicksort  Memory: 1293kB
                           Worker 2:  Sort Method: quicksort  Memory: 1293kB
                           Worker 3:  Sort Method: quicksort  Memory: 1421kB
                           Worker 4:  Sort Method: quicksort  Memory: 1301kB
                           Worker 5:  Sort Method: quicksort  Memory: 1300kB
                           Worker 6:  Sort Method: quicksort  Memory: 1289kB
                           Worker 7:  Sort Method: quicksort  Memory: 1299kB
                           Worker 8:  Sort Method: quicksort  Memory: 1431kB
                           Worker 9:  Sort Method: quicksort  Memory: 1425kB
                           ->  Parallel Index Scan using idx1 on order_events  (cost=0.57..537775.79 rows=7030 width=40) (actual time=0.173..932.088 rows=18550.27 loops=11)
                                 Index Cond: ((event_created >= '2024-01-01 00:00:00+00'::timestamp with time zone) AND (event_created < '2024-02-01 00:00:00+00'::timestamp with time zone))
                                 Filter: ((event_type = ANY ('{Created,Departed,Delivered}'::text[])) AND ((event_payload ->> 'terminal'::text) = ANY ('{Berlin,Hamburg,Munich}'::text[])))
                                 Rows Removed by Filter: 1281796
                                 Index Searches: 1
                                 Buffers: shared hit=14317536
 Settings: work_mem = '1GB', min_parallel_table_scan_size = '0', min_parallel_index_scan_size = '0', parallel_setup_cost = '1e-11', parallel_tuple_cost = '1e-13', max_parallel_workers_per_gather = '16', max_parallel_workers = '16'
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.399 ms
 Execution Time: 1008.383 ms
```
В коде есть лимит на количество страниц в таблице, который не обойти. Поэтому воспользуемся ручным режимом:
`ALTER TABLE order_events SET (parallel_workers = 16);`
Интересно, а как джойн принимает решение о количестве воркеров?
```
/* This is a foolish way to estimate parallel_workers, but for now... */
pathnode->jpath.path.parallel_workers = outer_path->parallel_workers;
```

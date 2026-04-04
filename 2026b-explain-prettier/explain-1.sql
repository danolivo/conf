SELECT pretty_explain_text($$
Limit  (cost=1140.86..1156.16 rows=306 width=565) (actual time=5.507..5.588 rows=76 loops=1)
  ->  Result  (cost=1140.76..1156.06 rows=306 width=565) (actual time=5.506..5.581 rows=76 loops=1)
        ->  Sort  (cost=1140.76..1141.07 rows=306 width=706) (actual time=5.497..5.511 rows=76 loops=1)
              Sort Key: t1._fld33610 DESC, t1._documenttref DESC, t1._documentrref DESC
              Sort Method: quicksort  Memory: 48kB
              ->  Nested Loop Left Join  (cost=60.77..1130.46 rows=306 width=706) (actual time=1.040..5.394 rows=76 loops=1)
                    Join Filter: (t1._documenttref = '\\x00000428'::bytea)
                    ->  Hash Left Join  (cost=60.65..1072.45 rows=306 width=333) (actual time=1.020..5.033 rows=76 loops=1)
                          Hash Cond: (t1._documentrref = t5._idrref)
                          Join Filter: (t1._documenttref = '\\x000003d8'::bytea)
                          Rows Removed by Hash Matching: 74
                          ->  Nested Loop Left Join  (cost=56.51..1067.99 rows=306 width=331) (actual time=0.974..4.960 rows=76 loops=1)
                                Join Filter: (t1._documenttref = '\\x0000049d'::bytea)
                                ->  Hash Left Join  (cost=56.40..1022.95 rows=306 width=323) (actual time=0.964..4.696 rows=76 loops=1)
                                      Hash Cond: (t1._documentrref = t11._idrref)
                                      Join Filter: (t1._documenttref = '\\x000004a8'::bytea)
                                      Rows Removed by Hash Matching: 76
                                      ->  Nested Loop Left Join  (cost=55.22..1021.45 rows=306 width=315) (actual time=0.945..4.653 rows=76 loops=1)
                                            Join Filter: (t1._documenttref = '\\x000003d7'::bytea)
                                            ->  Hash Left Join  (cost=55.11..976.47 rows=306 width=313) (actual time=0.933..4.436 rows=76 loops=1)
                                                  Hash Cond: (t1._documentrref = t22._idrref)
                                                  Join Filter: (t1._documenttref = '\\x0000049e'::bytea)
                                                  Rows Removed by Hash Matching: 76
                                                  ->  Nested Loop Left Join  (cost=51.14..972.18 rows=306 width=305) (actual time=0.896..4.374 rows=76 loops=1)
                                                        Join Filter: ((t1._documenttref = '\\x00000415'::bytea) AND (t1._documentrref = t19._idrref))
                                                        ->  Nested Loop Left Join  (cost=51.14..968.51 rows=306 width=297) (actual time=0.891..4.291 rows=76 loops=1)
                                                              Join Filter: (t1._documenttref = '\\x0000042a'::bytea)
                                                              ->  Nested Loop Left Join  (cost=51.03..924.32 rows=306 width=289) (actual time=0.880..4.066 rows=76 loops=1)
                                                                    Join Filter: (t1._documenttref = '\\x000003dc'::bytea)
                                                                    ->  Nested Loop Left Join  (cost=50.92..871.68 rows=306 width=281) (actual time=0.869..3.812 rows=76 loops=1)
                                                                          Join Filter: (t1._documenttref = '\\x00000349'::bytea)
                                                                          ->  Nested Loop Left Join  (cost=50.81..823.81 rows=306 width=273) (actual time=0.858..3.544 rows=76 loops=1)
                                                                                Join Filter: (t1._documenttref = '\\x0000050d'::bytea)
                                                                                ->  Hash Left Join  (cost=50.70..779.19 rows=306 width=263) (actual time=0.847..3.327 rows=76 loops=1)
                                                                                      Hash Cond: (t1._documentrref = t13._idrref)
                                                                                      Join Filter: (t1._documenttref = '\\x0000042b'::bytea)
                                                                                      Rows Removed by Hash Matching: 76
                                                                                      ->  Hash Left Join  (cost=45.07..773.24 rows=306 width=255) (actual time=0.793..3.251 rows=76 loops=1)
                                                                                            Hash Cond: (t1._documentrref = t12._idrref)
                                                                                            Join Filter: (t1._documenttref = '\\x000004a3'::bytea)
                                                                                            Rows Removed by Hash Matching: 76
                                                                                            ->  Nested Loop Left Join  (cost=42.83..770.68 rows=306 width=247) (actual time=0.766..3.202 rows=76 loops=1)
                                                                                                  ->  Nested Loop Left Join  (cost=42.76..763.80 rows=306 width=230) (actual time=0.750..3.135 rows=76 loops=1)
                                                                                                        Join Filter: ((t1._documenttref = '\\x0000050e'::bytea) AND (t1._documentrref = t9._idrref))
                                                                                                        Rows Removed by Join Filter: 76
                                                                                                        ->  Nested Loop Left Join  (cost=42.76..758.81 rows=306 width=220) (actual time=0.736..3.085 rows=76 loops=1)
                                                                                                              ->  Hash Left Join  (cost=42.59..609.60 rows=306 width=219) (actual time=0.715..2.769 rows=76 loops=1)
                                                                                                                    Hash Cond: (t1._documentrref = t14._idrref)
                                                                                                                    Join Filter: (t1._documenttref = '\\x000004a7'::bytea)
                                                                                                                    Rows Removed by Hash Matching: 76
                                                                                                                    ->  Nested Loop Left Join  (cost=41.42..608.10 rows=306 width=211) (actual time=0.693..2.726 rows=76 loops=1)
                                                                                                                          Join Filter: (t1._documenttref = '\\x0000048e'::bytea)
                                                                                                                          ->  Nested Loop Left Join  (cost=41.31..563.24 rows=306 width=210) (actual time=0.680..2.505 rows=76 loops=1)
                                                                                                                                Join Filter: ((t1._documenttref = '\\x0000048f'::bytea) AND (t1._documentrref = t7._idrref))
                                                                                                                                Rows Removed by Join Filter: 76
                                                                                                                                ->  Hash Left Join  (cost=41.31..558.25 rows=306 width=209) (actual time=0.667..2.454 rows=76 loops=1)
                                                                                                                                      Hash Cond: (t1._documentrref = t17._idrref)
                                                                                                                                      Join Filter: (t1._documenttref = '\\x00000416'::bytea)
                                                                                                                                      Rows Removed by Hash Matching: 76
                                                                                                                                      ->  Hash Left Join  (cost=22.59..539.21 rows=306 width=201) (actual time=0.504..2.271 rows=76 loops=1)
                                                                                                                                            Hash Cond: (t1._documentrref = t25._idrref)
                                                                                                                                            Join Filter: (t1._documenttref = '\\x0000042c'::bytea)
                                                                                                                                            Rows Removed by Hash Matching: 76
                                                                                                                                            ->  Nested Loop Left Join  (cost=13.52..529.82 rows=306 width=193) (actual time=0.420..2.167 rows=76 loops=1)
                                                                                                                                                  Join Filter: ((t1._documenttref = '\\x00000420'::bytea) AND (t1._documentrref = t24._idrref))
                                                                                                                                                  ->  Hash Left Join  (cost=13.52..526.15 rows=306 width=185) (actual time=0.413..2.096 rows=76 loops=1)
                                                                                                                                                        Hash Cond: (t1._documentrref = t10._idrref)
                                                                                                                                                        Join Filter: (t1._documenttref = '\\x000161a6'::bytea)
                                                                                                                                                        Rows Removed by Hash Matching: 76
                                                                                                                                                        ->  Nested Loop Left Join  (cost=12.48..524.79 rows=306 width=177) (actual time=0.384..2.045 rows=76 loops=1)
                                                                                                                                                              Join Filter: ((t1._documenttref = '\\x00000421'::bytea) AND (t1._documentrref = t18._idrref))
                                                                                                                                                              ->  Nested Loop  (cost=12.48..521.11 rows=306 width=169) (actual time=0.370..1.953 rows=76 loops=1)
                                                                                                                                                                    ->  HashAggregate  (cost=12.31..15.38 rows=307 width=22) (actual time=0.346..0.425 rows=566 loops=1)
                                                                                                                                                                          Group Key: t26._fld44395_rtref, t26._fld44395_rrref
                                                                                                                                                                          Batches: 1  Memory Usage: 105kB
                                                                                                                                                                          ->  Index Only Scan Backward using _inforg44394_2 on _inforg44394 t26  (cost=0.17..11.70 rows=308 width=22) (actual time=0.036..0.174 rows=769 loops=1)
                                                                                                                                                                                Index Cond: ((_fld2488 = '0'::numeric) AND (_fld44396rref = '\\x0a890cc47a352c1911e64dbdf9c36468'::bytea) AND (_fld44395_type = '\\x08'::bytea))
                                                                                                                                                                                Heap Fetches: 0
                                                                                                                                                                    ->  Index Scan using _documentjournal33607_1 on _documentjournal33607 t1  (cost=0.16..1.66 rows=1 width=169) (actual time=0.002..0.002 rows=0 loops=566)
                                                                                                                                                                          Index Cond: ((_fld2488 = '0'::numeric) AND (_documenttref = t26._fld44395_rtref) AND (_documentrref = t26._fld44395_rrref))
                                                                                                                                                                          Filter: ((_fld33610 < '2024-03-26 00:00:00'::timestamp without time zone) OR ((_fld33610 = '2024-03-26 00:00:00'::timestamp without time zone) AND ((_documenttref < '\\x00000428'::bytea) OR ((_documenttref = '\\x00000428'::bytea) AND (_documentrref <= '\\x8dba1866dab152db11eedbc9d181dd34'::bytea)))))
                                                                                                                                                              ->  Seq Scan on _document1057 t18  (cost=0.00..0.00 rows=1 width=40) (actual time=0.000..0.000 rows=0 loops=76)
                                                                                                                                                                    Filter: (_fld2488 = '0'::numeric)
                                                                                                                                                        ->  Hash  (cost=1.02..1.02 rows=2 width=25) (actual time=0.022..0.023 rows=2 loops=1)
                                                                                                                                                              Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                                                                                                                                              ->  Seq Scan on _document90534 t10  (cost=0.00..1.02 rows=2 width=25) (actual time=0.019..0.020 rows=2 loops=1)
                                                                                                                                                                    Filter: (_fld2488 = '0'::numeric)
                                                                                                                                                  ->  Seq Scan on _document1056 t24  (cost=0.00..0.00 rows=1 width=40) (actual time=0.000..0.000 rows=0 loops=76)
                                                                                                                                                        Filter: (_fld2488 = '0'::numeric)
                                                                                                                                            ->  Hash  (cost=8.03..8.03 rows=94 width=25) (actual time=0.078..0.078 rows=94 loops=1)
                                                                                                                                                  Buckets: 1024  Batches: 1  Memory Usage: 14kB
                                                                                                                                                  ->  Seq Scan on _document1068 t25  (cost=0.00..8.03 rows=94 width=25) (actual time=0.010..0.065 rows=94 loops=1)
                                                                                                                                                        Filter: (_fld2488 = '0'::numeric)
                                                                                                                                      ->  Hash  (cost=16.86..16.86 rows=169 width=25) (actual time=0.157..0.157 rows=169 loops=1)
                                                                                                                                            Buckets: 1024  Batches: 1  Memory Usage: 18kB
                                                                                                                                            ->  Seq Scan on _document1046 t17  (cost=0.00..16.86 rows=169 width=25) (actual time=0.011..0.134 rows=169 loops=1)
                                                                                                                                                  Filter: (_fld2488 = '0'::numeric)
                                                                                                                                ->  Materialize  (cost=0.00..1.01 rows=1 width=18) (actual time=0.000..0.000 rows=1 loops=76)
                                                                                                                                      ->  Seq Scan on _document1167x1 t7  (cost=0.00..1.01 rows=1 width=18) (actual time=0.008..0.008 rows=1 loops=1)
                                                                                                                                            Filter: (_fld2488 = '0'::numeric)
                                                                                                                          ->  Index Scan using _document1166_s_hpkx1 on _document1166x1 t6  (cost=0.11..0.14 rows=1 width=18) (actual time=0.002..0.002 rows=0 loops=76)
                                                                                                                                Index Cond: ((_fld2488 = '0'::numeric) AND (_idrref = t1._documentrref))
                                                                                                                    ->  Hash  (cost=1.09..1.09 rows=8 width=25) (actual time=0.017..0.017 rows=8 loops=1)
                                                                                                                          Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                                                                                                          ->  Seq Scan on _document1191 t14  (cost=0.00..1.09 rows=8 width=25) (actual time=0.010..0.014 rows=8 loops=1)
                                                                                                                                Filter: (_fld2488 = '0'::numeric)
                                                                                                              ->  Index Scan using _inforg39484_1 on _inforg39484 t2  (cost=0.17..0.49 rows=1 width=23) (actual time=0.004..0.004 rows=0 loops=76)
                                                                                                                    Index Cond: ((_fld2488 = '0'::numeric) AND (_fld39485_type = '\\x08'::bytea) AND (_fld39485_rtref = t1._documenttref) AND (_fld39485_rrref = t1._documentrref))
                                                                                                        ->  Materialize  (cost=0.00..1.01 rows=1 width=27) (actual time=0.000..0.000 rows=1 loops=76)
                                                                                                              ->  Seq Scan on _document1294x1 t9  (cost=0.00..1.01 rows=1 width=27) (actual time=0.009..0.009 rows=1 loops=1)
                                                                                                                    Filter: (_fld2488 = '0'::numeric)
                                                                                                  ->  Memoize  (cost=0.06..0.08 rows=1 width=34) (actual time=0.000..0.000 rows=1 loops=76)
                                                                                                        Cache Key: t1._fld33608rref
                                                                                                        Cache Mode: logical
                                                                                                        Estimates: capacity=7 distinct keys=7 lookups=306 hit percent=97.71%
                                                                                                        Hits: 74  Misses: 2  Evictions: 0  Overflows: 0  Memory Usage: 1kB
                                                                                                        ->  Index Scan using _reference395_s_hpk on _reference395 t3  (cost=0.05..0.07 rows=1 width=34) (actual time=0.006..0.006 rows=1 loops=2)
                                                                                                              Index Cond: ((_fld2488 = '0'::numeric) AND (_idrref = t1._fld33608rref))
                                                                                            ->  Hash  (cost=2.12..2.12 rows=11 width=25) (actual time=0.021..0.022 rows=11 loops=1)
                                                                                                  Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                                                                                  ->  Seq Scan on _document1187 t12  (cost=0.00..2.12 rows=11 width=25) (actual time=0.012..0.019 rows=11 loops=1)
                                                                                                        Filter: (_fld2488 = '0'::numeric)
                                                                                      ->  Hash  (cost=4.81..4.81 rows=74 width=25) (actual time=0.047..0.048 rows=74 loops=1)
                                                                                            Buckets: 1024  Batches: 1  Memory Usage: 13kB
                                                                                            ->  Seq Scan on _document1067 t13  (cost=0.00..4.81 rows=74 width=25) (actual time=0.010..0.037 rows=74 loops=1)
                                                                                                  Filter: (_fld2488 = '0'::numeric)
                                                                                ->  Index Scan using _document1293_s_hpkx1 on _document1293x1 t8  (cost=0.11..0.13 rows=1 width=27) (actual time=0.002..0.002 rows=0 loops=76)
                                                                                      Index Cond: ((_fld2488 = '0'::numeric) AND (_idrref = t1._documentrref))
                                                                          ->  Index Scan using _document841_s_hpk on _document841 t16  (cost=0.11..0.15 rows=1 width=25) (actual time=0.003..0.003 rows=0 loops=76)
                                                                                Index Cond: ((_fld2488 = '0'::numeric) AND (_idrref = t1._documentrref))
                                                                    ->  Index Scan using _document988_s_hpkx1 on _document988x1 t23  (cost=0.11..0.16 rows=1 width=25) (actual time=0.003..0.003 rows=0 loops=76)
                                                                          Index Cond: ((_fld2488 = '0'::numeric) AND (_idrref = t1._documentrref))
                                                              ->  Index Scan using _document1066_s_hpk on _document1066 t20  (cost=0.11..0.13 rows=1 width=25) (actual time=0.002..0.002 rows=0 loops=76)
                                                                    Index Cond: ((_fld2488 = '0'::numeric) AND (_idrref = t1._documentrref))
                                                        ->  Seq Scan on _document1045 t19  (cost=0.00..0.00 rows=1 width=40) (actual time=0.000..0.000 rows=0 loops=76)
                                                              Filter: (_fld2488 = '0'::numeric)
                                                  ->  Hash  (cost=3.48..3.48 rows=44 width=25) (actual time=0.032..0.032 rows=44 loops=1)
                                                        Buckets: 1024  Batches: 1  Memory Usage: 11kB
                                                        ->  Seq Scan on _document1182 t22  (cost=0.00..3.48 rows=44 width=25) (actual time=0.009..0.025 rows=44 loops=1)
                                                              Filter: (_fld2488 = '0'::numeric)
                                            ->  Index Scan using _document983_s_hpkx1 on _document983x1 t4  (cost=0.11..0.14 rows=1 width=19) (actual time=0.002..0.002 rows=0 loops=76)
                                                  Index Cond: ((_fld2488 = '0'::numeric) AND (_idrref = t1._documentrref))
                                      ->  Hash  (cost=1.09..1.09 rows=8 width=25) (actual time=0.014..0.014 rows=8 loops=1)
                                            Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                            ->  Seq Scan on _document1192 t11  (cost=0.00..1.09 rows=8 width=25) (actual time=0.010..0.012 rows=8 loops=1)
                                                  Filter: (_fld2488 = '0'::numeric)
                                ->  Index Scan using _document1181_s_hpk on _document1181 t21  (cost=0.11..0.14 rows=1 width=25) (actual time=0.003..0.003 rows=0 loops=76)
                                      Index Cond: ((_fld2488 = '0'::numeric) AND (_idrref = t1._documentrref))
                          ->  Hash  (cost=3.57..3.57 rows=52 width=19) (actual time=0.039..0.039 rows=52 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 11kB
                                ->  Seq Scan on _document984x1 t5  (cost=0.00..3.57 rows=52 width=19) (actual time=0.010..0.031 rows=52 loops=1)
                                      Filter: (_fld2488 = '0'::numeric)
                    ->  Index Scan using _document1064_s_hpk on _document1064 t15  (cost=0.11..0.17 rows=1 width=25) (actual time=0.004..0.004 rows=0 loops=76)
                          Index Cond: ((_fld2488 = '0'::numeric) AND (_idrref = t1._documentrref))
Planning Time: 351.461 ms
Execution Time: 6.070 ms$$);
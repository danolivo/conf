# Vanilla LR V/S batched vanilla LR

## No indexes

### Tuple-by-tuple insertion

```md
=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                   546          712
Replication apply (ms)              10587        22660
Total (ms)                          11134        23372
Publisher WAL                       70 MB       115 MB
Subscriber WAL                     122 MB       123 MB
Publisher table size                89 MB        89 MB
Subscriber table size               89 MB        89 MB
Subscriber rows                   1000000      1000000

=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                  6928        38785
Replication apply (ms)              64953        69396
Total (ms)                          71881       108181
Publisher WAL                      697 MB      1148 MB
Subscriber WAL                    2120 MB      2120 MB
Publisher table size               888 MB       888 MB
Subscriber table size              888 MB       888 MB
Subscriber rows                  10000000     10000000

=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                 57422       144312
Replication apply (ms)             514139       674543
Total (ms)                         571561       818855
Publisher WAL                     6968 MB        11 GB
Subscriber WAL                      21 GB        21 GB
Publisher table size              8880 MB      8880 MB
Subscriber table size             8880 MB      8880 MB
Subscriber rows                 100000000    100000000
```

### Batch subscriber insertion

```md
=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                   514          778
Replication apply (ms)               4210         4430
Total (ms)                           4724         5209
Publisher WAL                       70 MB       115 MB
Subscriber WAL                      70 MB        70 MB
Publisher table size                89 MB        89 MB
Subscriber table size               89 MB        89 MB
Subscriber rows                   1000000      1000000

=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                  5385        35096
Replication apply (ms)              38690        39363
Total (ms)                          44076        74460
Publisher WAL                      697 MB      1148 MB
Subscriber WAL                     702 MB       701 MB
Publisher table size               888 MB       888 MB
Subscriber table size              888 MB       888 MB
Subscriber rows                  10000000     10000000

=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                 56172       204234
Replication apply (ms)             400767       403412
Total (ms)                         456939       607647
Publisher WAL                     6968 MB        11 GB
Subscriber WAL                    7020 MB      7021 MB
Publisher table size              8880 MB      8880 MB
Subscriber table size             8880 MB      8880 MB
Subscriber rows                 100000000    100000000
```

## One PK

### Vanilla

```md
=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                  1175         1234
Replication apply (ms)              10907         5426
Total (ms)                          12083         6660
Publisher WAL                      133 MB       178 MB
Subscriber WAL                     186 MB       186 MB
Publisher table size               111 MB       110 MB
Subscriber table size              110 MB       110 MB
Subscriber rows                   1000000      1000000

=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                 10082        35756
Replication apply (ms)              35243        64356
Total (ms)                          45326       100112
Publisher WAL                     1329 MB      1780 MB
Subscriber WAL                    1861 MB      1860 MB
Publisher table size              1103 MB      1102 MB
Subscriber table size             1102 MB      1102 MB
Subscriber rows                  10000000     10000000

=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                 87359       568807
Replication apply (ms)             701367       921969
Total (ms)                         788727      1490776
Publisher WAL                       13 GB        17 GB
Subscriber WAL                      27 GB        27 GB
Publisher table size                11 GB        11 GB
Subscriber table size               11 GB        11 GB
Subscriber rows                 100000000    100000000
```

### Batch insertion

```md
=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                  1122         1274
Replication apply (ms)               3988         4977
Total (ms)                           5110         6251
Publisher WAL                      133 MB       178 MB
Subscriber WAL                     132 MB       133 MB
Publisher table size               111 MB       110 MB
Subscriber table size              110 MB       110 MB
Subscriber rows                   1000000      1000000

=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                 10018        62646
Replication apply (ms)              40600        65361
Total (ms)                          50618       128008
Publisher WAL                     1329 MB      1780 MB
Subscriber WAL                    1334 MB      1334 MB
Publisher table size              1103 MB      1102 MB
Subscriber table size             1102 MB      1102 MB
Subscriber rows                  10000000     10000000

=========================================
               SUMMARY
=========================================
                                     COPY       INSERT
---                                  ----       ------
Publisher load (ms)                 85097       584348
Replication apply (ms)             676689       753396
Total (ms)                         761787      1337745
Publisher WAL                       13 GB        17 GB
Subscriber WAL                      20 GB        20 GB
Publisher table size                11 GB        11 GB
Subscriber table size               11 GB        11 GB
Subscriber rows                 100000000    100000000
```

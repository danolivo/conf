# Phase 4 benchmark results: dec128 numeric vs stock numeric

```
# generated 2026-08-12T06:22:17+00:00
# host: Linux 6.17.0-1022-gcp x86_64
# cpu: Intel(R) Xeon(R) Platinum 8481C CPU @ 2.70GHz
# rows=5000000 reps=20 shared_buffers=32GB pin_core=2
# governor=none
# /opt/pg-stock version: postgres (PostgreSQL) 18.3
# /opt/pg-stock configure:  '--prefix=/opt/pg-stock' '--without-icu' '--without-readline' '--without-zlib' '--enable-depend' 'CFLAGS=-O2'
# /opt/pg-dec128 version: postgres (PostgreSQL) 18.3
# /opt/pg-dec128 configure:  '--prefix=/opt/pg-dec128' '--without-icu' '--without-readline' '--without-zlib' '--enable-depend' 'CFLAGS=-O2'
```


Ratio is dec128 / stock: **below 1.0 means dec128 is faster**.
CI is a bootstrap 95% interval on the ratio of medians.


## Tier A - marginal cost per operation

Slope of execution time against operation count, so the scan and aggregation overhead lands in the discarded intercept. This is the control: if it shows nothing, the rest is not worth reading.

| op | stock ns/row | dec128 ns/row | ratio |
|---|---|---|---|
| add | 53.01 | 10.62 | 0.20x |
| cmp | 21.66 | 9.35 | 0.43x |
| div | 92.86 | 46.19 | 0.50x |
| mul | 56.99 | 12.74 | 0.22x |
| sub | 51.99 | 10.77 | 0.21x |

## Tier B - query level

| query | stock ms (MAD) | dec128 ms (MAD) | ratio | 95% CI | p | verdict |
|---|---|---|---|---|---|---|
| avg | 412.5 (0.1) | 311.2 (0.2) | 0.75x | [0.75, 0.76] | 0.004 | FASTER (24-25% better) |
| cast_float8 | 900.6 (0.9) | 926.3 (0.3) | 1.03x | [1.03, 1.03] | 0.004 | no difference (within +/-5%) |
| cast_int | 521.9 (0.7) | 556.4 (0.7) | 1.07x | [1.06, 1.07] | 0.004 | SLOWER (6-7% worse) |
| hash_agg | 911.2 (0.8) | 643.6 (0.9) | 0.71x | [0.71, 0.71] | 0.004 | FASTER (29-29% better) |
| hash_join | 923.2 (6.3) | 929.6 (3.2) | 1.01x | [1.00, 1.01] | 0.078 | no difference (within +/-5%) |
| index_scan | 90.8 (0.7) | 100.3 (1.2) | 1.10x | [1.05, 1.16] | 0.004 | SLOWER (5-16% worse) |
| num_mul2 | 641.3 (1.0) | 429.4 (0.4) | 0.67x | [0.67, 0.67] | 0.004 | FASTER (33-33% better) |
| order_by_limit | 0.1 (0.0) | 0.1 (0.0) | 0.87x | [0.79, 0.98] | 0.010 | inconclusive - raise REPS |
| ref_bigint_8add | 477.4 (0.8) | 454.2 (0.3) | 0.95x | [0.95, 0.95] | 0.004 | inconclusive - raise REPS |
| ref_bigint_mul | 348.6 (0.8) | 345.9 (0.5) | 0.99x | [0.99, 1.00] | 0.004 | no difference (within +/-5%) |
| ref_bigint_sum | 330.3 (1.1) | 329.8 (0.6) | 1.00x | [0.99, 1.00] | 0.262 | no difference (within +/-5%) |
| ref_float8_sum | 909.8 (0.4) | 926.2 (0.3) | 1.02x | [1.02, 1.02] | 0.004 | no difference (within +/-5%) |
| ref_money_8add | 468.9 (2.3) | 442.1 (0.3) | 0.94x | [0.94, 0.95] | 0.004 | FASTER (5-6% better) |
| ref_money_mul2 | 330.0 (1.3) | 325.1 (0.8) | 0.99x | [0.98, 0.99] | 0.004 | no difference (within +/-5%) |
| ref_money_sum | 314.1 (0.7) | 313.9 (0.7) | 1.00x | [0.99, 1.00] | 0.522 | no difference (within +/-5%) |
| scan_count | 271.1 (0.7) | 284.0 (0.1) | 1.05x | [1.04, 1.05] | 0.004 | inconclusive - raise REPS |
| stddev | 499.8 (0.2) | 544.0 (0.2) | 1.09x | [1.09, 1.09] | 0.004 | SLOWER (9-9% worse) |
| sum | 412.4 (0.1) | 311.4 (0.7) | 0.76x | [0.75, 0.76] | 0.004 | FASTER (24-25% better) |
| sum_8add | 2494.2 (3.6) | 767.0 (0.4) | 0.31x | [0.31, 0.31] | 0.004 | FASTER (69-69% better) |
| sum_d | 440.8 (0.9) | 322.2 (0.8) | 0.73x | [0.73, 0.73] | 0.004 | FASTER (27-27% better) |
| sum_div | 892.9 (0.5) | 590.5 (0.3) | 0.66x | [0.66, 0.66] | 0.004 | FASTER (34-34% better) |
| sum_expr_mixed | 1276.7 (1.9) | 537.1 (0.4) | 0.42x | [0.42, 0.43] | 0.004 | FASTER (57-58% better) |
| sum_mul | 715.2 (0.8) | 440.1 (0.3) | 0.62x | [0.61, 0.62] | 0.004 | FASTER (38-39% better) |
| sum_mul_d | 706.2 (0.7) | 467.2 (0.3) | 0.66x | [0.66, 0.66] | 0.004 | FASTER (34-34% better) |
| text_out | 504.4 (1.0) | 557.0 (0.1) | 1.10x | [1.10, 1.11] | 0.004 | SLOWER (10-11% worse) |
| where_gt | 455.2 (0.4) | 362.8 (0.1) | 0.80x | [0.80, 0.80] | 0.004 | FASTER (20-20% better) |

## Tier D - sorts, grouping, windows

| query | stock ms (MAD) | dec128 ms (MAD) | ratio | 95% CI | p | verdict |
|---|---|---|---|---|---|---|
| distinct_hash | 911.3 (2.2) | 642.9 (2.0) | 0.71x | [0.70, 0.71] | 0.004 | FASTER (29-30% better) |
| distinct_sort | 1817.2 (3.2) | 1480.4 (4.6) | 0.81x | [0.81, 0.82] | 0.004 | FASTER (18-19% better) |
| groupagg_sort | 1848.2 (1.8) | 1520.4 (1.5) | 0.82x | [0.82, 0.83] | 0.004 | FASTER (17-18% better) |
| hashagg_highcard | 2294.0 (9.8) | 2327.7 (6.2) | 1.01x | [1.01, 1.02] | 0.004 | no difference (within +/-5%) |
| hashagg_spill | 2033.4 (7.4) | 2059.8 (3.3) | 1.01x | [1.01, 1.02] | 0.004 | no difference (within +/-5%) |
| merge_join | 13233.4 (21.4) | 9523.4 (29.4) | 0.72x | [0.72, 0.72] | 0.004 | FASTER (28-28% better) |
| minmax | 0.1 (0.0) | 0.1 (0.0) | 0.85x | [0.82, 0.87] | 0.004 | FASTER (13-18% better) |
| percentile | 1411.6 (1.3) | 1479.8 (1.0) | 1.05x | [1.05, 1.05] | 0.004 | no difference (within +/-5%) |
| ref_minmax_money | 344.0 (0.6) | 340.0 (0.3) | 0.99x | [0.98, 0.99] | 0.004 | no difference (within +/-5%) |
| ref_sort_bigint | 817.7 (1.1) | 824.0 (0.6) | 1.01x | [1.00, 1.01] | 0.055 | no difference (within +/-5%) |
| ref_sort_money | 1052.7 (1.8) | 1078.2 (0.7) | 1.02x | [1.02, 1.03] | 0.004 | no difference (within +/-5%) |
| ref_win_money | 2155.9 (5.3) | 2093.6 (3.2) | 0.97x | [0.97, 0.97] | 0.004 | no difference (within +/-5%) |
| sort_d_scale15 | 1330.4 (4.8) | 1337.2 (2.1) | 1.01x | [1.00, 1.01] | 0.037 | no difference (within +/-5%) |
| sort_desc | 1484.5 (8.0) | 1428.3 (2.7) | 0.96x | [0.95, 0.97] | 0.004 | no difference (within +/-5%) |
| sort_mem | 1581.9 (5.5) | 1453.1 (1.4) | 0.92x | [0.88, 0.96] | 0.025 | inconclusive - raise REPS |
| sort_spill | 1578.2 (7.0) | 1450.1 (1.9) | 0.92x | [0.91, 0.92] | 0.004 | FASTER (8-9% better) |
| variance | 500.9 (0.8) | 545.3 (0.5) | 1.09x | [1.09, 1.09] | 0.004 | SLOWER (9-9% worse) |
| win_moving_avg | 3659.7 (3.5) | 3006.4 (2.5) | 0.82x | [0.82, 0.82] | 0.004 | FASTER (18-18% better) |
| win_moving_sum | 3174.1 (0.9) | 2679.8 (2.3) | 0.84x | [0.84, 0.85] | 0.004 | FASTER (15-16% better) |

## Tier C - storage and WAL

| metric | stock | dec128 | change |
|---|---|---|---|
| heap | 326 MiB | 482 MiB | +48.0% |
| heap_plus_toast_idx | 433 MiB | 633 MiB | +46.1% |
| btree_index | 107 MiB | 151 MiB | +40.4% |
| wal_1m_insert | 61 MiB | 61 MiB | -0.1% |

## Cost of exactness, measured inside one engine

numeric divided by the engine's own reference types. `money` is int64 pass-by-value with the scale in the catalog, i.e. structurally what DuckDB does for DECIMAL(18,2).

| operation | build | numeric ms | vs money | vs bigint | vs float8 |
|---|---|---|---|---|---|
| sum(v) | stock | 412.4 | 1.31x | 1.25x | 0.45x |
| sum(v) | dec128 | 311.4 | 0.99x | 0.94x | 0.34x |
| 8 adds | stock | 2494.2 | 5.32x | 5.22x | - |
| 8 adds | dec128 | 767.0 | 1.73x | 1.69x | - |
| multiply by 2 | stock | 641.3 | 1.94x | - | - |
| multiply by 2 | dec128 | 429.4 | 1.32x | - | - |

---

Reminder on interpretation: a single headline number would be misleading here, because the two builds do not differ uniformly - fixed-width storage makes arithmetic cheaper and makes unpacking a stored value more expensive. Read the per-query rows, and weight them by the real query mix before drawing a conclusion.

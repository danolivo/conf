# Phase 4 benchmark results: dec128 numeric vs stock numeric

```
# generated 2026-08-11T21:42:22+00:00
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
| add | 52.70 | 10.66 | 0.20x |
| cmp | 21.78 | 9.18 | 0.42x |
| div | 93.40 | 46.28 | 0.50x |
| mul | 57.11 | 12.75 | 0.22x |
| sub | 52.05 | 10.78 | 0.21x |

## Tier B - query level

| query | stock ms (MAD) | dec128 ms (MAD) | ratio | 95% CI | p | verdict |
|---|---|---|---|---|---|---|
| avg | 418.9 (1.0) | 318.7 (1.5) | 0.76x | [0.76, 0.77] | <0.001 | FASTER (23-24% better) |
| cast_float8 | 906.0 (1.8) | 937.6 (1.0) | 1.03x | [1.03, 1.04] | <0.001 | no difference (within +/-5%) |
| cast_int | 526.0 (0.8) | 595.3 (1.3) | 1.13x | [1.13, 1.13] | <0.001 | SLOWER (13-13% worse) |
| hash_agg | 918.5 (1.0) | 654.9 (1.1) | 0.71x | [0.71, 0.71] | <0.001 | FASTER (29-29% better) |
| hash_join | 1000.8 (24.4) | 1034.4 (34.8) | 1.03x | [0.99, 1.06] | 0.070 | inconclusive - raise REPS |
| index_scan | 92.3 (0.7) | 101.4 (0.8) | 1.10x | [1.09, 1.11] | 0.001 | SLOWER (9-11% worse) |
| num_mul2 | 645.7 (0.5) | 436.8 (0.6) | 0.68x | [0.68, 0.68] | <0.001 | FASTER (32-32% better) |
| order_by_limit | 0.1 (0.0) | 0.1 (0.0) | 0.82x | [0.80, 0.88] | <0.001 | FASTER (12-20% better) |
| ref_bigint_8add | 482.3 (0.6) | 461.9 (0.5) | 0.96x | [0.96, 0.96] | <0.001 | no difference (within +/-5%) |
| ref_bigint_mul | 353.0 (0.6) | 351.6 (0.1) | 1.00x | [1.00, 1.00] | 0.019 | no difference (within +/-5%) |
| ref_bigint_sum | 333.9 (0.7) | 335.5 (0.6) | 1.00x | [1.00, 1.01] | <0.001 | no difference (within +/-5%) |
| ref_float8_sum | 915.8 (1.1) | 941.3 (0.5) | 1.03x | [1.03, 1.03] | <0.001 | no difference (within +/-5%) |
| ref_money_8add | 472.3 (0.4) | 449.8 (0.7) | 0.95x | [0.95, 0.95] | <0.001 | no difference (within +/-5%) |
| ref_money_mul2 | 333.1 (0.8) | 332.3 (0.8) | 1.00x | [1.00, 1.00] | 0.200 | no difference (within +/-5%) |
| ref_money_sum | 318.2 (1.0) | 320.8 (0.8) | 1.01x | [1.00, 1.02] | 0.004 | no difference (within +/-5%) |
| scan_count | 275.7 (1.8) | 291.3 (0.6) | 1.06x | [1.04, 1.06] | <0.001 | inconclusive - raise REPS |
| stddev | 504.7 (0.6) | 552.8 (0.7) | 1.10x | [1.09, 1.10] | <0.001 | SLOWER (9-10% worse) |
| sum | 418.5 (1.0) | 318.4 (0.5) | 0.76x | [0.76, 0.76] | <0.001 | FASTER (24-24% better) |
| sum_8add | 2504.1 (17.6) | 775.6 (0.4) | 0.31x | [0.31, 0.31] | <0.001 | FASTER (69-69% better) |
| sum_d | 446.3 (0.2) | 329.3 (1.1) | 0.74x | [0.74, 0.74] | <0.001 | FASTER (26-26% better) |
| sum_div | 899.4 (1.0) | 597.9 (0.4) | 0.66x | [0.66, 0.67] | <0.001 | FASTER (33-34% better) |
| sum_expr_mixed | 1285.6 (1.0) | 545.3 (0.6) | 0.42x | [0.42, 0.42] | <0.001 | FASTER (58-58% better) |
| sum_mul | 721.1 (0.3) | 447.2 (0.3) | 0.62x | [0.62, 0.62] | <0.001 | FASTER (38-38% better) |
| sum_mul_d | 711.4 (0.7) | 474.7 (0.4) | 0.67x | [0.67, 0.67] | <0.001 | FASTER (33-33% better) |
| text_out | 509.7 (2.4) | 563.6 (1.1) | 1.11x | [1.10, 1.11] | <0.001 | SLOWER (10-11% worse) |
| where_gt | 460.0 (0.5) | 370.7 (0.6) | 0.81x | [0.80, 0.81] | <0.001 | FASTER (19-20% better) |

## Tier C - storage and WAL

| metric | stock | dec128 | change |
|---|---|---|---|
| heap | 326 MiB | 482 MiB | +48.0% |
| heap_plus_toast_idx | 433 MiB | 633 MiB | +46.1% |
| btree_index | 107 MiB | 151 MiB | +40.4% |
| wal_1m_insert | 61 MiB | 62 MiB | +0.7% |

## Cost of exactness, measured inside one engine

numeric divided by the engine's own reference types. `money` is int64 pass-by-value with the scale in the catalog, i.e. structurally what DuckDB does for DECIMAL(18,2).

| operation | build | numeric ms | vs money | vs bigint | vs float8 |
|---|---|---|---|---|---|
| sum(v) | stock | 418.5 | 1.32x | 1.25x | 0.46x |
| sum(v) | dec128 | 318.4 | 0.99x | 0.95x | 0.34x |
| 8 adds | stock | 2504.1 | 5.30x | 5.19x | - |
| 8 adds | dec128 | 775.6 | 1.72x | 1.68x | - |
| multiply by 2 | stock | 645.7 | 1.94x | - | - |
| multiply by 2 | dec128 | 436.8 | 1.31x | - | - |

---

Reminder on interpretation: a single headline number would be misleading here, because the two builds do not differ uniformly - fixed-width storage makes arithmetic cheaper and makes unpacking a stored value more expensive. Read the per-query rows, and weight them by the real query mix before drawing a conclusion.

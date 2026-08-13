# Phase 4 benchmark results: dec128 numeric vs stock numeric

```
# generated 2026-08-11T14:43:10+00:00
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
| add | 53.08 | 10.45 | 0.20x |
| cmp | 21.68 | 8.01 | 0.37x |
| div | 93.12 | 46.70 | 0.50x |
| mul | 57.15 | 12.47 | 0.22x |
| sub | 52.03 | 10.90 | 0.21x |

## Tier B - query level

| query | stock ms (MAD) | dec128 ms (MAD) | ratio | 95% CI | p | verdict |
|---|---|---|---|---|---|---|
| avg | 399.5 (0.5) | 295.4 (0.8) | 0.74x | [0.74, 0.74] | <0.001 | FASTER (26-26% better) |
| cast_float8 | 889.5 (1.5) | 873.9 (0.8) | 0.98x | [0.98, 0.98] | <0.001 | no difference (within +/-5%) |
| cast_int | 543.3 (1.3) | 531.8 (1.4) | 0.98x | [0.98, 0.98] | <0.001 | no difference (within +/-5%) |
| hash_agg | 898.9 (0.4) | 642.5 (0.4) | 0.71x | [0.71, 0.72] | <0.001 | FASTER (28-29% better) |
| hash_join | 1013.1 (20.5) | 1026.2 (15.7) | 1.01x | [0.99, 1.03] | 0.199 | no difference (within +/-5%) |
| index_scan | 84.1 (0.5) | 93.0 (0.5) | 1.11x | [1.10, 1.11] | 0.001 | SLOWER (10-11% worse) |
| order_by_limit | 0.1 (0.0) | 0.1 (0.0) | 0.98x | [0.91, 1.03] | 0.211 | inconclusive - raise REPS |
| scan_count | 258.9 (0.5) | 270.6 (0.8) | 1.05x | [1.04, 1.05] | <0.001 | no difference (within +/-5%) |
| stddev | 486.5 (1.0) | 526.2 (0.6) | 1.08x | [1.08, 1.08] | <0.001 | SLOWER (8-8% worse) |
| sum | 399.5 (0.4) | 296.0 (0.6) | 0.74x | [0.74, 0.74] | <0.001 | FASTER (26-26% better) |
| sum_8add | 2485.0 (8.4) | 750.0 (0.5) | 0.30x | [0.30, 0.30] | <0.001 | FASTER (70-70% better) |
| sum_div | 879.0 (1.2) | 575.3 (0.6) | 0.65x | [0.65, 0.66] | <0.001 | FASTER (34-35% better) |
| sum_expr_mixed | 1263.1 (1.2) | 524.3 (1.0) | 0.42x | [0.41, 0.42] | <0.001 | FASTER (58-59% better) |
| sum_mul | 701.2 (0.8) | 423.2 (0.5) | 0.60x | [0.60, 0.60] | <0.001 | FASTER (40-40% better) |
| text_out | 492.4 (0.4) | 538.0 (1.2) | 1.09x | [1.09, 1.09] | <0.001 | SLOWER (9-9% worse) |
| where_gt | 444.4 (0.6) | 340.2 (0.2) | 0.77x | [0.76, 0.77] | <0.001 | FASTER (23-24% better) |

## Tier C - storage and WAL

| metric | stock | dec128 | change |
|---|---|---|---|
| heap | 212 MiB | 326 MiB | +54.1% |
| heap_plus_toast_idx | 319 MiB | 477 MiB | +49.5% |
| btree_index | 107 MiB | 151 MiB | +40.4% |
| wal_1m_insert | 61 MiB | 69 MiB | +12.5% |

---

Reminder on interpretation: a single headline number would be misleading here, because the two builds do not differ uniformly - fixed-width storage makes arithmetic cheaper and makes unpacking a stored value more expensive. Read the per-query rows, and weight them by the real query mix before drawing a conclusion.

# Phase 4 benchmark results: dec128 numeric vs stock numeric

```
# generated 2026-08-11T13:09:49+00:00
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
| add | 53.34 | 10.55 | 0.20x |
| cmp | 22.55 | 8.37 | 0.37x |
| div | 91.84 | 146.12 | 1.59x |
| mul | 55.88 | 12.51 | 0.22x |
| sub | 47.93 | 10.67 | 0.22x |

## Tier B - query level

| query | stock ms (MAD) | dec128 ms (MAD) | ratio | 95% CI | p | verdict |
|---|---|---|---|---|---|---|
| avg | 398.2 (0.2) | 459.3 (0.6) | 1.15x | [1.15, 1.16] | <0.001 | SLOWER (15-16% worse) |
| cast_float8 | 850.7 (0.4) | 868.8 (1.1) | 1.02x | [1.02, 1.02] | <0.001 | no difference (within +/-5%) |
| cast_int | 509.6 (0.9) | 569.3 (0.7) | 1.12x | [1.12, 1.12] | <0.001 | SLOWER (12-12% worse) |
| hash_agg | 873.9 (0.5) | 641.1 (1.4) | 0.73x | [0.73, 0.74] | <0.001 | FASTER (26-27% better) |
| hash_join | 975.3 (15.2) | 1029.3 (19.8) | 1.06x | [0.99, 1.07] | 0.085 | inconclusive - raise REPS |
| index_scan | 84.4 (0.8) | 93.5 (0.5) | 1.11x | [1.09, 1.13] | <0.001 | SLOWER (9-13% worse) |
| order_by_limit | 0.1 (0.0) | 0.1 (0.0) | 0.89x | [0.86, 0.94] | 0.002 | FASTER (6-14% better) |
| scan_count | 248.8 (0.7) | 261.0 (0.5) | 1.05x | [1.05, 1.05] | <0.001 | inconclusive - raise REPS |
| stddev | 482.8 (0.3) | 558.7 (0.1) | 1.16x | [1.16, 1.16] | <0.001 | SLOWER (16-16% worse) |
| sum | 398.9 (0.9) | 459.0 (0.4) | 1.15x | [1.15, 1.15] | <0.001 | SLOWER (15-15% worse) |
| sum_8add | 2497.2 (5.3) | 839.2 (1.1) | 0.34x | [0.34, 0.34] | <0.001 | FASTER (66-66% better) |
| sum_div | 875.9 (0.6) | 1226.9 (1.1) | 1.40x | [1.40, 1.40] | <0.001 | SLOWER (40-40% worse) |
| sum_expr_mixed | 1259.6 (2.0) | 630.7 (1.5) | 0.50x | [0.50, 0.50] | <0.001 | FASTER (50-50% better) |
| sum_mul | 686.9 (0.9) | 548.8 (1.2) | 0.80x | [0.80, 0.80] | <0.001 | FASTER (20-20% better) |
| text_out | 480.7 (1.1) | 534.9 (0.4) | 1.11x | [1.11, 1.12] | <0.001 | SLOWER (11-12% worse) |
| where_gt | 463.5 (1.2) | 332.4 (0.5) | 0.72x | [0.72, 0.72] | <0.001 | FASTER (28-28% better) |

## Tier C - storage and WAL

| metric | stock | dec128 | change |
|---|---|---|---|
| heap | 212 MiB | 326 MiB | +54.1% |
| heap_plus_toast_idx | 319 MiB | 477 MiB | +49.5% |
| btree_index | 107 MiB | 151 MiB | +40.4% |
| wal_1m_insert | 61 MiB | 56 MiB | -8.4% |

---

Reminder on interpretation: a single headline number would be misleading here, because the two builds do not differ uniformly - fixed-width storage makes arithmetic cheaper and makes unpacking a stored value more expensive. Read the per-query rows, and weight them by the real query mix before drawing a conclusion.

# Phase 4 benchmark results: dec128 numeric vs stock numeric

```
# generated 2026-08-11T13:52:59+00:00
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
| add | 52.93 | 10.19 | 0.19x |
| cmp | 21.64 | 8.09 | 0.37x |
| div | 92.79 | 48.97 | 0.53x |
| mul | 57.12 | 11.97 | 0.21x |
| sub | 53.45 | 10.61 | 0.20x |

## Tier B - query level

| query | stock ms (MAD) | dec128 ms (MAD) | ratio | 95% CI | p | verdict |
|---|---|---|---|---|---|---|
| avg | 397.0 (0.3) | 297.5 (0.5) | 0.75x | [0.75, 0.75] | <0.001 | FASTER (25-25% better) |
| cast_float8 | 884.8 (1.3) | 865.4 (1.3) | 0.98x | [0.98, 0.98] | <0.001 | no difference (within +/-5%) |
| cast_int | 508.1 (1.0) | 551.7 (0.4) | 1.09x | [1.08, 1.09] | <0.001 | SLOWER (8-9% worse) |
| hash_agg | 894.4 (0.5) | 668.6 (1.1) | 0.75x | [0.75, 0.75] | <0.001 | FASTER (25-25% better) |
| hash_join | 907.4 (8.4) | 919.1 (11.0) | 1.01x | [1.00, 1.03] | 0.008 | no difference (within +/-5%) |
| index_scan | 82.9 (0.4) | 91.8 (0.4) | 1.11x | [1.10, 1.13] | <0.001 | SLOWER (10-13% worse) |
| order_by_limit | 0.1 (0.0) | 0.1 (0.0) | 0.94x | [0.90, 1.02] | 0.069 | inconclusive - raise REPS |
| scan_count | 255.6 (1.5) | 271.8 (0.2) | 1.06x | [1.05, 1.07] | <0.001 | SLOWER (5-7% worse) |
| stddev | 484.2 (1.0) | 548.8 (0.4) | 1.13x | [1.13, 1.13] | <0.001 | SLOWER (13-13% worse) |
| sum | 397.0 (0.3) | 297.7 (0.5) | 0.75x | [0.75, 0.75] | <0.001 | FASTER (25-25% better) |
| sum_8add | 2474.7 (11.6) | 736.8 (0.3) | 0.30x | [0.30, 0.30] | <0.001 | FASTER (70-70% better) |
| sum_div | 875.6 (0.5) | 549.2 (0.3) | 0.63x | [0.63, 0.63] | <0.001 | FASTER (37-37% better) |
| sum_expr_mixed | 1258.9 (1.0) | 514.3 (0.2) | 0.41x | [0.41, 0.41] | <0.001 | FASTER (59-59% better) |
| sum_mul | 698.8 (1.2) | 414.9 (0.2) | 0.59x | [0.59, 0.59] | <0.001 | FASTER (41-41% better) |
| text_out | 490.9 (2.0) | 532.9 (1.0) | 1.09x | [1.08, 1.09] | <0.001 | SLOWER (8-9% worse) |
| where_gt | 439.9 (0.6) | 337.8 (0.4) | 0.77x | [0.77, 0.77] | <0.001 | FASTER (23-23% better) |

## Tier C - storage and WAL

| metric | stock | dec128 | change |
|---|---|---|---|
| heap | 212 MiB | 326 MiB | +54.1% |
| heap_plus_toast_idx | 319 MiB | 477 MiB | +49.5% |
| btree_index | 107 MiB | 151 MiB | +40.4% |
| wal_1m_insert | 61 MiB | 69 MiB | +12.5% |

---

Reminder on interpretation: a single headline number would be misleading here, because the two builds do not differ uniformly - fixed-width storage makes arithmetic cheaper and makes unpacking a stored value more expensive. Read the per-query rows, and weight them by the real query mix before drawing a conclusion.

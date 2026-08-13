#!/usr/bin/env bash
#
# Phase 4 benchmark runner: dec128 numeric vs stock numeric.
# See README.md for the design rationale.
#
# Usage: sudo ./bench.sh <stock-prefix> <dec128-prefix> <rows> <reps>
#
set -euo pipefail

STOCK=${1:?stock install prefix}
DEC=${2:?dec128 install prefix}
ROWS=${3:-20000000}
REPS=${4:-30}

PGUSER_RUN=${PGUSER_RUN:-postgres}
SOCK=/tmp/pgbench-sock
OUT=${OUT:-/tmp/results.csv}
PIN_CORE=${PIN_CORE:-2}
SHARED_BUFFERS=${SHARED_BUFFERS:-32GB}

mkdir -p "$SOCK"
chown "$PGUSER_RUN" "$SOCK"

# Pre-flight cleanup. A previous run that died on `set -e` leaves a postmaster
# holding the socket, and the next run then fails with a confusing "lock file
# already exists" instead of anything actionable. Clean up unconditionally.
# Stopping a cluster that is not running is expected, so its failure is genuinely
# uninteresting -- but say so rather than hiding it behind "|| true", and never
# let that idiom near anything whose success matters.
for old in "$STOCK" "$DEC"; do
	for d in /var/lib/pgbench/stock /var/lib/pgbench/dec128; do
		if [ -d "$d" ]; then
			sudo -u "$PGUSER_RUN" "$old/bin/pg_ctl" -D "$d" -m immediate -w stop \
				>/dev/null 2>&1 && echo "stopped leftover cluster $d"
		fi
	done
done
# pkill exits 1 when nothing matched, which is the normal case here.
if pkill -x postgres >/dev/null; then
	echo "killed leftover postgres processes"
	sleep 2
fi
rm -f "$SOCK"/.s.PGSQL.*

# ---------------------------------------------------------------- hygiene ----
# Each of these has been observed to produce double-digit percentage artefacts
# in per-operation measurements. Refuse to run rather than silently produce
# numbers nobody can defend.
say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die() { printf '\nFATAL: %s\n' "$*" >&2; exit 1; }

say "machine hygiene"
# Optional by design: not every kernel exposes a governor.  Report which branch
# was taken instead of swallowing the result -- the provenance block below
# records the governor, and a silent failure here would make it look deliberate.
if command -v cpupower >/dev/null 2>&1; then
	if cpupower frequency-set -g performance >/dev/null; then
		echo "governor: set to performance"
	else
		echo "governor: cpupower present but frequency-set failed; frequency is not pinned"
	fi
else
	echo "governor: cpupower not installed; frequency is not pinned"
fi
gov=$(cat /sys/devices/system/cpu/cpu$PIN_CORE/cpufreq/scaling_governor 2>/dev/null || echo "none")
echo "governor(core $PIN_CORE): $gov"

if [ -w /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
	echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
	echo "turbo: disabled"
else
	echo "turbo: could not disable (no intel_pstate); variance will be higher"
fi

if [ -w /sys/kernel/mm/transparent_hugepage/enabled ]; then
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
	echo "THP: never"
fi

command -v taskset >/dev/null 2>&1 || die "taskset not found (need util-linux)"
nproc_avail=$(nproc)
[ "$PIN_CORE" -lt "$nproc_avail" ] || die "PIN_CORE=$PIN_CORE >= nproc=$nproc_avail"

for p in "$STOCK" "$DEC"; do
	[ -x "$p/bin/postgres" ] || die "no postgres binary under $p"
done

# ------------------------------------------------------------- provenance ----
say "provenance"
{
	echo "# generated $(date -Is)"
	echo "# host: $(uname -srm)"
	echo "# cpu: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
	echo "# rows=$ROWS reps=$REPS shared_buffers=$SHARED_BUFFERS pin_core=$PIN_CORE"
	echo "# governor=$gov"
	for p in "$STOCK" "$DEC"; do
		echo "# $p version: $("$p/bin/postgres" --version)"
		echo "# $p configure: $("$p/bin/pg_config" --configure 2>/dev/null || echo unknown)"
	done
} > "$OUT.meta"
cat "$OUT.meta"

# ------------------------------------------------------------------ setup ----
# Deterministic data only: no random(). Both builds must see byte-identical
# input, and random() itself routes through numeric so it is not even the same
# generator between builds.
# Reference columns, so "how much does exactness cost" can be answered inside
# one engine rather than across engines:
#
#   v  numeric(12,2)  the type under test
#   w  numeric(8,3)   second numeric, for mixed-scale arithmetic
#   d  numeric        division-derived, so scale = 15.  Exposes the multiply
#                     fast path's scale ceiling, which is invisible on v.
#   mo money          int64, pass-by-value, scale fixed in the catalog --
#                     architecturally what DuckDB does for DECIMAL(18,2), and
#                     the closest thing PostgreSQL has to it.
#   bi bigint         int64 with no decimal semantics at all: the floor.
#
# Note sum(bigint) returns numeric and accumulates in numeric internally, so it
# is not a "pure integer sum"; the honest integer-arithmetic signal is the
# difference between sum(bi+bi+...) and sum(bi), not sum(bi) itself.
DDL=$(cat <<SQL
SET client_min_messages = warning;
CREATE TABLE b AS
  SELECT i AS id,
         ((100 + (i * 37 % 9973))::numeric / 100)::numeric(12,2) AS v,
         ((1 + (i * 13 % 500))::numeric / 1000)::numeric(8,3)    AS w,
         (100 + (i * 37 % 9973))::numeric / 100                  AS d,
         (((100 + (i * 37 % 9973))::numeric / 100))::money        AS mo,
         (100 + (i * 37 % 9973))::bigint                         AS bi
  FROM generate_series(1, $ROWS) i;
CREATE INDEX b_v_btree ON b (v);
VACUUM (ANALYZE, FREEZE) b;
SQL
)

start_pg() {
	local prefix=$1 data=$2 port=$3
	rm -rf "$data"
	sudo -u "$PGUSER_RUN" "$prefix/bin/initdb" -D "$data" -U "$PGUSER_RUN" \
		--no-sync >/dev/null 2>&1
	cat >> "$data/postgresql.conf" <<CONF
port = $port
unix_socket_directories = '$SOCK'
listen_addresses = ''
shared_buffers = $SHARED_BUFFERS
work_mem = 256MB
maintenance_work_mem = 2GB
max_wal_size = 32GB
min_wal_size = 8GB
checkpoint_timeout = 60min
jit = off
max_parallel_workers_per_gather = 0
track_io_timing = on
fsync = off
synchronous_commit = off
full_page_writes = off
autovacuum = off
CONF
	sudo -u "$PGUSER_RUN" "$prefix/bin/pg_ctl" -D "$data" -l "$data/log" -w start >/dev/null
}

stop_pg() {
	sudo -u "$PGUSER_RUN" "$1/bin/pg_ctl" -D "$2" -m immediate -w stop >/dev/null \
		|| echo "WARN: could not stop cluster at $2" >&2
}

# psql pinned to one core; -qAt gives bare values, easy to parse
q() {
	local prefix=$1 port=$2 sql=$3
	taskset -c "$PIN_CORE" sudo -u "$PGUSER_RUN" \
		"$prefix/bin/psql" -h "$SOCK" -p "$port" -U "$PGUSER_RUN" -d postgres \
		-qAt -v ON_ERROR_STOP=1 -c "$sql"
}

# Multi-statement scripts must go through stdin, not -c: psql wraps everything
# in a single -c into one transaction, and VACUUM cannot run inside one.
qscript() {
	local prefix=$1 port=$2
	taskset -c "$PIN_CORE" sudo -u "$PGUSER_RUN" \
		"$prefix/bin/psql" -h "$SOCK" -p "$port" -U "$PGUSER_RUN" -d postgres \
		-qAt -v ON_ERROR_STOP=1 -f -
}

# Time a query server-side. \timing includes client round-trip; instead we use
# EXPLAIN ANALYZE's execution time, which excludes psql overhead and is what we
# actually want to attribute to the arithmetic.
timeq() {
	local prefix=$1 port=$2 sql=$3
	taskset -c "$PIN_CORE" sudo -u "$PGUSER_RUN" \
		"$prefix/bin/psql" -h "$SOCK" -p "$port" -U "$PGUSER_RUN" -d postgres \
		-qAt -v ON_ERROR_STOP=1 \
		-c "EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF, FORMAT JSON) $sql" \
	| python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["Execution Time"])'
}

# As timeq(), but with GUC setup that has to reach the same session as the
# EXPLAIN.  Several Tier D entries exist only to force a particular plan shape,
# so the settings are part of the measurement, not incidental.
timeq_set() {
	local prefix=$1 port=$2 setup=$3 sql=$4
	taskset -c "$PIN_CORE" sudo -u "$PGUSER_RUN" \
		"$prefix/bin/psql" -h "$SOCK" -p "$port" -U "$PGUSER_RUN" -d postgres \
		-qAt -v ON_ERROR_STOP=1 \
		-c "$setup EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF, FORMAT JSON) $sql" \
	| python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["Execution Time"])'
}

# Index build is a large tuplesort but cannot be wrapped in EXPLAIN ANALYZE,
# so it is timed on the wall clock, once per build, outside the rep loop.
time_index_build() {
	local prefix=$1 port=$2 t0 t1
	q "$prefix" "$port" "DROP INDEX IF EXISTS b_tmp_idx" >/dev/null
	t0=$(date +%s%N)
	q "$prefix" "$port" "SET maintenance_work_mem='1GB'; CREATE INDEX b_tmp_idx ON b (v)" >/dev/null
	t1=$(date +%s%N)
	q "$prefix" "$port" "DROP INDEX IF EXISTS b_tmp_idx" >/dev/null
	awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", (b-a)/1000000}'
}

# ------------------------------------------------------------- query sets ----
# Tier A: op-count series. Slope of time vs op count = marginal cost of one op.
# The intercept absorbs scan + aggregation overhead and is thrown away, which
# is why this is more robust than subtracting a single noisy baseline.
declare -a TIER_A_NAMES TIER_A_SQL TIER_A_OPS
add_a() { TIER_A_NAMES+=("$1"); TIER_A_OPS+=("$2"); TIER_A_SQL+=("$3"); }

add_a add 0 "SELECT count(v) FROM b"
add_a add 1 "SELECT count(v+v) FROM b"
add_a add 2 "SELECT count(v+v+v) FROM b"
add_a add 4 "SELECT count(v+v+v+v+v) FROM b"
add_a add 8 "SELECT count(v+v+v+v+v+v+v+v+v) FROM b"

add_a sub 0 "SELECT count(v) FROM b"
add_a sub 1 "SELECT count(v-w) FROM b"
add_a sub 2 "SELECT count(v-w-w) FROM b"
add_a sub 4 "SELECT count(v-w-w-w-w) FROM b"
add_a sub 8 "SELECT count(v-w-w-w-w-w-w-w-w) FROM b"

add_a mul 0 "SELECT count(v) FROM b"
add_a mul 1 "SELECT count(v*w) FROM b"
add_a mul 2 "SELECT count(v*w*w) FROM b"
add_a mul 4 "SELECT count(v*w*w*w*w) FROM b"

add_a div 0 "SELECT count(v) FROM b"
add_a div 1 "SELECT count(v/w) FROM b"
add_a div 2 "SELECT count(v/w/w) FROM b"
add_a div 4 "SELECT count(v/w/w/w/w) FROM b"

add_a cmp 0 "SELECT count(v) FROM b"
add_a cmp 1 "SELECT count(1) FROM b WHERE v > 5.00"
add_a cmp 2 "SELECT count(1) FROM b WHERE v > 5.00 AND v > 4.00"
add_a cmp 4 "SELECT count(1) FROM b WHERE v > 5.00 AND v > 4.00 AND v > 3.00 AND v > 2.00"

# Tier B: query level. Spec 3.2's mix, plus the aggregation and text-output
# cases earlier work flagged as suspect. Every row gets reported.
declare -a TIER_B_NAMES TIER_B_SQL
add_b() { TIER_B_NAMES+=("$1"); TIER_B_SQL+=("$2"); }

add_b "scan_count"        "SELECT count(v) FROM b"
add_b "sum"               "SELECT sum(v) FROM b"
add_b "avg"               "SELECT avg(v) FROM b"
add_b "sum_8add"          "SELECT sum(v+v+v+v+v+v+v+v+v) FROM b"
add_b "sum_expr_mixed"    "SELECT sum((v+v)*v-v) FROM b"
add_b "sum_mul"           "SELECT sum(v*w) FROM b"
add_b "sum_div"           "SELECT sum(v/w) FROM b"
add_b "stddev"            "SELECT stddev(v) FROM b"
add_b "order_by_limit"    "SELECT v FROM b ORDER BY v LIMIT 10"
add_b "where_gt"          "SELECT count(1) FROM b WHERE v > 5.00"
add_b "text_out"          "SELECT count(v::text) FROM b"
add_b "hash_agg"          "SELECT count(*) FROM (SELECT v, count(*) FROM b GROUP BY v) s"
# Bounded deliberately: an unrestricted 20M-row self-join spills work_mem and
# takes tens of seconds, which would dominate total runtime across 30 reps
# without telling us anything extra about numeric hashing.
add_b "hash_join"         "SELECT count(*) FROM b b1 JOIN (SELECT * FROM b WHERE id <= 200000) b2 ON b1.v = b2.v AND b1.id = b2.id"
add_b "index_scan"        "SELECT count(v) FROM b WHERE v BETWEEN 20.00 AND 30.00"
add_b "cast_int"          "SELECT count(v::int) FROM b"
add_b "cast_float8"       "SELECT count(v::float8) FROM b"

# --- the scale cliff: same magnitudes as v, but scale 15 instead of 2 -------
add_b "sum_d"             "SELECT sum(d) FROM b"
add_b "sum_mul_d"         "SELECT sum(d*d) FROM b"

# --- reference types, identical code in both builds -------------------------
# These let the report answer "what does exactness cost" within one engine,
# the way the DuckDB note argues it must be measured.  They are unaffected by
# the patch, so they double as a per-run noise control.
add_b "ref_money_sum"     "SELECT sum(mo) FROM b"
add_b "ref_money_8add"    "SELECT sum(mo+mo+mo+mo+mo+mo+mo+mo+mo) FROM b"
add_b "ref_money_mul2"    "SELECT sum(mo*2) FROM b"
add_b "ref_bigint_sum"    "SELECT sum(bi) FROM b"
add_b "ref_bigint_8add"   "SELECT sum(bi+bi+bi+bi+bi+bi+bi+bi+bi) FROM b"
add_b "ref_bigint_mul"    "SELECT sum(bi*bi) FROM b"
add_b "ref_float8_sum"    "SELECT sum(v::float8) FROM b"
# numeric counterparts of the reference shapes, for a like-for-like ratio
add_b "num_mul2"          "SELECT sum(v*2) FROM b"

# ---------------------------------------------------------------------------
# Tier D: sorting, aggregation and window paths.
#
# These exist because the patch rewrote code that Tier B never exercises:
#   numeric_abbrev_convert()/numeric_fast_cmp()  -> every sort, index build,
#       merge join, sort-based DISTINCT and GroupAgg
#   do_numeric_discard()                         -> window frames that evict
#   numeric_dec128_canonical()                   -> hash agg / hash join / hash
#       DISTINCT
#
# Tier B's "order_by_limit" is a top-N heapsort over 10 rows taking 0.1 ms; it
# measures nothing.  A full sort is what puts abbreviated keys on the hot path.
#
# work_mem is set per query where the point is to force a particular strategy,
# so these are deliberately not comparable to Tier B's absolute numbers.
# Each entry carries its own GUC setup, because several of these exist
# specifically to force one execution strategy.  Setup and query go to the
# server in a single psql invocation so the settings apply to the EXPLAIN.
declare -a TIER_D_NAMES TIER_D_SET TIER_D_SQL
add_d() { TIER_D_NAMES+=("$1"); TIER_D_SET+=("$2"); TIER_D_SQL+=("$3"); }

W1="SET work_mem='1GB';"
W4="SET work_mem='4MB';"

# --- sorts: abbreviated keys and the full comparator ------------------------
add_d "sort_mem"          "$W1" "SELECT count(*) FROM (SELECT v FROM b ORDER BY v) s"
add_d "sort_spill"        "$W4" "SELECT count(*) FROM (SELECT v FROM b ORDER BY v) s"
add_d "sort_desc"         "$W1" "SELECT count(*) FROM (SELECT v FROM b ORDER BY v DESC) s"
add_d "sort_d_scale15"    "$W1" "SELECT count(*) FROM (SELECT d FROM b ORDER BY d) s"
add_d "ref_sort_money"    "$W1" "SELECT count(*) FROM (SELECT mo FROM b ORDER BY mo) s"
add_d "ref_sort_bigint"   "$W1" "SELECT count(*) FROM (SELECT bi FROM b ORDER BY bi) s"
add_d "distinct_sort"     "$W1 SET enable_hashagg=off;" "SELECT count(*) FROM (SELECT DISTINCT v FROM b) s"
add_d "distinct_hash"     "$W1" "SELECT count(*) FROM (SELECT DISTINCT v FROM b) s"

# --- grouping: hash vs sort, low vs high cardinality -----------------------
# v has ~9973 distinct values; id is unique, so grouping on id is the
# high-cardinality case that actually stresses hashing and spilling.
add_d "groupagg_sort"     "$W1 SET enable_hashagg=off;" "SELECT count(*) FROM (SELECT v, sum(w) FROM b GROUP BY v) s"
add_d "hashagg_highcard"  "$W1" "SELECT count(*) FROM (SELECT id, sum(v) FROM b GROUP BY id) s"
add_d "hashagg_spill"     "$W4" "SELECT count(*) FROM (SELECT id, sum(v) FROM b GROUP BY id) s"

# --- comparison-only aggregates -------------------------------------------
add_d "minmax"            "" "SELECT min(v), max(v) FROM b"
add_d "ref_minmax_money"  "" "SELECT min(mo), max(mo) FROM b"

# --- window frames: exercise the inverse transition (do_numeric_discard) ---
add_d "win_moving_sum"    "$W1" "SELECT count(s) FROM (SELECT sum(v) OVER (ORDER BY id ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) s FROM b) t"
add_d "win_moving_avg"    "$W1" "SELECT count(s) FROM (SELECT avg(v) OVER (ORDER BY id ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) s FROM b) t"
add_d "ref_win_money"     "$W1" "SELECT count(s) FROM (SELECT sum(mo) OVER (ORDER BY id ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) s FROM b) t"

# --- ordered-set aggregate: numeric-specific, sorts internally -------------
add_d "percentile"        "$W1" "SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY v) FROM b"

# --- variance family: the one aggregate that cannot use the fast sum -------
add_d "variance"          "" "SELECT variance(v) FROM b"

# --- merge join needs both inputs sorted ----------------------------------
add_d "merge_join"        "$W1 SET enable_hashjoin=off; SET enable_nestloop=off;" "SELECT count(*) FROM b b1 JOIN (SELECT * FROM b WHERE id <= 200000) b2 ON b1.v = b2.v AND b1.id = b2.id"

# Tier B parallel rows are run separately with workers enabled.
declare -a TIER_P_NAMES TIER_P_SQL
TIER_P_NAMES=("par2_sum" "par2_where")
TIER_P_SQL=("SELECT sum(v) FROM b" "SELECT count(1) FROM b WHERE v > 5.00")

# ------------------------------------------------------------------- main ----
DATA_STOCK=/var/lib/pgbench/stock
DATA_DEC=/var/lib/pgbench/dec128
mkdir -p /var/lib/pgbench && chown "$PGUSER_RUN" /var/lib/pgbench

echo "build,tier,query,ops,rep,ms" > "$OUT"

say "starting clusters and loading ${ROWS} rows (this takes a few minutes)"
start_pg "$STOCK" "$DATA_STOCK" 6001
start_pg "$DEC"   "$DATA_DEC"   6002

for spec in "stock:$STOCK:6001:$DATA_STOCK" "dec128:$DEC:6002:$DATA_DEC"; do
	IFS=: read -r label prefix port data <<< "$spec"
	echo "  loading $label ..."
	printf '%s\n' "$DDL" | qscript "$prefix" "$port" >/dev/null
	# Prewarm is load-bearing: the whole point of Tier A/B is to measure CPU, not
	# I/O, so a silently skipped prewarm invalidates every number below.  These
	# two calls used to end in "|| true" and did exactly that for five runs --
	# contrib was never built (plain "make install" does not build it; that needs
	# "install-world"), pg_prewarm did not exist, and the harness reported
	# success.  Fail loudly instead.
	q "$prefix" "$port" "CREATE EXTENSION IF NOT EXISTS pg_prewarm" >/dev/null \
		|| die "pg_prewarm unavailable for $label -- build contrib (make install-world) or the numbers below measure I/O, not CPU"
	q "$prefix" "$port" "SELECT pg_prewarm('b'), pg_prewarm('b_v_btree')" >/dev/null \
		|| die "pg_prewarm() failed for $label"
done

# ---- Tier C: sizes and WAL. Measured once; not a latency, but capable of
# ---- dominating the decision on a write-heavy or replicated system.
say "Tier C: storage and WAL"
{
	echo "build,metric,bytes"
	for spec in "stock:$STOCK:6001" "dec128:$DEC:6002"; do
		IFS=: read -r label prefix port <<< "$spec"
		tbl=$(q "$prefix" "$port" "SELECT pg_relation_size('b')")
		tot=$(q "$prefix" "$port" "SELECT pg_total_relation_size('b')")
		idx=$(q "$prefix" "$port" "SELECT pg_relation_size('b_v_btree')")
		# WAL for a 1M-row insert of the same shape
		l1=$(q "$prefix" "$port" "SELECT pg_current_wal_lsn()")
		q "$prefix" "$port" "CREATE TABLE walprobe AS SELECT ((100+(i*37%9973))::numeric/100)::numeric(12,2) v FROM generate_series(1,1000000) i" >/dev/null
		l2=$(q "$prefix" "$port" "SELECT pg_current_wal_lsn()")
		wal=$(q "$prefix" "$port" "SELECT pg_wal_lsn_diff('$l2','$l1')::bigint")
		q "$prefix" "$port" "DROP TABLE walprobe" >/dev/null
		echo "$label,heap,$tbl"
		echo "$label,heap_plus_toast_idx,$tot"
		echo "$label,btree_index,$idx"
		echo "$label,wal_1m_insert,$wal"
	done
} > "${OUT%.csv}-sizes.csv"
cat "${OUT%.csv}-sizes.csv"

# ---- warmup: discard, so the first build measured does not pay cache fill
say "warmup"
for r in 1 2; do
	for spec in "stock:$STOCK:6001" "dec128:$DEC:6002"; do
		IFS=: read -r label prefix port <<< "$spec"
		timeq "$prefix" "$port" "SELECT sum(v) FROM b" >/dev/null
	done
done

# ---- Tier A + B, interleaved per repetition so that any drift in machine
# ---- state affects both builds equally instead of only the one measured last.
say "Tier A + B, $REPS interleaved repetitions"
for rep in $(seq 1 "$REPS"); do
	printf '\r  rep %d/%d' "$rep" "$REPS"
	for spec in "stock:$STOCK:6001" "dec128:$DEC:6002"; do
		IFS=: read -r label prefix port <<< "$spec"

		for i in "${!TIER_A_SQL[@]}"; do
			ms=$(timeq "$prefix" "$port" "${TIER_A_SQL[$i]}")
			echo "$label,A,${TIER_A_NAMES[$i]},${TIER_A_OPS[$i]},$rep,$ms" >> "$OUT"
		done

		for i in "${!TIER_B_SQL[@]}"; do
			ms=$(timeq "$prefix" "$port" "${TIER_B_SQL[$i]}")
			echo "$label,B,${TIER_B_NAMES[$i]},1,$rep,$ms" >> "$OUT"
		done

		for i in "${!TIER_D_SQL[@]}"; do
			ms=$(timeq_set "$prefix" "$port" "${TIER_D_SET[$i]}" "${TIER_D_SQL[$i]}")
			echo "$label,D,${TIER_D_NAMES[$i]},1,$rep,$ms" >> "$OUT"
		done
	done
done
printf '\n'

# ---- index build: wall clock, a few times each, outside the rep loop
say "index build (tuplesort, cannot be EXPLAIN ANALYZEd)"
for rep in 1 2 3; do
	for spec in "stock:$STOCK:6001" "dec128:$DEC:6002"; do
		IFS=: read -r label prefix port <<< "$spec"
		ms=$(time_index_build "$prefix" "$port")
		echo "$label,D,index_build,1,$rep,$ms" >> "$OUT"
	done
done

# ---- parallel rows, fewer reps (more variance, less central to the question)
say "parallel rows"
PREPS=$(( REPS / 3 + 1 ))
for spec in "stock:$STOCK:6001" "dec128:$DEC:6002"; do
	IFS=: read -r label prefix port <<< "$spec"
	q "$prefix" "$port" "ALTER SYSTEM SET max_parallel_workers_per_gather = 2" >/dev/null
	q "$prefix" "$port" "SELECT pg_reload_conf()" >/dev/null
done
for rep in $(seq 1 "$PREPS"); do
	for spec in "stock:$STOCK:6001" "dec128:$DEC:6002"; do
		IFS=: read -r label prefix port <<< "$spec"
		for i in "${!TIER_P_SQL[@]}"; do
			ms=$(timeq "$prefix" "$port" "${TIER_P_SQL[$i]}")
			echo "$label,P,${TIER_P_NAMES[$i]},1,$rep,$ms" >> "$OUT"
		done
	done
done

# ---- verify we measured CPU and not I/O
# This check was previously informational, which was useless: it printed a
# nonzero number for dec128 and nobody noticed.  If the measurements were
# supposed to be CPU-bound, a material number of disk reads means they were not,
# so make it a verdict rather than a line of output.
say "I/O sanity check"
IO_BUDGET=${IO_BUDGET:-1000}
for spec in "stock:$STOCK:6001" "dec128:$DEC:6002"; do
	IFS=: read -r label prefix port <<< "$spec"
	blks=$(q "$prefix" "$port" "SELECT heap_blks_read FROM pg_statio_user_tables WHERE relname='b'")
	echo "$label: $blks heap blocks read from disk"
	if [ "${blks:-0}" -gt "$IO_BUDGET" ]; then
		die "$label did more than $IO_BUDGET disk reads on table b; these timings include I/O and are not comparable"
	fi
done

stop_pg "$STOCK" "$DATA_STOCK"
stop_pg "$DEC" "$DATA_DEC"

say "done -> $OUT  (+ ${OUT%.csv}-sizes.csv, $OUT.meta)"
wc -l "$OUT"

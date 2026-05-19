#!/bin/bash
#
# pgbench INSERT-with-bigserial benchmark
#
# Measures real-world INSERT throughput on a single-column UNLOGGED table
# with a bigserial PK source.  Heap blocks are pre-allocated and vacuumed,
# so the test path is: nextval -> tuple form -> heap_insert into pre-existing
# free space, with no relation extension and no WAL.
#
# The test stops after a fixed number of INSERTs (not wall time), so the
# total tuple count stays well below the pre-allocated free space and no
# heap extension happens during the measurement window.
#
# Tunables (override via environment):
#   PREALLOC_ROWS    rows to bulk-insert then DELETE (default 10_000_000)
#   WARMUP_INSERTS   total warm-up INSERTs across all clients (default 1_000_000)
#   INSERTS          total measurement INSERTs across all clients (default 5_000_000)
#   CLIENTS          concurrent pgbench clients (default 1)
#   JOBS             pgbench worker threads (default = CLIENTS)
#
ulimit -c unlimited

INSTDIR=`pwd`/tmp_install
export LD_LIBRARY_PATH=$INSTDIR/lib:$LD_LIBRARY_PATH
export PATH=$INSTDIR/bin:$PATH

if [[ -z "${PGPORT}" ]]; then
  export PGPORT=5432
  echo "Set PGPORT to default value 5432"
else
  echo "PGPORT $PGPORT"
fi

PREALLOC_ROWS=${PREALLOC_ROWS:-10000000}
WARMUP_INSERTS=${WARMUP_INSERTS:-500000}
INSERTS=${INSERTS:-5000000}
CLIENTS=${CLIENTS:-1}
JOBS=${JOBS:-$CLIENTS}

# Per-client transaction counts (pgbench -t is per-client).
WARMUP_T=$((WARMUP_INSERTS / CLIENTS))
MEASURE_T=$((INSERTS / CLIENTS))

# Hard constraint: the total number of INSERTs done during warm-up plus
# measurement must not exceed the number of rows inserted at table creation
# time.  Anything beyond that forces the heap to extend mid-run, which
# contaminates the measurement with smgrextend / FSM / extension-lock work.
TOTAL=$((WARMUP_INSERTS + INSERTS))
if [ $TOTAL -gt $PREALLOC_ROWS ]; then
    echo "ERROR: WARMUP_INSERTS + INSERTS = $TOTAL exceeds PREALLOC_ROWS = $PREALLOC_ROWS."
    echo "       Total INSERTs during the run must not exceed the rows inserted"
    echo "       at table creation, otherwise the heap will extend and the"
    echo "       measurement will include extension overhead."
    echo "       Either decrease WARMUP_INSERTS/INSERTS or increase PREALLOC_ROWS."
    exit 1
fi

# Kill any leftover processes
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
    pkill -U `whoami` -9 -e postgres 2>/dev/null
    pkill -U `whoami` -9 -e pgbench  2>/dev/null
    pkill -U `whoami` -9 -e psql     2>/dev/null
elif [[ "$OSTYPE" == "darwin"* ]]; then
    killall -u `whoami` -vz -9 postgres 2>/dev/null
    killall -u `whoami` -vz -9 pgbench  2>/dev/null
    killall -u `whoami` -vz -9 psql     2>/dev/null
    ipcs -om | awk 'NR>3 && $7==0 {print $2}' | xargs -I {} ipcrm -m {} 2>/dev/null
else
    echo "Unintended OS." ; exit 1
fi
sleep 1

mk

M=`pwd`/PGDATA
U=`whoami`
export PGUSER=$U

rm -rf $M logfile.log result_pgbench.txt 2>/dev/null
mkdir $M

export LC_ALL=en_US.UTF-8
initdb -D $M -U $U --locale=en_US.UTF-8

# Same isolation knobs as the nextval microbench, plus a larger
# max_wal_size to keep checkpoints from firing on the smgrextend path.
cat >> $M/postgresql.conf <<EOF
autovacuum = off
checkpoint_timeout = 1h
shared_buffers = 8GB
fsync = off
full_page_writes = off
synchronous_commit = off
bgwriter_lru_maxpages = 0
max_wal_size = 64GB
EOF

pg_ctl -w -D $M -l logfile.log start
createdb

#
# Build the test table:
#  - single column, bigserial (implicit sequence + nextval default)
#  - UNLOGGED (no WAL on INSERTs)
#  - no indexes (we want only the INSERT path, no per-row index work)
#  - heap is pre-extended via INSERT of PREALLOC_ROWS, then DELETEd
#    (keeping the highest id so VACUUM does not truncate the relation)
#  - VACUUM marks dead line pointers reusable; the FSM is populated.
#    Subsequent INSERTs slot into freed space without extending the heap.
#
psql <<EOF
\\timing on
DROP TABLE IF EXISTS bench_t;
CREATE UNLOGGED TABLE bench_t (id bigserial);

-- Bulk-extend the heap.  generate_series is faster than \\copy here.
INSERT INTO bench_t SELECT generate_series(1, $PREALLOC_ROWS);

-- Delete all but the highest id (keeps the relation from being truncated).
DELETE FROM bench_t WHERE id < (SELECT max(id) FROM bench_t);

-- VACUUM marks dead line pointers reusable; FSM gets populated.
-- Without VACUUM the dead tuples occupy space and INSERTs would extend.
VACUUM bench_t;

\\timing off

SELECT
    relpages                                    AS pages_before,
    pg_size_pretty(pg_relation_size('bench_t')) AS size_before,
    (SELECT count(*) FROM bench_t)              AS live_rows
FROM pg_class
WHERE relname = 'bench_t' \\gset
\\echo Pre-test heap: :pages_before pages, :size_before, :live_rows live rows
EOF

# Capture relpages before the test for the post-run delta check.
PAGES_BEFORE=$(psql -tAc "SELECT relpages FROM pg_class WHERE relname='bench_t'")

# pgbench worker script: one INSERT per transaction, no batching.
cat > /tmp/bench_insert.sql <<EOF
INSERT INTO bench_t DEFAULT VALUES;
EOF

echo ""
echo "=== Warm-up: ${WARMUP_INSERTS} INSERTs total (${WARMUP_T} per client) ==="
echo "    ${CLIENTS} client(s), ${JOBS} job(s)"
pgbench -n -c $CLIENTS -j $JOBS -t $WARMUP_T \
        -f /tmp/bench_insert.sql 2>&1 | tail -8

echo ""
echo "=== Measurement: ${INSERTS} INSERTs total (${MEASURE_T} per client) ==="
echo "    ${CLIENTS} client(s), ${JOBS} job(s)"
pgbench -n -c $CLIENTS -j $JOBS -t $MEASURE_T \
        -P 5 \
        -f /tmp/bench_insert.sql 2>&1 | tee result_pgbench.txt

# Post-run check: verify no heap extension happened during measurement.
echo ""
echo "=== Final table state ==="
psql <<EOF
SELECT
    relpages                                    AS pages_after,
    pg_size_pretty(pg_relation_size('bench_t')) AS size_after,
    (SELECT count(*) FROM bench_t)              AS live_rows
FROM pg_class WHERE relname = 'bench_t';
EOF

PAGES_AFTER=$(psql -tAc "SELECT relpages FROM pg_class WHERE relname='bench_t'")
PAGES_GROWTH=$((PAGES_AFTER - PAGES_BEFORE))
if [ $PAGES_GROWTH -eq 0 ]; then
    echo "OK: heap did not extend during the run (pages: $PAGES_BEFORE -> $PAGES_AFTER)"
else
    echo "WARNING: heap extended by $PAGES_GROWTH pages during the run"
    echo "         pages: $PAGES_BEFORE -> $PAGES_AFTER"
    echo "         Increase PREALLOC_ROWS to keep the measurement extension-free."
fi

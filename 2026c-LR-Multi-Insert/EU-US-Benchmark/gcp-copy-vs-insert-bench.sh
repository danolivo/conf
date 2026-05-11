#!/bin/bash
# =============================================================================
# COPY Replication Benchmark: multi_insert ON vs OFF
# =============================================================================
# Loads data via COPY on the publisher twice — once with the subscription in
# multi_insert = true mode, once with multi_insert = false — and compares:
#   - Wall-clock COPY time on publisher
#   - WAL generated on publisher
#   - WAL generated on subscriber
#   - Replication catch-up time
#   - Table sizes on both sides
#
# Usage:  gcp-copy-vs-insert-bench.sh [nrows]
#         (default: 1 000 000 rows)
# =============================================================================
set -euo pipefail

# ── Configuration (must match gcp-replicaset.sh) ──────────────────
PUB_VM="danolivo-eu"
PUB_ZONE="europe-west1-d"
SUB_VM="danolivo-usa"
SUB_ZONE="us-west1-b"

DBNAME="danolivo"
DBUSER="danolivo"
DBPASS='bZx7!mQ2nL9w'
PGPORT=5432

NROWS=${1:-100000000}

# ── Discover external IPs ──────────────────────────────────────────
PUB_HOST=$(gcloud compute instances describe "$PUB_VM" \
    --zone="$PUB_ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
SUB_HOST=$(gcloud compute instances describe "$SUB_VM" \
    --zone="$SUB_ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

export PGPASSWORD="$DBPASS"

psql_pub() { psql -h "$PUB_HOST" -p "$PGPORT" -U "$DBUSER" -d "$DBNAME" "$@"; }
psql_sub() { psql -h "$SUB_HOST" -p "$PGPORT" -U "$DBUSER" -d "$DBNAME" "$@"; }

# ── Helper: millisecond timestamp (works on both macOS and Linux) ──
now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }

# ── Helper: wait for subscriber to catch up ────────────────────────
wait_for_replication() {
    local table=$1
    local expected=$2
    local start_ms=$(now_ms)

    for i in $(seq 1 30000000); do
        local count=$(psql_sub -Atc "SELECT count(*) FROM $table" 2>/dev/null || echo "0")
        if [ "$count" -ge "$expected" ] 2>/dev/null; then
            local end_ms=$(now_ms)
            local elapsed=$(( end_ms - start_ms ))
            echo "  Replication catch-up: ${elapsed} ms ($count rows on subscriber)"
            return 0
        fi
        sleep 1
    done
    echo "  WARNING: replication did not catch up within 60s (got $count / $expected rows)"
    return 1
}

# ── Run one COPY benchmark round ──────────────────────────────────
# Args: $1 = label, $2 = multi_insert value (true/false)
run_copy_bench() {
    local label=$1
    local multi_insert=$2

    echo ""
    echo "============================================="
    echo " $label (multi_insert = $multi_insert)"
    echo "============================================="

    # Drop old subscription/publication
    psql_sub -c "DROP SUBSCRIPTION IF EXISTS bench_sub" 2>/dev/null || true
    psql_pub -c "DROP PUBLICATION IF EXISTS bench_pub" 2>/dev/null || true

    # Recreate tables
    psql_pub -c "
    DROP TABLE IF EXISTS bench_copy;
    CREATE TABLE bench_copy (
        id        bigint PRIMARY KEY,
        val       double precision,
        payload   text,
        ts        timestamptz
    );
    "
    psql_sub -c "
    DROP TABLE IF EXISTS bench_copy;
    CREATE TABLE bench_copy (
        id        bigint PRIMARY KEY,
        val       double precision,
        payload   text,
        ts        timestamptz
    );
    "

    # Publication & subscription
    psql_pub -c "CREATE PUBLICATION bench_pub FOR TABLE bench_copy"

    CONNINFO="host=$PUB_HOST port=$PGPORT dbname=$DBNAME user=$DBUSER password=$DBPASS"
    psql_sub -c "CREATE SUBSCRIPTION bench_sub CONNECTION '$CONNINFO' PUBLICATION bench_pub WITH (streaming = false, multi_insert = $multi_insert)"

    # Wait for initial sync
    echo "  Waiting for subscription sync..."
    for i in $(seq 1 30); do
        READY=$(psql_sub -Atc "SELECT bool_and(srsubstate = 'r') FROM pg_subscription_rel" 2>/dev/null || echo "f")
        [ "$READY" = "t" ] && break
        sleep 1
    done
    echo "  Subscription ready."

    # Checkpoint on both sides so WAL counters start clean
    psql_pub -c "CHECKPOINT"
    psql_sub -c "CHECKPOINT"

    # Capture WAL positions before
    PUB_WAL_BEFORE=$(psql_pub -Atc "SELECT pg_current_wal_lsn()")
    SUB_WAL_BEFORE=$(psql_sub -Atc "SELECT pg_current_wal_lsn()")

    # Run COPY
    echo ""
    psql_pub -c "\timing on" -c "
    COPY bench_copy (id, val, payload, ts)
    FROM '/tmp/bench_src_data.csv' WITH (FORMAT csv);
    "

    # Publisher WAL
    PUB_WAL_AFTER=$(psql_pub -Atc "SELECT pg_current_wal_lsn()")
    psql_pub -Atc "SELECT '  Publisher WAL generated: ' || pg_size_pretty('$PUB_WAL_AFTER'::pg_lsn - '$PUB_WAL_BEFORE'::pg_lsn)"
    psql_pub -Atc "SELECT '  Publisher table size:    ' || pg_size_pretty(pg_total_relation_size('bench_copy'))"

    # Wait for replication
    wait_for_replication bench_copy "$NROWS"

    # Subscriber WAL
    SUB_WAL_AFTER=$(psql_sub -Atc "SELECT pg_current_wal_lsn()")
    psql_sub -Atc "SELECT '  Subscriber WAL generated: ' || pg_size_pretty('$SUB_WAL_AFTER'::pg_lsn - '$SUB_WAL_BEFORE'::pg_lsn)"
    psql_sub -Atc "SELECT '  Subscriber table size:    ' || pg_size_pretty(pg_total_relation_size('bench_copy'))"
}

# =============================================================================
# Main
# =============================================================================
echo "============================================="
echo " COPY replication benchmark — $NROWS rows"
echo " Publisher:  $PUB_HOST ($PUB_VM)"
echo " Subscriber: $SUB_HOST ($SUB_VM)"
echo "============================================="

# ── Generate source data once ──────────────────────────────────────
echo ""
echo "Generating source data ($NROWS rows) on publisher..."

psql_pub -c "
DROP TABLE IF EXISTS _src_data;
CREATE TABLE _src_data AS
SELECT
    g                                        AS id,
    random()                                 AS val,
    md5(g::text)                             AS payload,
    now() - (random() * interval '365 days') AS ts
FROM generate_series(1, $NROWS) g;

ANALYSE _src_data;

COPY (SELECT id, val, payload, ts FROM _src_data ORDER BY id)
  TO '/tmp/bench_src_data.csv' WITH (FORMAT csv);
"
echo "Source data ready."

# ── Round 1: multi_insert = true ───────────────────────────────────
run_copy_bench "Round 1" true

# ── Round 2: multi_insert = false ──────────────────────────────────
run_copy_bench "Round 2" false

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========== DONE =========="
echo ""
echo "--- Replication status ---"
psql_sub -c "SELECT subname, received_lsn, latest_end_lsn, latest_end_time FROM pg_stat_subscription"

# Clean up
psql_pub -c "DROP TABLE IF EXISTS _src_data"

unset PGPASSWORD

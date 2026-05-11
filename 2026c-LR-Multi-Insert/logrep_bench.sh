#!/usr/bin/env bash
# =============================================================================
# Logical Replication Benchmark: COPY vs INSERT
# =============================================================================
#
# Run after pre_replicaset.sh which:
#   - Starts publisher (PGPORT1) and subscriber (PGPORT2)
#   - Creates bench_copy on both sides
#   - Creates publication bench_pub FOR ALL TABLES on publisher
#   - Creates subscription bench_sub on subscriber
#
# This script:
#   - Generates source data, loads via COPY and INSERT
#   - Measures time + WAL on both publisher and subscriber
#
# Usage:
#   source pre_replicaset.sh
#   ./logrep_bench.sh [--nrows 1000000] [--skip-teardown]
#
# =============================================================================
set -euo pipefail

# ── inherit environment from pre_replicaset.sh ────────────────────────────────
if [[ -z "${PGPORT1:-}" ]]; then
    PGPORT1=${PGPORT:-5432}
fi
PGPORT2=${PGPORT2:-$((PGPORT1 + 1))}

U=${PGUSER:-$(whoami)}
DB=${PGDATABASE:-$U}
SUB_NAME="bench_sub"

NROWS=1000000
SKIP_TEARDOWN=false
POLL_INTERVAL=0.2

# ── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --nrows)         NROWS="$2";        shift 2;;
        --skip-teardown) SKIP_TEARDOWN=true; shift;;
        *) echo "Unknown arg: $1"; exit 1;;
    esac
done

pub_psql() { psql -p "$PGPORT1" -U "$U" -d "$DB" -XAtq "$@"; }
sub_psql() { psql -p "$PGPORT2" -U "$U" -d "$DB" -XAtq "$@"; }

echo "============================================="
echo " Logical Replication Benchmark — ${NROWS} rows"
echo "============================================="
echo " Publisher:  port ${PGPORT1}, db ${DB}, user ${U}"
echo " Subscriber: port ${PGPORT2}, db ${DB}, user ${U}"
echo ""

# ── generate source data on publisher ─────────────────────────────────────────
echo "Generating ${NROWS} rows of source data on the publisher..."
pub_psql <<SQL
    CREATE TEMP TABLE _src_data AS
    SELECT
        g                                        AS id,
        random()                                 AS val,
        md5(g::text)                             AS payload,
        now() - (random() * interval '365 days') AS ts
    FROM generate_series(1, ${NROWS}) g;

    COPY (SELECT id, val, payload, ts FROM _src_data ORDER BY id)
      TO '/tmp/bench_src_data.csv' WITH (FORMAT csv);
SQL
echo "Source data ready."
echo ""

# ── helper: wait for subscriber to catch up to a given publisher LSN ──────────
wait_for_subscriber() {
    local target_lsn="$1"
    while true; do
        local sub_lsn
        sub_lsn=$(sub_psql -c \
            "SELECT latest_end_lsn
               FROM pg_stat_subscription
              WHERE subname = '${SUB_NAME}'
              LIMIT 1;")
        if [[ -n "$sub_lsn" ]] && \
           [[ $(pub_psql -c "SELECT '${sub_lsn}'::pg_lsn >= '${target_lsn}'::pg_lsn;") == "t" ]]; then
            break
        fi
        sleep "$POLL_INTERVAL"
    done
}

wait_for_row_count() {
    local table="$1"
    local expected="$2"
    while true; do
        local cnt
        cnt=$(sub_psql -c "SELECT count(*) FROM ${table};")
        if [[ "$cnt" -ge "$expected" ]]; then
            break
        fi
        sleep "$POLL_INTERVAL"
    done
}

# =============================================================================
# 1. COPY on publisher → replicate to subscriber
# =============================================================================
echo "--- 1. COPY ---"

pub_psql -c "CHECKPOINT;"
sub_psql -c "CHECKPOINT;"

pub_lsn_before=$(pub_psql -c "SELECT pg_current_wal_lsn();")
sub_lsn_before=$(sub_psql -c "SELECT pg_current_wal_lsn();")

load_start=$(date +%s%N)
pub_psql -c "COPY bench_copy (id, val, payload, ts)
             FROM '/tmp/bench_src_data.csv' WITH (FORMAT csv);"
load_end=$(date +%s%N)

pub_lsn_after_load=$(pub_psql -c "SELECT pg_current_wal_lsn();")

wait_for_subscriber "$pub_lsn_after_load"
wait_for_row_count "bench_copy" "$NROWS"
repl_end=$(date +%s%N)

sub_lsn_after=$(sub_psql -c "SELECT pg_current_wal_lsn();")

copy_load_ms=$(( (load_end - load_start) / 1000000 ))
copy_repl_ms=$(( (repl_end - load_end) / 1000000 ))
copy_total_ms=$(( (repl_end - load_start) / 1000000 ))

pub_wal_copy=$(pub_psql -c \
    "SELECT pg_size_pretty('${pub_lsn_after_load}'::pg_lsn - '${pub_lsn_before}'::pg_lsn);")
sub_wal_copy=$(sub_psql -c \
    "SELECT pg_size_pretty('${sub_lsn_after}'::pg_lsn - '${sub_lsn_before}'::pg_lsn);")

pub_size_copy=$(pub_psql -c "SELECT pg_size_pretty(pg_total_relation_size('bench_copy'));")
sub_size_copy=$(sub_psql -c "SELECT pg_size_pretty(pg_total_relation_size('bench_copy'));")

sub_rows_copy=$(sub_psql -c "SELECT count(*) FROM bench_copy;")

echo "  Publisher load time:      ${copy_load_ms} ms"
echo "  Replication apply time:   ${copy_repl_ms} ms"
echo "  Total (load + repl):      ${copy_total_ms} ms"
echo "  Publisher WAL generated:  ${pub_wal_copy}"
echo "  Subscriber WAL generated: ${sub_wal_copy}"
echo "  Publisher table size:     ${pub_size_copy}"
echo "  Subscriber table size:    ${sub_size_copy}"
echo "  Subscriber row count:     ${sub_rows_copy}"
echo ""

# =============================================================================
# 2. INSERT … SELECT on publisher → replicate to subscriber
# =============================================================================
echo "--- 2. INSERT ---"

# Load the same CSV into a staging table (temp tables don't survive between sessions)
pub_psql -c "CREATE UNLOGGED TABLE _src_staging (LIKE bench_insert INCLUDING ALL);"
pub_psql -c "COPY _src_staging (id, val, payload, ts)
             FROM '/tmp/bench_src_data.csv' WITH (FORMAT csv);"

pub_psql -c "CHECKPOINT;"
sub_psql -c "CHECKPOINT;"

pub_lsn_before=$(pub_psql -c "SELECT pg_current_wal_lsn();")
sub_lsn_before=$(sub_psql -c "SELECT pg_current_wal_lsn();")

load_start=$(date +%s%N)
pub_psql -c "INSERT INTO bench_insert (id, val, payload, ts)
             SELECT id, val, payload, ts FROM _src_staging;"
load_end=$(date +%s%N)

pub_lsn_after_load=$(pub_psql -c "SELECT pg_current_wal_lsn();")

wait_for_subscriber "$pub_lsn_after_load"
wait_for_row_count "bench_insert" "$NROWS"
repl_end=$(date +%s%N)

sub_lsn_after=$(sub_psql -c "SELECT pg_current_wal_lsn();")

ins_load_ms=$(( (load_end - load_start) / 1000000 ))
ins_repl_ms=$(( (repl_end - load_end) / 1000000 ))
ins_total_ms=$(( (repl_end - load_start) / 1000000 ))

pub_wal_insert=$(pub_psql -c \
    "SELECT pg_size_pretty('${pub_lsn_after_load}'::pg_lsn - '${pub_lsn_before}'::pg_lsn);")
sub_wal_insert=$(sub_psql -c \
    "SELECT pg_size_pretty('${sub_lsn_after}'::pg_lsn - '${sub_lsn_before}'::pg_lsn);")

pub_size_insert=$(pub_psql -c "SELECT pg_size_pretty(pg_total_relation_size('bench_insert'));")
sub_size_insert=$(sub_psql -c "SELECT pg_size_pretty(pg_total_relation_size('bench_insert'));")

sub_rows_insert=$(sub_psql -c "SELECT count(*) FROM bench_insert;")

echo "  Publisher load time:      ${ins_load_ms} ms"
echo "  Replication apply time:   ${ins_repl_ms} ms"
echo "  Total (load + repl):      ${ins_total_ms} ms"
echo "  Publisher WAL generated:  ${pub_wal_insert}"
echo "  Subscriber WAL generated: ${sub_wal_insert}"
echo "  Publisher table size:     ${pub_size_insert}"
echo "  Subscriber table size:    ${sub_size_insert}"
echo "  Subscriber row count:     ${sub_rows_insert}"
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "========================================="
echo "               SUMMARY"
echo "========================================="
printf "%-28s %12s %12s\n"   ""                      "COPY"              "INSERT"
printf "%-28s %12s %12s\n"   "---"                   "----"              "------"
printf "%-28s %12s %12s\n"   "Publisher load (ms)"    "${copy_load_ms}"  "${ins_load_ms}"
printf "%-28s %12s %12s\n"   "Replication apply (ms)" "${copy_repl_ms}" "${ins_repl_ms}"
printf "%-28s %12s %12s\n"   "Total (ms)"             "${copy_total_ms}" "${ins_total_ms}"
printf "%-28s %12s %12s\n"   "Publisher WAL"          "$pub_wal_copy"    "$pub_wal_insert"
printf "%-28s %12s %12s\n"   "Subscriber WAL"         "$sub_wal_copy"    "$sub_wal_insert"
printf "%-28s %12s %12s\n"   "Publisher table size"   "$pub_size_copy"   "$pub_size_insert"
printf "%-28s %12s %12s\n"   "Subscriber table size"  "$sub_size_copy"   "$sub_size_insert"
printf "%-28s %12s %12s\n"   "Subscriber rows"        "$sub_rows_copy"   "$sub_rows_insert"
echo ""

# ── teardown ──────────────────────────────────────────────────────────────────
if [[ "$SKIP_TEARDOWN" == false ]]; then
    echo "Cleaning up..."
    pub_psql -c "DROP TABLE IF EXISTS bench_copy, bench_insert, _src_staging CASCADE;"
    sub_psql -c "DROP TABLE IF EXISTS bench_copy, bench_insert CASCADE;"
    rm -f /tmp/bench_src_data.csv
    echo "Done."
else
    echo "Skipping teardown (--skip-teardown). Clean up manually."
fi

#!/bin/bash
# Restore cherkizovo into the dec128 cluster on the Tantor 1C stand.
#
# Target is deliberately the experimental build and its own data directory:
#   binaries /opt/pgdev/1C_18_1-decimal128/bin   (numeric as packed dec128)
#   PGDATA   /var/lib/pgdev/1C_18_1-decimal128/data
#   port     5433
# The on-disk format differs from every other cluster on this host, so this must
# never be pointed at /var/lib/pgdev/1C_18_1/data.
#
# Source is cherkiz_18.sql, the same file the 1C_18_1 baseline cluster was loaded
# from -- a different dump would make the A/B comparison meaningless. Its header
# has no CREATE DATABASE and no \connect, so the target database is created here
# and named on the command line; getting that wrong loads 277 GB into `postgres`
# with a clean log.
set -uo pipefail

PREFIX=/opt/pgdev/1C_18_1-decimal128
BIN=$PREFIX/bin
SERVICE=pgdev-dec128.service
PORT=5433
TARGET=cherkizovo
DUMP=/1C_dumps_new/cherkiz_18.sql
LOGDIR=$HOME/pgdev/logs

PSQL="sudo -u postgres $BIN/psql -p $PORT -X -q"

say() { echo "==> $*"; }
die() { echo "!!! $*" >&2; exit 1; }

[ -r "$DUMP" ] || die "dump not readable: $DUMP"
systemctl is-active --quiet "$SERVICE" || die "$SERVICE is not running"

say "source: $DUMP ($(stat -c %s "$DUMP" | awk '{printf "%.0f GiB", $1/2^30}'))"
say "target: $TARGET on port $PORT, build $($BIN/postgres --version)"
say "numeric width in this build: $($PSQL -d postgres -Atc 'select pg_column_size(1.5::numeric)') bytes"
say "free space: $(df -h / | awk 'NR==2{print $4}')"

# ---------------------------------------------------------------- fresh target
$PSQL -d postgres -c "drop database if exists schema_probe" > /dev/null
$PSQL -d postgres -c "drop database if exists $TARGET" > /dev/null
$PSQL -d postgres -c "create database $TARGET" || die "could not create $TARGET"

# --------------------------------------------------------------- speed levers
# The database is disposable: a crash means reloading either way, so durability
# buys nothing here. maintenance_work_mem is the big one -- the tail of a plain
# SQL dump is nothing but CREATE INDEX, and at the 64 MB default every index on
# a large register becomes an external merge sort.
say "applying load-time settings"
$PSQL -d postgres -c "alter system set fsync = off"
$PSQL -d postgres -c "alter system set full_page_writes = off"
$PSQL -d postgres -c "alter system set wal_compression = off"
$PSQL -d postgres -c "alter system set maintenance_work_mem = '4GB'"
$PSQL -d postgres -c "alter system set max_parallel_maintenance_workers = 4"
sudo systemctl restart "$SERVICE" || die "restart failed"
sleep 5
$PSQL -d postgres -Atc "select name || ' = ' || setting from pg_settings
	where name in ('fsync','full_page_writes','wal_compression',
	               'maintenance_work_mem','max_parallel_maintenance_workers',
	               'wal_level','max_wal_senders') order by name"

# ---------------------------------------------------------------------- load
# ON_ERROR_STOP stays off: a 1C dump can trip on a comment for a missing object,
# and the remaining hundreds of GB should still load. The errors are counted at
# the end instead.
say "loading (hours) -- started $(date -Is)"
T0=$(date +%s)
sudo -u postgres $BIN/psql -p $PORT --dbname=$TARGET -X -f "$DUMP" \
	> $LOGDIR/cherkiz-dec128-psql.log 2>&1
T1=$(date +%s)
say "load finished in $(( (T1-T0)/3600 ))h $(( ((T1-T0)%3600)/60 ))m"

# ------------------------------------------------------------------- revert
# Reset before anything is measured: Tantor runs with fsync on and
# maintenance_work_mem at the 64 MB default, and leaving these in place would be
# an unexplained difference in any later comparison.
say "reverting load-time settings"
for g in fsync full_page_writes wal_compression maintenance_work_mem \
         max_parallel_maintenance_workers; do
	$PSQL -d postgres -c "alter system reset $g"
done
sudo systemctl restart "$SERVICE" || die "restart after revert failed"
sleep 5

# --------------------------------------------------------------------- guard
SZ=$($PSQL -d postgres -Atc "select coalesce((select pg_database_size(oid)
	from pg_database where datname='$TARGET'),0)")
if [ "${SZ:-0}" -lt 1073741824 ]; then
	say "target is only $SZ bytes -- the data went somewhere else"
	$PSQL -d postgres -c "select datname, pg_size_pretty(pg_database_size(datname))
		from pg_database order by pg_database_size(datname) desc limit 5"
	die "refusing to report success"
fi

# ------------------------------------------------------------------- analyze
say "analyze"
T2=$(date +%s)
sudo -u postgres $BIN/vacuumdb --analyze -j 4 -p $PORT $TARGET \
	> $LOGDIR/cherkiz-dec128-analyze.log 2>&1
T3=$(date +%s)
say "analyze took $(( (T3-T2)/60 ))m $(( (T3-T2)%60 ))s"

# -------------------------------------------------------------------- verify
say "result"
$PSQL -d postgres -c "select datname, pg_size_pretty(pg_database_size(datname))
	from pg_database where datistemplate = false
	order by pg_database_size(datname) desc"
$PSQL -d $TARGET -c "select relkind::text, count(*) from pg_class c
	join pg_namespace n on n.oid = c.relnamespace
	where n.nspname = 'public' group by 1 order by 1"
$PSQL -d $TARGET -c "select extname, extversion from pg_extension order by 1"
$PSQL -d $TARGET -c "select datname, datcollate, datcollversion,
	pg_database_collation_actual_version(oid) from pg_database
	where datname = '$TARGET'"
$PSQL -d $TARGET -Atc "select 'numeric cols: ' || count(*)
	|| ' | max scale: ' || max(numeric_scale)
	|| ' | max precision: ' || max(numeric_precision)
	|| ' | scale > 15: ' || count(*) filter (where numeric_scale > 15)
	from information_schema.columns where data_type = 'numeric'"

say "errors in the load log: $(grep -c '^ERROR:' $LOGDIR/cherkiz-dec128-psql.log)"
say "free space: $(df -h / | awk 'NR==2{print $4}')"
say DONE

#!/bin/bash
ulimit -c unlimited

INSTDIR=`pwd`/tmp_install
export LD_LIBRARY_PATH=$INSTDIR/lib:$LD_LIBRARY_PATH
export PATH=$INSTDIR/bin:$PATH

if [[ -z "${PGPORT}" ]]; then
  export PGPORT1=5432
  export PGPORT2=5433
  echo "Set PGPORT to default value 5432"
else
  PGPORT1=$PGPORT
  PGPORT2=$((PGPORT1 + 1))
  echo "PGPORT $PGPORT1 $PGPORT2"
  export PGPORT=$PGPORT1
fi

M1=`pwd`/pgdata_publisher
M2=`pwd`/pgdata_subscriber
U=`whoami`

export PGUSER=$U
export PGDATABASE=$U

pg_ctl -w -D $M1 -o "-p $PGPORT1" stop
pg_ctl -w -D $M2 -o "-p $PGPORT2" stop

# Kill all processes
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
    pkill -U `whoami` -9 -e postgres
	pkill -U `whoami` -9 -e pgbench
	pkill -U `whoami` -9 -e psql
elif [[ "$OSTYPE" == "darwin"* ]]; then
    killall -u `whoami` -vz -9 postgres
    killall -u `whoami` -vz -9 pgbench
    killall -u `whoami` -vz -9 psql
	ipcs -om | awk 'NR>3 && $7==0 {print $2}' | xargs -I {} ipcrm -m {} 2>/dev/null
else
    echo "Unintended OS."
fi

mk

sleep 1

rm -rf $M1 || true && rm -rf publisher.log || true && mkdir $M1
rm -rf $M2 || true && rm -rf subscriber.log || true && mkdir $M2

#export LC_ALL=C
export LC_ALL=en_US.UTF-8
initdb -D $M1 -U $U --locale=en_US.UTF-8
initdb -D $M2 -U $U --locale=en_US.UTF-8

echo "
wal_level = 'logical'
track_commit_timestamp = 'on'
autovacuum = off                   # Disable during benchmarks!
log_statement = 'none'
log_duration = off
log_checkpoints = off
checkpoint_timeout = 1h            # Delay checkpoints during benchmark
max_wal_size = 20GB
#log_min_messages = 'debug1'
#log_min_error_statement = 'debug1'
" >> $M1/postgresql.conf

echo "
wal_level = 'logical'
track_commit_timestamp = 'on'
autovacuum = off                   # Disable during benchmarks!
log_statement = 'none'
log_duration = off
log_checkpoints = off
checkpoint_timeout = 1h            # Delay checkpoints during benchmark
max_wal_size = 20GB
#log_min_messages = 'debug1'
#log_min_error_statement = 'debug1'
" >> $M2/postgresql.conf

#
# Engage !
#
pg_ctl -w -D $M1 -o "-p $PGPORT1" -l publisher.log start
pg_ctl -w -D $M2 -o "-p $PGPORT2" -l subscriber.log start
createdb -p $PGPORT1
createdb -p $PGPORT2

psql -p $PGPORT1 -c "
CREATE TABLE bench_copy (id bigint, val double precision, payload text, ts timestamptz);
CREATE TABLE bench_insert (LIKE bench_copy INCLUDING ALL);
"
psql -p $PGPORT2 -c "
CREATE TABLE bench_copy (id bigint, val double precision, payload text, ts timestamptz);
CREATE TABLE bench_insert (LIKE bench_copy INCLUDING ALL);
"
psql -p $PGPORT1 -c "CREATE PUBLICATION bench_pub FOR ALL TABLES"
psql -p $PGPORT2 -c "CREATE SUBSCRIPTION bench_sub CONNECTION 'port=$PGPORT1 dbname=$U' PUBLICATION bench_pub WITH (streaming = false, multi_insert = true)"
#psql -p $PGPORT2 -c "CREATE SUBSCRIPTION bench_sub CONNECTION 'port=$PGPORT1 dbname=$U' PUBLICATION bench_pub WITH (multi_insert = true)"

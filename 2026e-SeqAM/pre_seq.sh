#!/bin/bash
ulimit -c unlimited

sudo pmset -c sleep 0 displaysleep 0 disksleep 0 powernap 0
sudo mdutil -a -i off   # disable Spotlight indexing during test
caffeinate -i -s &
CAFF_PID=$!
trap "kill $CAFF_PID 2>/dev/null; sudo mdutil -a -i on" EXIT

INSTDIR=`pwd`/tmp_install
export LD_LIBRARY_PATH=$INSTDIR/lib:$LD_LIBRARY_PATH
export PATH=$INSTDIR/bin:$PATH

if [[ -z "${PGPORT}" ]]; then
  export PGPORT=5432
  echo "Set PGPORT to default value 5432"
else
  PGPORT=$PGPORT
  echo "PGPORT $PGPORT"
  export PGPORT=$PGPORT
fi

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
sleep 1

mk

M=`pwd`/PGDATA
U=`whoami`
export PGUSER=$U

rm -rf $M || true && rm -rf logfile.log || true && mkdir $M

export LC_ALL=en_US.UTF-8
initdb -D $M -U $U --locale=en_US.UTF-8

echo "
autovacuum = off
checkpoint_timeout = 1h
shared_buffers = 1GB
fsync = off
full_page_writes = off
synchronous_commit = off
bgwriter_lru_maxpages = 0
" >> $M/postgresql.conf

#
# Engage !
#
pg_ctl -w -D $M -l logfile.log start
createdb

psql > out.txt <<EOF
  \o waste.txt
	
  DROP SEQUENCE IF EXISTS abc;
  -- CREATE UNLOGGED SEQUENCE abc USING seqlocal;
  CREATE UNLOGGED SEQUENCE abc;
  
  -- Warm up
  SELECT count(nextval('abc')) FROM generate_series(1, 1E6) \watch i=0 c=100
  
  \timing on 
  
  \o result.txt
  
  SELECT count(nextval('abc')) FROM generate_series(1, 1E6) \watch i=0 c=100
  SELECT count(nextval('abc')) FROM generate_series(1, 1E1) \watch i=0 c=10000
  
  \o
  
EOF
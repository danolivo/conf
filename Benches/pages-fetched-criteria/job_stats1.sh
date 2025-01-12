# ##############################################################################
#
#
# ##############################################################################

#!/bin/bash
ulimit -c unlimited

# Set PG environment variables for correct access to the DBMS
export PGDATA=PGDATA
export PGPORT=5433
export PGUSER=`whoami`

# Binaries and data dirs
INSTDIR=`pwd`/tmp_install
QUERY_DIR=../jo-bench/queries/

#define environment
export LD_LIBRARY_PATH=$INSTDIR/lib:$LD_LIBRARY_PATH
export PATH=$INSTDIR/bin:$PATH

# Stop instances and clean logs.
pg_ctl -D $PGDATA stop
rm -rf logfile.log

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
else
    echo "Unintended OS."
fi
sleep 1

# Startup defaults
echo "shared_preload_libraries = 'pg_stat_statements'" > $PGDATA/postgresql.conf
echo "max_parallel_workers = 8" >> $PGDATA/postgresql.conf
echo "parallel_setup_cost = 1000." >> $PGDATA/postgresql.conf
echo "parallel_tuple_cost = 0.1" >> $PGDATA/postgresql.conf
echo "min_parallel_table_scan_size = 0" >> $PGDATA/postgresql.conf
echo "min_parallel_index_scan_size = 0" >> $PGDATA/postgresql.conf
echo "default_statistics_target = 1000" >> $PGDATA/postgresql.conf

pg_ctl -w -D $PGDATA -l logfile.log start

# Set default preferences
psql -c "DROP EXTENSION IF EXISTS pg_stat_statements;"

psql -c "ALTER SYSTEM SET max_parallel_workers_per_gather = 2"
psql -c "ALTER SYSTEM SET statement_timeout = 3600000"
psql -c "ALTER SYSTEM SET log_statement = 'none'"
psql -c "ALTER SYSTEM SET from_collapse_limit = 20"
psql -c "ALTER SYSTEM SET join_collapse_limit = 20"

psql -c "ALTER SYSTEM SET pg_stat_statements.track_planning = 'off'"
psql -c "ALTER SYSTEM SET pg_stat_statements.track_utility = false"
psql -c "ALTER SYSTEM SET pg_stat_statements.save = false"
psql -c "ALTER SYSTEM SET pg_stat_statements.track = 'top'" > /dev/null

psql -c "SELECT pg_reload_conf();"
psql -c "CREATE EXTENSION pg_stat_statements;"
psql -c "VACUUM ANALYZE aka_name,aka_title,cast_info,char_name, comp_cast_type,company_name,company_type, complete_cast, info_type, keyword, kind_type, link_type, movie_companies, movie_info, movie_info_idx, movie_keyword, movie_link, name, person_info, role_type, title" > /dev/null

echo "iter | short_file | blocks | exec_time"
echo "iter | short_file | blocks | exec_time" > out.txt

iter=0
for iter in {0..10}
do
  for file in $QUERY_DIR/*.sql
  do
    psql -c "SELECT pg_stat_statements_reset()" > /dev/null
  
    short_file=$(basename "$file")
    echo -n "EXPLAIN (ANALYZE) " > test.sql
    cat $file >> test.sql
    result=$(psql -f test.sql)
	echo -ne "$result" > $iter-$short_file.txt

	result=$(psql -f $file)
    result=$(psql -tc "SELECT shared_blks_hit+shared_blks_read+local_blks_hit+local_blks_read+temp_blks_read AS blocks, total_exec_time AS exec_time
      FROM pg_stat_statements
      WHERE query NOT LIKE '%pg_reload_conf%' AND query NOT LIKE '%pg_stat_statements_reset%'") > /dev/null

    echo -e "$iter\t$short_file\t$result"
	echo -e "$iter\t$short_file\t$result" >> out.txt
  done
  psql -c "VACUUM ANALYZE aka_name,aka_title,cast_info,char_name, comp_cast_type,company_name,company_type, complete_cast, info_type, keyword, kind_type, link_type, movie_companies, movie_info, movie_info_idx, movie_keyword, movie_link, name, person_info, role_type, title" > /dev/null
done

pg_ctl -D $PGDATA stop

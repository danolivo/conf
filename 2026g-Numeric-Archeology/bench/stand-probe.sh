#!/bin/bash
# Pre-flight probe for deploying the dec128 build to the 1C stand.
#
# The one thing that can make the whole deployment pointless: this build rejects
# a declared numeric scale above 15, so if the 1C schemas use wider scales the
# dump will not restore at all.  Check that against the live cluster before
# spending twenty minutes on a build.
set -u

PSQL=/opt/pgdev/1C_18_1-numeric-unpack/bin/psql
Q() { sudo -u postgres "$PSQL" -p 5432 -Atc "$1"; }
QD() { sudo -u postgres "$PSQL" -p 5432 -d "$1" -Atc "$2"; }

echo "=== databases in the live cluster ==="
Q "select datname || '  ' || pg_size_pretty(pg_database_size(datname)) from pg_database where datname not like 'template%' order by pg_database_size(datname) desc"

echo
echo "=== numeric columns: count, max scale, and how many exceed 15 ==="
for db in $(Q "select datname from pg_database where datname not like 'template%' and datname <> 'postgres'"); do
    printf -- '--- %-16s ' "$db"
    QD "$db" "select 'numeric cols: ' || count(*) || ' | max scale: ' || coalesce(max(numeric_scale)::text,'-') || ' | scale>15: ' || count(*) filter (where numeric_scale > 15) from information_schema.columns where data_type = 'numeric'"
done

echo
echo "=== if any exceed 15, which ones (first 10) ==="
for db in $(Q "select datname from pg_database where datname not like 'template%' and datname <> 'postgres'"); do
    n=$(QD "$db" "select count(*) from information_schema.columns where data_type='numeric' and numeric_scale > 15")
    if [ "${n:-0}" -gt 0 ]; then
        echo "--- $db"
        QD "$db" "select '    ' || table_name || '.' || column_name || ' numeric(' || numeric_precision || ',' || numeric_scale || ')' from information_schema.columns where data_type='numeric' and numeric_scale > 15 limit 10"
    fi
done

echo
echo "=== 1C type columns (mchar/mvarchar) -- confirms the fork's contrib is required ==="
for db in $(Q "select datname from pg_database where datname not like 'template%' and datname <> 'postgres'"); do
    printf -- '--- %-16s ' "$db"
    QD "$db" "select 'mvarchar: ' || count(*) filter (where udt_name = 'mvarchar') || ' | mchar: ' || count(*) filter (where udt_name = 'mchar') from information_schema.columns"
done

echo
echo "=== disk headroom (a second cluster needs its own copy of the data) ==="
df -h / | tail -1

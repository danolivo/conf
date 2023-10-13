#!/bin/sh
# You could probably do this fancier and have an array of extensions
# to create, but this is mostly an illustration of what can be done

echo shared_preload_libraries = 'sr_plan' >> /var/lib/postgresql/data/postgresql.conf
echo "compute_query_id = 'on'" >> /var/lib/postgresql/data/postgresql.conf
echo "sr_plan.enable = 'true'" >> /var/lib/postgresql/data/postgresql.conf
echo "sr_plan.auto_freeze = 'off'" >> /var/lib/postgresql/data/postgresql.conf
echo "fsync = 'off'" >> /var/lib/postgresql/data/postgresql.conf

pg_ctl -D /var/lib/postgresql/data/ restart
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<EOF
create extension sr_plan;
EOF

#!/bin/bash
# Enumerate the (precision, scale) pairs that dec128's 15-digit scale ceiling
# would reject, so the cost of widening the scale field can be sized.
set -u
PSQL=/opt/pgdev/1C_18_1-numeric-unpack/bin/psql

for db in erp_v cherkizovo; do
    echo "=== $db ==="
    sudo -u postgres "$PSQL" -p 5432 -d "$db" -Atc "
      select 'numeric(' || numeric_precision || ',' || numeric_scale || ') x ' || count(*)
        from information_schema.columns
       where data_type = 'numeric' and numeric_scale > 15
       group by numeric_precision, numeric_scale
       order by numeric_scale desc, numeric_precision desc"
    sudo -u postgres "$PSQL" -p 5432 -d "$db" -Atc "
      select 'max precision overall: ' || max(numeric_precision)
             || ' | max scale overall: ' || max(numeric_scale)
        from information_schema.columns where data_type = 'numeric'"
    echo
done

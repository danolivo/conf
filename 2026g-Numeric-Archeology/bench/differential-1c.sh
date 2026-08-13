#!/bin/bash
# Differential check of the dec128 numeric representation on real 1C data.
#
# Same dump, same fork, same configuration -- the only difference between the
# two clusters is how numeric is stored. So every aggregate over every numeric
# column must come out bit-identical. This is stronger evidence than any
# synthetic test: these are values a real ERP produced, at scales up to 20, in
# tables of tens of gigabytes.
#
#   port 5432  /opt/pgdev/1C_18_1              classic varlena numeric
#   port 5433  /opt/pgdev/1C_18_1-decimal128   packed 16-byte dec128
set -uo pipefail

BASE_PSQL=/opt/pgdev/1C_18_1/bin/psql
DEC_PSQL=/opt/pgdev/1C_18_1-decimal128/bin/psql
DB=cherkizovo
TOPN=${1:-8}

base() { sudo -u postgres $BASE_PSQL -p 5432 -d "$DB" -X -A -t -q -c "$1"; }
dec()  { sudo -u postgres $DEC_PSQL  -p 5433 -d "$DB" -X -A -t -q -c "$1"; }

# Biggest tables that actually have numeric columns -- chosen on the baseline so
# the choice cannot be biased by the patch.
echo "==> picking the $TOPN largest tables with numeric columns"
TABLES=$(base "
  select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and exists (select 1 from pg_attribute a
                  where a.attrelid = c.oid and a.attnum > 0
                    and not a.attisdropped
                    and a.atttypid = 'numeric'::regtype)
   order by pg_relation_size(c.oid) desc
   limit $TOPN")

fail=0
for t in $TABLES; do
	cols=$(base "
	  select string_agg(quote_ident(attname), ',' order by attnum)
	    from pg_attribute
	   where attrelid = 'public.$t'::regclass and attnum > 0
	     and not attisdropped and atttypid = 'numeric'::regtype")
	[ -z "$cols" ] && continue

	# One query per table: count, and for each numeric column the exact sum,
	# min, max and a count of non-nulls. Sums are the interesting part -- they
	# exercise the int128 accumulator and its promotion path on real values.
	agg=$(base "
	  select string_agg(format('sum(%1\$s)::text, min(%1\$s)::text,
	                            max(%1\$s)::text, count(%1\$s)::text',
	                           quote_ident(attname)), ', ' order by attnum)
	    from pg_attribute
	   where attrelid = 'public.$t'::regclass and attnum > 0
	     and not attisdropped and atttypid = 'numeric'::regtype")

	q="select count(*)::text, $agg from public.$t"
	a=$(base "$q")
	b=$(dec "$q")
	ncols=$(echo "$cols" | tr ',' '\n' | wc -l)
	size=$(base "select pg_size_pretty(pg_relation_size('public.$t'))")

	if [ "$a" = "$b" ]; then
		printf '  %-28s %-9s %2s numeric cols  IDENTICAL\n' "$t" "$size" "$ncols"
	else
		fail=$((fail+1))
		printf '  %-28s %-9s %2s numeric cols  *** DIFFERS ***\n' "$t" "$size" "$ncols"
		echo "    baseline: $a"
		echo "    dec128  : $b"
	fi
done

echo
if [ "$fail" -eq 0 ]; then
	echo "==> all $TOPN tables agree exactly"
else
	echo "==> $fail table(s) disagree"
fi
exit $fail

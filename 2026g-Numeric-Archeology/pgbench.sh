run() { # label, sql
  local best=999999
  for i in 1 2 3; do
    t=$(psql -X -q -At -c "SET jit=off;SET max_parallel_workers_per_gather=0;" -c "\timing on" -c "$2" 2>/dev/null | grep -o 'Time: [0-9.]*' | tail -1 | cut -d' ' -f2)
    best=$(python3 -c "print(min($best,$t))")
  done
  printf "%-34s %9.1f ms\n" "$1" "$best"
}
run "scan only: count(v) numeric"  "SELECT count(v) FROM t_num;"
run "scan only: count(v) money"    "SELECT count(v) FROM t_money;"
run "scan only: count(v) bigint"   "SELECT count(v) FROM t_i8;"
run "scan only: count(v) float8"   "SELECT count(v) FROM t_f8;"
echo
run "sum(v) numeric(18,2)"         "SELECT sum(v) FROM t_num;"
run "sum(v) money"                 "SELECT sum(v) FROM t_money;"
run "sum(v) bigint"                "SELECT sum(v) FROM t_i8;"
run "sum(v) float8"                "SELECT sum(v) FROM t_f8;"
echo
run "sum(v+v+v+v+v+v+v+v) numeric" "SELECT sum(v+v+v+v+v+v+v+v) FROM t_num;"
run "sum(v+v+v+v+v+v+v+v) money"   "SELECT sum(v+v+v+v+v+v+v+v) FROM t_money;"
run "sum(v+v+v+v+v+v+v+v) bigint"  "SELECT sum(v+v+v+v+v+v+v+v) FROM t_i8;"
run "sum(v+v+v+v+v+v+v+v) float8"  "SELECT sum(v+v+v+v+v+v+v+v) FROM t_f8;"
echo
run "sum(v*v) numeric"             "SELECT sum(v*v) FROM t_num;"
run "sum(v*2) money"               "SELECT sum(v*2) FROM t_money;"
run "sum(v*v) bigint"              "SELECT sum(v*v) FROM t_i8;"
run "sum(v*v) float8"              "SELECT sum(v*v) FROM t_f8;"
echo
run "order by v numeric (top-10)"  "SELECT v FROM t_num ORDER BY v LIMIT 10;"
run "order by v money (top-10)"    "SELECT v FROM t_money ORDER BY v LIMIT 10;"
run "order by v bigint (top-10)"   "SELECT v FROM t_i8 ORDER BY v LIMIT 10;"

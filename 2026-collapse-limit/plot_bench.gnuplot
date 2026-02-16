# Gnuplot script: GEQO planning time & memory vs number of joined tables
#
# Usage:  gnuplot plot_bench.gnuplot

set terminal pngcairo size 1000,600 enhanced font "Arial,12"
set output "bench_plot.png"

set title "GEQO Optimizer: Planning Time & Memory vs Number of Tables"
set xlabel "Number of joined tables"

# Dual y-axes
set ylabel  "Planning time (ms)"    textcolor rgb "#0060ad"
set y2label "Allocated memory (kB)" textcolor rgb "#dd181f"

set ytics  nomirror textcolor rgb "#0060ad"
set y2tics nomirror textcolor rgb "#dd181f"

set xtics 32
set grid xtics ytics

set key top left

set style line 1 lc rgb "#0060ad" lw 2 pt 7 ps 1.0
set style line 2 lc rgb "#dd181f" lw 2 pt 5 ps 1.0
set style line 3 lc rgb "#0060ad" lw 1.5 dt 2

# O(n) reference line: passes through (4, 0.403) with slope = 0.403/4
t0 = 4.0
v0 = 0.403
linear(x) = v0 * (x / t0)

plot "bench_data.dat" using 1:2 axes x1y1 with linespoints ls 1 title "Planning time (ms)", \
     linear(x)                  axes x1y1 with lines       ls 3 title "O(n) linear growth", \
     "bench_data.dat" using 1:3 axes x1y2 with steps      ls 2 title "Allocated memory (kB)"

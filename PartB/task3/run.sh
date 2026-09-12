#!/usr/bin/env bash
# Part B Task 3: same 2 MB cache, only the objective changes.
#   delay   pure delay   weights 100:0:0:0:0, Optimize NONE
#   area    pure area    weights 0:0:0:0:100, Optimize NONE
#   ed2     ED^2P        Optimize ED^2 (this is the Task 1 baseline)
#   area20  pure area, with the stock 20% delay-deviation filter left in
# Deviations are relaxed for the two pure-weight runs so the weight alone picks
# the winner; area20 shows what the stock filter does instead.  See findings.md.
set -e
cd "$(dirname "$0")"
mkdir -p obj
mk () {  # name  weights  optimize  deviate
    sed -e "s|^-design objective (weight delay, dynamic power, leakage power, cycle time, area) .*|-design objective (weight delay, dynamic power, leakage power, cycle time, area) $2|" \
        -e "s|^-Optimize ED or ED\^2 (ED, ED\^2, NONE): .*|-Optimize ED or ED^2 (ED, ED^2, NONE): \"$3\"|" \
        -e "s|^-deviate (delay, dynamic power, leakage power, cycle time, area) .*|-deviate (delay, dynamic power, leakage power, cycle time, area) $4|" \
        ../cache.cfg > obj/$1.cfg
}
OPEN="100000:100000:100000:100000:100000"
mk delay  "100:0:0:0:0" "NONE"  "$OPEN"
mk area   "0:0:0:0:100" "NONE"  "$OPEN"
mk ed2    "0:0:0:100:0" "ED^2"  "20:100000:100000:100000:100000"
mk area20 "0:0:0:0:100" "NONE"  "20:100000:100000:100000:100000"
for n in delay ed2 area area20; do
    (cd ../cacti && ./cacti -infile ../task3/obj/$n.cfg) > obj/$n.txt
    printf "%-7s " "$n"
    grep -m1 "Access time (ns)" obj/$n.txt | tr -d "\n"
    grep -m1 "Best Ndwl" obj/$n.txt | tr -d "\n"
    grep -m1 "Best Ndbl" obj/$n.txt
done

#!/usr/bin/env bash
# Part C Task 3: TMR 2:1 -> 3:1, plus a TMR sweep at fixed R_on.
#   sample_tmr3.cell  R_on 4k / R_off 12k  (the task: TMR 100% -> 200%)
#   c_25 / c_80 / c_200  additional TMR sweep points
set -e
cd "$(dirname "$0")"
../nvsim STT_4bank_tmr3.cfg > out_4bank_tmr3.txt
../nvsim STT_cache_tmr3.cfg > out_cache_tmr3.txt
for n in 25 80 200; do
    ../nvsim "c_$n.cfg" > "o_$n.txt"
done
grep -H -m1 "Cache Hit Latency"   out_4bank_tmr3.txt o_25.txt o_80.txt o_200.txt
grep -H -m1 "Cache Write Latency" out_4bank_tmr3.txt o_25.txt o_80.txt o_200.txt

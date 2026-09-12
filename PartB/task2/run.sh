#!/usr/bin/env bash
# Part B Task 2: capacity sweep 256 kB -> 16 MB, everything else fixed.
set -e
cd "$(dirname "$0")"
mkdir -p sweep
for kb in 256 512 1024 2048 4096 8192 16384; do
    sed "s|^-size (bytes) .*|-size (bytes) $((kb*1024))|" ../cache.cfg > sweep/c_$kb.cfg
    (cd ../cacti && ./cacti -infile ../task2/sweep/c_$kb.cfg) > sweep/o_$kb.txt
    printf "%6s kB  " "$kb"; grep -m1 "Access time (ns)" sweep/o_$kb.txt
done
python3 plotB2.py

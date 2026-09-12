#!/usr/bin/env bash
# Part C Task 1: 2 MB STT-MRAM, shipped cell file.
#   STT_cache.cfg  - NVSim free search (prefers 1 bank)
#   STT_4bank.cfg  - banking forced to 2x2 to match Part B's 4 UCA banks
set -e
cd "$(dirname "$0")"
../nvsim STT_cache.cfg > out.txt
../nvsim STT_4bank.cfg > out_4bank.txt
for f in out.txt out_4bank.txt; do
    echo "=== $f"
    grep -A14 "CACHE DESIGN" "$f"
done

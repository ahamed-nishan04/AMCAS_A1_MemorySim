#!/usr/bin/env bash
# Put fresh results where the task directories expect them and remove scratch.
# Safe to run repeatedly; run it after any verification pass.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" >/dev/null
cd "$A1_ROOT"

# ---- Part D: stats belong with their task, traces in traces/
mkdir -p PartD/traces PartD/task1
for f in PartD/real_bfs.stats PartD/real_sssp.stats \
         PartD/t_seq.stats PartD/t_rand.stats PartD/t_mixed.stats; do
    [ -f "$f" ] && mv -f "$f" PartD/task1/
done
for f in PartD/*.ls PartD/*.trace; do
    [ -f "$f" ] && [ "$(basename "$f")" != "handout_example.trace" ] && mv -f "$f" PartD/traces/
done
mv -f PartD/ddr4_fcfs_*.stats        PartD/task2/ 2>/dev/null
mv -f PartD/ddr4_chrabaroco_*.stats  PartD/task3/ 2>/dev/null
mv -f PartD/ddr4_2ch_*.stats         PartD/task4/ 2>/dev/null
rm -rf PartD/cmdtrace PartD/.cfg_*.yaml

# ---- Part E: results into the task directories
if [ -d PartE/m5out ] && [ -n "$(ls -A PartE/m5out 2>/dev/null)" ]; then
    mkdir -p PartE/task1; rm -rf PartE/task1/m5out; mv PartE/m5out PartE/task1/m5out
fi
if [ -d PartE/m5out_timing ] && [ -n "$(ls -A PartE/m5out_timing 2>/dev/null)" ]; then
    mkdir -p PartE/task3; rm -rf PartE/task3/m5out_timing
    mv PartE/m5out_timing PartE/task3/m5out_timing
fi
rmdir PartE/m5out PartE/m5out_timing 2>/dev/null
if [ -d PartE/logs ]; then
    mkdir -p PartE/task1/logs PartE/task3/logs
    mv -f PartE/logs/m5out_timing_*.log PartE/task3/logs/ 2>/dev/null
    mv -f PartE/logs/*.log              PartE/task1/logs/ 2>/dev/null
    rmdir PartE/logs 2>/dev/null
fi
rm -rf PartE/cfgtrees
rm -f  PartE/traces/*/l2miss.csv          # 39 MB, regenerable from the .trc.gz

# ---- stray gem5 output from a bare invocation
[ -d m5out ] && [ -z "$(ls -A m5out 2>/dev/null)" ] && rmdir m5out

echo "tidied. tree size: $(du -sh "$A1_ROOT" | cut -f1)"

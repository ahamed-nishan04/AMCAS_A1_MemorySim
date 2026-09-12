#!/usr/bin/env bash
# Part E Tasks 1 and 3, run in parallel.
#
#   bash PartE/run_parallel.sh            # all 12 runs, JOBS at a time
#   JOBS=6 bash PartE/run_parallel.sh     # limit concurrency
#
# Why this exists: run_parte.sh and run_taskE3.sh set the L2 latency by
# rewriting gem5/configs/common/Caches.py in place, so two runs at different
# latencies cannot be in flight at once -- the second would clobber the first's
# setting mid-run.  gem5 itself is single-threaded, so on a many-core box that
# serialisation is the whole cost.
#
# The fix: there are only two distinct latencies (6 and 12).  Copy gem5's
# configs/ tree once per latency, patch each copy, and point each run at the
# copy it needs.  Nothing is shared and everything can run at once.
#
# Results land directly in the task directories -- task1/m5out/ and
# task3/m5out_timing/ -- which is where the task files and answers/ expect them.
set -uo pipefail   # NOT -e: a failed run must be reported, not abort the sweep
source "$(dirname "${BASH_SOURCE[0]}")/../tools/env.sh"
cd "$A1_ROOT/PartE"

JOBS="${JOBS:-6}"     # gem5 is memory-hungry; 6 concurrent x ~2 GB is sane
[ -x "$GEM5BIN" ] || { echo "missing gem5: $GEM5BIN"; exit 1; }
[ -f "$GRAPH.sg" ] || { echo "missing graphs: run tools/build_tools.sh gapbs"; exit 1; }

# ---------------------------------------------------------------- config trees
CFGROOT="$PWD/cfgtrees"
rm -rf "$CFGROOT"; mkdir -p "$CFGROOT"
for lat in 6 12; do
    cp -r "$GEM5DIR/configs" "$CFGROOT/lat$lat"
    # set_l2_latency.py takes a gem5 dir and expects <dir>/configs/common/Caches.py
    tmp="$CFGROOT/shim$lat"; mkdir -p "$tmp"
    ln -sfn "$CFGROOT/lat$lat" "$tmp/configs"
    python3 set_l2_latency.py "$tmp" "$lat"
done
echo "config trees ready: $CFGROOT/lat6 $CFGROOT/lat12"

# ---------------------------------------------------------------- run matrix
mkdir -p task1/m5out task3/m5out_timing task1/logs task3/logs
PIDS=()
launch () {  # outdir  name  cpu  l2size  lat  kernel  graph
    local base=$1 name=$2 cpu=$3 size=$4 lat=$5 kern=$6 graph=$7
    local se="$CFGROOT/lat$lat/deprecated/example/se.py"
    echo "  queue $base/${name}_${kern}  ($cpu, $size, ${lat}cyc)"
    (
        "$GEM5BIN" --outdir="$base/${name}_${kern}" "$se" \
            --cpu-type="$cpu" --caches --l2cache \
            --l1d_size=32kB --l1i_size=32kB \
            --l2_size="$size" --l2_assoc=8 \
            --cpu-clock="$CPUCLOCK" --sys-clock="$CPUCLOCK" \
            --mem-type=DDR4_2400_8x8 --mem-size=4GB \
            --fast-forward="$FF" --maxinsts="$MAXI" \
            --cmd="${GAPBS_RUN:-$GAPBS}/$kern" --options="-f $graph -n 1"
    ) > "$(dirname "$base")/logs/${name}_${kern}.log" 2>&1 &
    PIDS+=($!)
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 5; done
}

echo "launching 12 runs, $JOBS at a time (FF=$FF MAXI=$MAXI)"
for spec in "sram2MB_6 2MB 6" "stt8MB_6 8MB 6" "stt8MB_12 8MB 12"; do
    read -r name size lat <<< "$spec"
    launch task1/m5out        "$name" O3CPU           "$size" "$lat" bfs  "$GRAPH.sg"
    launch task1/m5out        "$name" O3CPU           "$size" "$lat" sssp "$GRAPH.wsg"
    launch task3/m5out_timing "$name" TimingSimpleCPU "$size" "$lat" bfs  "$GRAPH.sg"
    launch task3/m5out_timing "$name" TimingSimpleCPU "$size" "$lat" sssp "$GRAPH.wsg"
done

echo "waiting..."
FAIL=0
for p in "${PIDS[@]}"; do wait "$p" || FAIL=$((FAIL+1)); done
if [ "$FAIL" -gt 0 ]; then
    echo "!! $FAIL of ${#PIDS[@]} run(s) failed. First failing log:"
    for f in task1/logs/*.log task3/logs/*.log; do
        if [ -s "$f" ] && ! grep -q "Exiting @ tick" "$f"; then
            echo "--- $f"; tail -12 "$f" | sed 's/^/    /'; break
        fi
    done
fi

# The fast-forward must land BEFORE the kernel starts.  If it overshoots, the
# kernel runs under AtomicSimpleCPU (which models no caches) and the detailed
# region measures teardown -- gem5 does not warn, and the tell-tale is that
# every cache configuration produces identical results.
BAD=0
for f in task1/logs/*.log task3/logs/*.log; do
    sw=$(grep -n "Switched CPUS" "$f" | head -1 | cut -d: -f1)
    tt=$(grep -n "Trial Time"    "$f" | head -1 | cut -d: -f1)
    if [ -n "$sw" ] && [ -n "$tt" ] && [ "$tt" -lt "$sw" ]; then
        echo "!! OVERSHOOT: $(basename "$f") -- kernel finished before the CPU switch"
        BAD=$((BAD+1))
    fi
done
if [ "$BAD" -gt 0 ]; then
    echo
    echo "!! $BAD run(s) measured teardown, not the kernel. Lower FF (currently $FF)"
    echo "   and re-run. Results below are meaningless for those configs."
    FAIL=$((FAIL+BAD))
fi

echo
echo "=== out-of-order (O3CPU, Task 1) ==="
python3 collect.py task1/m5out/*/stats.txt
echo
echo "=== in-order (TimingSimpleCPU, Task 3) ==="
python3 collect.py task3/m5out_timing/*/stats.txt
echo
rm -rf "$CFGROOT"
echo "Next: bash PartE/gen_l2_trace.sh   # the real Part D trace"
exit "$FAIL"

#!/usr/bin/env bash
# Part E Task 3: same configurations, in-order CPU.
#
#   GEM5BIN=../gem5.sh ./run_taskE3.sh
#
# The task says --cpu-type=TimingSimple; gem5's class is TimingSimpleCPU.
# TimingSimpleCPU is in-order and blocking: one outstanding memory request,
# no MSHRs in flight behind it, no speculation past a miss. Everything else
# is identical to Task 1 so the only variable is the core model.
#
# Runs into m5out_timing/ so the Task 1 results are not overwritten.
set -eu

GEM5BIN=${GEM5BIN:-../gem5.sh}
GEM5DIR=${GEM5DIR:-../gem5}
SE=${SE:-/work/gem5/configs/deprecated/example/se.py}
GAPBS=${GAPBS_RUN:-${GAPBS:-/work/gapbs}}
GRAPH=${GRAPH:-/work/gapbs/graphs/g18}

FF=${FF:-5000000}
MAXI=${MAXI:-150000000}
CPUCLOCK=${CPUCLOCK:-2GHz}

[ -x "$GEM5BIN" ] || { echo "missing gem5 binary/wrapper: $GEM5BIN"; exit 1; }
[ -f "$GEM5DIR/configs/common/Caches.py" ] || { echo "missing gem5 dir: $GEM5DIR"; exit 1; }

run () {  # name  l2_size  l2_latency  kernel  graphfile
    local name=$1 size=$2 lat=$3 kern=$4 graph=$5
    python3 set_l2_latency.py "$GEM5DIR" "$lat"
    "$GEM5BIN" --outdir="m5out_timing/${name}_${kern}" "$SE" \
        --cpu-type=TimingSimpleCPU --caches --l2cache \
        --l1d_size=32kB --l1i_size=32kB \
        --l2_size="$size" --l2_assoc=8 \
        --cpu-clock="$CPUCLOCK" --sys-clock="$CPUCLOCK" \
        --mem-type=DDR4_2400_8x8 --mem-size=4GB \
        --fast-forward="$FF" --maxinsts="$MAXI" \
        --cmd="$GAPBS/$kern" --options="-f $graph -n 1"
}

run sram2MB_6   2MB  6  bfs  "$GRAPH.sg"
run stt8MB_6    8MB  6  bfs  "$GRAPH.sg"
run stt8MB_12   8MB 12  bfs  "$GRAPH.sg"
run sram2MB_6   2MB  6  sssp "$GRAPH.wsg"
run stt8MB_6    8MB  6  sssp "$GRAPH.wsg"
run stt8MB_12   8MB 12  sssp "$GRAPH.wsg"

echo
echo "=== in-order (TimingSimpleCPU) ==="
python3 collect.py m5out_timing/*/stats.txt
echo
echo "=== out-of-order (O3CPU, Task 1) ==="
python3 collect.py m5out/*/stats.txt

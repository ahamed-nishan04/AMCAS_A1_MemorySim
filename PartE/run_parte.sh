#!/usr/bin/env bash
# Part E Task 1: three L2 configurations x two GAPBS kernels.
#
#   GEM5BIN=../gem5.sh ./run_parte.sh
#
# Config A  SRAM  2 MB  @  6 cycles   (CACTI  2.902 ns @ 2 GHz)
# Config B  STT   8 MB  @  6 cycles   (NVSim  2.967 ns @ 2 GHz, iso-area)
# Config C  STT   8 MB  @ 12 cycles   (handout's "2x slower hits" assumption)
#
# Two things this script does that the handout's command line does not:
#
#  * --fast-forward, not --warmup-insts.  se.py reads warmup_insts only inside
#    the --standard-switch path (Simulation.py:631), so it is silently ignored
#    otherwise.  --fast-forward=N runs AtomicSimpleCPU for N instructions and
#    then switches to O3CPU (Simulation.py:744) -- the atomic warm-up the
#    handout asks for.  Because the detailed CPU is then switch_cpus, IPC lands
#    in system.switch_cpus.ipc, which collect.py already looks for.
#
#  * -f <pre-built graph>, not -g <scale>.  With -g, the simulated region is
#    dominated by the Kronecker generator: a streaming phase with no reuse, in
#    which L2 capacity makes no difference at all.  Build the graphs once on the
#    host and load them instead:
#       make -C ../gapbs CXX_FLAGS="-std=c++11 -O3 -static" PAR_FLAG="" converter
#       mkdir -p ../gapbs/graphs
#       ../gapbs/converter -g 18    -b ../gapbs/graphs/g18.sg
#       ../gapbs/converter -g 18 -w -b ../gapbs/graphs/g18.wsg
set -eu

GEM5BIN=${GEM5BIN:-../gem5.sh}                                # host binary or container wrapper
GEM5DIR=${GEM5DIR:-../gem5}                                   # host path, for set_l2_latency.py
SE=${SE:-/work/gem5/configs/deprecated/example/se.py}         # path as gem5 sees it
GAPBS=${GAPBS_RUN:-${GAPBS:-/work/gapbs}}                                   # path as gem5 sees it
GRAPH=${GRAPH:-/work/gapbs/graphs/g18}                        # without .sg / .wsg suffix

# NOTE: these defaults were 100000000 / 200000000, but the results in task1/m5out
# were produced with 5000000 / 5000000 (see config.ini: max_insts_any_thread).
# They are set to the values that actually generated the committed stats so the
# script reproduces them.  Raising them is the right move for a final run -- the
# assignment asks for tens of millions of warm-up accesses -- but the numbers in
# task1.md will then change.  See findings.md.
FF=${FF:-5000000}            # atomic warm-up instructions
MAXI=${MAXI:-5000000}        # detailed instructions after the switch
CPUCLOCK=${CPUCLOCK:-2GHz}

[ -x "$GEM5BIN" ] || { echo "missing gem5 binary/wrapper: $GEM5BIN"; exit 1; }
[ -f "$GEM5DIR/configs/common/Caches.py" ] || { echo "missing gem5 dir: $GEM5DIR"; exit 1; }

run () {  # name  l2_size  l2_latency  kernel  graphfile
    local name=$1 size=$2 lat=$3 kern=$4 graph=$5
    python3 set_l2_latency.py "$GEM5DIR" "$lat"
    "$GEM5BIN" --outdir="m5out/${name}_${kern}" "$SE" \
        --cpu-type=O3CPU --caches --l2cache \
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

python3 collect.py m5out/*/stats.txt

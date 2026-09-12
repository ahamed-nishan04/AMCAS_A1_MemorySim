#!/usr/bin/env bash
# Generate the real l2miss trace from gem5's CommMonitor on the L2 memory-side
# port, and install it into PartD as a Ramulator LoadStoreTrace.
#
#   bash PartE/gen_l2_trace.sh [kernel ...]     # default: bfs sssp
#
# This is the thing Part D was missing: the committed Part D numbers came from
# synthetic streams, and the assignment asks for this stream instead.
#
# The trace is taken from the SRAM 2 MB / 6 cycle baseline (config A), because
# that is the configuration whose miss stream Part D's central question is
# about -- "does the changed miss traffic still fit in one DDR4 channel" is
# asked of the cache we are considering replacing.  Pass CONFIG=stt8MB_6 to
# take the STT-MRAM stream instead and compare the two.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../tools/env.sh"
cd "$A1_ROOT/PartE"

KERNELS=("$@"); [ ${#KERNELS[@]} -eq 0 ] && KERNELS=(bfs sssp)
CONFIG="${CONFIG:-sram2MB_6}"
case "$CONFIG" in
    sram2MB_6) L2SIZE=2MB; L2LAT=6  ;;
    stt8MB_6)  L2SIZE=8MB; L2LAT=6  ;;
    stt8MB_12) L2SIZE=8MB; L2LAT=12 ;;
    *) echo "unknown CONFIG=$CONFIG"; exit 1 ;;
esac

[ -x "$GEM5BIN" ] || { echo "missing gem5: $GEM5BIN  (run tools/build_tools.sh gem5)"; exit 1; }

# gem5 generates its protobuf Python bindings with the system protoc.  If that
# is older than 3.20 while the installed python `protobuf` package is 4.x or
# newer, decode_packet_trace.py dies with
#   "Descriptors cannot not be created directly"
# Forcing the pure-python implementation makes the mismatch harmless.
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
python3 insert_commmonitor.py "$GEM5DIR"
python3 set_l2_latency.py "$GEM5DIR" "$L2LAT"

mkdir -p traces
for kern in "${KERNELS[@]}"; do
    case "$kern" in
        sssp) graph="$GRAPH.wsg" ;;
        *)    graph="$GRAPH.sg"  ;;
    esac
    out="traces/${CONFIG}_${kern}"
    mkdir -p "$out"

    echo "=============== gem5 + CommMonitor: $CONFIG $kern"
    if [ -s "$out/l2miss.trc.gz" ] && [ "${REUSE_TRACE:-1}" = "1" ]; then
        echo "reusing existing $out/l2miss.trc.gz (REUSE_TRACE=0 to force a re-run)"
    else
    L2_TRACE="$PWD/$out/l2miss.trc.gz" \
    "$GEM5BIN" --outdir="$out/m5out" "$SE" \
        --cpu-type=O3CPU --caches --l2cache \
        --l1d_size=32kB --l1i_size=32kB \
        --l2_size="$L2SIZE" --l2_assoc=8 \
        --cpu-clock="$CPUCLOCK" --sys-clock="$CPUCLOCK" \
        --mem-type=DDR4_2400_8x8 --mem-size=4GB \
        --fast-forward="$FF" --maxinsts="$MAXI" \
        --cmd="${GAPBS_RUN:-$GAPBS}/$kern" --options="-f $graph -n 1" \
        2>&1 | tee "$out/gem5.log"

    fi

    log="$out/m5out/simout.txt"
    [ -f "$log" ] || log="$out/gem5.log"

    # The fast-forward must land BEFORE the kernel, or the trace is teardown.
    if [ -f "$log" ] && grep -q "Trial Time" "$log"; then
        sw=$(grep -n "Switched CPUS" "$log" | head -1 | cut -d: -f1)
        tt=$(grep -n "Trial Time"    "$log" | head -1 | cut -d: -f1)
        if [ -n "$sw" ] && [ -n "$tt" ] && [ "$tt" -lt "$sw" ]; then
            echo "!! FF=$FF overshot the $kern kernel -- the kernel finished before"
            echo "   the detailed CPU engaged, so this trace is teardown, not work."
            echo "   Lower FF and re-run."
            exit 1
        fi
    fi

    # Exclude the atomic warm-up: only packets after the CPU switch are part
    # of the measured region.
    SWTICK=$(grep -o "Switched CPUS @ tick [0-9]*" "$log" 2>/dev/null | grep -o "[0-9]*$" | head -1)
    SWTICK=${SWTICK:-0}
    echo "--- decoding (skipping warm-up before tick $SWTICK)"

    # gem5's own decoder handles the protobuf; we only reinterpret its CSV.
    python3 "$GEM5DIR/util/decode_packet_trace.py" \
        "$out/l2miss.trc.gz" "$out/l2miss.csv" > /dev/null

    echo "--- requestor mix (requestor 0 = evictions, everything else = fills)"
    python3 decode_l2_trace.py "$out/l2miss.csv" \
        --histogram --skip-ticks "$SWTICK"

    # The L2 puts EVERY eviction on its memory-side port, but only the dirty
    # ones become DRAM writes; clean evictions are coherence notifications the
    # controller drops, and the trace cannot tell them apart.  Take the true
    # DRAM write count from this run's own stats and subsample to match.
    STATS="$out/m5out/stats.txt"
    WTARGET=$(awk '/^system\.l2\.writebacks::total/ {print $2; exit}' "$STATS")
    WTARGET=${WTARGET:-0}
    echo "--- ground truth from stats.txt"
    grep -E "^system\.(l2\.overallMisses::total|l2\.writebacks::total|mem_ctrls\.readReqs|mem_ctrls\.writeReqs)" \
        "$STATS" || true

    python3 decode_l2_trace.py "$out/l2miss.csv" "$out/l2miss.trace" \
        --skip-ticks "$SWTICK" --write-target "$WTARGET" --max "$TRACE_ACCESSES"
    # Write straight into PartD/traces/, which is where verify_all.sh and
    # run.sh look.  (Writing to the PartD root instead made verify_all fall
    # back to the synthetic brackets unless tidy.sh happened to run first.)
    mkdir -p "$A1_ROOT/PartD/traces"
    python3 "$A1_ROOT/PartD/to_ramulator.py" \
        "$out/l2miss.trace" "$A1_ROOT/PartD/traces/real_${kern}.ls"
done

echo
echo "=============== installed into PartD:"
ls -la "$A1_ROOT/PartD/traces"/real_*.ls
echo
echo "Run them with:   bash verify_all.sh D"

#!/usr/bin/env bash
# Run and verify every task in every part.
#
#   bash verify_all.sh              # everything
#   bash verify_all.sh A B C        # no external tools beyond cacti/nvsim
#   bash verify_all.sh D            # Ramulator (needs PartD/ramulator2)
#   bash verify_all.sh E            # gem5 (needs gem5/ and gapbs/)
#
# Part E runs BEFORE Part D, because Part D's trace is generated out of it.
# Logs go to verify_logs/<step>.log, with a pass/fail summary at the end.
#
# Defaults live in tools/env.sh. FF=10000000 MAXI=20000000 are the values that
# place the CPU switch correctly for BOTH kernels -- do not raise FF without
# re-checking (see PartE/findings.md).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/tools/env.sh"

PARTS=("$@"); [ ${#PARTS[@]} -eq 0 ] && PARTS=(A B C D E)
has () { for p in "${PARTS[@]}"; do [ "$p" = "$1" ] && return 0; done; return 1; }

LOGS="$A1_ROOT/verify_logs"; mkdir -p "$LOGS"
RESULTS=()
step () {
    local name=$1; shift
    echo "───────────────────────────── $name"
    if "$@" >"$LOGS/$name.log" 2>&1; then
        RESULTS+=("PASS  $name"); echo "PASS   (log: verify_logs/$name.log)"
    else
        RESULTS+=("FAIL  $name"); echo "FAIL   (log: verify_logs/$name.log)"
        tail -15 "$LOGS/$name.log" | sed 's/^/       /'
    fi
}

# ============================================================== A — ngspice
if has A; then
command -v ngspice >/dev/null || { echo "!! ngspice not found"; exit 1; }
python3 -c "import numpy, matplotlib" 2>/dev/null || {
    echo "!! numpy/matplotlib missing:  pip install numpy matplotlib"; exit 1; }
step PartA bash -c "cd '$A1_ROOT/PartA' && bash run.sh"
fi

# ================================================================ B — CACTI
if has B; then
[ -x "$A1_ROOT/PartB/cacti/cacti" ] || {
    echo "!! build CACTI:  bash tools/build_tools.sh cacti"; exit 1; }
for t in 1 2 3 4; do step "PartB_task$t" bash "$A1_ROOT/PartB/task$t/run.sh"; done
fi

# ================================================================ C — NVSim
if has C; then
[ -x "$A1_ROOT/PartC/nvsim" ] || {
    echo "!! build NVSim:  bash tools/build_tools.sh nvsim"; exit 1; }
for t in 1 3 4; do step "PartC_task$t" bash "$A1_ROOT/PartC/task$t/run.sh"; done
RESULTS+=("n/a   PartC_task2 (analysis of Task 1 output, nothing to execute)")
fi

# ================================================================= E — gem5
if has E; then
[ -x "$GEM5BIN" ] || { echo "!! build gem5:  bash tools/build_tools.sh gem5"; exit 1; }
# gem5 embeds the Python interpreter it was built against, so a
# container-built binary only runs inside that container.  Probe by running it
# with no arguments: gem5 prints usage and exits non-zero either way, so the
# exit code says nothing -- what matters is whether the dynamic loader could
# start it at all.
_probe=$("$GEM5BIN" 2>&1 | head -5)
if printf '%s' "$_probe" | grep -q "error while loading shared libraries"; then
    echo "!! $GEM5BIN cannot start on this host:"
    printf '%s\n' "$_probe" | sed 's/^/     /'
    echo
    echo "   gem5 links libpythonX.Y.so, so a container-built binary only runs"
    echo "   inside the container. Run Part E where gem5 lives:"
    echo "       bash tools/container.sh verify E"
    echo "   Part D stays on the host -- ramulator2 is host-built."
    echo "   To build gem5 natively instead (needs gcc <= 14.2):"
    echo "       rm -rf gem5/build && bash tools/build_tools.sh gem5"
    exit 1
fi

echo "Part E at FF=$FF MAXI=$MAXI, JOBS=${JOBS:-6} in parallel (PARALLEL=0 to disable)."
if [ "${PARALLEL:-1}" = "1" ]; then
    step PartE_tasks1and3 bash -c "cd '$A1_ROOT/PartE' && bash run_parallel.sh"
else
    step PartE_task1_O3      bash -c "cd '$A1_ROOT/PartE' && bash run_parte.sh"
    step PartE_task3_inorder bash -c "cd '$A1_ROOT/PartE' && bash run_taskE3.sh"
fi
step PartE_trace bash -c "cd '$A1_ROOT/PartE' && bash gen_l2_trace.sh"
fi

# ============================================================ D — Ramulator
if has D; then
[ -x "$A1_ROOT/PartD/ramulator2" ] && [ -f "$A1_ROOT/PartD/libramulator.so" ] || {
    echo "!! Ramulator not ready.  PartD needs both ramulator2 and"
    echo "   libramulator.so next to it:  bash tools/build_tools.sh ramulator"
    exit 1; }
cd "$A1_ROOT/PartD"

# Prefer the real CommMonitor traces; fall back to the synthetic brackets.
if [ -s traces/real_bfs.ls ] && [ -s traces/real_sssp.ls ]; then
    TRACES="traces/real_bfs.ls traces/real_sssp.ls"
    echo "Using the real gem5 CommMonitor traces."
elif [ "${ALLOW_SYNTHETIC:-0}" = "1" ]; then
    echo "!! no real traces -- falling back to the synthetic brackets (ALLOW_SYNTHETIC=1)."
    mkdir -p traces
    for k in seq rand mixed; do
        python3 gen_trace.py $k 100000 traces/t_$k.trace
        python3 to_ramulator.py traces/t_$k.trace traces/t_$k.ls
    done
    TRACES="traces/t_seq.ls traces/t_rand.ls traces/t_mixed.ls"
else
    echo "!! PartD/traces/real_bfs.ls and real_sssp.ls are missing."
    echo "   These are the gem5 CommMonitor stream the assignment asks for, and"
    echo "   the committed Part D results are computed from them. Generate them:"
    echo "       bash tools/container.sh verify E     # or: bash verify_all.sh E"
    echo
    echo "   Refusing to run on the synthetic brackets, because that would"
    echo "   silently overwrite the real results with different numbers."
    echo "   To do it deliberately:  ALLOW_SYNTHETIC=1 bash verify_all.sh D"
    exit 1
fi

step PartD_task1 bash -c "cd '$A1_ROOT/PartD' && ./run.sh $TRACES && \
    python3 stats.py \$(for t in $TRACES; do echo task1/\$(basename \$t .ls).stats; done)"
step PartD_task2 bash -c "cd '$A1_ROOT/PartD' && ./run2.sh task2/ddr4_fcfs.yaml $TRACES && \
    python3 stats2.py task2/ddr4_fcfs_*.stats"
step PartD_task3 bash -c "cd '$A1_ROOT/PartD' && ./run2.sh task3/ddr4_chrabaroco.yaml $TRACES && \
    python3 stats2.py task3/ddr4_chrabaroco_*.stats"
step PartD_task4 bash -c "cd '$A1_ROOT/PartD' && ./run2.sh task4/ddr4_2ch.yaml $TRACES && \
    python3 task4/sweep_timings.py $TRACES"
fi

# ================================================================== summary
echo
echo "═════════════════════════════ summary"
printf '%s\n' "${RESULTS[@]}"
echo
if printf '%s\n' "${RESULTS[@]}" | grep -q '^FAIL'; then
    echo "Some steps failed. Logs are in verify_logs/."
    exit 1
fi
echo "All steps passed. Logs in verify_logs/."
echo "Next:  bash tools/tidy.sh        # file results into the task directories"
echo "       bash tools/sync_answers.sh # refresh the report copies in answers/"

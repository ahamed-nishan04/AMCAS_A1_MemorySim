#!/usr/bin/env bash
# Clean-room rebuild of every result in the repository.
#
#   bash tools/cleanroom.sh                 # gem5 via the container (default)
#   GEM5_MODE=host bash tools/cleanroom.sh  # gem5 natively
#   bash tools/cleanroom.sh --dry-run       # list what would be deleted
#
# What it does, in order:
#   1. archives every current result to cleanroom/before/
#   2. deletes every generated file (keeping inputs and shipped artefacts)
#   3. re-runs Parts E, D, A, B, C from scratch
#   4. extracts the headline numbers and diffs them against the archive
#   5. writes a full transcript to cleanroom/transcript.log
#
# Inputs that are NOT deleted, because they cannot be regenerated here:
#   PartB/task4/bldbg.txt      produced by an instrumented CACTI build
#   PartB/task4/forced.cfg     and the other hand-written configs
#   PartC/task*/*.cell *.cfg   cell files and configs
#   PartD/ddr4*.yaml           DRAM configurations
#   PartE/task1/cap_*.cfg      NVSim capacity-sweep inputs
#   everything under notes/, answers/ is refreshed at the end
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" >/dev/null
cd "$A1_ROOT"

DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
GEM5_MODE="${GEM5_MODE:-container}"
OUT="$A1_ROOT/cleanroom"
LOG="$OUT/transcript.log"
mkdir -p "$OUT/before" "$OUT/after"

say () { echo "$@" | tee -a "$LOG"; }

# ---------------------------------------------------------------- what is generated
generated () {
    # Part A -- csv and figures
    ls PartA/task*/*.csv PartA/task*/*.png 2>/dev/null
    # Part B -- tool output
    ls PartB/task1/cacti_out.txt PartB/task2/sweep/* PartB/task2/*.png \
       PartB/task3/obj/* PartB/task4/forced_cacti_out.txt PartB/cache.cfg.out 2>/dev/null
    # Part C -- nvsim output
    ls PartC/task*/out*.txt PartC/task*/o_*.txt 2>/dev/null
    # Part D -- stats and traces
    ls PartD/task*/*.stats PartD/task4/sens/* PartD/traces/* 2>/dev/null
    # Part E -- simulation output
    find PartE/task1/m5out PartE/task3/m5out_timing PartE/traces \
         PartE/task1/logs PartE/task3/logs -type f 2>/dev/null
}

# ---------------------------------------------------------------- headline extractor
extract () {  # extract <destdir>
    local d=$1; mkdir -p "$d"
    # Part A: the measured values from the run log, plus checksums of the raw
    # ngspice CSVs (figures are excluded -- matplotlib embeds a timestamp).
    { grep -hE "^(dv|dv_s|qmax|qfin|qbfin) +=|^vcross|^r\[[0-9]\] =|SNM =" \
          "$A1_ROOT/verify_logs/PartA.log" 2>/dev/null
      (cd "$A1_ROOT" && md5sum PartA/task*/*.csv 2>/dev/null | sort -k2)
    } > "$d/partA.txt" 2>/dev/null
    grep -hE "Access time \(ns\)|Total leakage power of a bank|Cache height x width" \
        PartB/task1/cacti_out.txt 2>/dev/null > "$d/partB.txt"
    for f in PartB/task2/sweep/o_*.txt PartB/task3/obj/*.txt; do
        [ -f "$f" ] && printf '%s ' "$(basename "$f")" && grep -m1 "Access time (ns)" "$f"
    done >> "$d/partB.txt" 2>/dev/null
    grep -hE "Cache Hit Latency|Cache Write Latency|Total Area|Total Leakage Power" \
        PartC/task1/out_4bank.txt PartC/task4/out_[1-4]00.txt 2>/dev/null > "$d/partC.txt"
    for f in PartD/task*/*.stats; do
        [ -f "$f" ] || continue
        printf '%s ' "$(basename "$f")"
        grep -hE "^  memory_system_cycles|^    row_hits_0" "$f" | tr -d '\n'; echo
    done > "$d/partD.txt" 2>/dev/null
    python3 PartE/collect.py PartE/task1/m5out/*/stats.txt \
        PartE/task3/m5out_timing/*/stats.txt > "$d/partE.txt" 2>/dev/null
    wc -l "$d"/*.txt 2>/dev/null | sed 's/^/    /'
}

# ================================================================= 1. archive
say "=============== 1. archiving current results"
extract "$OUT/before" | tee -a "$LOG"
N=$(generated | wc -l)
say "    $N generated files currently present"

if [ "$DRY" = "1" ]; then
    say; say "--dry-run: these would be deleted"
    generated | sed 's/^/    /' | tee -a "$LOG"
    exit 0
fi

# ================================================================= 2. wipe
say
say "=============== 2. deleting generated files"
generated | while read -r f; do rm -f "$f"; done
rm -rf PartE/task1/m5out PartE/task3/m5out_timing PartE/traces \
       PartE/task1/logs PartE/task3/logs PartE/cfgtrees \
       PartB/task2/sweep PartB/task3/obj PartD/task4/sens PartD/traces
say "    done. remaining generated files: $(generated | wc -l)"

# ================================================================= 3. rebuild
say
say "=============== 3. Part E (gem5) -- $GEM5_MODE"
if [ "$GEM5_MODE" = "container" ]; then
    bash tools/container.sh verify E 2>&1 | tee -a "$LOG"
else
    bash verify_all.sh E 2>&1 | tee -a "$LOG"
fi

say
say "=============== 4. Part D (Ramulator) -- host"
bash verify_all.sh D 2>&1 | tee -a "$LOG"

say
say "=============== 5. Parts A, B, C -- host"
bash verify_all.sh A B C 2>&1 | tee -a "$LOG"

say
say "=============== 6. tidy and sync"
bash tools/tidy.sh 2>&1 | tee -a "$LOG"
bash tools/sync_answers.sh 2>&1 | tee -a "$LOG"

# ================================================================= 7. compare
say
say "=============== 7. comparing against the archive"
extract "$OUT/after" | tee -a "$LOG"
DIFFS=0
for p in A B C D E; do
    b="$OUT/before/part$p.txt"; a="$OUT/after/part$p.txt"
    [ -f "$b" ] && [ -f "$a" ] || { say "    Part $p: nothing to compare"; continue; }
    if diff -q "$b" "$a" >/dev/null; then
        say "    Part $p: IDENTICAL"
    else
        say "    Part $p: DIFFERS"
        diff "$b" "$a" | head -20 | sed 's/^/        /' | tee -a "$LOG"
        DIFFS=$((DIFFS+1))
    fi
done

say
say "═════════════════════════════ clean-room result"
if [ "$DIFFS" -eq 0 ]; then
    say "Every part reproduced identically from scratch."
else
    say "$DIFFS part(s) differ. Inspect cleanroom/before vs cleanroom/after."
    say "Part A may differ in the last digit (ngspice solver noise) -- harmless."
fi
say "Transcript: cleanroom/transcript.log"
say "Archive:    cleanroom/before/  cleanroom/after/"
exit "$DIFFS"

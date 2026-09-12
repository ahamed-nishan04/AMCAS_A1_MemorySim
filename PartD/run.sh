#!/usr/bin/env bash
# run.sh <trace.ls> ...  -> task1/<n>.stats for each
# Traces live in traces/; pass either "real_bfs.ls" or "traces/real_bfs.ls".
set -e
cd "$(dirname "$0")"
# ramulator2 links libramulator.so. build_tools.sh copies both into this
# directory; fall back to the build tree if only the binary is here.
export LD_LIBRARY_PATH="$PWD:${RAMULATOR_DIR:-../tools/ramulator2}:${LD_LIBRARY_PATH:-}"
mkdir -p task1
for t in "$@"; do
    [ -f "$t" ] || t="traces/$t"
    n=$(basename "$t" .ls)
    sed "s|^  path: .*|  path: $t|" ddr4.yaml > .cfg_$n.yaml
    ./ramulator2 -f .cfg_$n.yaml > "task1/$n.stats" 2>&1
    echo "$t -> task1/$n.stats"
done
rm -f .cfg_*.yaml

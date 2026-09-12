#!/usr/bin/env bash
# run2.sh <cfg.yaml> <trace.ls> ... -> <taskdir>/<cfgname>_<tracename>.stats
# The output directory is taken from the config's own location, so
#   ./run2.sh task2/ddr4_fcfs.yaml traces/real_bfs.ls
# writes task2/ddr4_fcfs_real_bfs.stats
set -e
cd "$(dirname "$0")"
# ramulator2 links libramulator.so. build_tools.sh copies both into this
# directory; fall back to the build tree if only the binary is here.
export LD_LIBRARY_PATH="$PWD:${RAMULATOR_DIR:-../tools/ramulator2}:${LD_LIBRARY_PATH:-}"
cfg=$1; shift
c=$(basename "$cfg" .yaml)
outdir=$(dirname "$cfg")
for t in "$@"; do
    [ -f "$t" ] || t="traces/$t"
    n=$(basename "$t" .ls)
    sed "s|^  path: .*|  path: $t|" "$cfg" > .cfg_${c}_$n.yaml
    ./ramulator2 -f .cfg_${c}_$n.yaml > "$outdir/${c}_${n}.stats" 2>&1
    echo "$t -> $outdir/${c}_${n}.stats"
done
rm -f .cfg_*.yaml

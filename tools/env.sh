#!/usr/bin/env bash
# Shared configuration for build_tools.sh and verify_all.sh.
# Source this, don't execute it.  Override any of these in your shell.

# Repository root (the directory containing PartA .. PartE)
export A1_ROOT="${A1_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Where the external tools get cloned/built.  Kept out of the repo by .gitignore.
export TOOLS_DIR="${TOOLS_DIR:-$A1_ROOT/tools}"
export GEM5DIR="${GEM5DIR:-$A1_ROOT/gem5}"
export GAPBS="${GAPBS:-$A1_ROOT/gapbs}"
export RAMULATOR_DIR="${RAMULATOR_DIR:-$TOOLS_DIR/ramulator2}"

# Kronecker graph scale for GAPBS.
export GRAPH_SCALE="${GRAPH_SCALE:-18}"

# gem5 invocation.  Two routes:
#
#   native     GEM5BIN=$GEM5DIR/build/X86/gem5.opt          (default)
#   container  GEM5BIN=$A1_ROOT/gem5.sh
#
# The container route mounts the repository root at /work, so the paths handed
# to gem5 must be the container's view.  Setting GEM5BIN to gem5.sh switches
# them automatically below.
export GEM5BIN="${GEM5BIN:-$GEM5DIR/build/X86/gem5.opt}"

if [ "$(basename "$GEM5BIN")" = "gem5.sh" ]; then
    export SE="${SE:-/work/gem5/configs/deprecated/example/se.py}"
    export GAPBS_RUN="${GAPBS_RUN:-/work/gapbs}"
    export GRAPH="${GRAPH:-/work/gapbs/graphs/g$GRAPH_SCALE}"
    echo "gem5: container route (paths are the container's /work view)"
else
    export SE="${SE:-$GEM5DIR/configs/deprecated/example/se.py}"
    export GAPBS_RUN="${GAPBS_RUN:-$GAPBS}"
    export GRAPH="${GRAPH:-$GAPBS/graphs/g$GRAPH_SCALE}"
fi

# Simulation scale.
#   FF    atomic warm-up instructions before switching to the detailed CPU
#   MAXI  detailed instructions after the switch
# The committed Part E results used 5000000 / 5000000.  The assignment asks for
# "tens of millions" of warm-up accesses, so the verification default raises
# both.  Expect roughly 8-15x the runtime of the committed run per config.
export FF="${FF:-10000000}"
export MAXI="${MAXI:-20000000}"
export CPUCLOCK="${CPUCLOCK:-2GHz}"

# How many L2 accesses to keep from the CommMonitor trace for Part D.
# Ramulator runtime is roughly linear in this.  100000 matches the synthetic
# runs the committed Part D numbers used, which makes the two directly
# comparable; raise it for a more representative stream.
export TRACE_ACCESSES="${TRACE_ACCESSES:-100000}"

export NPROC="${NPROC:-$(nproc)}"

echo "A1_ROOT=$A1_ROOT"
echo "GEM5DIR=$GEM5DIR   GAPBS=$GAPBS   RAMULATOR_DIR=$RAMULATOR_DIR"
echo "FF=$FF  MAXI=$MAXI  TRACE_ACCESSES=$TRACE_ACCESSES  NPROC=$NPROC"

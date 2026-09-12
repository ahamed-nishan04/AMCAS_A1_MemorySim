#!/usr/bin/env bash
# One command to go from `git clone` to runnable.
#
#   bash tools/setup.sh
#
# Installs system packages, clones and builds CACTI, NVSim, Ramulator 2.0a and
# GAPBS, and sets up gem5 — natively if your compiler is supported, otherwise
# in a pinned-toolchain container. Then tells you what to run.
#
# Safe to re-run; every step skips work that is already done.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh" >/dev/null
cd "$A1_ROOT"

ok ()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad ()  { printf '  \033[31m✗\033[0m %s\n' "$1"; }
step () { printf '\n\033[1m%s\033[0m\n' "$1"; }

step "1/5  system packages"
bash tools/build_tools.sh deps || { bad "package install failed"; exit 1; }

step "2/5  CACTI, NVSim, Ramulator, GAPBS"
bash tools/build_tools.sh cacti nvsim ramulator gapbs || {
    bad "a tool failed to build — see the error above"; exit 1; }

step "3/5  gem5"
GEM5_OK=0
if [ -x "$GEM5BIN" ] && ! "$GEM5BIN" 2>&1 | head -3 | grep -q "error while loading"; then
    ok "gem5 already built and runnable"
    GEM5_OK=1
else
    GCCMAJ=$(gcc -dumpversion | cut -d. -f1)
    if [ "$GCCMAJ" -le 14 ]; then
        echo "  gcc $GCCMAJ is within gem5's supported range — building natively."
        bash tools/build_tools.sh gem5 && GEM5_OK=1
    else
        echo "  gcc $GCCMAJ is outside gem5's supported range (11–14.2)."
        echo "  A build with it segfaults inside the O3 CPU partway through a run,"
        echo "  so gem5 goes in the container instead."
        if command -v podman >/dev/null || command -v docker >/dev/null; then
            bash tools/container.sh build && bash tools/container.sh gem5 && GEM5_OK=2
        else
            bad "no podman or docker found. Install one:  sudo dnf install podman"
            bad "then:  bash tools/container.sh build && bash tools/container.sh gem5"
        fi
    fi
fi

step "4/5  checks"
command -v ngspice >/dev/null            && ok "ngspice"            || bad "ngspice missing"
python3 -c "import numpy, matplotlib" 2>/dev/null \
                                          && ok "numpy + matplotlib" || bad "numpy/matplotlib missing"
[ -x PartB/cacti/cacti ]                 && ok "cacti"              || bad "cacti missing"
[ -x PartC/nvsim ]                       && ok "nvsim"              || bad "nvsim missing"
[ -x PartD/ramulator2 ] && [ -f PartD/libramulator.so ] \
                                          && ok "ramulator2"         || bad "ramulator2 missing"
[ -f "$GRAPH.sg" ] && [ -f "$GRAPH.wsg" ] && ok "GAPBS graphs"       || bad "GAPBS graphs missing"
case "$GEM5_OK" in
  1) ok "gem5 (native)" ;;
  2) ok "gem5 (container)" ;;
  *) bad "gem5 not available — Parts A–D still work" ;;
esac

step "5/5  how to run"
cat <<EOT
  Parts A, B, C and D run on the host:

      bash verify_all.sh A B C D

EOT
if [ "$GEM5_OK" = "2" ]; then
cat <<EOT
  gem5 is container-built, so Part E runs there (it embeds the container's
  Python and will not start on the host):

      bash tools/container.sh verify E

EOT
elif [ "$GEM5_OK" = "1" ]; then
cat <<EOT
  Part E runs on the host too:

      bash verify_all.sh E

EOT
fi
cat <<EOT
  Part D's trace is produced by Part E, but both are already committed, so
  Part D reproduces immediately without running Part E first.

  Full rebuild from nothing, with a before/after comparison:

      bash tools/cleanroom.sh --dry-run
      bash tools/cleanroom.sh

  Read README.md for the layout and the known approximations.
EOT

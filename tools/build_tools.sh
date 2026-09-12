#!/usr/bin/env bash
# Clone and build every tool the assignment needs, into this repository.
#
#   bash tools/build_tools.sh            # everything
#   bash tools/build_tools.sh ramulator  # just one
#
# Targets: deps cacti nvsim ramulator gem5 gapbs
#
# gem5 is the long one -- allow 40-60 minutes on a many-core box, much longer
# on one core.  Everything else is a few minutes.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
mkdir -p "$TOOLS_DIR"

want () { [ $# -eq 0 ] && return 0; for t in "$@"; do [ "$t" = "$TARGET" ] && return 0; done; return 1; }
TARGETS=("$@"); [ ${#TARGETS[@]} -eq 0 ] && TARGETS=(deps cacti nvsim ramulator gem5 gapbs)
has () { for t in "${TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done; return 1; }

# ---------------------------------------------------------------- deps
if has deps; then
echo "=============== system packages"
# protobuf is NOT optional: gem5's CommMonitor MemTraceProbe needs it, and
# without it the Part D trace comes back empty.
# The static C/C++ libraries are not optional either: GAPBS is built -static
# because gem5 SE mode has no dynamic loader.  On Debian/Ubuntu they come with
# build-essential; on Fedora they are separate packages.

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

if command -v dnf >/dev/null; then
    echo "--- Fedora / RHEL (dnf)"
    $SUDO dnf install -y \
        gcc gcc-c++ make cmake git m4 scons \
        glibc-static libstdc++-static \
        zlib-devel protobuf-devel protobuf-compiler \
        gperftools-devel boost-devel hdf5-devel \
        libpng-devel elfutils-libelf-devel capstone-devel \
        pkgconf-pkg-config python3-devel python3-pip \
        ngspice
elif command -v apt-get >/dev/null; then
    echo "--- Debian / Ubuntu (apt)"
    $SUDO apt-get update -qq
    $SUDO apt-get install -y \
        build-essential git m4 scons zlib1g-dev \
        libprotobuf-dev protobuf-compiler libprotoc-dev \
        libgoogle-perftools-dev libboost-all-dev libhdf5-serial-dev \
        libpng-dev libelf-dev libcapstone-dev pkg-config \
        python3-dev python3-pip python3-venv \
        cmake ngspice
elif command -v pacman >/dev/null; then
    echo "--- Arch (pacman)"
    $SUDO pacman -S --needed --noconfirm \
        base-devel git m4 scons cmake zlib protobuf gperftools boost hdf5 \
        libpng libelf capstone pkgconf python ngspice
else
    echo "!! no supported package manager found."
    echo "   Install by hand: a C++ toolchain, static libc/libstdc++, scons,"
    echo "   cmake, m4, git, ngspice, and the development headers for"
    echo "   protobuf, zlib, boost, hdf5, libpng, libelf, capstone, gperftools"
    echo "   and python3."
    exit 1
fi

# Python packages go into whatever environment is active.
python3 -m pip install --upgrade numpy matplotlib protobuf || \
python3 -m pip install --user --upgrade numpy matplotlib protobuf || \
python3 -m pip install --break-system-packages --upgrade numpy matplotlib protobuf

# scons sometimes is not packaged for the running python; fall back to pip.
command -v scons >/dev/null || python3 -m pip install --upgrade scons

echo "--- toolchain check"
gcc --version | head -1
python3 --version
command -v protoc >/dev/null && protoc --version || echo "!! protoc missing -- gem5 trace probe will be disabled"
fi

# ---------------------------------------------------------------- CACTI
if has cacti; then
echo "=============== CACTI 7"
cd "$A1_ROOT/PartB"
[ -d cacti/.git ] || [ -f cacti/makefile ] || \
    git clone --depth 1 https://github.com/HewlettPackard/cacti.git
make -C cacti -j"$NPROC"
test -x cacti/cacti && echo "cacti OK"
fi

# ---------------------------------------------------------------- NVSim
if has nvsim; then
echo "=============== NVSim"
cd "$A1_ROOT/PartC"
[ -d nvsim-src ] || git clone --depth 1 https://github.com/SEAL-UCSB/NVSim.git nvsim-src
# NVSim predates C++17: a local named `data` collides with std::data under
# `using namespace std;`.  The patch pins -std=c++11.
git -C nvsim-src apply --check ../PartC/nvsim_build.patch 2>/dev/null \
  && git -C nvsim-src apply ../PartC/nvsim_build.patch || true
make -C nvsim-src -j"$NPROC"
cp nvsim-src/nvsim .
echo "nvsim OK"
fi

# ---------------------------------------------------------------- Ramulator
if has ramulator; then
echo "=============== Ramulator 2.0a"
# Tag v2.0a, NOT main: main is 2.1 and has replaced the YAML CLI with a Python
# API, so `./ramulator2 -f ddr4.yaml` does not exist there.
if [ ! -d "$RAMULATOR_DIR" ]; then
    git clone https://github.com/CMU-SAFARI/ramulator2.git "$RAMULATOR_DIR"
    git -C "$RAMULATOR_DIR" checkout v2.0a 2>/dev/null || {
        echo "!! tag v2.0a not found; pinning to the last 2.0 commit instead"
        git -C "$RAMULATOR_DIR" checkout "$(git -C "$RAMULATOR_DIR" rev-list -1 --before=2024-06-01 main)"
    }
fi

# Task 2 needs an FCFS scheduler, which 2.0a does not ship (only FRFCFS is
# registered in generic_scheduler.cpp).
SCHED_DIR="$RAMULATOR_DIR/src/dram_controller/impl/scheduler"
if [ ! -f "$SCHED_DIR/fcfs_scheduler.cpp" ]; then
    cp "$A1_ROOT/PartD/task2/fcfs_scheduler.cpp" "$SCHED_DIR/"
    CML="$RAMULATOR_DIR/src/dram_controller/CMakeLists.txt"
    grep -q fcfs_scheduler "$CML" || \
        sed -i 's|impl/scheduler/generic_scheduler.cpp|impl/scheduler/generic_scheduler.cpp\n    impl/scheduler/fcfs_scheduler.cpp|' "$CML"
    grep -q fcfs_scheduler "$CML" || { echo "!! could not register fcfs_scheduler in $CML"; exit 1; }
    echo "registered FCFS scheduler"
fi

echo "--- ramulator ref: $(git -C "$RAMULATOR_DIR" describe --tags --always)"

cd "$RAMULATOR_DIR"
mkdir -p build && cd build
# CMake >= 4 removed compatibility with cmake_minimum_required(VERSION <3.5),
# which Ramulator's vendored ext/yaml-cpp still declares.  The policy flag
# tells CMake to configure it anyway.  Harmless on older CMake.
# Two flags for two independent modern-toolchain problems:
#   CMAKE_POLICY_VERSION_MINIMUM  CMake >= 4 dropped cmake_minimum_required(<3.5),
#                                 which the vendored yaml-cpp still declares.
#   -include cstdint              GCC >= 13 no longer pulls <cstdint> in
#                                 transitively; this vintage of yaml-cpp relies
#                                 on it and fails on uint16_t in emitterutils.cpp.
# Both are no-ops on older toolchains.
RAM_CXXFLAGS="-include cstdint ${RAM_CXXFLAGS:-}"
cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
         -DCMAKE_CXX_FLAGS="$RAM_CXXFLAGS" >/dev/null || {
    echo "!! cmake configure failed; retrying verbosely"
    cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_CXX_FLAGS="$RAM_CXXFLAGS"
    exit 1
}
make -j"$NPROC" || {
    echo
    echo "!! Ramulator build failed."
    echo
    echo "   Read the FIRST error, not the last: the build is parallel, so the"
    echo "   real cause scrolls past. Common ones:"
    echo
    echo "   * 'uint16_t was not declared' in ext/yaml-cpp"
    echo "       -> a missing <cstdint>; already handled by -include cstdint."
    echo "          If it still appears, the flag did not reach the subproject:"
    echo "            cd $RAMULATOR_DIR && sed -i '1i #include <cstdint>' \\"
    echo "                 ext/yaml-cpp/src/emitterutils.cpp"
    echo
    echo "   * errors inside Ramulator's own src/ (not ext/, not _deps/)"
    echo "       -> genuinely a compiler-vintage problem. Use clang:"
    echo "            sudo dnf install clang"
    echo "            cd $RAMULATOR_DIR/build && rm -rf CMakeCache.txt CMakeFiles"
    echo "            cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \\"
    echo "                     -DCMAKE_CXX_FLAGS='-include cstdint' \\"
    echo "                     -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++"
    echo "            make -j$NPROC"
    echo
    echo "   * or skip the host toolchain entirely:"
    echo "         bash tools/container.sh build"
    echo "         bash tools/container.sh run bash tools/build_tools.sh"
    exit 1
}
cp "$RAMULATOR_DIR/ramulator2" "$A1_ROOT/PartD/" 2>/dev/null || \
    cp "$RAMULATOR_DIR/build/ramulator2" "$A1_ROOT/PartD/"
# ramulator2 is dynamically linked against libramulator.so; ship both so
# PartD works without the build tree.
cp "$RAMULATOR_DIR/libramulator.so" "$A1_ROOT/PartD/" 2>/dev/null || \
    cp "$RAMULATOR_DIR/build/libramulator.so" "$A1_ROOT/PartD/" 2>/dev/null || \
    echo "!! libramulator.so not found; PartD will need RAMULATOR_DIR set"
chmod +x "$A1_ROOT/PartD/ramulator2"
"$A1_ROOT/PartD/ramulator2" 2>&1 | head -3 || true
echo "ramulator2 OK -> PartD/ramulator2"
fi

# ---------------------------------------------------------------- gem5
if has gem5; then
echo "=============== gem5 (long)"
[ -d "$GEM5DIR" ] || git clone --depth 1 https://github.com/gem5/gem5.git "$GEM5DIR"
cd "$GEM5DIR"

# gem5's scons picks up whatever python3 is first on PATH and links the
# embedded interpreter against it.  A conda base or a .venv can leave it
# pointing at an interpreter whose headers are not installed, which shows up
# as "Can't find Python.h" or a link error late in the build.  Building
# against the system python is the reliable choice.
if [ -n "${VIRTUAL_ENV:-}${CONDA_PREFIX:-}" ]; then
    echo "!! a virtualenv or conda env is active:"
    echo "     VIRTUAL_ENV=${VIRTUAL_ENV:-(none)}"
    echo "     CONDA_PREFIX=${CONDA_PREFIX:-(none)}"
    echo "   If the gem5 build fails on Python.h or on linking libpython,"
    echo "   deactivate and re-run just this target:"
    echo "     deactivate; conda deactivate"
    echo "     bash tools/build_tools.sh gem5"
    echo
fi

# gem5 declares a supported compiler range and MEANS it.  Building outside it
# produces a binary that links and runs but miscompiles the O3 CPU -- the
# failure mode is a SIGSEGV in o3::Decode::sortInsts() partway into a long
# simulation, not a build error.  Refuse rather than waste hours on it.
GCCMAJ=$(gcc -dumpversion | cut -d. -f1)
if [ "${FORCE_GCC:-0}" != "1" ] && [ "$GCCMAJ" -gt 14 ]; then
    echo
    echo "!! gcc $GCCMAJ is outside gem5's supported range (v11 to v14.2)."
    echo "   A build with it links fine and then segfaults inside the O3 CPU"
    echo "   partway through a run. Do not use it."
    echo
    echo "   Use the pinned-toolchain container instead:"
    echo "     rm -rf $GEM5DIR/build"
    echo "     bash tools/container.sh build"
    echo "     bash tools/container.sh run bash tools/build_tools.sh gem5"
    echo "     bash tools/container.sh run bash verify_all.sh E"
    echo
    echo "   Or, if you have a supported compiler:"
    echo "     CC=gcc-13 CXX=g++-13 bash tools/build_tools.sh gem5"
    echo
    echo "   FORCE_GCC=1 overrides this check. It will not end well."
    exit 1
fi

# --ignore-style skips the pre-commit hook check; the rest is a normal build.
scons build/X86/gem5.opt -j"$NPROC" --ignore-style \
      ${CC:+CC="$CC"} ${CXX:+CXX="$CXX"} || {
    echo
    echo "!! gem5 build failed."
    echo "   GCC 16 is far newer than gem5 targets, and gem5's SConstruct also"
    echo "   enforces a maximum supported compiler version.  Fedora 44 has no"
    echo "   older gcc package, so the practical routes are:"
    echo
    echo "   (a) clang:"
    echo "         sudo dnf install clang"
    echo "         cd $GEM5DIR && scons build/X86/gem5.opt -j$NPROC \\"
    echo "              CC=clang CXX=clang++ --ignore-style"
    echo
    echo "   (b) a conda-forge GCC:"
    echo "         conda create -n gcc13 -c conda-forge gxx=13 -y"
    echo "         conda activate gcc13"
    echo "         cd $GEM5DIR && scons build/X86/gem5.opt -j$NPROC \\"
    echo "              CC=\$CC CXX=\$CXX --ignore-style"
    echo "       (then 'conda deactivate' before running gem5)"
    echo
    echo "   (c) the prebuilt container, which sidesteps the toolchain entirely"
    echo "       and is what gem5.sh already expects:"
    echo "         bash tools/build_tools.sh gem5_docker"
    exit 1
}
test -x build/X86/gem5.opt && echo "gem5 OK"
# The CommMonitor hook Part D's trace needs.  Idempotent.
python3 "$A1_ROOT/PartE/insert_commmonitor.py" "$GEM5DIR"
fi

# ---------------------------------------------------------------- GAPBS
if has gapbs; then
echo "=============== GAPBS + graphs"
[ -d "$GAPBS" ] || git clone --depth 1 https://github.com/sbeamer/gapbs.git "$GAPBS"
cd "$GAPBS"
# Static, single-threaded: gem5 SE mode has no dynamic loader and no OpenMP.
# Needs glibc-static and libstdc++-static on Fedora (installed by the deps
# target); without them this fails with "cannot find -lstdc++" or similar.
make CXX_FLAGS="-std=c++11 -O3 -static" PAR_FLAG="" converter bfs sssp -j"$NPROC" || {
    echo
    echo "!! GAPBS static build failed."
    echo "   Fedora needs the static libraries explicitly:"
    echo "     sudo dnf install glibc-static libstdc++-static"
    exit 1
}
file ./bfs | grep -q "statically linked" || \
    echo "!! warning: bfs is not statically linked; gem5 SE mode will not run it"
mkdir -p graphs
[ -f "graphs/g$GRAPH_SCALE.sg" ]  || ./converter -g "$GRAPH_SCALE"    -b "graphs/g$GRAPH_SCALE.sg"
[ -f "graphs/g$GRAPH_SCALE.wsg" ] || ./converter -g "$GRAPH_SCALE" -w -b "graphs/g$GRAPH_SCALE.wsg"
ls -la graphs/
echo "gapbs OK"
fi

# ---------------------------------------------------------------- gem5 (docker)
if has gem5_docker; then
echo "=============== gem5 via the official container"
# Sidesteps the host toolchain entirely.  gem5.sh already runs this image.
command -v docker >/dev/null || command -v podman >/dev/null || {
    echo "!! neither docker nor podman found: sudo dnf install podman"; exit 1; }
RUNNER=$(command -v docker || command -v podman)
[ -d "$GEM5DIR" ] || git clone --depth 1 https://github.com/gem5/gem5.git "$GEM5DIR"
"$RUNNER" run --rm -u "$(id -u):$(id -g)" \
    --volume "$A1_ROOT:/work:z" -w /work/gem5 \
    ghcr.io/gem5/ubuntu-24.04_all-dependencies:latest \
    scons build/X86/gem5.opt -j"$NPROC" --ignore-style
python3 "$A1_ROOT/PartE/insert_commmonitor.py" "$GEM5DIR"
echo "gem5 OK (container-built)."
echo "Run Part E with:  GEM5BIN=$A1_ROOT/gem5.sh bash verify_all.sh E"
fi

echo
echo "=============== done"

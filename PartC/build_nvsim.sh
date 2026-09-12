#!/usr/bin/env bash
# Build NVSim and run the Part C 2 MB STT-MRAM cache.
set -e
[ -d nvsim-src ] || git clone --depth 1 https://github.com/SEAL-UCSB/NVSim.git nvsim-src
# NVSim predates C++17: a local variable named `data` collides with std::data
# under `using namespace std;`. -std=c++11 fixes it; the rest is warning noise.
git -C nvsim-src apply --check ../nvsim_build.patch 2>/dev/null \
  && git -C nvsim-src apply ../nvsim_build.patch || true
make -C nvsim-src -j"$(nproc)"
cp nvsim-src/nvsim .
./nvsim STT_cache.cfg | tee out.txt          # NVSim's own optimum
./nvsim STT_4bank.cfg | tee out_4bank.txt    # banking matched to Part B

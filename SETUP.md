# Setup — from `git clone` to running

Tested on Fedora 44 and Ubuntu 24.04. Everything below is one command plus
whatever your package manager asks for.

```bash
git clone <repo-url> A1
cd A1
bash tools/setup.sh
```

That installs system packages, clones and builds CACTI, NVSim, Ramulator 2.0a
and GAPBS into the tree, sets up gem5, checks every tool, and prints the exact
commands to run. It is safe to re-run — each step skips work already done.

Expect **10–15 minutes** for everything except gem5, and **20–40 minutes** for
gem5 itself (native or container).

## What is and is not in the repository

**In** (~30 MB): all source, configs, scripts, every writeup, and every result
— the ngspice CSVs and figures, the CACTI and NVSim outputs, the Ramulator
`.stats`, the gem5 `m5out` directories and the L2 miss traces. You can read the
whole submission without building anything.

**Not in**, because they are large and reproducible — `tools/setup.sh` fetches
them:

| | |
|---|---|
| `gem5/` | ~4 GB built |
| `gapbs/` + graphs | ~130 MB |
| `PartB/cacti/`, `PartC/nvsim-src/`, `tools/ramulator2/` | upstream clones |

The tool clones are excluded rather than vendored because each carries its own
`.git`, which git would commit as an empty gitlink — the code would not come
with your clone.

## If you only have ngspice

That is enough for Part A immediately:

```bash
pip install numpy matplotlib
bash verify_all.sh A
```

`tools/setup.sh` handles the rest.

## The one thing to know about gem5

gem5 embeds the Python interpreter it was compiled against, and **will not
build correctly with GCC newer than 14.2** — it links fine and then miscompiles
the O3 CPU, segfaulting hours into a run. `setup.sh` checks your compiler and
routes around it:

- **GCC ≤ 14.2** → native build. Everything runs with `bash verify_all.sh`.
- **GCC > 14.2** (Fedora 44 ships GCC 16) → builds gem5 in a pinned container.
  Part E must then run there too:

  ```bash
  bash tools/container.sh verify E    # gem5 lives in the container
  bash verify_all.sh A B C D          # everything else on the host
  ```

Ramulator is always host-built, so Part D always runs on the host.

## Verifying

```bash
bash verify_all.sh A B C D          # minutes
bash tools/container.sh verify E    # or: bash verify_all.sh E
```

To prove reproducibility rather than confirm committed results — deletes every
generated file, rebuilds, and diffs the headline numbers:

```bash
bash tools/cleanroom.sh --dry-run
bash tools/cleanroom.sh
```

A full clean-room run reproduces all five parts identically.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `error while loading shared libraries: libpython3.12` | container-built gem5 run on the host | `bash tools/container.sh verify E` |
| `libramulator.so: cannot open shared object file` | binary without its library | `bash tools/build_tools.sh ramulator` |
| `Compatibility with CMake < 3.5 has been removed` | CMake ≥ 4 vs vendored yaml-cpp | handled by `build_tools.sh` |
| `uint16_t was not declared` in `ext/yaml-cpp` | GCC ≥ 13 dropped a transitive include | handled by `build_tools.sh` |
| GAPBS `cannot find -lstdc++` | static libs absent | `sudo dnf install glibc-static libstdc++-static` |
| Part D says "no real traces" | `PartD/traces/real_*.ls` missing | they are committed; if deleted, `bash tools/container.sh run bash PartE/gen_l2_trace.sh` |

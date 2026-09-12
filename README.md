# ECE2.414 Advanced Memory Circuits and Systems — Assignment 1

Simulating Memory: Devices to Systems · ngspice · CACTI · NVSim · Ramulator ·
gem5

**Central question: should the 2 MB L2 cache in our accelerator be SRAM or
STT-MRAM?**

## Layout

```
PartA/   ngspice    6T read margin and disturb
PartB/   CACTI 7    2 MB SRAM L2 at 45 nm
PartC/   NVSim      the same 2 MB as STT-MRAM
PartD/   Ramulator  the real L2 miss stream on DDR4-3200
PartE/   gem5       whole-system runs on GAPBS bfs and sssp
answers/            final tables, figures and writeups (copies — nothing runs here)
tools/              build and verification scripts
```

Each part contains:

| | |
|---|---|
| `taskN/taskN.md` | the answer to that task, and nothing else |
| `taskN/` | that task's inputs, outputs and `run.sh` |
| `findings.md` | tool bugs, config caveats and known approximations |
| `summary.md` | part-level narrative (Parts A and B) |
| `notes/` | the original long-form writeups, kept verbatim |

**New here?** `SETUP.md` walks a fresh clone to all 20 tasks passing, including
the Fedora 44 and WSL specifics.

## Quick start

```bash
git clone <repo-url> A1 && cd A1
bash tools/setup.sh
```

See `SETUP.md` for what that does, what is and is not in the repository, and
the troubleshooting table.

## Building the tools

`gem5/`, `gapbs/` and `tools/ramulator2/` are not in the repository — they are
cloned and built into it:

```bash
bash tools/build_tools.sh          # cacti, nvsim, ramulator 2.0a, gem5, gapbs + graphs
```

`build_tools.sh` detects dnf, apt or pacman. Two packages matter more than they
look: **protobuf** (without it gem5 compiles out `MemTraceProbe` and the Part D
trace comes back empty) and **static libc/libstdc++** (`glibc-static`,
`libstdc++-static` on Fedora — GAPBS is built `-static` because gem5 SE mode has
no dynamic loader).

**gem5 will not build with GCC > 14.2** — it links and then miscompiles the O3
CPU, segfaulting hours into a run. `build_tools.sh` refuses rather than let that
happen. If your host compiler is too new, use the pinned-toolchain container,
which needs no host toolchain at all:

```bash
bash tools/container.sh build      # once, ~3 min
bash tools/container.sh gem5       # builds gem5 inside, into ./gem5
bash tools/container.sh verify E   # runs Part E inside
```

The repository is bind-mounted at `/work`, so everything the container builds
lands in your working tree and persists. Only the toolchain lives in the image.

## Reproducing

```bash
bash verify_all.sh                 # all five parts
bash verify_all.sh A B C           # minutes; no gem5 or Ramulator needed
bash verify_all.sh E               # gem5; Part D's trace comes out of this
bash verify_all.sh D               # Ramulator, on the trace Part E produced
bash tools/sync_answers.sh         # refresh answers/ from the part directories
```

Part E runs **before** Part D, because Part D's trace is generated out of it.

**Run each part where its tool was built.** gem5 embeds the Python interpreter
it was compiled against, so a container-built `gem5.opt` only runs inside the
container; `ramulator2` links the host libstdc++ and only runs on the host. If
you used the container for gem5, the split is:

```bash
bash verify_all.sh A B C           # host
bash tools/container.sh verify E   # container — gem5 lives there
bash verify_all.sh D               # host — ramulator2 lives here
```

`verify_all.sh` detects a gem5 binary that will not start and says which of
these you need, rather than failing with a loader error.

### Clean-room rebuild

To prove reproducibility rather than confirm cached results — delete every
generated file, rebuild from scratch, and diff the headline numbers against
what was there before:

```bash
bash tools/cleanroom.sh --dry-run    # list what would be deleted first
bash tools/cleanroom.sh              # archive, wipe, rebuild, compare
```

It archives to `cleanroom/before/`, rebuilds Parts E, D, A, B, C in that order
(E first, since Part D's trace comes out of it), re-extracts to
`cleanroom/after/`, and reports IDENTICAL or DIFFERS per part. Full transcript
in `cleanroom/transcript.log`. Exit status is the number of parts that differ.

Hand-written inputs are never deleted — `PartB/task4/bldbg.txt` (produced by an
instrumented CACTI build), the NVSim `.cell` and `.cfg` files, the DRAM YAMLs,
the ngspice decks, and everything in `answers/` and `notes/`. Use `--dry-run`
to confirm.

`GEM5_MODE=host bash tools/cleanroom.sh` if gem5 was built natively rather than
in the container.

### The one setting not to change casually

`tools/env.sh` defaults to `FF=10000000 MAXI=20000000`. `FF` is the atomic
warm-up length, and it is the only parameter here that can silently produce
wrong results: at `FF=50000000` the bfs kernel finishes *during* the warm-up, so
the detailed CPU measures teardown and gem5 reports a complete, plausible,
meaningless `stats.txt`. `run_parallel.sh` and `gen_l2_trace.sh` both check for
this and abort, but if you change `FF`, verify that `Switched CPUS` precedes
`Trial Time` in the run logs. Full explanation in `PartE/findings.md`.

## Verification status

Every part has been re-executed end to end.

| Part | Status |
|---|---|
| **A** | all five ngspice decks re-run; every measured value and all four figures reproduce |
| **B** | baseline, capacity sweep, objective sweep and bitline hand-check all reproduce; 4 UCA banks confirmed |
| **C** | all eleven NVSim outputs **byte-identical** to fresh runs |
| **D** | runs on the **real gem5 CommMonitor trace**; read counts match `system.mem_ctrls.readReqs` to the unit (160 569 bfs, 208 852 sssp) |
| **E** | 12/12 configs; fast-forward validated per kernel so the detailed region covers the kernel and not teardown |

## Known approximations, all documented

1. **Part D write stream** is count-exact but not identity-exact. The L2 puts
   every eviction on its memory-side port, but only dirty ones become DRAM
   writes, and the two are indistinguishable in the trace (requestor 0, size 64,
   flags 0, command letter `u` for both). Writebacks are subsampled to the count
   gem5 reports. `PartD/findings.md`.
2. **Part E hit latency** for STT-MRAM carries cross-tool uncertainty — NVSim's
   sense path is a hard-coded constant independent of the cell file. Config C
   brackets it, and every conclusion is stated against both. For sssp the verdict
   flips sign between B and C. `PartE/findings.md`, `PartC/findings.md`.
3. **Write cost is unmodelled in Part E** — gem5 applies one latency to reads and
   writes alike, so the 22-cycle STT write never appears. Largest known weakness
   in the chain, and point three of the Task 4 reviewer list.

## Accuracy reminders

ngspice ±5 % · CACTI ±10 % · Ramulator ±10 % · gem5 ±20 %. Errors compound
multiplicatively, so the writeups report ratios rather than absolutes wherever
the comparison allows it.

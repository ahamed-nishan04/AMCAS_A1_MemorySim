# Part E — gem5 findings, caveats and open gaps

## Open gap: gem5 itself is not in this tree

`gem5.sh` runs the container-built binary at `/work/gem5/build/X86/gem5.opt`, and
there is no `gem5/` directory here. Neither is `gapbs/graphs/`. Part E cannot be
re-executed from this repository alone; `task1/m5out/` and `task3/m5out_timing/`
are the reproducible artifacts.

To rebuild:

```bash
git clone --depth 1 https://github.com/gem5/gem5.git
cd gem5 && scons build/X86/gem5.opt -j$(nproc)     # allow ~40 min
make -C ../gapbs CXX_FLAGS="-std=c++11 -O3 -static" PAR_FLAG="" converter bfs sssp
mkdir -p ../gapbs/graphs
../gapbs/converter -g 18    -b ../gapbs/graphs/g18.sg
../gapbs/converter -g 18 -w -b ../gapbs/graphs/g18.wsg
```

## Fixed: the run script did not reproduce its own results

`run_parte.sh` shipped with `FF=100000000 MAXI=200000000`, but
`task1/m5out/*/config.ini` shows `max_insts_any_thread=5000000` — the committed
stats were produced with 5 M / 5 M. Anyone re-running would have got different
numbers after a 20–40× longer run.

The defaults are now set to the values that actually generated the stats, with a
comment saying so. **Raising them is the right move for a final submission** —
the assignment asks for tens of millions of warm-up accesses, and 5 M is below
that — but `task1/task1.md` and everything derived from it will then change.
`run_taskE3.sh` was already at `FF=5000000`.

## Two necessary deviations from the handout's command line

**`--fast-forward`, not `--warmup-insts`.** `se.py` reads `warmup_insts` only
inside the `--standard-switch` path (`Simulation.py:631`), so it is silently
ignored otherwise. `--fast-forward=N` runs AtomicSimpleCPU for N instructions and
then switches to O3CPU (`Simulation.py:744`) — the atomic warm-up the handout
asks for. Because the detailed CPU is then `switch_cpus`, IPC lands in
`system.switch_cpus.ipc`, which `collect.py` already looks for.

**`-f <pre-built graph>`, not `-g <scale>`.** With `-g`, the simulated region is
dominated by the Kronecker generator — a streaming phase with no reuse, in which
L2 capacity makes no difference at all. The graphs are built once on the host and
loaded.

## Hit latency: what is and is not derived

**Derived.** The 8 MB capacity comes from the NVSim area sweep against Part B's
11.474 mm² (`task1/cap_*.txt`), and the cycle counts come from
`CacheConfig.py:135`, which builds the L2 with `clk_domain=system.cpu_clk_domain`
— so L2 latencies are CPU cycles at `--cpu-clock`, not L2-clock cycles.

**Not derived.** The STT hit latency of 2.967 ns contains no information about
the MTJ resistances. NVSim sets `senseVoltage = cell->minSenseVoltage`, a
constant read from the cell file, and adds a hard-coded 803 ps IV-converter delay
(see `../PartC/findings.md`). It is also a cross-tool comparison between two
different peripheral models. That is why config C exists: the handout's
pessimistic 2× assumption brackets the uncertainty, and every conclusion is
stated against both.

## Unmodelled: the write cost, in full

**gem5's cache applies one tag/data/response latency to reads and writes alike.**
An L2 whose measured write latency is 10.871 ns — 22 cycles at 2 GHz, 92 % of it
the cell file's 10 ns switching pulse — was simulated as if writes completed in 6
or 12 cycles. Nothing in Part E charges the write penalty that Part C measured.

The write *energy* is worse than unmodelled: NVSim reports 0.497 nJ per line
write against a 1.024 nJ floor implied by its own cell file
(`../PartC/findings.md`).

**Endurance appears in none of the five tools**, and it is the failure mode that
actually decides whether STT-MRAM can serve as a last-level cache.

A reviewer should ask for `system.l2.WritebackDirty::total` and re-derive with
writes priced at 22 cycles and 1.024 nJ. On a writeback L2 fed by graph kernels
with scattered updates, that alone could reverse the sssp verdict and materially
narrow bfs's. This is point three of the Task 4 reviewer list and is the largest
known weakness in the chain.

## Reproduction status

gem5 could not be re-executed in the verification container (1 core, no gem5
build). Every number in `task1.md`, `task2.md` and `task3.md` was instead checked
against the committed `stats.txt` files via `collect.py`, and the derived
quantities — IPC ratios, runtime ratios, CPI decompositions, P\* break-even
penalties — were recomputed and all agree.

## Fast-forward length must be validated per kernel

The single most important methodological finding in Part E, and it cost six
hours of wasted simulation to discover.

**A fast-forward that overshoots the region of interest does not fail.** gem5
emits a complete, well-formed `stats.txt` full of post-kernel teardown, and
nothing in the output says anything is wrong. At `FF=50000000` the bfs kernel
runs to completion *inside the atomic warm-up*, so the detailed O3 CPU never
sees it.

**The diagnostic** is the order of two lines in the run log:

```
Read Time:  0.00145          <- graph loaded
Graph has 262143 nodes ...   <- CSR built
Switched CPUS @ tick ...     <- detailed CPU engages   <<< must come BEFORE
**** REAL SIMULATION ****
Trial Time: 0.01458          <- kernel runs under O3 + caches
```

If `Trial Time` precedes `Switched CPUS`, the run measured nothing.

**The confirming symptom** is that results become *identical across cache
configurations*. At `FF=50000000` all six bfs runs reported
`Trial Time: 0.01714` — SRAM 2 MB, STT 8 MB at 6 cycles and at 12 cycles, O3
and in-order alike. AtomicSimpleCPU models no caches, so the cache under test
cannot affect anything. Identical results across configurations that should
differ is the tell.

**Scale-18 numbers.** bfs completes in under 50 M instructions; sssp does not
(it is roughly 8x longer). A single `FF` therefore cannot serve both, and the
value must be checked against each kernel rather than chosen to sound
generous. `FF=10000000 / MAXI=20000000` places the switch correctly for both
and is what `tools/env.sh` now defaults to.

**Note on the assignment's wording.** It asks for a warm-up of "tens of
millions of *accesses*", not instructions. Loading a 32 MB CSR graph is tens of
millions of memory accesses inside only a few million instructions, so the
original `FF=5000000` may well have satisfied it. Raising it was the error, not
the original choice.

`run_parallel.sh` and `gen_l2_trace.sh` both check this ordering automatically
and abort with a named error rather than producing plausible nonsense.

## What the corrected measurement window changed

The committed 5 M-instruction results had the CPU switch land *during* CSR
construction, so their detailed region blended graph building — a streaming,
cache-friendly phase — with traversal. That diluted the measured miss rate
downward. With the switch correctly placed after construction:

| bfs, O3 | committed (FF=5M) | corrected (FF=10M/20M) |
|---|---|---|
| SRAM 2 MB miss rate | 41.01 % | **75.76 %** |
| STT 8 MB miss rate | 19.31 % | **31.46 %** |

75 % is the believable figure for BFS traversal of a 3.8 M-edge graph through a
2 MB L2; 41 % was optimistic. **The corrected runs are the ones to quote.**

# Part E, Task 1 — gem5: SRAM vs STT-MRAM L2 on bfs and sssp

gem5 25.1.0.1, X86, SE mode, O3CPU at 2 GHz, 32 kB L1I/L1D, 8-way L2,
DDR4_2400_8x8, 4 GB. GAPBS bfs and sssp on a Kronecker graph, scale 18
(262 143 nodes, 3 805 449 undirected edges), one trial. Atomic warm-up of 5 M
instructions through the graph load, then switch to O3 for the kernel.

## The configurations, derived from Parts B and C

The handout's `--l2-hit-latency=7`, `8MB` and "2× slower hits" are placeholders;
the assignment says these come from CACTI and NVSim, so:

**Capacity trade, from the area outputs.** SRAM 2 MB costs 11.474 mm² (Part B).
Sweeping the Part C STT-MRAM design:

| STT capacity | Area | Hit latency | Leakage |
|---|---|---|---|
| 2 MB | 3.008 mm² | 1.727 ns | 265.3 mW |
| 4 MB | 5.355 mm² | 2.187 ns | 472.4 mW |
| **8 MB** | **9.345 mm²** | **2.967 ns** | 552.7 mW |
| 16 MB | 17.697 mm² | 5.786 ns | 622.4 mW |

**8 MB is the iso-area point** — 9.345 mm² against 11.474, with 2.1 mm² to
spare; 16 MB overshoots by 54 %. The handout's 8 MB is right, and now it is
derived. Leakage there is 552.7 mW against the SRAM's 2250.5 mW: **4.1× better
at 4× the capacity.**

**Hit latency in cycles.** `CacheConfig.py:135` builds the L2 with
`clk_domain=system.cpu_clk_domain`, so the cycles are CPU cycles at
`--cpu-clock`. At 2 GHz: SRAM 2.902 ns → **6 cycles**; STT 8 MB 2.967 ns →
**6 cycles**.

That says 4× capacity for a 2 % latency penalty, not 2×. It is too good, and
Part C found why: NVSim's read path spends a hard-coded 803 ps in a
current-sense IV converter that is independent of everything in the cell file,
and this is a cross-tool comparison with different peripheral models. So a third
configuration carries the handout's pessimistic assumption, and the two bracket
the uncertainty:

| Config | L2 | Hit latency | Source |
|---|---|---|---|
| **A** | SRAM 2 MB | 6 cycles | CACTI, measured |
| **B** | STT 8 MB | 6 cycles | NVSim, measured |
| **C** | STT 8 MB | 12 cycles | handout's 2× assumption |

## Results

| Config | Kernel | IPC | L2 miss rate | simSeconds |
|---|---|---|---|---|
| A — SRAM 2 MB, 6 cyc | bfs | 0.6628 | 41.01 % | 0.011131 |
| B — STT 8 MB, 6 cyc | bfs | **0.9085** | 19.31 % | **0.008120** |
| C — STT 8 MB, 12 cyc | bfs | 0.8469 | 19.38 % | 0.008711 |
| A — SRAM 2 MB, 6 cyc | sssp | 0.6410 | 17.43 % | 0.092304 |
| B — STT 8 MB, 6 cyc | sssp | **0.7447** | 12.54 % | **0.079457** |
| C — STT 8 MB, 12 cyc | sssp | 0.6638 | 12.53 % | 0.089138 |

Relative to the SRAM baseline:

| Kernel | Config | IPC | Runtime | L2 miss rate |
|---|---|---|---|---|
| bfs | B | **+37.1 %** | 27.1 % faster | 52.9 % lower |
| bfs | C | **+27.8 %** | 21.7 % faster | 52.7 % lower |
| sssp | B | **+16.2 %** | 13.9 % faster | 28.1 % lower |
| sssp | C | **+3.6 %** | 3.4 % faster | 28.1 % lower |

**The iso-area STT-MRAM L2 wins in all four comparisons.** The conclusion is
robust to the cross-tool latency uncertainty: even under the handout's
pessimistic 2× assumption, both kernels are faster with 8 MB at 12 cycles than
with 2 MB at 6.

## Reading the numbers

**Capacity beats latency, by a margin that depends on reuse.** bfs's miss rate
halves, 41.01 → 19.31 %, and it gains 37 %. sssp's falls by only 28 %,
17.43 → 12.54 %, and it gains 16 %. sssp starts with a far lower miss rate — it
already fits 2 MB better — so there is less for the extra 6 MB to capture. The
size of the win tracks the size of the miss-rate improvement, not the technology.

**The latency penalty is real but second-order.** Doubling the hit latency at
fixed capacity costs bfs 6.8 % of IPC and sssp 10.9 %. Against capacity gains of
37 % and 16 %, the trade is favourable in both — but note that the *margin*
narrows sharply for sssp, from +16.2 % to +3.6 %. A workload with slightly better
2 MB locality than sssp would cross over, and the crossover point sits inside the
uncertainty band of the NVSim/CACTI latency comparison rather than safely outside
it.

**Miss rate is insensitive to latency, as it must be.** B and C differ by
0.07 points for bfs and 0.01 for sssp — they run the same capacity with the same
replacement behaviour, and the residual difference is timing-dependent
interleaving. That the two agree is a consistency check that the size and
latency knobs are independent and both taking effect.

## Four things that had to be fixed to get here

**1. gem5 built with GCC 16 segfaults in O3.** Fedora 44 ships GCC 16.1/16.2;
gem5 25.1 supports 11–14.2 and warns but builds. The resulting binary crashes in
`gem5::o3::Decode::sortInsts` on entry to detailed simulation, while
TimingSimpleCPU runs the identical config fine — a miscompile, not a
configuration error. Neither `gcc14` nor a clang ≤ 19 exists in Fedora 44's
repositories, so the build was done in gem5's own container
(`ghcr.io/gem5/ubuntu-24.04_all-dependencies`, GCC 13). The container binary
links `libpython3.12`, which Fedora does not have, so it is also *run* in the
container via a wrapper (`gem5.sh`). SELinux additionally requires the `:z`
relabel on the bind mount or the container sees an empty tree.

**2. `--l2-hit-latency` does not exist.** `_get_cache_opts()`
(`CacheConfig.py:60`) forwards only size, assoc and prefetcher type; argparse
rejects the flag outright. L2 latency lives in the `L2Cache` class in
`configs/common/Caches.py`, defaulting to tag/data/response = 20/20/20 cycles.
`set_l2_latency.py` rewrites those three fields. Left unnoticed, every
configuration would silently have run at 20 cycles and the comparison would have
been void.

**3. `--warmup-insts` is a no-op here.** `Simulation.py:631` reads it only inside
the `--standard-switch` path, so with a plain `--cpu-type=O3CPU` it is silently
ignored and no CPU switch happens. The option that performs the atomic warm-up
the handout describes is `--fast-forward=N` (`Simulation.py:744`): AtomicSimpleCPU
for N instructions, then switch to O3. Because the detailed CPU is then
`switch_cpus`, IPC moves from `system.cpu.ipc` to `system.switch_cpus.ipc`.

**4. `-g 18` measures the graph generator, not the kernel.** The first run gave
IPC 1.3213 for *both* 2 MB and 8 MB, and 1.3213 vs 1.3216 for bfs vs sssp — two
different kernels agreeing to four digits. The simulated region was entirely
inside GAPBS's Kronecker generator, a streaming phase with no reuse where L2
capacity cannot matter and the miss rate pins at 97 %. The fix is to build the
graph once with `converter -g 18 -b` (and `-w -b` for sssp's weights) and load it
with `-f`, so the simulated region is the kernel.

A related trap: the warm-up must end *before* the kernel starts. At FF = 50 M the
entire 19 M-instruction program finished inside the fast-forward and O3 measured
nothing. The check is the ordering of gem5's own output — `Switched CPUS` must
appear between GAPBS's `Graph has ...` and `Trial Time` lines.

**On warm-up depth.** The handout asks for tens of millions of atomically warmed
accesses. bfs at this scale is only ~16 M instructions of kernel, so that budget
is not reachable with `-n 1`; the warm-up here is 5 M instructions, enough to
cover the graph load and page-in but less than asked. `-n 3` or larger would give
a longer steady-state region at proportionate simulation cost. This is a stated
trade, not an oversight.

**On measurement window.** An earlier run capped at 20 M instructions truncated
sssp mid-kernel and reported config C *losing* to the SRAM baseline by 1.4 %.
Run to completion at 150 M, C *wins* by 3.6 %. SSSP's delta-stepping changes
character as the frontier evolves, and the first sixth of the kernel is not
representative. Both kernels in the table above run to their natural exit.

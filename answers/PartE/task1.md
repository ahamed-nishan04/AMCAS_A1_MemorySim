# Part E, Task 1 — gem5: SRAM vs STT-MRAM L2 on bfs and sssp

gem5 25.1.0.1, X86, SE mode, O3CPU at 2 GHz, 32 kB L1I/L1D, 8-way L2,
DDR4_2400_8x8, 4 GB. GAPBS bfs and sssp on a Kronecker graph, scale 18
(262 143 nodes, 3 805 449 undirected edges), one trial. Atomic warm-up of 10 M
instructions covering graph load and CSR construction, then switch to O3 for
the kernel, 20 M detailed instructions.

**The warm-up length is load-bearing and was validated per kernel** — a
fast-forward that overshoots silently measures teardown instead of the kernel.
See `../findings.md`; it also explains why these miss rates differ
substantially from an earlier 5 M-instruction run.

## The configurations, derived from Parts B and C

The handout's `--l2-hit-latency=7`, `8MB` and "2x slower hits" are placeholders;
the assignment says these come from CACTI and NVSim.

**Capacity trade, from the area outputs.** SRAM 2 MB costs 11.474 mm² (Part B).
Sweeping the Part C STT-MRAM design:

| STT capacity | Area | Hit latency | Leakage |
|---|---|---|---|
| 2 MB | 3.008 mm² | 1.727 ns | 265.3 mW |
| 4 MB | 5.355 mm² | 2.187 ns | 472.4 mW |
| **8 MB** | **9.345 mm²** | **2.967 ns** | 552.7 mW |
| 16 MB | 17.697 mm² | 5.786 ns | 622.4 mW |

**8 MB is the iso-area point** — 9.345 mm² against 11.474, with 2.1 mm² to
spare; 16 MB overshoots by 54 %. Leakage there is 552.7 mW against the SRAM's
2250.5 mW: **4.1x better at 4x the capacity.**

**Hit latency in cycles.** `CacheConfig.py:135` builds the L2 with
`clk_domain=system.cpu_clk_domain`, so the cycles are CPU cycles at
`--cpu-clock`. At 2 GHz: SRAM 2.902 ns → **6 cycles**; STT 8 MB 2.967 ns →
**6 cycles**.

That says 4x capacity for a 2 % latency penalty, which is too good — Part C
found why (NVSim's read path spends a hard-coded 803 ps in a current-sense IV
converter independent of the cell file, and this is a cross-tool comparison
with different peripheral models). A third configuration therefore carries the
handout's pessimistic assumption, and the two bracket the uncertainty:

| Config | L2 | Hit latency | Source |
|---|---|---|---|
| **A** | SRAM 2 MB | 6 cycles | CACTI, measured |
| **B** | STT 8 MB | 6 cycles | NVSim, measured |
| **C** | STT 8 MB | 12 cycles | handout's 2x assumption |

## Results

| Config | Kernel | IPC | L2 miss rate | simSeconds |
|---|---|---|---|---|
| A — SRAM 2 MB, 6 cyc | bfs | 0.6799 | 75.76 % | 0.007174 |
| B — STT 8 MB, 6 cyc | bfs | **1.0020** | 31.46 % | **0.004868** |
| C — STT 8 MB, 12 cyc | bfs | 0.9444 | 31.53 % | 0.005164 |
| A — SRAM 2 MB, 6 cyc | sssp | 0.7489 | 14.01 % | 0.013352 |
| B — STT 8 MB, 6 cyc | sssp | **0.7999** | 11.27 % | **0.012501** |
| C — STT 8 MB, 12 cyc | sssp | 0.7183 | 11.27 % | 0.013922 |

Relative to the SRAM baseline:

| Kernel | Config | IPC | Runtime | L2 miss rate |
|---|---|---|---|---|
| bfs | B | **+47.4 %** | 32.1 % faster | 58.5 % lower |
| bfs | C | **+38.9 %** | 28.0 % faster | 58.4 % lower |
| sssp | B | **+6.8 %** | 6.4 % faster | 19.6 % lower |
| sssp | **C** | **−4.1 %** | **4.3 % slower** | 19.6 % lower |

## The result does not go one way

**The iso-area STT-MRAM L2 wins overwhelmingly for bfs and loses for sssp.**
Under the optimistic latency (B) both kernels gain, but under the handout's
pessimistic 2x assumption (C) — the configuration that actually represents the
trade the task describes — sssp is 4.1 % *slower* than the 2 MB SRAM it
replaced.

That is the honest result and it is more useful than a clean sweep would be:
the same hardware change is worth +38.9 % on one graph kernel and −4.1 % on
another, on the same machine, same graph, same trial. Task 2 identifies what
separates them.

bfs's margin is large enough to be robust to the cross-tool latency
uncertainty — it wins by 38.9 % even at 12 cycles. sssp's verdict is not: it
flips sign between B and C, so for that kernel the answer depends entirely on a
hit latency that neither CACTI nor NVSim can settle (`../findings.md`).

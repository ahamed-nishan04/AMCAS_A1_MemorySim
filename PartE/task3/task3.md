# Part E, Task 3 — Re-run with `--cpu-type=TimingSimple`

Same three configurations, same two kernels, in-order core in place of O3.

| Config | Kernel | IPC (in-order) | IPC (O3) | L2 miss rate (in-order / O3) |
|---|---|---|---|---|
| A — SRAM 2 MB, 6 cyc | bfs | 0.2080 | 0.6799 | 74.38 % / 75.76 % |
| B — STT 8 MB, 6 cyc | bfs | 0.2646 | 1.0020 | 25.04 % / 31.46 % |
| C — STT 8 MB, 12 cyc | bfs | 0.2547 | 0.9444 | 25.04 % / 31.53 % |
| A — SRAM 2 MB, 6 cyc | sssp | 0.1966 | 0.7489 | 13.99 % / 14.01 % |
| B — STT 8 MB, 6 cyc | sssp | 0.2064 | 0.7999 | 11.26 % / 11.27 % |
| C — STT 8 MB, 12 cyc | sssp | 0.1871 | 0.7183 | 11.26 % / 11.27 % |

| Kernel | Advantage of C over A, O3 | in-order |
|---|---|---|
| bfs | +38.9 % | **+22.5 %** |
| sssp | −4.1 % | **−4.8 %** |

**The out-of-order result was the optimistic one, for both kernels.** Removing
the out-of-order core cuts bfs's advantage by nearly half and deepens sssp's
loss. The verdicts do not change sign — bfs still wins, sssp still loses — but
the margin moves substantially in the same direction in both cases.

That is the opposite of the naive expectation: an in-order core exposes memory
latency, so one would predict the cache advantage to grow. In absolute terms it
does. In relative terms it does not, and the reason is the part of the trade
that gets exposed along with it.

## Decomposing it

Split the change into its two halves using config B, which shares capacity with
C and hit latency with A. Working in CPI, where the effects add:

**bfs**

| | in-order | O3 | O3 hides |
|---|---|---|---|
| CPI, A / B / C | 4.8077 / 3.7793 / 3.9262 | 1.4708 / 0.9980 / 1.0589 | |
| Capacity benefit (A→B) | **−1.0284** | −0.4728 | **54.0 %** |
| Hit-latency cost (B→C) | **+0.1469** | +0.0609 | **58.6 %** |
| Net (A→C) | −0.8815 | −0.4119 | |

**sssp**

| | in-order | O3 | O3 hides |
|---|---|---|---|
| CPI, A / B / C | 5.0865 / 4.8450 / 5.3447 | 1.3353 / 1.2502 / 1.3922 | |
| Capacity benefit (A→B) | **−0.2415** | −0.0851 | **64.7 %** |
| Hit-latency cost (B→C) | **+0.4998** | +0.1420 | **71.6 %** |
| Net (A→C) | **+0.2583 (worse)** | +0.0569 (worse) | |

**The in-order core exposes more absolute latency, as expected.** bfs saves
1.03 CPI from the extra capacity in-order against 0.47 with O3; sssp saves 0.24
against 0.09. Roughly half to two thirds of the memory latency the bigger cache
eliminates was already invisible to the out-of-order core, overlapped with
other work.

**But out-of-order hides the hit-latency cost better than it hides the miss
benefit — 58.6 % vs 54.0 % for bfs, 71.6 % vs 64.7 % for sssp.** That asymmetry
is the whole result. O3 discounts the *cost* of the trade more than it
discounts the *gain*, so it makes the trade look better than it is. Strip O3
away and the penalty reasserts itself at a larger fraction of full price.

The asymmetry is not arbitrary. An L2 *hit* at 12 cycles is a short,
predictable delay: an out-of-order core has ample independent instructions in
its window to cover twelve cycles, and covers nearly all of it. A *miss* costs
a couple of hundred cycles — far more than the reorder window can absorb, so
only a fraction is recovered, mostly by overlapping several misses against each
other via the MSHRs. **Short latencies are nearly free to an OoO core; long
ones are not. The 2x hit-latency penalty is exactly the kind of latency O3 is
best at erasing.**

## Why sssp is negative on both cores

For sssp the hit-latency cost exceeds the capacity benefit under *either* core —
in-order +0.4998 against −0.2415, O3 +0.1420 against −0.0851. It hits in the L2
about 86 % of the time; every one of those hits pays 6 extra cycles, and there
were not enough misses saved to compensate. The in-order core simply makes the
imbalance starker, because it pays a larger share of both.

Note that sssp's hit-latency cost in-order (0.4998 CPI) is **3.4x bfs's**
(0.1469), for the same +6 cycles. That is the hit-count difference showing up
directly: **the kernel with the better locality is the one most damaged by
making hits slower.**

## What out-of-order execution was doing to the Task 1 result

Three things, all of which flattered the STT-MRAM configuration.

1. **It concealed 54–65 % of the miss latency the larger cache eliminates.**
   The raw memory-system improvement is roughly two to three times what Task 1's
   IPC numbers show; O3 had already recovered the rest through overlap.
2. **It concealed 59–72 % of the hit-latency penalty**, which is the entire cost
   side of the trade. This dominates: it is why the *net* advantage was larger
   under O3 despite the benefit also being discounted.
3. **It changed the miss rate itself.** bfs's L2 miss rate is 1.4–6.4 points
   higher under O3 (31.46 % vs 25.04 % for B) because speculative execution
   issues accesses down mispredicted paths that never retire. Those are real L2
   and real DRAM traffic, absent on an in-order core. sssp shows almost none of
   this (0.02 points), consistent with delta-stepping's branch behaviour being
   far more predictable than BFS's frontier tests.

**The honest statement for Task 4** is that the Task 1 result is core-dependent
and in a specific direction: the STT-MRAM L2 looks best on an aggressive
out-of-order core, which is the machine most able to hide the very penalty the
technology imposes. On a simpler core — an embedded or in-order design,
precisely where a non-volatile last-level cache is most often proposed for its
leakage — bfs's advantage halves and sssp's loss deepens. **The leakage argument
from Part C and the performance argument from Part E point at different
machines.**

# Part E, Task 3 — In-order (TimingSimpleCPU)

Identical configurations, `--cpu-type=TimingSimpleCPU` instead of `O3CPU`.
(gem5's class is `TimingSimpleCPU`; `TimingSimple` is rejected.) In-order and
blocking: one outstanding memory request, no overlap of a miss with anything
behind it.

| Config | Kernel | IPC (in-order) | IPC (O3) | L2 miss rate (in-order / O3) |
|---|---|---|---|---|
| A — SRAM 2 MB, 6 cyc | bfs | 0.2038 | 0.6628 | 38.54 % / 41.01 % |
| B — STT 8 MB, 6 cyc | bfs | 0.2471 | 0.9085 | 15.58 % / 19.31 % |
| C — STT 8 MB, 12 cyc | bfs | 0.2331 | 0.8469 | 15.58 % / 19.38 % |
| A — SRAM 2 MB, 6 cyc | sssp | 0.1803 | 0.6410 | 16.78 % / 17.43 % |
| B — STT 8 MB, 6 cyc | sssp | 0.1958 | 0.7447 | 12.53 % / 12.54 % |
| C — STT 8 MB, 12 cyc | sssp | 0.1771 | 0.6638 | 12.53 % / 12.53 % |

## The advantage shrinks, and sssp changes sign

| Kernel | Advantage of C over A, O3 | in-order |
|---|---|---|
| bfs | +27.8 % | **+14.4 %** |
| sssp | +3.6 % | **−1.8 %** |

**The out-of-order result was the optimistic one.** Removing the out-of-order
core roughly halves bfs's benefit and turns sssp's small win into a small loss.
The iso-area STT-MRAM L2 that won both kernels in Task 1 wins only one of them
on an in-order core.

That is the opposite of the naive expectation — an in-order core exposes memory
latency, so one would predict the cache advantage to grow. In absolute terms it
does. In relative terms it does not, and the reason is the part of the trade
that gets exposed along with it.

## Decomposing it

Split the change into its two halves using config B, which shares capacity with
C and hit latency with A. Working in CPI, where the effects add:

**bfs**

| | in-order | O3 | O3 hides |
|---|---|---|---|
| CPI, A / B / C | 4.9068 / 4.0469 / 4.2900 | 1.5088 / 1.1007 / 1.1808 | |
| Capacity benefit (A→B) | **−0.8598** | −0.4080 | **52.5 %** |
| Hit-latency cost (B→C) | **+0.2431** | +0.0801 | **67.1 %** |
| Net (A→C) | −0.6168 | −0.3280 | |

**sssp**

| | in-order | O3 | O3 hides |
|---|---|---|---|
| CPI, A / B / C | 5.5463 / 5.1073 / 5.6465 | 1.5601 / 1.3428 / 1.5065 | |
| Capacity benefit (A→B) | **−0.4391** | −0.2172 | **50.5 %** |
| Hit-latency cost (B→C) | **+0.5393** | +0.1637 | **69.7 %** |
| Net (A→C) | **+0.1002 (worse)** | −0.0536 | |

Two things fall out of this.

**The in-order core does expose more absolute latency, as expected.** bfs saves
0.86 CPI from the extra capacity in-order against 0.41 with O3; sssp saves 0.44
against 0.22. Roughly half the memory latency the bigger cache eliminates was
already invisible to the out-of-order core, because it was overlapped with other
work.

**But out-of-order hides the hit-latency penalty better than it hides the miss
benefit — 67–70 % against 50–52 %.** That asymmetry is the whole result. O3
discounts the cost of the trade more than it discounts the gain, so it makes the
trade look better than it is. Strip O3 away and the penalty reasserts itself at
full price.

The asymmetry is not arbitrary. An L2 *hit* at 12 cycles is a short, predictable
delay: an out-of-order core has ample independent instructions in its window to
cover twelve cycles, and covers nearly all of it. A *miss* costs a couple of
hundred cycles — far more than the reorder window can absorb, so only a fraction
is recovered, mostly through overlapping several misses against each other via
the MSHRs. **Short latencies are nearly free to an OoO core; long ones are not.
The 2× hit-latency penalty is exactly the kind of latency O3 is best at
erasing.**

## Why sssp flips and bfs does not

The sign is set by which half is larger once both are charged at full price.

For sssp in-order, the hit-latency cost (+0.5393 CPI) **exceeds** the capacity
benefit (−0.4391), so C is worse than A by 0.10 CPI. sssp hits in the L2 87.5 %
of the time; every one of those hits pays 6 extra cycles with nothing to overlap
them against, and there were not enough misses saved to compensate. For bfs the
same arithmetic goes the other way — 0.2431 against 0.8598 — because bfs saves
far more misses (Task 2's Δm of 0.22 against 0.05) *and* has fewer hits to pay
the penalty on.

Note that sssp's hit-latency cost in-order (0.5393 CPI) is more than twice bfs's
(0.2431), for the same +6 cycles. That is the hit-count difference showing up
directly: the kernel with the better locality is the one most damaged by making
hits slower.

## What out-of-order execution was doing to the Task 1 result

**Three things, all of which flattered the STT-MRAM configuration.**

1. **It concealed about half the miss latency the larger cache eliminates.**
   The raw memory-system improvement is roughly twice what Task 1's IPC numbers
   show — O3 had already recovered the other half through overlap.

2. **It concealed about two thirds of the hit-latency penalty**, which is the
   entire cost side of the trade. This dominates: it is why the *net* advantage
   was larger under O3 despite the benefit also being discounted.

3. **It changed the miss rate itself.** bfs's L2 miss rate is 2.5–3.8 points
   higher under O3 (41.01 % vs 38.54 % for A) because speculative execution
   issues accesses down mispredicted paths that never retire. Those are real
   L2 traffic and real DRAM traffic, and they do not appear on an in-order core
   at all. sssp shows almost none of this (0.65 points, and zero at 8 MB) —
   consistent with delta-stepping's branch behaviour being far more predictable
   than BFS's frontier tests.

**The honest statement for Task 4** is that the Task 1 result is
core-dependent, and in a specific direction: the STT-MRAM L2 looks best on an
aggressive out-of-order core, which is the machine most able to hide the very
penalty the technology imposes. On a simpler core — an embedded or in-order
design, precisely the kind where a non-volatile last-level cache is most often
proposed for its leakage — the same trade is marginal for bfs and negative for
sssp. The leakage argument from Part C and the performance argument from Part E
point at different machines.

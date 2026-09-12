# Part D, Task 1 — Ramulator on the real L2 miss stream

Ramulator 2.0a, DDR4_8Gb_x8, 1 channel, 2 ranks, DDR4_3200AA, FR-FCFS,
all-bank refresh, open-row policy, RoBaRaCoCh mapping.

**The trace is the real one.** It comes from a `CommMonitor` on gem5's L2
memory-side port in the SRAM 2 MB / 6-cycle baseline (Part E config A), not
from a synthetic generator. Provenance, the exact agreement with gem5's own
counters, and the one approximation on the write side are in `../findings.md`.

## Results

First 100 000 DRAM accesses of each kernel's detailed region.

| Stream | cycles | reads | writes | write share | read_latency total | **avg read latency** | row-buffer hit rate |
|---|---|---|---|---|---|---|---|
| **bfs** | 643 601 | 87 065 | 12 935 | 12.9 % | 23 759 537 | **272.9** | **82.6 %** |
| **sssp** | 884 695 | 82 486 | 17 514 | 17.5 % | 44 983 407 | **545.3** | **74.6 %** |

Latencies are DRAM command cycles; tCK = 625 ps at DDR4-3200, so 272.9 cycles
is 171 ns and 545.3 is 341 ns.

Averages are computed by hand as `read_latency_0 / total_num_read_requests`.
`stats.py` also prints Ramulator's own `avg_read_latency_0` — 13.95 and 19.21 —
and **those are wrong by ~20x**; the denominator counts retries, not requests
(`../findings.md`). Ramulator 2.0 has no write-latency statistic at all, so the
task's "total read/write latency" can only be answered for reads.

## The write ratio is a workload property, not an assumption

The synthetic traces used a flat 25 % writes for every stream. The real ones
differ from each other and from that guess: **bfs 12.9 %, sssp 17.5 %**, taken
from `system.l2.writebacks::total` in each kernel's own gem5 run.

The difference is structural. bfs spends most of its traffic streaming the
29 MB read-only CSR edge array, so most evicted lines are clean and never
become DRAM writes. sssp repeatedly updates `dist[]` during delta-stepping, so
a larger fraction of its evictions carry dirty data. A guessed constant could
not have produced that.

## Row-buffer behaviour

Both kernels have **high row locality** — 82.6 % and 74.6 %. That is far from
the synthetic `rand` bracket (0.1 %) and close to the `seq` end (99.1 %), and
it is the single most important thing the real trace changes: an L2 miss stream
from a graph kernel is nothing like random.

The reason is that an L2 miss stream is *not* the program's access stream. The
L1 and L2 have already absorbed the short-range reuse; what reaches DRAM is
dominated by the CSR edge array being walked in address order, one 64 B line
after another. Consecutive misses therefore land in the same DRAM row far more
often than the scattered vertex access pattern would suggest.

## Does the miss traffic fit in one DDR4 channel?

Against the channel's 25.6 GB/s peak (3200 MT/s x 8 B):

| Stream | cycles/access | time | bandwidth | channel utilisation |
|---|---|---|---|---|
| bfs | 6.44 | 402.3 us | **15.91 GB/s** | **62.2 %** |
| sssp | 8.85 | 552.9 us | **11.57 GB/s** | **45.2 %** |

**It fits, with headroom, but not comfortably.** A saturating L2 miss stream
occupies 45–62 % of one DDR4-3200 channel. bfs is the heavier of the two
despite having *better* row locality, because at 75.8 % L2 miss rate (Part E)
it generates far more misses per instruction than sssp does.

Neither kernel is bus-bound: at nBL = 4 the data bus could sustain 4.00
cycles/access, and both run well above that (6.44 and 8.85). The gap is what
Tasks 2–4 account for.

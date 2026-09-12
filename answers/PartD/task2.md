# Part D, Task 2 — FR-FCFS to FCFS

Same config as Task 1, one line changed: `Scheduler: { impl: FCFS }`. Ramulator
2.0a ships no FCFS, so the scheduler had to be written — `fcfs_scheduler.cpp`,
35 lines, FR-FCFS with the first-ready half removed (`../findings.md`).

## Results

| Stream | Scheduler | cycles | cyc/access | avg read latency | row-buffer hit rate |
|---|---|---|---|---|---|
| **bfs** | FR-FCFS | 643 601 | 6.44 | 272.9 | 82.6 % |
| **bfs** | FCFS | 1 516 950 | 15.17 | **606.3** | **80.6 %** |
| **sssp** | FR-FCFS | 884 695 | 8.85 | 545.3 | 74.6 % |
| **sssp** | FCFS | 1 845 532 | 18.46 | **1032.6** | **72.6 %** |

| Stream | execution time | avg read latency |
|---|---|---|
| bfs | **2.36x slower** | 272.9 → 606.3 cycles (171 → 379 ns), **2.22x** |
| sssp | **2.09x slower** | 545.3 → 1032.6 cycles (341 → 645 ns), **1.89x** |

Channel utilisation collapses with it: bfs 62.2 % → 26.4 %, sssp 45.2 % →
21.7 %. Over half the DRAM bandwidth is lost to scheduling policy alone, on
identical hardware with an identical timing table.

## The row-buffer hit rate barely moves

The task predicts it will collapse. It does not:

| Stream | FR-FCFS | FCFS | change |
|---|---|---|---|
| bfs | 82.6 % | 80.6 % | **−2.0 points** |
| sssp | 74.6 % | 72.6 % | **−2.0 points** |

A 2-point drop cannot explain a 2.4x slowdown. **Row-buffer hit rate is not the
mechanism** — and the real traces make that case far more sharply than the
synthetic ones did, because here both streams have genuine row locality to
lose and still barely lose any.

The reason it survives is that these streams arrive *already* in near-row
order. The CSR edge array is walked in address order, so consecutive misses
mostly target the same open row whatever order the controller picks them in.
Reordering had little to find, so removing reordering costs little.

## Explanation in terms of tRCD and tRP

DDR4_3200AA: nCL = 22, nRCD = 22, nRP = 22, nRAS = 52, nRC = 74, nBL = 4,
nCCD_S = 4, nCCD_L = 8.

| Case | Commands | Cycles to data |
|---|---|---|
| Row hit | `RD` | nCL + nBL = **26** |
| Row miss (bank idle) | `ACT`, `RD` | nRCD + nCL + nBL = **48** |
| Row conflict (wrong row open) | `PRE`, `ACT`, `RD` | nRP + nRCD + nCL + nBL = **70** |

Converting a conflict to a hit is worth **nRP + nRCD = 44 cycles = 27.5 ns**,
and a bank is unavailable for nRC = 74 cycles between activations.

Check that against the measurement. bfs loses 2.0 points of hit rate over
100 000 accesses — about 2 000 extra conflicts, worth 2 000 x 44 = 88 000
cycles. The observed slowdown is 873 349 cycles. **Lost row hits account for
10 % of the damage.** For sssp the figure is similar: ~2 000 extra conflicts
against 960 837 cycles lost, about 9 %.

### Where the other 90 % comes from

Head-of-line blocking. FCFS hands the controller the oldest request whatever
its state. If that request needs `PRE` + `ACT`, the controller issues nothing
for nRP + nRCD = 44 cycles — and during those 44 cycles it will not issue a
command for any *other* request either, including ones whose bank is idle and
whose row is already open.

With 2 ranks x 4 bank groups x 4 banks = 32 banks and RoBaRaCoCh spreading
accesses evenly across all of them, FR-FCFS overlaps the `ACT`/`PRE` of one
bank with the `RD` of another: 32 banks' worth of tRCD and tRP hidden behind
each other. FCFS serialises them into one queue, so each stall is exposed end
to end instead of overlapped. bfs goes from 6.44 to 15.17 cycles per access —
and 15.17 is close to what you get when a meaningful share of accesses pay
their 44-cycle penalty in the open.

**Summary in tRCD/tRP terms:** FR-FCFS wins twice. It *avoids* nRP + nRCD by
batching accesses to an open row — worth 44 cycles each, but only ~10 % of the
gap on these traces. And it *hides* the nRP + nRCD it cannot avoid by issuing
those commands on banks that are idle — worth the other ~90 %. The second
effect dominates, and it is invisible in the row-buffer hit rate, which is
exactly why the statistic the task points at is the wrong one to watch.

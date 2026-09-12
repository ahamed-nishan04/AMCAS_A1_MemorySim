# Part D, Task 3 — Row bits below bank bits

`AddrMapper: { impl: RoBaRaCoCh }` → `{ impl: ChRaBaRoCo }`. Scheduler back to
FR-FCFS, everything else as Task 1.

Field order, low bit first, for this organisation (DDR4_8Gb_x8, 2 ranks: 0
channel bits, 1 rank, 2 bank-group, 2 bank, 16 row, 7 column after the 64 B
transfer granularity):

| Mapping | Byte-address bit assignment |
|---|---|
| `RoBaRaCoCh` | col 6–12, **rank 13, bg 14–15, bank 16–17**, row 18–33 |
| `ChRaBaRoCo` | col 6–12, **row 13–28**, bank 29–30, bg 31–32, rank 33 |

## The cost

| Stream | Mapping | cycles | cyc/access | avg read latency | bandwidth | utilisation |
|---|---|---|---|---|---|---|
| bfs | RoBaRaCoCh | 643 601 | 6.44 | 272.9 (171 ns) | 15.91 GB/s | 62.2 % |
| bfs | ChRaBaRoCo | 2 067 835 | 20.68 | **816.0 (510 ns)** | 4.95 GB/s | 19.3 % |
| sssp | RoBaRaCoCh | 884 695 | 8.85 | 545.3 (341 ns) | 11.57 GB/s | 45.2 % |
| sssp | ChRaBaRoCo | 2 517 773 | 25.18 | **1435.0 (897 ns)** | 4.07 GB/s | 15.9 % |

| Stream | slowdown | latency |
|---|---|---|
| bfs | **3.21x** | **2.99x** |
| sssp | **2.85x** | **2.63x** |

## The row-buffer hit rate goes *up*

| Stream | RoBaRaCoCh | ChRaBaRoCo | change |
|---|---|---|---|
| bfs | 82.6 % | **83.0 %** | **+0.4 points** |
| sssp | 74.6 % | **76.9 %** | **+2.3 points** |

**Performance collapses by a factor of three while the row-buffer hit rate
improves.** This is the cleanest result in Part D, and it is only visible with
the real traces — the synthetic streams showed hit rate falling slightly, which
left room to argue the two were connected. Here they move in *opposite*
directions, so no causal story linking them survives.

The hit rate rises because burying the bank bits above bit 28 means a 256 MB
working set never changes bank: every access goes to bank 0, whose row buffer
now serves a stream that used to be spread over 32 banks. More consecutive
accesses to one row buffer, marginally better locality — on a machine doing one
thing at a time.

## Quantified against the timing constraints

| Bound | Constraint | Cycles/access |
|---|---|---|
| Data bus | nBL | 4.00 |
| Column commands, same bank group | nCCD_L | 8.00 |
| Activations, one bank | **nRC** | **74.00** |

| Stream | RoBaRaCoCh | ChRaBaRoCo |
|---|---|---|
| bfs | 6.44 | **20.68** |
| sssp | 8.85 | **25.18** |

Under ChRaBaRoCo both kernels are **activation-bound on a single bank**. They
do not reach the full 74 cycles/access that a 100 %-conflict stream would,
precisely *because* their row locality is high — at 83 % hits, only ~17 % of
accesses need a new activation, and 0.17 x 74 ≈ 12.6 cycles/access of
activation cost, plus column and refresh overhead, lands near the observed 20.7.

That is the whole mechanism stated exactly: **with one bank, every activation
is exposed; with 32 banks, activations overlap with other banks' data
transfers.** The conflicts did not increase — they stopped being hidden.

The measured overlap factor under RoBaRaCoCh is 20.68 / 6.44 = **3.2 banks deep
for bfs** and 2.8 for sssp. Lower than the 14x the synthetic `rand` stream
achieved, and for a good reason: a stream with 83 % row hits does not *need*
deep bank parallelism, because most of its accesses never activate at all. Bank
parallelism pays in proportion to how often you activate.

## Why the real traces lose less than the synthetic worst case

Synthetic `rand` lost **15.6x** to this change; bfs loses 3.21x. The difference
is row locality. `rand` was 100 % conflicts spread over 32 banks — every access
paying tRC, perfectly overlapped, so collapsing to one bank exposed all of it.
The real streams pay tRC on only ~17–25 % of accesses, so there is far less
hidden cost to expose.

**The synthetic bracket overstated the mapping's importance by ~5x.** The
mechanism is identical and the conclusion — that address mapping is worth more
than scheduler choice — still holds (3.21x against 2.36x for bfs). But the real
magnitude is 3x, not 15x, and only the real trace could establish that.

## The three results together

Across Tasks 1–3, on the same DRAM and the same 100 000 real accesses:

| Knob | bfs best | bfs worst | spread |
|---|---|---|---|
| Scheduler (Task 2) | 6.44 | 15.17 cyc/access | 2.36x |
| Address mapping (Task 3) | 6.44 | 20.68 | **3.21x** |

Neither is a DRAM-device property. Both are decisions in the memory controller,
and the worse of them costs more than tripling the memory time of a real
workload — larger than any bitcell difference Part C measured except leakage.
The timing table is identical in every row; only the order in which legal
commands get issued changed.

# Part D, Task 4 — Double the channel count

`org: { ..., channel: 2 }`, everything else as Task 1 (FR-FCFS, RoBaRaCoCh,
DDR4_3200AA). Peak bandwidth goes 25.6 → 51.2 GB/s.

## Throughput more than doubles, and latency improves too

| Stream | channels | cycles | cyc/access | avg read latency | bandwidth | % of peak |
|---|---|---|---|---|---|---|
| bfs | 1 | 643 601 | 6.44 | 272.9 (171 ns) | 15.91 GB/s | 62.2 % |
| bfs | 2 | **296 305** | **2.96** | **203.1 (127 ns)** | 34.56 GB/s | 67.5 % |
| sssp | 1 | 884 695 | 8.85 | 545.3 (341 ns) | 11.57 GB/s | 45.2 % |
| sssp | 2 | **391 529** | **3.92** | **370.1 (231 ns)** | 26.15 GB/s | 51.1 % |

| Stream | throughput | latency |
|---|---|---|
| bfs | **2.17x — superlinear** | **1.34x better** |
| sssp | **2.26x — superlinear** | **1.47x better** |

Two results here differ from what the synthetic traces showed, and both are
more interesting.

**Throughput scaling is superlinear.** Doubling the channels more than doubles
the throughput (2.17x and 2.26x). Channel utilisation *rises* — 62.2 → 67.5 %
for bfs — so the second channel is not merely adding capacity, it is making
each channel work better. Splitting one address stream across two channels
halves the per-channel request rate, which shortens queues, which gives
FR-FCFS a *less* congested window to schedule in and reduces read/write
turnaround pressure per channel.

**Latency improves, by 26–32 %.** Under the synthetic open-loop traces it did
not move at all: `LoadStoreTrace` retried every tick, so both queues stayed
saturated and Little's law held W constant. The real traces have finite,
bursty arrival structure, so the extra service capacity actually drains the
queue rather than just absorbing more offered load. That is a genuine
qualitative difference between a constructed stream and a real one, and it is
the clearest single argument in Part D for why the real trace was worth
obtaining.

## Which timing parameter is binding

Halving each timing parameter one at a time, at 2 channels, versus that
baseline. Ramulator 2.0a accepts individual overrides alongside a preset
(`DDR4.cpp:418`):

```yaml
timing:
  preset: DDR4_3200AA
  nCCDL: 4
```

| Parameter halved | bfs | sssp |
|---|---|---|
| nRCD 22 → 11 | 1.05x | 1.06x |
| nRP 22 → 11 | 1.05x | 1.05x |
| nRAS 52 → 26 | **0.99x** | 1.00x |
| nRC 74 → 37 | **1.00x** | **1.00x** |
| **nCCD_L 8 → 4** | **1.13x** | **1.31x** |
| nBL 4 → 2 | 1.10x | 1.10x |

**The binding parameter is tCCD_L for both kernels**, and decisively so for
sssp (1.31x). That follows directly from Task 1's row-buffer result: streams
with 75–83 % row hits issue long runs of back-to-back column commands into one
bank group, where tCCD_L = 8 paces them while the data bus wants one every
nBL = 4. Half the bus sits idle, and no channel count changes per-channel
pacing. tRCD and tRP together are worth only ~5 % each, because with high row
locality most accesses never activate.

Two rows are worth reading rather than skipping:

**nRC halved changes nothing, exactly 1.00x for both.** Not because bank cycle
time is irrelevant but because it is redundant: the ACT→PRE→ACT path is already
constrained by nRAS + nRP = 52 + 22 = 74, which *is* nRC. Overriding nRC alone
leaves the binding pair untouched. A sensitivity sweep has to respect which
constraints are derived from which — this is the trap in the method.

**nRAS halved makes bfs slightly *slower* (0.99x).** Shortening the minimum
time a row must stay open lets FR-FCFS precharge sooner, closing rows that
later queued requests would have hit. On a stream with 82.6 % row locality that
is a real cost. A timing parameter getting tighter is not always a speedup, and
a sweep that only looks for improvements will miss it.

Full stats dumps for all 14 runs are kept in `sens/`, so every column of this
table is regenerable — `sweep_timings.py` writes complete dumps rather than the
`read_latency`-only fragments the earlier sweep left behind.

## How to determine this from the output, in order

1. **Compare cycles/access per channel.** bfs goes 6.44 → 2.96 total, i.e.
   5.92 per channel against 6.44 — *better* than before, so the bottleneck was
   partly queueing rather than purely inside the channel. That is the signature
   of superlinear scaling and tells you more channels buy more than bandwidth.
2. **Check whether latency moved.** It did (1.34x, 1.47x), which rules out the
   pure open-loop saturated-queue regime and means the arrival process has
   structure worth modelling.
3. **Compare the row statistics** at 1 and 2 channels. Nearly unchanged, so the
   extra channel changed scheduling opportunity, not row behaviour.
4. **Sweep the timings one at a time**, remembering that derived constraints
   (nRC = nRAS + nRP) will not respond when overridden alone, and that some
   parameters help in the wrong direction.

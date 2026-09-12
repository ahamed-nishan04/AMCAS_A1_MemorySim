# Part E, Task 2 — Which kernel does the 4x-larger / 2x-slower trade win for?

Config A is SRAM 2 MB at 6 cycles; config C is the iso-area STT-MRAM L2, 8 MB
at 12 cycles — 4x the capacity, 2x the hit latency, the trade exactly as the
task frames it.

| Kernel | IPC, A → C | Runtime | L2 miss rate, A → C |
|---|---|---|---|
| **bfs** | 0.6799 → 0.9444 | **28.0 % faster** | 75.76 % → 31.53 % |
| **sssp** | 0.7489 → 0.7183 | **4.3 % slower** | 14.01 % → 11.27 % |

**It wins decisively for bfs (+38.9 % IPC) and loses for sssp (−4.1 %).** The
same hardware change, the same graph, opposite verdicts.

## The property that decides it

Not the miss rate. Not the working-set size. **The fraction of the working set
whose reuse distance falls between 2 MB and 8 MB** — the share of accesses that
miss in a 2 MB cache and hit in an 8 MB one. Nothing else about the kernel
matters to this trade, because capacity can only convert misses into hits in
that window.

The trade is worth taking when

```
    L_A + m_A · P   >   L_C + m_C · P
```

with L the hit latency, m the miss rate and P the miss penalty. Break-even:

```
    P* = ΔL / Δm = (12 − 6) / (m_A − m_C)
```

| Kernel | Δm (miss rate captured) | **P\*** |
|---|---|---|
| **bfs** | **44.23 points** | **13.6 cycles** |
| **sssp** | **2.74 points** | **219.0 cycles** |

**Δm differs by 16x, and that is the entire answer.** A DDR4-2400 miss costs a
couple of hundred cycles, so bfs clears its threshold by more than an order of
magnitude while sssp does not clear it at all at realistic penalties.

Expressed as AMAT:

| P (cycles) | bfs: A → C | sssp: A → C |
|---|---|---|
| 50 | 43.9 → 27.8 (**1.58x better**) | 13.0 → 17.6 (**0.74x — worse**) |
| 100 | 81.8 → 43.5 (**1.88x**) | 20.0 → 23.3 (0.86x — worse) |
| 200 | 157.5 → 75.1 (**2.10x**) | 34.0 → 34.5 (0.98x — worse) |
| 219 | — | **break-even** |
| 300 | 233.3 → 106.6 (**2.19x**) | 48.0 → 45.8 (1.05x) |

bfs is better at every penalty in the range and improves as DRAM gets slower.
sssp needs a miss penalty above **219 cycles** before the trade pays — slower
than the DDR4-2400 in this system delivers. **On a faster DRAM, or with more
memory-level parallelism, sssp's loss would only deepen.**

## Why bfs has reuse in that window and sssp does not

The graph is 262 143 nodes and 3 805 449 undirected edges:

| Structure | Size |
|---|---|
| One 4 B field per vertex (bfs `parent`, sssp `dist`) | 1.00 MB |
| CSR row offsets, 8 B per vertex | 2.00 MB |
| Visited bitmap, 1 bit per vertex | 32 kB |
| CSR edge array, 4 B x 2E (bfs) | 29.0 MB |
| Weighted edge array, 8 B x 2E (sssp) | 58.1 MB |

The edge arrays are 29–58 MB. They do not fit in 2 MB or 8 MB, they are
traversed once per visit, and they stream. **No L2 size in this comparison
changes what happens to them.** The only thing 8 MB can capture that 2 MB
cannot is the vertex-indexed set: roughly 3 MB of `parent`/`dist`, offsets and
bitmap — larger than 2 MB, smaller than 8 MB. **It sits precisely in the window
the trade operates on**, which is why the effect exists at all.

The two kernels touch it completely differently.

**bfs sweeps the whole vertex space every level.** GAPBS uses
direction-optimising BFS: the bottom-up phase scans *all* unvisited vertices,
checking each one's neighbours against the frontier bitmap; the top-down phase
scatters writes across `parent` in frontier order. Both touch the entire ~3 MB
set on every level, in essentially random order within it. At 2 MB that set
thrashes — each level evicts what the previous level loaded, so the reuse
distance is the size of the set, which exceeds the cache. At 8 MB it is
resident across levels. That is the 75.8 % → 31.5 % collapse: **a working set
one size too big became resident.**

A 75.8 % L2 miss rate is the signature of exactly this. Three quarters of
everything that survives two levels of cache still misses — that is a working
set being cyclically destroyed, not a streaming workload.

**sssp works one bucket at a time.** Delta-stepping processes a bucket of
vertices whose tentative distances fall in a narrow range, and a bucket is a
small fraction of the vertex space. The active set at any instant is well under
1 MB, so **2 MB already holds it** — which is why sssp's baseline miss rate is
14.0 % against bfs's 75.8 % on the same graph. Its misses are dominated by the
58 MB weighted edge array, and enlarging the L2 does nothing for those. The
2.74 points it does gain are residual `dist[]` reuse that 2 MB was narrowly
dropping — real, but nowhere near enough to pay for doubled hit latency on the
86 % of accesses that hit.

Note the inversion this produces: **the kernel with better locality is the one
the trade hurts.** sssp hits in L2 86 % of the time, so it pays the +6-cycle
penalty on 86 % of its accesses while saving misses on only 2.7 %. Good
locality is what makes slower hits expensive.

## The general statement

**Cache capacity pays when a workload has a reuse-distance cliff inside the
window you are widening.** bfs has one between 2 MB and 8 MB, so 4x capacity is
worth 2x hit latency several times over. sssp's cliff is below 2 MB — already
captured — and its remaining traffic is a 58 MB stream no realistic L2 will
hold, so it pays the latency and receives almost nothing.

Note where this leaves the technology. **Nothing in this analysis is about
STT-MRAM.** The MRAM cell supplied the area that bought the capacity, and the
sensing path supplied the latency that had to be paid — but which side wins is
decided entirely by the reuse-distance distribution of the program. The same
verdict would follow from any technology offering the same 4x/2x exchange rate.
**The bitcell sets the exchange rate; the workload decides whether the exchange
is worth making** — and on these two kernels it decides opposite ways.

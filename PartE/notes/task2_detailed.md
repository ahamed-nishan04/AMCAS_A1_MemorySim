# Part E, Task 2 — Which kernel does the 4×-larger / 2×-slower trade win for?

Config A is SRAM 2 MB at 6 cycles; config C is the iso-area STT-MRAM L2, 8 MB at
12 cycles — 4× the capacity, 2× the hit latency, the trade exactly as the task
frames it.

| Kernel | IPC, A → C | Runtime | L2 miss rate, A → C |
|---|---|---|---|
| **bfs** | 0.6628 → 0.8469 | **21.7 % faster** | 41.01 % → 19.38 % |
| **sssp** | 0.6410 → 0.6638 | 3.4 % faster | 17.43 % → 12.53 % |

**It wins for both, but decisively only for bfs — +27.8 % IPC against +3.6 %, a
factor of eight difference in payoff from the same hardware change.**

## The property that decides it

Not the miss rate. Not the working-set size. **The fraction of the working set
whose reuse distance falls between 2 MB and 8 MB** — the share of accesses that
miss in a 2 MB cache and hit in an 8 MB one. Everything else about the kernel is
irrelevant to this trade, because capacity can only convert misses into hits in
that window.

The trade is worth taking when

```
    L_A + m_A · P   >   L_C + m_C · P
```

with L the hit latency, m the miss rate and P the miss penalty. Rearranged, the
break-even penalty is

```
    P* = ΔL / Δm = (12 − 6) / (m_A − m_C)
```

| Kernel | Δm (miss rate captured) | **P\*** |
|---|---|---|
| bfs | 0.2163 | **27.7 cycles** |
| sssp | 0.0490 | **122.4 cycles** |

A DDR4-2400 miss costs a couple of hundred cycles, so both clear their
threshold — but bfs clears it by roughly 7×, sssp by less than 2×. **Δm is the
whole answer**, and P\* is the clean way to state it: the extra capacity has to
save enough misses to pay for the slower hits, and bfs saves 4.4× as many.

Expressed as AMAT at a few plausible penalties:

| P (cycles) | bfs: A → C | sssp: A → C |
|---|---|---|
| 50 | 26.5 → 21.7 (1.22× better) | 14.7 → 18.3 (**0.81× — worse**) |
| 100 | 47.0 → 31.4 (1.50×) | 23.4 → 24.5 (0.96× — worse) |
| 150 | 67.5 → 41.1 (1.64×) | 32.1 → 30.8 (1.04×) |
| 200 | 88.0 → 50.8 (1.73×) | 40.9 → 37.1 (1.10×) |
| 300 | 129.0 → 70.1 (1.84×) | 58.3 → 49.6 (1.18×) |

sssp's verdict is a function of the memory system it sits in front of. On a
faster DRAM, or with more memory-level parallelism hiding the misses, **the same
STT-MRAM L2 would lose for sssp and still win for bfs.** bfs's verdict is stable
across the whole range.

## Why bfs has more reuse in that window and sssp does not

The graph is 262 143 nodes and 3 805 449 undirected edges. Its data structures:

| Structure | Size |
|---|---|
| One 4 B field per vertex (bfs `parent`, sssp `dist`) | 1.00 MB |
| CSR row offsets, 8 B per vertex | 2.00 MB |
| Visited bitmap, 1 bit per vertex | 32 kB |
| CSR edge array, 4 B × 2E (bfs) | 29.0 MB |
| Weighted edge array, 8 B × 2E (sssp) | 58.1 MB |

The edge arrays are 29–58 MB. They do not fit in 2 MB or in 8 MB, they are
traversed once per visit, and they stream. **No L2 size in this comparison
changes what happens to them.** The only thing 8 MB can capture that 2 MB cannot
is the vertex-indexed set: roughly 3 MB of `parent`/`dist`, offsets and bitmap.

That set is ~3 MB — larger than 2 MB, smaller than 8 MB. **It sits precisely in
the window the trade operates on**, which is why the effect exists at all.

The two kernels touch it completely differently:

**bfs sweeps the whole vertex space every level.** GAPBS uses
direction-optimising BFS: the bottom-up phase scans *all* unvisited vertices and
checks each one's neighbours against the frontier bitmap, and the top-down phase
scatters writes across `parent` in whatever order the frontier dictates. Both
touch the entire 3 MB set on every level, with essentially random order within
it. At 2 MB that set thrashes — each level evicts what the previous level
loaded, so the reuse distance is the size of the set, which exceeds the cache.
At 8 MB it is resident across levels. That is the 41 % → 19 % miss rate: **a
working set that was one size too big became resident.**

**sssp works one bucket at a time.** Delta-stepping processes a bucket of
vertices whose tentative distances fall in a narrow range, and a bucket is a
small fraction of the vertex space. The active vertex set at any instant is well
under 1 MB, so **2 MB already holds it** — which is why sssp's baseline miss rate
is 17.4 % against bfs's 41.0 % on the same graph. Its misses are dominated by
the 58 MB weighted edge array, and enlarging the L2 to 8 MB does nothing for
those. The 28 % improvement it does get is the residual: bucket-to-bucket reuse
of `dist` entries that 2 MB was narrowly dropping.

## The general statement

**Cache capacity pays when a workload has a reuse-distance cliff inside the
window you are widening.** bfs has one between 2 MB and 8 MB, so 4× capacity is
worth 2× hit latency several times over. sssp's cliff is below 2 MB — already
captured — and its remaining traffic is a 58 MB stream that no realistic L2 will
hold, so it is nearly indifferent, and its verdict flips with the DRAM behind it.

Note where this leaves the technology. **Nothing in this analysis is about
STT-MRAM.** The MRAM cell supplied the area that bought the capacity, and the
sensing path supplied the latency that had to be paid — but which side wins is
decided entirely by the reuse-distance distribution of the program. The same
verdict would follow from any technology offering the same 4×/2× exchange rate.
That is the point Task 4 has to carry: the bitcell sets the exchange rate, the
workload decides whether the exchange is worth making.

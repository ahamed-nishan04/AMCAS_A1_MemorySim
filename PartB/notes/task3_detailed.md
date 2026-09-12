# Part B, Task 3 — Same cache, three objectives

2 MB / 64 B / 8-way / 4 banks / 45 nm / 350 K / itrs-hp throughout. Only the
objective lines change. Run with `objsweep.sh`.

## First: the ED² flag overrides the weights entirely

`Ucache.cc:find_optimal_uca` branches on `-Optimize ED or ED^2` **before** it
ever looks at the weights:

```c
if (g_ip->ed == 2) cost = (D/Dmin)*(D/Dmin)*(E/Emin);   // weights unused
else               cost = d*(D/Dmin) + c*(C/Cmin) + ... // and check_uca_org()
```

With `ed == 1` or `2` the weighted sum is skipped and so is `check_uca_org`, the
function that enforces the `-deviate` line. **The Task 1 config's
`0:0:0:100:0` cycle-time weight therefore did nothing** — the baseline was
selected purely on delay² × dynamic energy. To make a weighted objective take
effect at all, `-Optimize` must be set to `"NONE"`. That is the real answer to
"why does the optimal organisation change": for two of the three runs it is a
different code path, not just different coefficients.

Second wrinkle: under `"NONE"`, the stock `-deviate` line
(`20:100000:...`) discards every candidate more than 20 % slower than the fastest
one. Left in place, "pure area" is really "smallest area among the fast ones". I
relaxed the deviations for the two pure-weight runs so the weight alone picks the
winner, and kept a fourth run (`area20`) with the stock filter to show the
difference.

## Results

| Objective | Ndwl/Ndbl/Nspd | Ntwl/Ntbl/Ntspd | Access (ns) | Cycle (ns) | Read E (pJ) | Leakage (mW) | Area (mm²) | Cell efficiency |
|---|---|---|---|---|---|---|---|---|
| **Pure delay** | **4/2/1** | 2/2/2 | 2.892 | 2.652 | 898.4 | 2243 | 10.970 | 56.8 % |
| **ED²P** (baseline) | **4/2/1** | 2/2/2 | 2.902 | 2.652 | 792.9 | 2251 | 11.474 | 54.3 % |
| **Pure area** | **2/2/1** | 2/2/2 | 4.231 | 8.532 | 790.0 | 2193 | 9.219 | 67.7 % |
| Pure area, 20 % delay filter | 2/2/1 | 2/2/2 | 3.355 | 8.528 | 796.7 | 2196 | 9.245 | 67.5 % |

Delay breakdown and geometry:

| Objective | H-tree (ns) | Array (ns) | Subarray length (mm) | H-tree E (pJ) | Bitline E (pJ) |
|---|---|---|---|---|---|
| Pure delay | 1.351 | 0.951 | 0.543 | 581 | 174 |
| ED²P | 1.355 | 0.951 | 0.543 | 585 | 87 |
| Pure area | 0.842 | 1.949 | 1.085 | 401 | 173 |

## Why the organisation moves

**Delay and ED² both pick Ndwl = 4; area picks Ndwl = 2.** Ndwl is the number of
wordline splits, so it sets how many mats the data array is cut into. Halving it
doubles the subarray length, 0.543 → 1.085 mm.

*Delay wants many small mats.* Splitting the wordline shortens both the wordline
and the bitline seen on any one access, so the array term is 0.951 ns at Ndwl = 4
against 1.949 ns at Ndwl = 2 — the delay through the array roughly doubles when
the subarray does, exactly as the RC-of-a-longer-wire argument predicts. The
price is replicated peripheral circuitry: every mat needs its own decoders,
precharge, and sense amplifiers, which is why cell efficiency drops to 54–57 %.

*Area wants few big mats.* Fewer mats amortise the peripheral overhead across
more cells; efficiency rises to 67.7 % and total area falls 11.47 → 9.22 mm², a
20 % saving. The array pays for it: access time rises 46 % and cycle time
**triples**, 2.65 → 8.53 ns, because the doubled bitline takes far longer to
precharge and restore. Cycle time is punished much harder than access time, which
is worth noting given that the baseline config nominally weighted cycle time.

*The interconnect partly self-compensates.* A smaller array has shorter global
wires, so the area-optimal organisation actually has the **faster** H-tree —
0.842 ns against 1.355 ns — and the cheaper one, 401 pJ against 585 pJ. That is
why total access time only degrades 46 % when the array term doubles, and it is
the same effect running in reverse from Task 2: array time and interconnect time
trade against each other as the partitioning changes.

**Why ED² lands next to pure delay.** Dynamic energy is nearly flat across these
organisations — 790, 793, 898 pJ across all four runs, under 14 % spread —
because the H-tree dominates it and the H-tree energy saving of the compact
organisation is almost exactly cancelled by its higher bitline energy (401 + 173
vs 585 + 87 pJ). Delay varies 46 %. In a product weighted D²·E, a term that
barely moves cannot outvote one that moves by half, so ED² is effectively a delay
objective here.

The two do differ, in one place: **Ndsam L2 = 2 for pure delay, 1 for ED²**. The
extra second-level sense-amp mux buys 10 ps (2.892 vs 2.902 ns) for 13 % more
read energy (898 vs 793 pJ). Pure delay takes any delay win at any energy cost;
ED² rejects a 0.3 % delay gain that costs 13 % energy. The Ndwl/Ndbl/Nspd triple
is identical — the objectives disagree about the sense path, not the array
partitioning.

## The point

There is no optimal cache, only the optimum of the objective. The same 2 MB
specification yields a 2.89 ns / 10.97 mm² design or a 4.23 ns / 9.22 mm² design
depending on one line of the config, and the mechanism is always the same trade:
peripheral replication against local wire length, with the global interconnect
moving the opposite way and softening the result. What the objective does is
choose where on that curve to stop.

# Part B, Task 3 — Same cache, three objectives

2 MB / 64 B / 8-way / 4 banks / 45 nm / 350 K / itrs-hp throughout. Only the
objective lines change.

A fourth run (`area20`) keeps the stock 20 % delay-deviation filter, to show what
that filter does to "pure area". Why the two pure-weight runs need their
deviations relaxed at all — and why the Task 1 config's cycle-time weight never
took effect — is in `../findings.md`; it matters for reading this table.

## The three winning triples

| Objective | **Ndwl/Ndbl/Nspd** | Ntwl/Ntbl/Ntspd | Access (ns) | Cycle (ns) | Read E (pJ) | Leakage (mW) | Area (mm²) | Cell efficiency |
|---|---|---|---|---|---|---|---|---|
| **Pure delay** | **4/2/1** | 2/2/2 | 2.892 | 2.652 | 898.4 | 2243 | 10.970 | 56.8 % |
| **ED²P** (baseline) | **4/2/1** | 2/2/2 | 2.902 | 2.652 | 792.9 | 2251 | 11.474 | 54.3 % |
| **Pure area** | **2/2/1** | 2/2/2 | 4.231 | 8.532 | 790.0 | 2193 | 9.219 | 67.7 % |
| Pure area, 20 % filter | 2/2/1 | 2/2/2 | 3.355 | 8.528 | 796.7 | 2196 | 9.245 | 67.5 % |

| Objective | H-tree (ns) | Array (ns) | Subarray length (mm) | H-tree E (pJ) | Bitline E (pJ) |
|---|---|---|---|---|---|
| Pure delay | 1.351 | 0.951 | 0.543 | 581 | 174 |
| ED²P | 1.355 | 0.951 | 0.543 | 585 | 87 |
| Pure area | 0.842 | 1.949 | 1.085 | 401 | 173 |

## Why the optimal organisation changes

**Delay and ED² both pick Ndwl = 4; area picks Ndwl = 2.** Ndwl is the number of
wordline splits, so it sets how many mats the data array is cut into. Halving it
doubles the subarray length, 0.543 → 1.085 mm.

*Delay wants many small mats.* Splitting the wordline shortens both the wordline
and the bitline seen on any one access, so the array term is 0.951 ns at Ndwl = 4
against 1.949 ns at Ndwl = 2 — the array delay roughly doubles when the subarray
does, as the RC-of-a-longer-wire argument predicts. The price is replicated
peripheral circuitry: every mat needs its own decoders, precharge and sense
amplifiers, which is why cell efficiency drops to 54–57 %.

*Area wants few big mats.* Fewer mats amortise the peripheral overhead across
more cells; efficiency rises to 67.7 % and total area falls 11.47 → 9.22 mm², a
20 % saving. The array pays for it: access time rises 46 % and cycle time
**triples**, 2.65 → 8.53 ns, because the doubled bitline takes far longer to
precharge and restore.

*The interconnect partly self-compensates.* A smaller array has shorter global
wires, so the area-optimal organisation has the **faster** H-tree — 0.842 ns
against 1.355 ns — and the cheaper one, 401 pJ against 585 pJ. That is why total
access time only degrades 46 % when the array term doubles.

**Why ED² lands next to pure delay.** Dynamic energy is nearly flat across these
organisations — 790, 793, 898 pJ, under 14 % spread — because the H-tree
dominates it and the compact organisation's H-tree saving is almost exactly
cancelled by its higher bitline energy (401 + 173 vs 585 + 87 pJ). Delay varies
46 %. In a product weighted D²·E, a term that barely moves cannot outvote one
that moves by half, so ED² is effectively a delay objective here.

The two differ in one place: **Ndsam L2 = 2 for pure delay, 1 for ED²**. The
extra second-level sense-amp mux buys 10 ps (2.892 vs 2.902 ns) for 13 % more
read energy. Pure delay takes any delay win at any energy cost; ED² rejects a
0.3 % delay gain costing 13 % energy. The objectives disagree about the sense
path, not the array partitioning.

## The point

There is no optimal cache, only the optimum of the objective. The same 2 MB
specification yields a 2.89 ns / 10.97 mm² design or a 4.23 ns / 9.22 mm² design
depending on one line of the config, and the mechanism is always the same trade:
peripheral replication against local wire length, with the global interconnect
moving the opposite way and softening the result.

# Part B, Task 2 — Capacity sweep, 256 kB to 16 MB

Only `-size (bytes)` varies. Everything else stays at the Task 1 baseline: 64 B
blocks, 8-way, 1 R/W port, 4 UCA banks, 45 nm, 350 K, itrs-hp, ED², objective
0:0:0:100:0. Run with `sweep.sh`, figure from `plotB2.py`.

| Capacity | Access (ns) | Δ per doubling (ps) | Read energy (pJ) | Leakage (mW, all 4 banks) | Area (mm²) | Ndwl/Ndbl/Nspd |
|---|---|---|---|---|---|---|
| 256 kB | 2.417 | — | 658.0 | 361 | 4.96 | 4/2/1 |
| 512 kB | 2.485 | 67 | 679.0 | 632 | 5.95 | 4/2/1 |
| 1 MB | 2.634 | 149 | 716.6 | 1175 | 7.60 | 4/2/1 |
| 2 MB | 2.902 | 268 | 792.9 | 2250 | 11.47 | 4/2/1 |
| 4 MB | 3.531 | 629 | 930.1 | 4409 | 18.46 | 4/2/1 |
| 8 MB | 4.473 | 942 | 1219.8 | 8735 | 39.50 | 4/4/1 |
| 16 MB | 6.362 | 1890 | 1742.1 | 16978 | 74.67 | 2/8/1 |

![](figB2_capacity.png)

## Is "one gate delay per doubling" visible?

**No.** Two separate reasons, and they compound.

**The slope is far too steep.** At 45 nm ITRS-HP, FO4 is roughly 15 ps (see
below), so the Amrutur–Horowitz rule predicts ~15 ps per doubling and a total of
~90 ps across the whole six-doubling sweep. CACTI gives 3945 ps — the mean slope
is 658 ps per doubling, about **44 FO4**. On the left panel the reference line is
visually flat against the measured curve.

**The curve is not even linear in log₂(capacity),** which is what the rule
requires. The increments grow monotonically — 67, 149, 268, 629, 942, 1890 ps —
so each doubling costs more than the last. A constant-gate-delay law would give
seven equally spaced points on a straight line; the data is convex.

## Why

The rule assumes the array is repartitioned as it grows so that local wire
lengths stay roughly constant, leaving only the decoder's logarithmic depth to
grow. That holds for the array proper and it fails for everything outside it.

Here the cache stays at 4 banks by construction, so area grows 15× (4.96 →
74.67 mm²) and the H-tree that distributes addresses and collects data grows with
the linear dimension of that area, roughly √capacity. Interconnect is 40–54 % of
access time at every point in the sweep, and it is a √C term sitting on top of a
log C term. That is the convexity.

The right panel shows where the time goes. Comparing 256 kB to 16 MB:

| Component | 256 kB | 16 MB | Growth |
|---|---|---|---|
| H-tree in + out | 1.294 ns | 2.653 ns | 2.05× |
| Decoder + wordline + bitline + sense | 0.540 ns | 2.548 ns | 4.72× |
| Not itemised by CACTI | 0.583 ns | 1.161 ns | 1.99× |

Even the array term grows 4.7×, not the ~6 FO4 ≈ 0.09 ns the rule would allow,
because the organisation is only free to repartition in discrete steps. Ndwl ×
Ndbl stays at 4×2 from 256 kB all the way to 4 MB: each doubling in that range
doubles the subarray, doubling the bitline and wordline length, so the array
delay rises steadily instead of staying flat. CACTI finally repartitions at
8 MB (4×4) and 16 MB (2×8). The effect is visible as the array term freezing at
1.4406 ns from 4 MB to 8 MB — the added capacity is absorbed by splitting rather
than by longer local wires — and then the H-tree jumps 716 ps in the same step,
because more mats means a deeper distribution network. The cost moves between
the two terms; it does not go away.

The listed components sum to less than the reported access time (0.58 ns at
256 kB, 1.16 ns at 16 MB). CACTI does not itemise the inter-bank routing, way
multiplexing, and final output driver, so those are shown as a separate grey band
rather than silently dropped.

## FO4 reference

CACTI's own 45 nm ITRS-HP parameters (`tech_params/45nm.dat`): C_g_ideal =
6.78e-16 F/µm, C_fringe = 5e-17 F/µm, I_on_n = 2.047e-3 A/µm, V_dd = 1.0 V. A
first-order fanout-of-4 estimate, load = 4 × 3W × (C_g + 2C_fringe), drive =
I_on_n·W, and t = C·V/(I/2), gives ≈ 9 ps; adding junction self-loading puts it
in the 10–20 ps range, consistent with the usual 45 nm figure. 15 ps is used
above. **The conclusion is insensitive to the choice** — even at 25 ps the
measured slope is 26 FO4 per doubling, and no constant value can fit a convex
curve.

Note that CACTI's itrs-hp cell runs at V_dd = 1.0 V, not the 1.1 V used in
Part A's netlist.

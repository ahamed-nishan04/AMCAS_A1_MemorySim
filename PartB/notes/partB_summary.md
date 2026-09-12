# Part B — CACTI, 2 MB SRAM L2 at 45 nm

CACTI 7 (`HewlettPackard/cacti`, commit `1ffd8df`), config as specified: 2 MB,
64 B blocks, 8-way, 1 R/W port, 4 UCA banks, 45 nm, 350 K, itrs-hp cells and
peripherals.

**Answer to the Part B question: 2.90 ns, 11.47 mm², and 2.25 W of leakage** —
the leakage is the headline number, more than the whole rest of the design
budget would normally allow, and it is what Part E has to argue against.

### Table B1 — SRAM baseline (Task 1)

| Access | Cycle | Read energy | Write energy | Leakage | Area |
|---|---|---|---|---|---|
| 2.902 ns | 2.652 ns | 792.9 pJ | 851.2 pJ | 2250.5 mW | 11.474 mm² |

Organisation: data Ndwl 4 / Ndbl 2 / Nspd 1 / Ndcm 1 / Ndsam 8,1; tags Ntwl 2 /
Ntbl 2 / Ntspd 2. Area splits 10.271 mm² data + 0.387 mm² tag + 0.82 mm² routing.
**Leakage is reported per bank** — CACTI's line reads "of a bank" and means it;
the whole-cache figure is 4 × 562.632 mW, confirmed by a 1-bank re-run giving
2150.4 mW. Area and dynamic energy are already whole-cache.

Delay breakdown: H-tree in 0.850, decoder + WL 0.541, bitline 0.407, sense amp
0.003, H-tree out 0.505 ns. **Interconnect is 47 % of access time** — more than
the array itself.

### Table B2 — Capacity sweep (Task 2)

| Capacity | 256 kB | 512 kB | 1 MB | 2 MB | 4 MB | 8 MB | 16 MB |
|---|---|---|---|---|---|---|---|
| Access (ns) | 2.417 | 2.485 | 2.634 | 2.902 | 3.531 | 4.473 | 6.362 |
| Δ per doubling (ps) | — | 67 | 149 | 268 | 629 | 942 | 1890 |
| Area (mm²) | 4.96 | 5.95 | 7.60 | 11.47 | 18.46 | 39.50 | 74.67 |

**Amrutur & Horowitz's one gate delay per doubling is not visible, and it fails
twice.** The mean slope is 658 ps per doubling — roughly 44 FO4 at 45 nm, not
one — and the increments grow monotonically, so the curve is convex in
log₂(capacity) where the rule requires a straight line. No choice of FO4 fits a
curve that bends, which makes the conclusion robust to the FO4 estimate.

The rule assumes the array is repartitioned as it grows so local wires stay
short. Here bank count is pinned at 4, area grows 15×, and the H-tree grows with
the linear dimension of that area — a √C term stacked on a log C term.
Ndwl × Ndbl is stuck at 4×2 from 256 kB to 4 MB, so each doubling simply doubles
the subarray. CACTI finally repartitions at 8 MB (4×4) and 16 MB (2×8): the array
term freezes at exactly 1.4406 ns from 4 MB to 8 MB while the H-tree jumps
716 ps. The cost moves between the terms; it does not go away.

### Table B3 — Objective sweep (Task 3)

| Objective | Ndwl/Ndbl/Nspd | Access | Cycle | Read E | Area | Cell efficiency |
|---|---|---|---|---|---|---|
| Pure delay | 4/2/1 | 2.892 ns | 2.652 ns | 898.4 pJ | 10.970 mm² | 56.8 % |
| ED²P | 4/2/1 | 2.902 ns | 2.652 ns | 792.9 pJ | 11.474 mm² | 54.3 % |
| Pure area | 2/2/1 | 4.231 ns | 8.532 ns | 790.0 pJ | 9.219 mm² | 67.7 % |

**The `-Optimize ED^2` flag overrides the weights entirely.**
`Ucache.cc:find_optimal_uca` branches on it before reading the weighted sum, and
also skips `check_uca_org`, the function enforcing `-deviate`. The supplied
config's `0:0:0:100:0` cycle-time weight therefore did nothing — the baseline was
selected on delay² × dynamic energy alone. A weighted objective requires
`-Optimize "NONE"`, and under that the stock 20 % delay-deviation filter must be
relaxed or "pure area" is really "smallest area among the fast ones" (3.355 ns /
9.245 mm²).

Ndwl sets how many mats the array is cut into. Delay wants many small mats —
array term 0.951 ns — and pays in replicated decoders, precharge and sense amps.
Area wants few big mats to amortise that peripheral: 67.7 % cell efficiency and
20 % less silicon, paid for with a doubled subarray, array term 1.949 ns, and a
**tripled cycle time** because the longer bitline dominates precharge and restore.
The interconnect runs the other way — the compact design has the *faster* H-tree,
0.842 vs 1.355 ns — which is why access time degrades only 46 % when the array
term doubles. ED² lands next to pure delay because dynamic energy spans under
14 % across all organisations (the H-tree saving of the compact design is almost
exactly cancelled by its higher bitline energy) while delay spans 46 %; a term
that barely moves cannot outvote one that moves by half. The two disagree in one
place only: Ndsam L2 = 2 vs 1, where pure delay buys 10 ps for 13 % more energy.

### Bitline hand-check (Task 4)

Bitline = 512 rows × 0.657 µm = 336.4 µm; CACTI's own 45 nm local-wire values
r = 4.2024 Ω/µm, c = 2.580e-16 F/µm give R = 1413.6 Ω, C = 86.8 fF.

| 0.38·R·C·L² | with CACTI's C_bl (115.5 fF) | CACTI | Discrepancy |
|---|---|---|---|
| 46.6 ps | 62.0 ps | 406.9 ps | **8.7×** |

**The effect the hand calculation omits is the finite drive resistance of the
accessed cell.** 0.38·R·C·L² is the 50 % delay of a distributed RC line driven by
an ideal source. The bitline discharges *through the cell*: access transistor in
series with the storing inverter's pull-down, 12 516 + 7 883 = 20 398 Ω, **14.4×
the 1414 Ω of metal**. The wire term `R_bl·C_bl/2` is 3.3 % of τ. Three effects
fight: the driver inflates τ ~15×, the 80 mV sense threshold deflates it 12×
(`ln(V_pre/(V_pre−V_sense))` = 0.0834 replaces the 0.38), and the Horowitz
wordline-slew term doubles what remains. Also 25 % of C_bl is access-transistor
drain junction, not metal. The bitline is a device-limited path with a wire
hanging on it, not a wire-limited path — the same conclusion Part A reached from
the other side, where read current rather than the 180 fF set how fast ΔV
developed. The 20 kΩ series pair is the cell ratio Part A measured RSNM against:
the transistor limiting read speed is the one setting read stability.

### Carried into Parts C–E
Access 2.902 ns, read energy 792.9 pJ, leakage 2250.5 mW, area 11.474 mm², at the
Part A operating constraint V_DD,min = 0.795 V (85 °C). CACTI has no
supply-voltage knob, so that constraint is applied when these numbers are used,
not inside CACTI.

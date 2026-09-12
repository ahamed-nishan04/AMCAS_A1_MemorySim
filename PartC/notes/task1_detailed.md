# Part C, Task 1 — 2 MB STT-MRAM vs the CACTI SRAM baseline

NVSim (`SEAL-UCSB/NVSim`), `sample.cell` exactly as given in the assignment,
`STT_cache.cfg` matched to Part B: 2 MB, 64 B line (WordWidth 512 bit), 8-way,
45 nm, HP roadmap, 350 K, H-tree routing, normal access mode.

Part B pinned 4 UCA banks, so `STT_4bank.cfg` forces `2x2, 1x1` banking for a
controlled comparison. NVSim's free search prefers a single bank; both are
reported because the difference is large and it is not the bitcell's doing.

## Side by side

| Metric | SRAM (CACTI, Part B) | STT-MRAM (NVSim, 4 banks) | Ratio |
|---|---|---|---|
| Read latency | 2.902 ns | 1.727 ns | **1.68× better** |
| Write latency | 2.902 ns | 10.871 ns | **3.75× worse** |
| Read energy | 792.9 pJ | 717 pJ | 1.11× better |
| Write energy | 851.2 pJ | 497 pJ | 1.71× better *(see caveat)* |
| Leakage | 2250.5 mW | 265.3 mW | **8.48× better** |
| Area | 11.474 mm² | 3.008 mm² | **3.81× better** |

With NVSim's own preferred organisation (1 bank) instead:

| Metric | STT-MRAM (NVSim, free search) | Ratio vs SRAM |
|---|---|---|
| Read latency | 2.695 ns | 1.08× better |
| Write latency | 11.848 ns | 4.08× worse |
| Read energy | 459 pJ | 1.73× better |
| Write energy | 255 pJ | 3.34× better *(see caveat)* |
| Leakage | 147.1 mW | 15.3× better |
| Area | 2.593 mm² | 4.42× better |

STT-MRAM organisation (4-bank run): data array 2.560 mm², tag array 0.448 mm²; data subarray 1024 × 1024, mat 2×2, bank 2×2, area efficiency 71.7 % against the SRAM's 54.3 %. Write latency decomposes as 10.000 ns of write pulse + 0.294 ns row decoder + 0.465 ns charge + 0.140 ns predecoder — the pulse is 92 % of it and comes straight from `-SetPulse`/`-ResetPulse` in the cell file. In the same run the H-tree is 256.9 pJ of the data array's 619.3 pJ read energy — 41 % of the read energy is interconnect, not cell.

Cell area: 54 F² × (45 nm)² = 0.1094 µm² against the SRAM cell's 0.657 × 0.45 =
0.2957 µm², so the bitcell is 2.70× denser. The array comes out 3.81× smaller — better than the cell ratio alone, because the 1T1R array also achieves 71.7 % area efficiency where the 6T SRAM managed 54.3 %.

## Caveat on the write-energy number

**NVSim's reported write energy is below the floor implied by its own cell
file, and should not be quoted without this note.**

For a current-mode write with no write voltage specified, NVSim computes the
per-bit switching energy as `V_dd × I_write × t_pulse` (`MemCell.cpp:516`).
From `sample.cell`: 1.0 V × 200 µA × 10 ns = **2.0 pJ per bit**, confirmed by
instrumenting the binary. A 64 B line is 512 bits, so switching the MTJs alone
costs **1.024 nJ** before any peripheral, wire, or decoder energy.

NVSim reports 0.497 nJ (4 banks) and 0.255 nJ (free search) for the whole cache
write — 2× and 4× *below* that floor. The cause is in `SubArray.cpp`: the cell
write energy is charged for `numColumn / (muxSenseAmp · muxOutputLev1 ·
muxOutputLev2)` bits of one subarray — 128 bits for the free-search
organisation, and the 4-bank run has a 1024-column subarray with the same
structural problem — not the 512 bits of a cache line, and the result is not
scaled back up to the line.

So: use **1.024 nJ as a hand-computed lower bound** on STT-MRAM write energy for
anything downstream, and treat the 0.497 nJ as the tool's figure rather than the
physical one. Against the SRAM's 851 pJ this turns a nominal 1.71× *advantage*
into at least a 1.2× *disadvantage* — and the gap widens once the H-tree and
write drivers are added. The assignment's framing applies exactly: *your results
are exactly as good as the .cell file you feed it* — and, it turns out, as good
as the tool's accounting of it.

Read energy passes the same check: NVSim's per-bit read energy is
`2 × ReadPower × t_sense` = 2 × 145 µW × 803 ps = 0.233 pJ, so 512 bits is
119 pJ, comfortably under the 717 pJ reported.

## Configuration mismatches worth stating

- **Objective.** CACTI optimised ED²P; NVSim has no ED² target, so `ReadEDP` is
  the closest. Part B Task 3 showed ED² sits essentially at the delay optimum
  here, so this is a small difference, but it is not zero.
- **Banking.** CACTI was told 4 banks; NVSim searches banking freely and prefers
  1. Forcing 2×2 costs read energy and leakage but halves read latency — the
  4-bank column above is the like-for-like one.
- **Tag array wire types.** NVSim reports `Local Aggressive` / `Global
  Aggressive` for the tag array regardless of the `LocalWireType` /
  `GlobalWireType` lines, which it does honour for the data array. The tag array
  is 0.448 mm² of 3.008 mm², so the effect is small, but the config is not doing
  what it appears to.
- **Supply.** Both tools use V_dd = 1.0 V at 45 nm HP. Part A's netlist ran at
  1.1 V, and Part A's V_DD,min = 0.795 V constraint is not expressible in either
  tool.

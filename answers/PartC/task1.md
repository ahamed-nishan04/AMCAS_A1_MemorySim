# Part C, Task 1 — 2 MB STT-MRAM vs the CACTI SRAM baseline

NVSim, `sample.cell` exactly as given in the assignment, `STT_cache.cfg` matched
to Part B: 2 MB, 64 B line (WordWidth 512 bit), 8-way, 45 nm, HP roadmap, 350 K,
H-tree routing, normal access mode.

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

| Metric | STT-MRAM (free search) | Ratio vs SRAM |
|---|---|---|
| Read latency | 2.695 ns | 1.08× better |
| Write latency | 11.848 ns | 4.08× worse |
| Read energy | 459 pJ | 1.73× better |
| Write energy | 255 pJ | 3.34× better *(see caveat)* |
| Leakage | 147.1 mW | 15.3× better |
| Area | 2.593 mm² | 4.42× better |

## Organisation

4-bank run: data array 2.560 mm², tag array 0.448 mm²; data subarray
1024 × 1024, mat 2×2, bank 2×2, area efficiency 71.7 % against the SRAM's
54.3 %.

Write latency decomposes as 10.000 ns of write pulse + 0.294 ns row decoder +
0.465 ns charge + 0.140 ns predecoder — the pulse is 92 % of it and comes
straight from `-SetPulse`/`-ResetPulse` in the cell file.

In the same run the H-tree is 256.9 pJ of the data array's 619.3 pJ read energy,
so 41 % of the read energy is interconnect, not cell.

Cell area: 54 F² × (45 nm)² = 0.1094 µm² against the SRAM cell's
0.657 × 0.45 = 0.2957 µm², so the bitcell is 2.70× denser. The array comes out
3.81× smaller — better than the cell ratio alone, because the 1T1R array also
achieves 71.7 % area efficiency where the 6T SRAM managed 54.3 %.

> **The write-energy row above should not be quoted without reading
> `../findings.md`.** NVSim's reported write energy is below the floor implied
> by its own cell file; the hand-computed lower bound is 1.024 nJ, which turns
> the nominal 1.71× advantage into at least a 1.2× disadvantage.

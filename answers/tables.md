# The five tables

One headline table per part, in the form the 6–8 page report needs. Full working
is in the `PartX/taskN/taskN.md` files; caveats that change how a number should
be read are in each part's `findings.md`.

---

## Table 1 — Part A: 6T read margin and disturb (ngspice, 45 nm PTM BSIM4)

| Quantity | 0.16 µm, 27 °C | 0.24 µm, 27 °C | 0.16 µm, 85 °C | Ratio vs baseline |
|---|---|---|---|---|
| ΔV @ t = 2.0 ns | 729.9 mV | 852.3 mV | 582.1 mV | 1.17× / 0.80× |
| ΔV @ 65 ps sense window | 69.1 mV | — | 54.2 mV | 0.78× |
| Read disturb peak v(Q) | 205.5 mV | 271.2 mV | 220.8 mV | 1.32× / 1.07× |
| Read SNM | 138.2 mV | 81.4 mV | — | **0.59×** |
| Hold SNM | 352.1 mV | 352.1 mV (WL off) | — | 1.00× |
| V_DD at the 25 mV crossing | 0.726 V | — | 0.795 V | +68 mV |

**Carried forward: V_DD,min = 0.795 V at 85 °C.** At 0.7 V and 85 °C the cell
does not read — ΔV = 16.7 mV against a 25 mV offset.

---

## Table 2 — Part B: 2 MB SRAM L2 at 45 nm, and the objective sweep (CACTI 7)

| Objective | Ndwl/Ndbl/Nspd | Access (ns) | Cycle (ns) | Read E (pJ) | Leakage (mW) | Area (mm²) | Cell eff. |
|---|---|---|---|---|---|---|---|
| **ED²P (baseline)** | **4/2/1** | **2.902** | 2.652 | **792.9** | **2250.5** | **11.474** | 54.3 % |
| Pure delay | 4/2/1 | 2.892 | 2.652 | 898.4 | 2243 | 10.970 | 56.8 % |
| Pure area | 2/2/1 | 4.231 | 8.532 | 790.0 | 2193 | 9.219 | 67.7 % |

Baseline delay breakdown (ns): H-tree in 0.850 · decoder+WL 0.541 · bitline
0.407 · sense 0.003 · H-tree out 0.505. Interconnect is 47 % of access time.
Hand-check of the bitline against 0.38·R·C·L²: 46.6 ps vs 406.9 ps, **8.7× out**.

**Carried forward: 2.902 ns, 11.474 mm², 2250.5 mW.**

---

## Table 3 — Part C: same 2 MB as STT-MRAM (NVSim), against the SRAM baseline

| Metric | SRAM (CACTI) | STT-MRAM (NVSim, 4 banks) | Ratio |
|---|---|---|---|
| Read latency | 2.902 ns | 1.727 ns | **1.68× better** |
| Write latency | 2.902 ns | 10.871 ns | **3.75× worse** |
| Read energy | 792.9 pJ | 717 pJ | 1.11× better |
| Write energy | 851.2 pJ | 497 pJ *(tool)* / ≥1024 pJ *(floor)* | **≥1.2× worse** |
| Leakage | 2250.5 mW | 265.3 mW | **8.48× better** |
| Area | 11.474 mm² | 3.008 mm² | **3.81× better** |

Write-current sensitivity, done by hand because NVSim does not model it:

| Write current | Access width | Array area | vs SRAM |
|---|---|---|---|
| 100 µA | 3 F | 2.290 mm² | 5.01× |
| **200 µA** | **6 F** | **3.008 mm²** | **3.81×** |
| 400 µA | 12 F | 4.151 mm² | 2.76× |

**Carried forward: iso-area point is 8 MB of STT in 9.345 mm².**

---

## Table 4 — Part D: the real L2 miss stream on DDR4-3200 (Ramulator 2.0a)

First 100 000 DRAM accesses of each kernel's detailed region, from a gem5
CommMonitor on the L2 memory-side port. Latencies in DRAM cycles
(tCK = 625 ps). Read counts match gem5's `mem_ctrls.readReqs` **to the unit**.

| Configuration | bfs | sssp |
|---|---|---|
| Baseline cycles (FR-FCFS, RoBaRaCoCh, 1 ch) | 643 601 | 884 695 |
| Avg read latency | 272.9 (171 ns) | 545.3 (341 ns) |
| Row-buffer hit rate | **82.6 %** | **74.6 %** |
| Write share of DRAM traffic | 12.9 % | 17.5 % |
| Channel utilisation | 62.2 % | 45.2 % |
| **FCFS** — slowdown / row-buffer change | **2.36x** / −2.0 pts | **2.09x** / −2.0 pts |
| **ChRaBaRoCo** — slowdown / row-buffer change | **3.21x** / **+0.4 pts** | **2.85x** / **+2.3 pts** |
| **2 channels** — throughput / latency | **2.17x** / 1.34x better | **2.26x** / 1.47x better |

Binding timing parameter at 2 channels: **nCCD_L** (1.13x bfs, 1.31x sssp;
nRCD and nRP ~1.05x, nRC exactly 1.00x, nRAS 0.99x — the wrong way).

**Headline:** under ChRaBaRoCo, performance collapses 3x while the row-buffer
hit rate *rises*. Bank-level parallelism, not row locality, is what the
mapping destroys.

---

## Table 5 — Part E: does the program run faster? (gem5, O3CPU @ 2 GHz)

| Config | Kernel | IPC | L2 miss rate | simSeconds | vs A |
|---|---|---|---|---|---|
| A — SRAM 2 MB, 6 cyc | bfs | 0.6799 | 75.76 % | 0.007174 | — |
| B — STT 8 MB, 6 cyc | bfs | **1.0020** | 31.46 % | 0.004868 | **+47.4 %** |
| C — STT 8 MB, 12 cyc | bfs | 0.9444 | 31.53 % | 0.005164 | **+38.9 %** |
| A — SRAM 2 MB, 6 cyc | sssp | 0.7489 | 14.01 % | 0.013352 | — |
| B — STT 8 MB, 6 cyc | sssp | **0.7999** | 11.27 % | 0.012501 | **+6.8 %** |
| C — STT 8 MB, 12 cyc | sssp | 0.7183 | 11.27 % | 0.013922 | **−4.1 %** |

Core dependence (advantage of C over A):

| Kernel | O3 | TimingSimple |
|---|---|---|
| bfs | +38.9 % | **+22.5 %** |
| sssp | −4.1 % | **−4.8 %** |

Break-even DRAM miss penalty P\* = ΔL/Δm: **13.6 cycles for bfs, 219.0 for
sssp.**

**Headline:** the iso-area STT-MRAM L2 wins decisively for bfs and loses for
sssp, on the same machine and the same graph. The bitcell sets the exchange
rate; the workload decides whether the exchange is worth making.

---

## The four plots

| Figure | Part | What it shows |
|---|---|---|
| `PartA/figA1_read.png` | A1 | Bitline discharge and the two sampling instants |
| `PartA/figA3_butterfly.png` | A2 | Read/hold butterfly curves, RSNM collapse 138 → 81 mV |
| `PartA/figA4_margin.png` | A3 | ΔV vs V_DD at both measurement points, 25 mV crossing |
| `PartB/figB2_capacity.png` | B2 | Access time vs log₂(capacity), array vs H-tree split |

`PartA/figA2_disturb.png` (v(Q) during the read) is a fifth, available if the
page budget allows.

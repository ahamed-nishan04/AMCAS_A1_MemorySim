# Part B, Task 1 — CACTI SRAM baseline

CACTI 7, `cache.cfg` as specified: 2 MB, 64 B blocks, 8-way, 1 R/W port, 4 UCA
banks, 45 nm, 350 K, itrs-hp cells and peripherals, ED², design objective
0:0:0:100:0.

## Baseline

| Quantity | Value |
|---|---|
| **Access time** | **2.902 ns** |
| Cycle time | 2.652 ns |
| **Dynamic read energy** | **792.9 pJ / access** |
| Dynamic write energy | 851.2 pJ / access |
| **Leakage** | **2250.5 mW** (562.632 mW × 4 banks) |
| Gate leakage | 65.5 mW (16.365 mW × 4) |
| **Area** | **11.474 mm²** (2.2134 × 5.1839 mm) |

Area splits as data array 10.271 mm² (54.3 % cell efficiency) + tag array
0.387 mm², the remaining 0.82 mm² being inter-bank routing. Leakage splits as
527.65 mW data + 34.98 mW tag per bank.

**Leakage is reported per bank.** The output line reads "Total leakage power of
a bank" and is exactly that. Re-running the same cache with `-UCA bank count 1`
gives 2150.4 mW for the whole array, close to 4 × 562.632 = 2250.5 mW. Area and
dynamic energy are already whole-cache. Verification run in
`bankcount1_check.txt`.

## Winning organisation

| | Ndwl | Ndbl | Nspd | Ndcm | Ndsam L1/L2 |
|---|---|---|---|---|---|
| Data | 4 | 2 | 1 | 1 | 8 / 1 |
| Tag | 2 (Ntwl) | 2 (Ntbl) | 2 (Ntspd) | 1 | 4 / 1 |

H-tree wires: global with 30 % delay penalty, both arrays.

## Delay breakdown (data side, ns)

| H-tree in | Decoder + WL | Bitline | Sense amp | H-tree out | Total |
|---|---|---|---|---|---|
| 0.850 | 0.541 | **0.407** | 0.0034 | 0.505 | 2.902 |

Tag side totals 0.596 ns and is off the critical path. The interconnect —
H-tree in plus out — is 1.355 ns, 47 % of the access time, more than the array
itself. The 0.407 ns bitline delay is the number Task 4 hand-checks.

**This is the SRAM baseline carried into Parts C, D and E.**

Config caveats and tool notes: `../findings.md`. Full output: `cacti_out.txt`.

# Part B, Task 1 — CACTI SRAM baseline

CACTI 7 (HewlettPackard/cacti, commit `1ffd8df`), `cache.cfg` as specified:
2 MB, 64 B blocks, 8-way, 1 R/W port, 4 UCA banks, 45 nm, 350 K, itrs-hp cells
and peripherals, ED², design objective 0:0:0:100:0 (all weight on cycle time).

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

**Leakage is per bank in CACTI's output.** The line reads "Total leakage power of
a bank", and it is exactly that — re-running the same cache with `-UCA bank
count 1` gives 2150.4 mW for the whole array, close to 4 × 562.632 = 2250.5 mW.
Area and dynamic energy are already whole-cache: the 1-bank run reports a
7.61 mm² data array against 10.27 mm² for 4 banks, the difference being banking
overhead (73.4 % vs 54.3 % cell efficiency). Verification run kept in
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

Tag side totals 0.596 ns and is off the critical path. The interconnect — H-tree
in plus out — is 1.355 ns, 47 % of the access time, more than the array itself.
The 0.407 ns bitline delay is the number Task 4 hand-checks against
0.38·R·C·L².

## Notes

- `cacti` resolves `tech_params/*.dat` relative to the working directory. Run it
  from the repo root or the run segfaults immediately after echoing the input
  parameters — the failure is a NULL `FILE*` in `TechnologyParameter::init`, not
  a bad config.
- The supplied config fragment omits several keys CACTI requires; everything not
  listed in the assignment is left at the stock `cache.cfg` default (ECC on,
  normal access mode, semi-global wires inside and outside mats, conservative
  interconnect projection). `-Cache level` is set to "L2"; it only affects the
  NUCA path and does not change these numbers.
- CACTI has no supply-voltage knob, so Part A's V_DD,min = 0.795 V cannot be fed
  in here. It stays a constraint on the operating point rather than a CACTI
  input, and is applied when the numbers are used in Parts C–E.

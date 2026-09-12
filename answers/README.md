# answers/ — final deliverables

Copies of everything that goes into the report. Nothing here needs to be run; the
working trees are in `../PartA` … `../PartE`.

| | |
|---|---|
| `tables.md` | the five headline tables and the four plots, assembled |
| `PartA/` … `PartE/` | task answers, per-part findings, figures |

## Reading order for the report

1. `tables.md` — the five tables the submission asks for
2. `PartE/task4.md` — **the two-paragraph argument, 30 % of the marks**
3. `PartA/summary.md`, `PartB/summary.md` — part-level narratives
4. `PartX/taskN.md` — individual task answers
5. `PartX/findings.md` — tool bugs and caveats; several of these change how a
   number in `tables.md` should be read, and the Part C and Part D ones are
   load-bearing for the Task 4 reviewer list

## Verification status

Every part has been re-executed and checked. Parts A, B and C reproduce
exactly; Part D now runs on the real gem5 CommMonitor trace the assignment
specifies; Part E's measurement window has been validated per kernel.

| Part | Status |
|---|---|
| A | all five ngspice decks re-run, every value and all four figures reproduce |
| B | baseline, capacity sweep, objective sweep and bitline hand-check all reproduce; 4 UCA banks confirmed |
| C | all eleven NVSim outputs byte-identical to fresh runs |
| D | **real CommMonitor trace**; read counts match gem5's `mem_ctrls.readReqs` to the unit |
| E | 12/12 configs; fast-forward validated so the detailed region covers the kernel |

## Known approximations, all documented

- **Part D write stream** is count-exact but not identity-exact: clean and dirty
  evictions are indistinguishable in the trace, so writebacks are subsampled to
  the DRAM write count gem5 reports. `PartD/findings.md`.
- **Part E hit latency** for STT-MRAM carries cross-tool uncertainty, which is
  why config C exists and every conclusion is stated against both. For sssp the
  verdict flips between B and C. `PartE/findings.md`.
- **Write cost is unmodelled in Part E** — gem5 applies one latency to reads and
  writes alike, so the 22-cycle STT write never appears. Largest known weakness
  in the chain; point three of the Task 4 reviewer list.

# Part B — CACTI findings and config caveats

## The ED² flag overrides the design-objective weights entirely

This is the most important thing in Part B and it changes how Task 1 and Task 3
should be read.

`Ucache.cc:find_optimal_uca` branches on `-Optimize ED or ED^2` **before** it
ever looks at the weights:

```c
if (g_ip->ed == 2) cost = (D/Dmin)*(D/Dmin)*(E/Emin);   // weights unused
else               cost = d*(D/Dmin) + c*(C/Cmin) + ... // and check_uca_org()
```

With `ed == 1` or `2` the weighted sum is skipped, and so is `check_uca_org`,
the function that enforces the `-deviate` line.

**Consequence: the Task 1 config's `0:0:0:100:0` cycle-time weight did nothing.**
The baseline organisation was selected purely on delay² × dynamic energy. The
assignment's config specifies both a weight vector and `ED^2`, and only the
latter has any effect. To make a weighted objective take effect at all,
`-Optimize` must be set to `"NONE"`.

This is also the real answer to Task 3's "explain why the optimal organisation
changes": for two of the three runs it is a different code path, not just
different coefficients.

## The `-deviate` filter silently redefines "pure area"

Under `-Optimize "NONE"`, the stock `-deviate` line (`20:100000:...`) discards
every candidate more than 20 % slower than the fastest one. Left in place,
"pure area" is really "smallest area among the fast ones" — it returns 3.355 ns
/ 9.245 mm² instead of the true area optimum at 4.231 ns / 9.219 mm².

`task3/run.sh` therefore relaxes the deviations for the two pure-weight runs so
the weight alone selects the winner, and keeps a fourth run (`area20`) with the
stock filter to show the difference. Both rows are in the Task 3 table.

## Leakage is per bank, area and dynamic energy are not

The output line "Total leakage power of a bank" means exactly that. Multiply by
`-UCA bank count` for the whole array. Area and dynamic energy in the same
output are already whole-cache. Cross-check in `task1/bankcount1_check.txt`: a
1-bank run of the same cache gives 2150.4 mW total against 4 × 562.632 =
2250.5 mW, and a 7.61 mm² data array against 10.27 mm² for 4 banks (73.4 % vs
54.3 % cell efficiency — the difference is banking overhead).

Note also that the `.cfg.out` files CACTI writes next to each input have a
`Standby leakage per bank` column that is **not** the same quantity as the text
output's `Total leakage power of a bank`, which is read-operation leakage.

## Operational

- **`cacti` resolves `tech_params/*.dat` relative to the working directory.**
  Run from inside the `cacti/` clone or the run segfaults immediately after
  echoing the input parameters. The failure is a NULL `FILE*` in
  `TechnologyParameter::init`, not a bad config. Every `run.sh` here launches it
  from `../cacti`.
- **The assignment's config fragment omits several keys CACTI requires.**
  Everything not listed there is left at the stock `cache.cfg` default: ECC on,
  normal access mode, semi-global wires inside and outside mats, conservative
  interconnect projection. `-Cache level` is set to "L2"; it only affects the
  NUCA path and does not change these numbers.
- **CACTI has no supply-voltage knob**, so Part A's V_DD,min = 0.795 V cannot be
  fed in. It stays a constraint on the operating point rather than a CACTI
  input.
- **CACTI's itrs-hp cell runs at V_dd = 1.0 V**, not the 1.1 V used in Part A's
  netlist.

## FO4 reference used in Task 2

From CACTI's own 45 nm ITRS-HP parameters (`tech_params/45nm.dat`):
C_g_ideal = 6.78e-16 F/µm, C_fringe = 5e-17 F/µm, I_on_n = 2.047e-3 A/µm,
V_dd = 1.0 V. A first-order fanout-of-4 estimate — load = 4 × 3W × (C_g +
2C_fringe), drive = I_on_n·W, t = C·V/(I/2) — gives ≈ 9 ps; adding junction
self-loading puts it in the 10–20 ps range. 15 ps is used.

**The Task 2 conclusion is insensitive to this choice.** Even at 25 ps the
measured slope is 26 FO4 per doubling, and no constant value can fit a convex
curve.

## Task 4 instrumentation

`bldbg.txt` is shipped. It was produced by `bitline_debug.patch`, which adds one
env-guarded `cerr` to `Mat::compute_bitline_delay`, run against `forced.cfg`
(which pins the Task 1 organisation with `-Force cache config "true"`). The
regeneration recipe is in the header of `task4/run.sh`. `bl_handcheck.py` reads
the shipped file, so Task 4 needs no rebuild.

## Reproduction status

Re-verified from a clean checkout: `task1/run.sh`, `task2/run.sh`,
`task3/run.sh` and `task4/run.sh` all reproduce the numbers in the task files
exactly — baseline 2.90184 ns, sweep all seven capacities, objectives 2.892 /
2.902 / 4.231 / 3.355, and the 8.7× / 6.6× hand-check discrepancies.

# Part A — method notes and ngspice caveats

Material that does not belong in the task answers but that the results depend on.

## ngspice behaviours worked around

- **`.meas FIND` cannot take an expression.** `meas tran dv FIND v(blb)-v(bl)`
  does not parse. The difference has to be materialised as a vector first —
  `let dvbl = v(blb)-v(bl)` — after the `tran` that creates `v(bl)` and `v(blb)`.
- **`alter Vdd` does not update the `.ic` card.** In the Task 3 supply sweep
  v(QB) is therefore initialised to 1.1 V at every step regardless of the swept
  supply. Verified harmless: at V_DD = 0.6 V the node settles to 0.5999 V by
  1 ns, 50 ps before the wordline edge, so no measurement sees the wrong
  initial condition.
- **`print r[0] r[1]` prints one value per line** rather than as columns,
  because the vectors resolve in different plots. The values are correct either
  way; only the formatting is affected.
- **`plot` is unavailable in batch mode** (`ngspice -b`) and is silently ignored
  with a warning. All figures come from `plots.py` reading the `wrdata` CSVs,
  not from ngspice itself.
- **Temperature** is set with `option temp=85` inside `.control` rather than a
  `.temp 85` card, which is equivalent and lets both corners run in one
  invocation.

## Simulation artefacts

- **`uic` start-up transient.** The first ~200 fs of every run has no operating
  point and v(QB) briefly overshoots to 1.43 V. All plots therefore start at
  0.5 ns. No measurement point falls inside the transient.

## Modelling assumptions that the numbers rest on

- **The sense instant is an assumption, not a measurement.** The netlist has no
  sense amplifier. The 1.115 ns sampling point used in Tasks 3 and 4 was chosen
  by calibrating against the Lecture-1 69 mV figure at the nominal corner, on
  the model that a sense amplifier fires at a fixed replica delay that does not
  stretch when V_DD or temperature move. Every ΔV-vs-V_DD and ΔV-vs-temperature
  number inherits this choice. A replica-timed design that *did* stretch would
  push the crossing voltage lower.
- **The 25 mV sense-amp offset is taken from Lecture 5 and held constant.** Its
  weak temperature dependence (Task 4) is argued from σ(ΔV_th) = A_VT/√(WL),
  not simulated.
- **SNM extraction** is the largest axis-aligned square inscribed in the
  butterfly lobe, found by bisection in `plots.py`. Read trip points
  (527 / 537 mV) exceed the hold value (493 mV) because the access device loads
  QB.

## Reproduction

`bash run.sh` from `PartA/`. Requires `ngspice`, plus `numpy` and `matplotlib`
for `plots.py`:

```bash
pip install numpy matplotlib
```

Verified against ngspice 44 on Fedora: every measured value reproduces exactly
as quoted in the task files (`dv = 7.298581e-01`, `dv_s = 6.910866e-02`,
`vcross = 7.264061e-01`, `vcross85 = 7.947550e-01`).

Under ngspice 42 on Ubuntu 24.04 the last digit of `dv` and `vcross85` differs
(`7.298577e-01`, `7.947546e-01`) -- solver noise between versions, ~5e-7
relative, affecting nothing.

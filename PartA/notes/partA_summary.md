# Part A — 6T SRAM read margin (ngspice)

45 nm PTM BSIM4 HP card (nominal 1.0 V, run at 1.1 V per the given netlist) · 6T
cell, Q = 0 / QB = 1, C_BL = C_BLB = 180 fF · cell ratio W(MN1)/W(MA) =
0.20/0.16 = 1.25.

**Answer to the Part A question: no — at 0.7 V and 85 °C the cell does not read.**
ΔV = 16.7 mV against a 25 mV sense-amp offset. It fails at 0.7 V cold as well
(22.1 mV). Minimum readable supply is **0.795 V hot, 0.726 V cold**.

### Table A1 — read margin and disturb

| Quantity | 0.16 µm, 27 °C | 0.24 µm, 27 °C | 0.16 µm, 85 °C | ratio vs baseline |
|---|---|---|---|---|
| ΔV @ t = 2.0 ns | 729.9 mV | 852.3 mV | 582.1 mV | 1.17× / 0.80× |
| ΔV @ 65 ps sense window | 69.1 mV | — | 54.2 mV | 0.78× |
| Read disturb peak v(Q) | 205.5 mV | 271.2 mV | 220.8 mV | 1.32× / 1.07× |
| Read SNM | 138.2 mV | 81.4 mV | — | **0.59×** |
| Hold SNM | 352.1 mV | 352.1 mV (WL off) | — | 1.00× |
| V_DD at the 25 mV crossing | 0.726 V | — | 0.795 V | +68 mV |

**Task 1.** ΔV at 2.0 ns is 729.9 mV, **10.6× the 69 mV Lecture-1 reference**. The
gap is a sampling-time artefact, not a cell property: the wordline is full by
1.05 ns, so 2.0 ns allows 950 ps of discharge into 180 fF, ~65 % of full swing.
Sampling the same run 65 ps after the wordline edge (t = 1.115 ns) gives 69.1 mV.
*Stated modelling assumption for Tasks 3–4:* the sense amplifier fires at a fixed
replica delay, calibrated at the nominal corner to the Lecture-1 reference.

**Task 2.** v(Q) moves: it peaks at 205.5 mV (18.7 % of V_DD) at the wordline
edge, then decays as the floating bitline collapses toward it. Widening MA to
0.24 µm (cell ratio 0.83) raises the peak to 271.2 mV and speeds the discharge
17 %, but produces **no flip** — a noiseless transient only reveals margins that
have already gone negative. The failure is static: **read SNM collapses 41 %,
138.2 → 81.4 mV**, against a ≈ V_DD/6 = 183 mV target. Read VTC endpoints (206.6 /
272.0 mV) match the transient peaks to four digits, confirming the disturb bump
is the static read level.

**Task 3.** ΔV degrades ~11.4 mV per 100 mV of supply, smoothly and with no knee,
crossing 25 mV at **V_DD = 0.726 V**. Under the literal t = 2 ns definition ΔV is
still 143.9 mV at 0.6 V and never crosses — both curves are in Fig. A4. The
disturb peak falls monotonically over the same sweep (205.5 → 71.6 mV), so the
low-voltage limit is a *sensing* failure, not a *stability* one: lower V_DD and
wider access devices trade the two in opposite directions.

**Task 4.** From 27 °C to 85 °C, ΔV falls 21.6 % at the sense window and 20.2 % at
2 ns — mobility degrades faster than V_th drops, so the access device delivers
less charge in a fixed window. The sense-amp offset moves far less: it is set by
V_th mismatch, σ(ΔV_th) = A_VT/√(WL), and A_VT is only weakly
temperature-dependent, so 25 mV shifts a few percent over 58 K. (Analytical —
there is no sense amplifier in the netlist.) **ΔV moves ~22 % against a few
percent, so ΔV sets the failure**, and the hot corner is limiting: minimum supply
rises 0.726 → 0.795 V, 68 mV of lost headroom. Read stability moves the other way,
so the cell is sensing-limited. The penalty itself worsens as supply drops
(−21.6 % at 1.1 V to −24.8 % at 0.6 V) — the hot, low-voltage corner is the worst
case twice over.

### Carried into Part B
**V_DD,min = 0.795 V (85 °C)** — the lowest supply at which the array can be
sensed. The CACTI / NVSim / Ramulator / gem5 runs use this as the SRAM operating
point rather than a nominal 1.1 V. C_BL is held at the given 180 fF in Part A; if
CACTI returns a materially different bitline capacitance for the 2 MB array, the
crossing voltage shifts and the number kept is stated there.

### Notes
- `.meas FIND` cannot take an expression; the difference is materialised with
  `let dvbl = v(blb)-v(bl)` after the analysis that creates the node vectors.
- In the V_DD sweep, `alter Vdd` does not update the `.ic` card, so v(QB) starts
  at 1.1 V at every step. Verified harmless: at V_DD = 0.6 V it settles to
  0.5999 V by 1 ns, 50 ps before the wordline edge.
- Plots start at 0.5 ns; the first ~200 fs is a `uic` start-up transient with no
  operating point (v(QB) → 1.43 V) and affects no measurement.
- Temperature is set with `option temp=85` inside `.control`, equivalent to a
  `.temp 85` card, so both corners run in one invocation.

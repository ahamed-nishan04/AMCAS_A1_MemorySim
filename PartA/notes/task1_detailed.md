# Task 1 — ΔV(BL, BLB) at t = 2 ns

Q = 0 / QB = 1 stored, C_BL = C_BLB = 180 fF, V_DD = V_BL = 1.1 V, 27 °C,
cell ratio W(MN1)/W(MA) = 0.20/0.16 = 1.25.

| Quantity | Value |
|---|---|
| v(BL) @ 2.0 ns | 0.3697 V |
| v(BLB) @ 2.0 ns | 1.0996 V |
| **ΔV @ 2.0 ns** | **729.9 mV** |
| Lecture-1 reference | 69 mV |
| **Ratio** | **10.6×** |

The measured swing is 10.6× the reference. The difference is *when* the pair is
sampled, not a property of the cell: the wordline is at full V_DD by 1.05 ns, so
`AT=2.0n` allows 950 ps of discharge into 180 fF — BL falls from 1.084 V to
0.370 V, about 65 % of full swing. That is a completed discharge, not a sense
margin.

The reference corresponds to a much shorter sense window. Sampling the same run
at t = 1.115 ns, i.e. 65 ps after the wordline edge, gives ΔV = 69.1 mV, matching
Lecture 1 to 0.1 mV. **Modelling assumption used in Tasks 3 and 4:** the sense
amplifier fires at a fixed replica delay, calibrated here so that the nominal
corner reproduces the Lecture-1 figure. This is a stated assumption, not a
derived result — it fixes the sense instant so it can be held constant while
V_DD and temperature vary.

Discharge trajectory (Fig. A1):

| t (ns) | 1.05 | 1.115 | 1.20 | 1.50 | 2.00 | 4.00 |
|---|---|---|---|---|---|---|
| ΔV (mV) | 15.2 | **69.1** | 136.6 | 377.3 | **729.9** | 1093.5 |

Measured:

```
dv    = 7.298577e-01     $ 729.9 mV @ 2.0 ns
dv_s  = 6.910836e-02     $  69.1 mV @ 1.115 ns
```

Note: `.meas FIND` cannot take an expression, so the difference is materialised
as a vector (`let dvbl = v(blb)-v(bl)`) after the `tran` that creates v(bl) and
v(blb). Plots start at 0.5 ns; the first ~200 fs is a `uic` start-up transient
with no operating point and affects no measurement.

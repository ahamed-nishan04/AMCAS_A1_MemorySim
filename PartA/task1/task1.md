# Part A, Task 1 — ΔV(BL, BLB) at t = 2 ns

45 nm PTM BSIM4, V_DD = V_BL = 1.1 V, 27 °C, Q = 0 / QB = 1, C_BL = C_BLB =
180 fF, cell ratio W(MN1)/W(MA) = 0.20/0.16 = 1.25.

| Quantity | Value |
|---|---|
| v(BL) @ 2.0 ns | 0.3697 V |
| v(BLB) @ 2.0 ns | 1.0996 V |
| **ΔV @ 2.0 ns** | **729.9 mV** |
| Lecture-1 reference | 69 mV |
| **Ratio** | **10.6×** |

## Comparison with the 69 mV reference

The measured swing is 10.6× the reference, and the difference is the sampling
instant rather than anything about the cell. The wordline reaches full V_DD at
1.05 ns, so `AT=2.0n` allows 950 ps of discharge into 180 fF — BL falls from
1.084 V to 0.370 V, about 65 % of full swing. That is a completed discharge, not
a sense margin.

Sampling the same run at t = 1.115 ns, 65 ps after the wordline edge, gives
ΔV = 69.1 mV, matching Lecture 1 to 0.1 mV. The reference corresponds to that
much shorter sense window.

| t (ns) | 1.05 | 1.115 | 1.20 | 1.50 | 2.00 | 4.00 |
|---|---|---|---|---|---|---|
| ΔV (mV) | 15.2 | **69.1** | 136.6 | 377.3 | **729.9** | 1093.5 |

**Assumption carried into Tasks 3 and 4:** the sense amplifier fires at a fixed
replica delay, calibrated at this nominal corner to reproduce the Lecture-1
figure. This fixes the sense instant so it can be held constant while V_DD and
temperature vary. It is a stated assumption, not a derived result.

Figure: `figA1_read.png`. Measured output:

```
dv    = 7.298577e-01     $ 729.9 mV @ 2.0 ns
dv_s  = 6.910836e-02     $  69.1 mV @ 1.115 ns
```

Method notes and tool caveats: `../findings.md`.

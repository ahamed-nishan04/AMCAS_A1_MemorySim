# Task 3 — Sense margin vs V_DD

V_DD swept 1.1 → 0.6 V in 50 mV steps, 27 °C, MA = 0.16 µm. Sense-amp offset
(Lecture 5) = 25 mV. Wordline amplitude and bitline precharge track the supply
at every step.

**ΔV crosses the 25 mV offset at V_DD = 0.726 V** (`vcross = 7.264061e-01`,
linearly interpolated between the 0.75 V and 0.70 V steps).

| V_DD (V) | 1.10 | 1.05 | 1.00 | 0.95 | 0.90 | 0.85 | 0.80 | **0.726** | 0.70 | 0.65 | 0.60 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| ΔV @ sense window (mV) | 69.1 | 63.0 | 56.9 | 50.9 | 44.9 | 39.0 | 33.2 | **25.0** | 22.1 | 16.9 | 12.1 |
| ΔV @ t = 2 ns (mV) | 729.9 | 673.6 | 616.0 | 557.1 | 497.4 | 437.2 | 376.8 | — | 257.1 | 199.1 | 143.9 |
| v(Q) peak (mV) | 205.5 | 191.7 | 177.9 | 164.2 | 150.5 | 136.8 | 123.2 | — | 96.5 | 83.7 | 71.6 |

**Which measurement point.** At the Task-1 sampling point of 2 ns, ΔV is still
143.9 mV at 0.6 V — the curve never crosses 25 mV anywhere in the swept range and
the task has no answer. A sense amplifier fires on a clock edge that does not
stretch when the supply drops, so ΔV is sampled at the fixed window defined in
Task 1 (1.115 ns). Both columns are plotted in Fig. A4 so the contrast is visible.

**Shape.** Close to linear, no knee: the per-step drop falls only from 6.1 mV to
4.8 mV across the range, averaging 11.4 mV of ΔV per 100 mV of supply. Even at
0.6 V there is still 12.1 mV of differential — the signal has not vanished, it has
fallen under what the amplifier can resolve. Access-device current falls with
gate overdrive while the sense window stays fixed, so the charge delivered in
65 ps shrinks roughly in proportion to the supply.

**The two failure modes oppose each other.** The disturb peak falls monotonically
over the same sweep (205.5 → 71.6 mV): the cell becomes *more* read-stable at low
supply even as it becomes unsensable. With Task 2, where widening MA raised ΔV
17 % while collapsing RSNM 41 %:

| Change | Sense margin | Read stability |
|---|---|---|
| Lower V_DD | worse | better |
| Wider access device | better | worse |

Task 3 sets the lower supply bound, Task 2 the upper access-width bound.

Note: `alter Vdd` does not update the `.ic` card, so v(QB) is initialised to
1.1 V at every sweep step. Verified harmless — at V_DD = 0.6 V the node settles
to 0.5999 V by 1 ns, 50 ps before the wordline edge.

# Part A, Task 2 — Read disturb on v(Q), and MA widened to 0.24 µm

## Does v(Q) move during the read?

Yes. The node holding the `0` is pulled up as soon as the wordline turns on.

| Quantity | Value |
|---|---|
| v(Q) during hold | 0 V |
| v(Q) peak | **205.5 mV @ 1.0575 ns** (18.7 % of V_DD) |
| v(Q) @ 4 ns | 2.71 mV |

MA1 connects the precharged bitline to Q against the MN1 pull-down, and Q settles
where the two currents balance. The peak sits at the wordline edge, when BL is
still at full V_DD. The decay afterwards is not the latch restoring itself — it
tracks the bitline collapsing toward v(Q), which removes the pull-up. The
bitline here is a floating capacitor, so the disturb is self-limiting; with a
clamped bitline it would persist for the whole wordline pulse.

Figure: `figA2_disturb.png`.

## MA1, MA2 grown to 0.24 µm

Cell ratio 1.25 → 0.83.

| Quantity | MA = 0.16 µm | MA = 0.24 µm | Change |
|---|---|---|---|
| v(Q) peak | 205.5 mV | 271.2 mV | +32 % |
| ΔV @ 2 ns | 729.9 mV | 852.3 mV | +17 % |
| **Read SNM** | **138.2 mV** | **81.4 mV** | **−41 %** |
| Hold SNM | 352.1 mV | 352.1 mV (WL off, MA irrelevant) | — |
| Flip? | no | no | — |

**No flip occurs in the transient, but the cell is failing.** A noiseless
transient only reveals a margin that has already gone negative; "marginal" means
the margin has collapsed, not that it is below zero. The metric that shows it is
read static noise margin, taken from the butterfly plot with WL on and the
bitlines clamped at V_DD: RSNM falls 138.2 → 81.4 mV, a **41 % collapse**,
against a ≈ V_DD/6 ≈ 183 mV rule-of-thumb target. The cell is one coupling
event, supply droop, or V_t mismatch from losing its state.

Node Q is driven through MA1 as a source follower, so the disturb is ceilinged
near V_DD − V_th,MA − body effect, close to the 493 mV bare-inverter trip point.
Widening MA raises drive current, not that ceiling — which is why the margin
erodes toward zero without crossing it. Confirmed: no flip at MA up to 0.80 µm,
with clamped bitlines, with pull-downs cut to cell ratio 0.25, or down to
V_DD = 0.5 V.

DC and transient agree — the read VTCs end at v(QB) = 206.6 mV and 272.0 mV at
v(Q) = 1.1 V, matching the transient peaks (205.5, 271.2 mV) to four digits. The
disturb bump *is* the static read level, not an overshoot.

Figure: `figA3_butterfly.png`. Measured output:

```
$ ngspice -b task2.sp
dv    = 8.523408e-01
qmax  = 2.712168e-01 at= 1.062500e-09

$ ngspice -b task2_snm.sp && python3 ../plots.py
vtc_hold.csv           SNM =  352.1 mV
vtc_read_016.csv       SNM =  138.2 mV
vtc_read_024.csv       SNM =   81.4 mV
```

Method notes and tool caveats: `../findings.md`.

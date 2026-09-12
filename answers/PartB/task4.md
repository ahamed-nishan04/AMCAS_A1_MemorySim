# Part B, Task 4 — Bitline delay: CACTI vs 0.38·R·C·L²

Task 1 winner: Ndwl 4 / Ndbl 2 / Nspd 1, data subarray **512 rows × 1152
columns**. CACTI reports **bitline delay = 0.406901 ns**.

`forced.cfg` pins that organisation so the parameters CACTI actually used can be
read out; arithmetic in `bl_handcheck.py`.

## The hand calculation

The bitline runs the height of the subarray: L = 512 rows × 0.657 µm cell pitch
= **336.4 µm**. From CACTI's own 45 nm local-wire parameters, r = 4.2024 Ω/µm and
c = 2.580e-16 F/µm, so R = 1413.6 Ω and C = 86.8 fF.

| | |
|---|---|
| 0.38·R·C·L², wire capacitance only | **46.6 ps** |
| 0.38·R·C·L², using CACTI's full C_bl (115.5 fF) | 62.0 ps |
| CACTI | **406.9 ps** |
| **Discrepancy** | **8.7× (6.6× including cell drain capacitance)** |

The hand calculation is out by nearly an order of magnitude, in the optimistic
direction.

## Where the factor of 8.7 comes from

CACTI's SRAM bitline model is

```
tau   = (R_pulldown + R_access)·C_bl  +  R_bl·C_bl/2  +  (sense-amp cap terms)
tstep = tau · ln( V_pre / (V_pre − V_sense) )
delay = horowitz(tstep, wordline rise time)
```

| Term | Value | Note |
|---|---|---|
| (R_pulldown + R_access)·C_bl | 2.3557 ns | R = 20 398 Ω, **14.4× the wire resistance** |
| R_bl·C_bl/2 | 0.0816 ns | the wire term — **3.3 %** of the two |
| τ including sense-amp isolation and latch caps | 2.4815 ns | |
| × ln(1/(1−0.08)) = 0.0834 | 0.2069 ns | only 80 mV of swing is needed, not 50 % |
| Horowitz with the wordline slew | **0.4069 ns** | **1.97×** |

Two of these move in opposite directions, which is why the naive answer is wrong
by 8.7× rather than by an obvious factor: the driver resistance inflates τ by
15× over the wire-only RC, the small sense swing deflates it by 12×, and the
wordline rise time doubles what is left.

## One effect CACTI models that the hand calculation does not

**The finite drive resistance of the accessed cell.** 0.38·R·C·L² is the 50 %
delay of a distributed RC line driven by an ideal source — it assumes the only
resistance in the path is the wire's own. In an SRAM read the bitline is
discharged *through the cell*: the access transistor in series with the
pull-down NMOS of the storing inverter, 12 516 Ω + 7 883 Ω = 20 398 Ω. That is
14.4× the 1414 Ω of the bitline metal, so the discharge is set almost entirely
by a device the hand formula has no term for.

This is the same series pair whose sizing ratio Part A measured as the cell
ratio: the transistor that limits read speed here is the one whose width sets
the read stability margin there.

Other things CACTI includes and 0.38RCL² does not, in rough order of size:

- **Sense-amplifier threshold.** The bitline never swings to 50 %; it develops
  V_sense = 80 mV and the amplifier fires. `ln(V_pre/(V_pre−V_sense))` replaces
  the 0.38, and 0.0834 ≪ 0.38 — worth 4.6× in the other direction.
- **Wordline slew.** The Horowitz expression folds the finite wordline rise time
  into the delay: 1.97× here.
- **Cell drain capacitance.** C_bl = 115.5 fF against 86.8 fF of wire — 25 % of
  the bitline capacitance is the drain junctions of the 512 access transistors,
  not metal.
- **Column-mux, sense-amp isolation and latch capacitance** at the foot of the
  bitline.

## Comment

The lecture formula is the right model for a *wire* and the wrong model for a
bitline. The bitline is a device-limited path with a wire hanging on it, not a
wire-limited path. This is the same conclusion Part A reached from the other
direction — there the read current, not the 180 fF of bitline capacitance, set
how fast ΔV developed.

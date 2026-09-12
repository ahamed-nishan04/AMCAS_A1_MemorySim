# Task 4 — Task 1 repeated at 85 °C

Temperature set with `option temp=85` inside `.control` (equivalent to a
`.temp 85` card) so both corners run in one invocation.

| Quantity | 27 °C | 85 °C | Change |
|---|---|---|---|
| ΔV @ 2.0 ns | 729.9 mV | 582.1 mV | −20.2 % |
| ΔV @ sense window | 69.1 mV | 54.2 mV | **−21.6 %** |
| v(Q) peak | 205.5 mV | 220.8 mV | +7.4 % |
| v(Q) @ 4 ns | 2.71 mV | 14.44 mV | +433 % |
| V_DD at the 25 mV crossing | 0.726 V | **0.795 V** | +68 mV |
| Sense-amp offset | 25 mV | ≈ 25 mV | a few % at most |

## Which moved more, and which sets the failure

Raising the junction temperature from 27 °C to 85 °C cuts the developed bitline
differential by 21.6 % at the sense window (69.1 → 54.2 mV) and by 20.2 % at
2 ns, because carrier mobility falls faster than the threshold voltage drops and
the access device therefore delivers less charge in a fixed window. The
sense-amplifier offset moves far less: input-referred offset is set by V_th
mismatch, σ(ΔV_th) = A_VT/√(WL), and A_VT is only weakly temperature-dependent —
the *mean* V_th falls with temperature, but the *spread* between two nominally
identical devices does not track it — so 25 mV shifts by a few percent at most
over a 58 K rise, an order of magnitude less movement than the signal. (There is
no sense amplifier in the netlist, so this half of the comparison is analytical,
not simulated.) **ΔV is therefore what sets the failure**, and the hot corner is
the limiting one: the supply at which ΔV falls below the offset rises from
0.726 V to 0.795 V, a 68 mV loss of low-voltage headroom, so a design validated
only at room temperature would appear to work down to 0.73 V while failing at
0.80 V in the field. Read stability moves the other way — the disturb peak rises
to 220.8 mV and the recovered low level degrades from 2.7 mV to 14.4 mV as
subthreshold leakage in MA1 competes with a weakened MN1 pull-down — but both
remain far below the ~493 mV trip point, so at 85 °C the cell is limited by
sensing rather than by retention.

## Temperature penalty vs supply

The penalty worsens as the supply drops, from −21.6 % at 1.1 V to −24.8 % at
0.6 V; the slope falls from 11.4 to 9.0 mV per 100 mV of supply. Mobility
degradation costs proportionally more when the gate overdrive is already small,
so the hot, low-voltage corner is the worst case twice over.

| V_DD (V) | 1.10 | 1.00 | 0.90 | **0.795** | 0.75 | **0.726** | 0.70 | 0.60 |
|---|---|---|---|---|---|---|---|---|
| ΔV, 27 °C (mV) | 69.1 | 56.9 | 44.9 | ~26 | 27.6 | **25.0** | 22.1 | 12.1 |
| ΔV, 85 °C (mV) | 54.2 | 44.4 | 34.8 | **25.0** | 21.0 | ~20 | 16.7 | 9.1 |

At the room-temperature limit of 0.726 V the hot cell delivers only ~20 mV,
already under the offset — validating at 27 °C alone would leave the part failing
across its whole rated temperature range at that supply.

Measured:

```
---- Task 1 repeated at 85 C, VDD = 1.1 V ----
r[0] = 7.298581e-01   r[1] = 5.821154e-01    $ dV @ 2.0 ns,  27 / 85 C
r[2] = 6.910866e-02   r[3] = 5.419373e-02    $ dV @ sense window
r[4] = 2.055219e-01   r[5] = 2.207622e-01    $ v(Q) peak
r[6] = 2.711905e-03   r[7] = 1.444291e-02    $ v(Q) @ 4 ns
vcross85 = 7.947550e-01
```

Note: `print r[0] r[1]` prints one value per line rather than as columns, because
the vectors resolve in different plots. Values are correct either way.

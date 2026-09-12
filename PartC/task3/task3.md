# Part C, Task 3 — TMR 2:1 → 3:1

`sample_tmr3.cell` is the assignment cell with `-ResistanceOn: 4000` and
`-ResistanceOff: 12000`. Everything else identical. TMR = (R_off − R_on)/R_on
goes from **100 % to 200 %** — in device-paper terms, a doubling of the headline
figure.

## Which output metric moved most

| Metric | TMR 2:1 | TMR 3:1 | Change |
|---|---|---|---|
| **Write latency** | 10.871 ns | 10.974 ns | **+0.95 % (worse)** |
| Read latency | 1.727 ns | 1.733 ns | +0.35 % (worse) |
| Read energy | 717 pJ | 716 pJ | −0.14 % |
| Write energy | 497 pJ | 495 pJ | −0.40 % |
| Leakage | 265.301 mW | 265.269 mW | −0.01 % |
| Area | 3.008 mm² | 3.003 mm² | −0.17 % |

Free-search organisation, same direction: read 2.695 → 2.732 ns, write
11.848 → 12.053 ns.

**Write latency moved most, and it moved the wrong way.** Doubling the TMR made
every latency worse and improved nothing. Inside the write path the change is
larger than the top-line number suggests:

| Component | TMR 2:1 | TMR 3:1 | Change |
|---|---|---|---|
| **Write charge latency** | 464.7 ps | 567.6 ps | **+22.1 %** |
| Read bitline latency | 137.7 ps | 143.6 ps | +4.3 % |
| **Sense-amp latency** | **803.455 ps** | **803.455 ps** | **0.00 %** |
| Write bandwidth | 6.006 GB/s | 5.949 GB/s | −0.95 % |

The one number TMR is supposed to improve — sense-amp latency — did not move by
a single femtosecond. Why NVSim cannot respond to TMR at all is in
`../findings.md`; it is the reason this table looks the way it does.

## Why the write path got worse

R_on sits in series with the write path. At the fixed 200 µA write current the
MTJ drops **I·R_on = 0.6 V at 3 kΩ, 0.8 V at 4 kΩ**. With V_dd = 1.0 V, the
headroom left for the access transistor and the bitline falls from 0.4 V to
0.2 V — halved. The access device must deliver the same current from half the
overdrive, which is why the charge phase stretches 22 %. The read path pays a
smaller version of the same thing: +4.3 %.

## What a TMR headline actually buys at the array level

Nothing in this run, because NVSim has no mechanism through which TMR can act.
But even in a correct model, TMR does not buy read *speed*. It buys **sensing
margin**, and margin is spent on things other than time.

**Longer bitlines, hence bigger subarrays.** The read signal must survive the
bitline IR drop and the parasitics of every unselected cell on the column. At
40 µA, TMR 2:1 gives ΔV = 40 µA × (6 − 3) kΩ = **120 mV**; TMR 3:1 gives
40 µA × (12 − 4) kΩ = **320 mV**, 2.67× more. That extra signal lets you hang
more rows on a bitline before the margin closes — fewer subarrays, fewer sense
amplifiers, fewer decoders. It converts into **area and leakage**, not latency.

**Tolerance of variation.** Real arrays fail on distribution overlap, not nominal
values: MTJ resistance varies cell to cell, the reference cell has its own
spread, and the sense amplifier has an input offset — the same kind of offset
Part A's Task 3 measured against. A nominal 120 mV separation with a few percent
σ(R)/R across 16.8 M cells is a yield question; 320 mV is a much safer one. TMR
buys **yield and bit-error rate**.

**Smaller, cheaper sense amplifiers.** A larger input signal means less gain and
less offset cancellation, so the amplifier can be smaller and faster. This is
where TMR *could* buy latency — indirectly, and only in a model that sizes the
amplifier from the signal rather than reading its delay from a table.

So the honest translation of "we achieved 200 % TMR" is **not** "reads get
faster". It is "you may build a larger subarray, with fewer sense amplifiers, and
still meet your BER target" — a density and yield claim.

There is also a cost NVSim misses entirely: the physical switching energy is
**I²·R_on·t = 1.2 pJ/bit at 3 kΩ and 1.6 pJ/bit at 4 kΩ, a 33 % increase**.
Raising R_on to raise TMR is not free, and the tool prices it at zero.

# Part C, Task 3 — TMR 2:1 → 3:1

`sample_tmr3.cell` is the assignment cell with `-ResistanceOn: 4000` and
`-ResistanceOff: 12000`. Everything else identical. TMR = (R_off − R_on)/R_on
goes from **100 % to 200 %** — in device-paper terms, a doubling of the headline
figure.

## What moved

| Metric | TMR 2:1 | TMR 3:1 | Change |
|---|---|---|---|
| **Write latency** | 10.871 ns | 10.974 ns | **+0.95 % (worse)** |
| Read latency | 1.727 ns | 1.733 ns | +0.35 % (worse) |
| Read energy | 717 pJ | 716 pJ | −0.14 % |
| Write energy | 497 pJ | 495 pJ | −0.40 % |
| Leakage | 265.301 mW | 265.269 mW | −0.01 % |
| Area | 3.008 mm² | 3.003 mm² | −0.17 % |

Free-search organisation, same direction: read 2.695 → 2.732 ns, write 11.848 →
12.053 ns.

**Write latency moved most, and it moved the wrong way.** Doubling the TMR made
every latency worse and improved nothing. Inside the write path the change is
larger than the top-line number suggests:

| Component | TMR 2:1 | TMR 3:1 | Change |
|---|---|---|---|
| **Write charge latency** | 464.7 ps | 567.6 ps | **+22.1 %** |
| Read bitline latency | 137.7 ps | 143.6 ps | +4.3 % |
| **Sense-amp latency** | **803.455 ps** | **803.455 ps** | **0.00 %** |
| Write bandwidth | 6.006 GB/s | 5.949 GB/s | −0.95 % |

The one number TMR is supposed to improve — sense-amp latency — did not move by a
single femtosecond.

## Why the sense amp did not notice

`SubArray.cpp:218`: `senseVoltage = cell->minSenseVoltage`. The signal the
amplifier must resolve is a **constant read from the cell file**, not a quantity
derived from R_on and R_off. Our cell file does not specify `-MinSenseVoltage`,
so it takes the default 0.08 V, regardless of what the resistances are.

`SenseAmp::CalculateLatency` then computes, for current sensing, a hard-coded
IV-converter delay — 0.80 ns at 45 nm, from the authors' HSPICE
characterisation — plus `tau · ln(V_dd / senseVoltage)`. **R_on and R_off appear
nowhere in either term.**

That second term is also nearly irrelevant. Sweeping `-MinSenseVoltage` by 8×
moves the sense-amp latency by 3 ps:

| MinSenseVoltage | 25 mV | 80 mV | 200 mV |
|---|---|---|---|
| Sense-amp latency | 805.0 ps | 803.5 ps | 802.2 ps |
| Cache hit latency | 1.728 ns | 1.727 ns | 1.725 ns |

So NVSim's MRAM read-sensing time is, to within 0.4 %, a constant. No cell
parameter you can write reaches it.

## Why the write path did notice, and got worse

R_on sits in series with the write path. At the fixed 200 µA write current the
MTJ drops **I·R_on = 0.6 V at 3 kΩ, 0.8 V at 4 kΩ**. With V_dd = 1.0 V, the
headroom left for the access transistor and the bitline falls from 0.4 V to
0.2 V — halved. The access device has to deliver the same current from half the
overdrive, which is why the charge phase stretches 22 %. The read path pays a
smaller version of the same thing: a higher-resistance cell charges the bitline
more slowly, +4.3 %.

There is a second cost NVSim misses. The physical switching energy is
**I²·R_on·t = 1.2 pJ/bit at 3 kΩ and 1.6 pJ/bit at 4 kΩ, a 33 % increase.** NVSim
charges `V_dd · I · t` = 2.0 pJ/bit in both cases (`MemCell.cpp:516`), so it
reports write energy as *falling* 0.4 % when it should rise by a third. Raising
R_on to raise TMR is not free, and the tool prices it at zero.

## What a TMR headline actually buys

Nothing in this run, because NVSim has no mechanism through which TMR can act.
But the deeper point is that even in a correct model, TMR does not buy read
speed. It buys **sensing margin**, and margin is spent on things other than time.

**Longer bitlines, hence bigger subarrays.** The read signal has to survive the
bitline IR drop and the parasitics of every unselected cell on the column. At
40 µA, TMR 2:1 gives ΔV = 40 µA × (6 − 3) kΩ = **120 mV**; TMR 3:1 gives 40 µA ×
(12 − 4) kΩ = **320 mV**, 2.67× more. That extra signal lets you hang more rows
on a bitline before the margin closes. More rows per subarray means fewer
subarrays, fewer sense amplifiers, fewer decoders — it converts into **area and
leakage**, not latency.

**Tolerance of variation.** Real arrays fail on distribution overlap, not on
nominal values: MTJ resistance varies cell to cell, the reference cell has its own
spread, and the sense amplifier has an input offset — exactly the 25 mV offset
Part A's Task 3 measured against. A nominal 120 mV separation with a few percent
σ(R)/R across 16.8 M cells is a yield question; 320 mV is a much safer one. TMR
buys **yield and bit-error rate**.

**Smaller, cheaper sense amplifiers.** A larger input signal means the amplifier
needs less gain and less offset cancellation, so it can be smaller and faster.
This is where TMR *could* buy latency — but only indirectly, and only in a model
that sizes the amplifier from the signal rather than reading its delay from a
table.

So the honest translation of "we achieved 200 % TMR" is **not** "reads get
faster." It is "you may build a larger subarray, with fewer sense amplifiers, and
still meet your BER target" — a density and yield claim. Whether the array cashes
that in depends on the periphery designer, and whether the *tool* can see it
depends on whether the tool models sensing margin at all. NVSim does not:
`senseVoltage` is an input, not an output.

## The modelling lesson

This is the clearest illustration in the assignment of the note at the top of
Part C: *your results are exactly as good as the .cell file you feed it.* Two
cell parameters that a device physicist would call the headline result of a paper
were doubled, and the simulator's response was to report every metric slightly
worse, because the only paths through which R_on and R_off reach the output are
parasitic ones. To make NVSim show what TMR buys, you would have to edit
`-MinSenseVoltage` by hand — which means supplying the answer as an input and
then reading it back out.

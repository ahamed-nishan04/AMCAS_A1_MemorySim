# Part C, Task 2 — Which two collapse, which two win, and why

| Metric | Ratio (STT vs SRAM, 4-bank) | Verdict |
|---|---|---|
| **Leakage** | 8.48× better (15.3× free search) | **dramatically better** |
| **Area** | 3.81× better | **dramatically better** |
| **Write latency** | 3.75× worse | **dramatically worse** |
| **Write energy** | 17× worse *at the cell*; ≥1.2× worse at the array | **dramatically worse** |
| Read latency | 1.68× better | organisational, not device |
| Read energy | 1.11× better | organisational, not device |

The split is not arbitrary: **every metric that moves dramatically is a
*standby* or *write* metric, and every metric that barely moves is a *read*
metric.** That is the signature of replacing a charge-held bistable latch with a
magnetically-held resistor. Storage and writing change completely; reading a
resistance and reading a charged node both end up as "drive a bitline into a
sense amplifier," and both then pay the same H-tree tax.

## Dramatically better

### Leakage — 134 nW/bit → 11 nW/bit

A 6T SRAM cell holds its state as a voltage on a node, and a voltage on a node
is only held by a conducting path to a rail. Both cross-coupled inverters are
biased between V_DD and ground at all times, so every cell carries subthreshold
current through its off devices, through both access transistors into the
precharged bitlines, and gate leakage through all six. At 45 nm ITRS-HP, with the
high-performance (low-V_th) devices this cache uses, and at 350 K where
subthreshold current has risen several fold over room temperature, that comes to
**2250.5 mW across 16.78 Mbit = 134 nW per bit**, continuously, whether or not
the cache is accessed.

An MTJ holds its state as the magnetisation direction of a free layer. A
direction is not maintained by a current — it is a minimum of the free layer's
own anisotropy energy, and it persists with the supply off. The 1T1R cell's only
standby path is the access transistor's subthreshold current, and with the
wordline low and the cell deselected that is a single off device rather than six
biased ones.

What survives is periphery. Of the STT design's 265.3 mW, 25.7 mW is H-tree
leakage and 55.8 mW is the tag array; the data mats account for ~184 mW, or
**11 nW per bit**, which is decoders, sense amplifiers, precharge and write
drivers, not cells. The cell array's contribution has gone to approximately zero
and what is left is the cost of the CMOS wrapped around it.

**The device point:** non-volatility is not a feature added on top of the
storage mechanism — it *is* the absence of a standby current path. The leakage
win and the non-volatility are the same physical fact stated twice.

### Area — 146 F² → 54 F² per cell

The 6T cell measures 0.657 × 0.45 µm = 0.2957 µm², which is **146 F²** at
F = 45 nm. It cannot be made of six minimum devices: Part A showed why. The cell
ratio W(pull-down)/W(access) has to stay above ~1 or read static noise margin
collapses — at CR = 0.83 the RSNM fell 41 %, to 81 mV. So the pull-downs are
oversized relative to the access transistors by design, and the whole cell
inflates. **SRAM area is set by a stability constraint, not by lithography.**

The STT cell is 54 F². It is one access transistor plus an MTJ, and the MTJ is
fabricated in the back-end metal stack *above* the transistor. The storage
element consumes no silicon footprint at all — the cell area is whatever the
access transistor needs, and the resistor is free in plan view. That is the 2.70×
cell-level density advantage.

The array advantage is larger still, 3.81×, because the peripheral overhead
amortises better: 71.7 % area efficiency against the SRAM's 54.3 %. The SRAM was
driven toward many small mats (Ndwl 4) to keep bitlines short for delay, and each
mat replicates decoders and sense amps; the MRAM array tolerates a 1024 × 1024
subarray. Some of that is the objective, not the cell — but the 2.70× is pure
device.

## Dramatically worse

### Write latency — a latch flip versus a magnetisation reversal

An SRAM write is a regenerative event. The write drivers overpower one side of
the cell, the cross-coupled pair's positive feedback takes over, and the cell
flips in roughly an inverter delay. There is no minimum time imposed by physics
beyond the RC of the bitline and the loop gain — it is fast because the storage
mechanism is *electrical* and the feedback is *amplifying*.

An STT write is a spin-transfer torque magnetisation reversal. Spin-polarised
current transfers angular momentum to the free layer; the magnetisation precesses
with growing amplitude until it crosses the energy barrier. The barrier E_b is
not incidental — it is exactly what gives ten-year retention, and it is the same
barrier the write current must push the magnetisation over. Switching time in the
precessional regime scales roughly as 1/(I/I_c0 − 1), so writing fast demands
large current overdrive, and there is no positive feedback to help: the current
must be sustained for the entire reversal.

The cell file's 10 ns `-SetPulse`/`-ResetPulse` is that reversal time. In the
measured write latency of 10.871 ns, **10.000 ns is the pulse — 92 %**. The
remaining 871 ps is decoder, predecoder and bitline charging. No array
organisation can touch it: repartitioning, more banks, wider mats all attack the
871 ps and leave the 10 ns untouched. Write bandwidth follows — 6.0 GB/s against
the SRAM's ~24 GB/s at its 2.652 ns cycle, 4× worse.

**The device point:** retention and write speed are set by the same energy
barrier, so they trade against each other directly. You cannot make an STT cell
write quickly and remember for ten years; the cell file's 10 ns is the price of
whatever E_b its authors assumed.

### Write energy — 0.115 pJ/bit → 2.0 pJ/bit

Same physics, integrated over time. An SRAM write dissipates roughly C_bl · V_DD²
on the bitline that swings: with Part B's measured C_bl = 115.5 fF at V_DD = 1.0 V,
**0.115 pJ per bit**, and it is a capacitor charge, so it ends the moment the
node reaches the rail.

The MTJ must *conduct* for the whole pulse. There is no capacitor to fill and
stop — the energy is I · V · t of a resistive path held on for the reversal time:
200 µA × 1.0 V × 10 ns = **2.0 pJ per bit**, **17× the SRAM cell write**. Both
factors are large and both are tied to the barrier: the current must exceed I_c0,
and the time must cover the reversal.

At the array level the ratio is compressed to ≥1.2× (1.024 nJ per 512-bit line
against the SRAM's 851 pJ) only because the SRAM's figure is dominated by H-tree
and decoder energy that both designs pay. Strip the shared periphery away and the
cell-level 17× is the honest number. NVSim's reported 497 pJ is below the
1.024 nJ floor its own cell file implies and should not be used — see Task 1.

Write energy-delay product is the compact statement: **11.1 nJ·ns against
2.47 nJ·ns, 4.5× worse.**

## Why read latency and read energy are not on this list

Both move by less than 2×, and neither move is primarily the bitcell's doing.

Reading an MTJ means forcing 40 µA through 3 kΩ or 6 kΩ and resolving the
difference — a 2:1 resistance ratio, which is a small signal and costs 803 ps of
sense-amp time in NVSim's model. Reading an SRAM cell means discharging a bitline
and resolving ~80 mV. Different mechanisms, comparable difficulty. The STT design
then wins on read latency mostly because its array is 3.8× smaller and therefore
its wires are shorter — it inherits the area advantage rather than earning a read
advantage. And 41 % of its read energy (256.9 pJ of 619.3 pJ in the data array)
is H-tree, exactly the same interconnect tax Part B found was 47 % of the SRAM's
access time. **Reads look similar because reads are dominated by the parts the
two technologies share.**

## Forward pointer to Part E

The two wins are continuous and the two losses are per-event, which means the
verdict depends entirely on access rate. The leakage saving is 1985 mW =
1.985 nJ/ns of standby power; the extra energy per line write is ~173 pJ. Those
break even at **11.5 writes per nanosecond** — a rate no L2 can sustain, so on
*energy* alone STT-MRAM wins overwhelmingly at any realistic workload.

The case against it is therefore not energy. It is the 10 ns write latency and
the 4× write bandwidth deficit, which Ramulator and gem5 will convert into cycles
the processor actually stalls for — plus endurance, which neither tool models at
all. That is the argument Part E has to settle.

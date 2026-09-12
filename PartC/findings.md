# Part C — NVSim findings and caveats

Three separate places where NVSim's output does not mean what its input implies.
All three affect how the task tables should be read.

## 1. The reported write energy is below the floor its own cell file implies

**Do not quote NVSim's write energy without this note.**

For a current-mode write with no write voltage specified, NVSim computes the
per-bit switching energy as `V_dd × I_write × t_pulse` (`MemCell.cpp:516`). From
`sample.cell`: 1.0 V × 200 µA × 10 ns = **2.0 pJ per bit**, confirmed by
instrumenting the binary. A 64 B line is 512 bits, so switching the MTJs alone
costs **1.024 nJ** before any peripheral, wire or decoder energy.

NVSim reports 0.497 nJ (4 banks) and 0.255 nJ (free search) for the whole cache
write — 2× and 4× *below* that floor.

The cause is in `SubArray.cpp`: the cell write energy is charged for
`numColumn / (muxSenseAmp · muxOutputLev1 · muxOutputLev2)` bits of one subarray
— 128 bits for the free-search organisation, and the 4-bank run has a 1024-column
subarray with the same structural problem — not the 512 bits of a cache line, and
the result is never scaled back up to the line.

**Use 1.024 nJ as a hand-computed lower bound** on STT-MRAM write energy for
anything downstream, and treat 0.497 nJ as the tool's figure rather than the
physical one. Against the SRAM's 851 pJ this turns a nominal 1.71× *advantage*
into at least a 1.2× *disadvantage*.

## 2. TMR cannot reach the sense amplifier at all

`SubArray.cpp:218`: `senseVoltage = cell->minSenseVoltage`. The signal the
amplifier must resolve is a **constant read from the cell file**, not a quantity
derived from R_on and R_off. The Part C cell file does not specify
`-MinSenseVoltage`, so it takes the default 0.08 V regardless of the
resistances.

`SenseAmp::CalculateLatency` then computes, for current sensing, a hard-coded
IV-converter delay — 0.80 ns at 45 nm, from the authors' HSPICE characterisation
— plus `tau · ln(V_dd / senseVoltage)`. **R_on and R_off appear nowhere in
either term.**

That second term is also nearly irrelevant. Sweeping `-MinSenseVoltage` by 8×
moves the sense-amp latency by 3 ps:

| MinSenseVoltage | 25 mV | 80 mV | 200 mV |
|---|---|---|---|
| Sense-amp latency | 805.0 ps | 803.5 ps | 802.2 ps |
| Cache hit latency | 1.728 ns | 1.727 ns | 1.725 ns |

(Runs `o_25.txt`, `o_80.txt`, `o_200.txt` in `task3/`.)

So NVSim's MRAM read-sensing time is, to within 0.4 %, a constant. No cell
parameter reaches it. To make NVSim show what TMR buys you would have to edit
`-MinSenseVoltage` by hand — which means supplying the answer as an input and
reading it back out.

**This also matters for Part E.** The 803 ps hard-coded IV-converter delay is a
large fraction of the STT read latency and is independent of everything in the
cell file, which is why the Part E configuration list carries a pessimistic
hit-latency variant alongside the measured one.

## 3. The write-current → cell-area chain is not modelled

Every link of the chain the assignment describes is broken:

- **Current does not size the transistor.** `-AccessCMOSWidth (F): 6` is read
  straight from the cell file (`MemCell.cpp:326`). NVSim never checks whether a
  6 F device can deliver 200 µA. The width is used only for on-resistance and
  gate/drain capacitance (`SubArray.cpp:250-252`), never for sizing.
- **Transistor width does not set cell area.** `MemCell.cpp:141`:

  ```c
  heightInFeatureSize = sqrt(area * aspectRatio);
  widthInFeatureSize  = sqrt(area / aspectRatio);
  ```

  Cell area is a pure input. `widthAccessCMOS` appears nowhere in it.
- **Write current *is* used**, but only at `SubArray.cpp:123`, which computes
  `maxBitlineCurrent` for wordline and bitline IR and electromigration limits.
  That is a wire-sizing check, not a cell-area calculation.
- **`writeDynamicEnergy = MAX(cellResetEnergy, cellSetEnergy)`**
  (`SubArray.cpp:750`), which is why halving `-ResetCurrent` alone changes
  nothing while `-SetCurrent` stays at 200 µA.

Task 4 therefore does the chain by hand and feeds consistent (current, width,
area) triples back in as `cell_*.cell` / `cfg_*.cfg`.

## Operational notes

- **Every `.cfg` here names its cell file with a bare filename** and is run from
  its own task directory via `../nvsim`. The original tree mixed conventions —
  some cfgs used bare names and had to run from inside their subdirectory, others
  used a directory-prefixed path and had to run from the part root. Normalised so
  all `run.sh` scripts work the same way.
- **NVSim predates C++17**: a local variable named `data` collides with
  `std::data` under `using namespace std;`. `nvsim_build.patch` sets
  `-std=c++11`; the rest is warning noise. `build_nvsim.sh` applies it.
- **Read the CACHE DESIGN SUMMARY block, not the per-array sections.** The
  headline numbers (Cache Hit Latency 1.727 ns, Cache Write Latency 10.871 ns,
  0.717 nJ, 0.497 nJ, 265.301 mW, 3.008 mm²) are in the summary. The
  `CACHE DATA ARRAY` and `CACHE TAG ARRAY` sections lower down report the same
  quantities per array and are easy to misread as totals.

## Reproduction status

Re-verified: all eleven shipped output files diff **byte-identical** against
fresh runs of the shipped binary — `out.txt`, `out_4bank.txt`, both `*_100`
variants, the five TMR runs and the four write-current runs.

## Demonstrated twice: the write-current chain really is absent

Task 4's claim that NVSim does not connect write current to cell area is not an
inference from reading the code — it is visible in two runs that were already
in the submission.

**`STT_4bank_reset100` (ResetCurrent halved, SetCurrent unchanged): every
single output digit is unchanged.** Not one number moves. Two independent
reasons, both mechanical: `SubArray.cpp:750` takes
`writeDynamicEnergy = MAX(cellResetEnergy, cellSetEnergy)`, and SetCurrent is
still 200 uA; and area does not depend on write current in either direction.

**`STT_4bank_both100` (both currents halved): area is still 3.008 mm^2,
identical to baseline.** This is the decisive one. Halving the current a cell
must switch with should, physically, permit a narrower access transistor and
therefore a smaller cell — and the area does not move at all. What *does* move
is write energy (497 -> 399 pJ) and read latency (1.727 -> 1.698 ns), both of
which are peripheral effects.

### Where that 29 ps of read latency actually comes from

Worth tracing, because it looks at first like the tool responding to the cell
change and it is not. `SubArray.cpp:123`:

```c
maxBitlineCurrent = MAX(cell->resetCurrent, cell->setCurrent)
                    + cell->leakageCurrentAccessDevice * (numRow - 1);
...
minBitlineMuxWidth = maxBitlineCurrent / tech->currentOnNmos[...];   // :184
```

The write current sizes the **bitline column-mux transistor** — a larger
current needs a wider mux device to carry it. That width sets the mux's
capacitance, and `bitlineMux`, `senseAmpMuxLev1` and `senseAmpMuxLev2` are all
`Initialize`d with `maxBitlineCurrent` for delay calculation. Halving the
current shrinks the mux, shrinks its capacitance, and shaves a few ps off the
read path.

So write current *is* used — but only to size peripheral mux transistors, never
to size the access device or the cell. The one place the current-to-width
relationship would matter is the one place it is not applied.

### Why NVSim is built this way

Not stated in the source, but the design intent is legible from the structure:
the `.cell` file is treated as a **pre-characterised description of a cell
someone has already designed** — in SPICE, or from a fab PDK. Area, access
width, resistances and currents are independent inputs describing a given
device, not degrees of freedom for NVSim to co-optimise. NVSim's job is
everything *around* the cell: array partitioning, decoders, sense amplifiers,
peripheral energy and delay. CACTI makes the same choice with SRAM cell
dimensions, which it takes as technology-node constants rather than deriving
them from drive strength.

**The practical consequence** is that NVSim cannot detect an internally
inconsistent cell file. Hand it `-AccessCMOSWidth: 6` with `-SetCurrent: 400`
and it will happily report a design in which that transistor cannot deliver the
current it is being asked to switch with. That is exactly the consistency check
Task 4 Step 1 performs by hand, and it is why the (current, width, area)
triples have to be constructed externally and fed back in.

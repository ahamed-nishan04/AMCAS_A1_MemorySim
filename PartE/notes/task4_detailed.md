# Part E, Task 4 — The argument

## (i) Should the 2 MB L2 be SRAM or STT-MRAM?

**On this evidence, STT-MRAM — but only as "8 MB of STT-MRAM in the 2 MB SRAM's
area, for read-dominated traversal on an out-of-order core, given this cell
file," and the qualifiers carry as much weight as the verdict.** The chain is
this. Part A established that the 6T cell is not free to shrink: at cell ratio
0.83 its read static noise margin collapses 41 % (138.2 → 81.4 mV), so SRAM area
is set by a stability constraint, and at 85 °C the array cannot be sensed below
0.795 V. Part B priced that cell at 2 MB: 2.902 ns, 11.474 mm², and **2250.5 mW
of leakage** — the number that motivates the whole question. Part C replaced the
bitcell and found the split is not uniform across metrics but falls cleanly into
standby-and-write versus read: leakage improves 8.5× and area 3.8× because a
magnetisation direction needs no holding current and the MTJ sits in the back-end
metal above the transistor, while write latency degrades 3.75× and cell write
energy 17× (0.115 → 2.0 pJ/bit) because both are governed by the same energy
barrier that provides retention. Sweeping capacity at fixed banking put the
iso-area point at **8 MB in 9.345 mm²** — 4× the capacity, still 4.1× less
leakage. Part E then converted that into cycles. On an O3 core, bfs gains
**+27.8 % IPC** and sssp **+3.6 %** even under the pessimistic 2×-hit-latency
assumption, because the extra capacity halves bfs's L2 miss rate (41.0 → 19.4 %).
Part E Task 2 identified what decides it: not the technology but the share of the
working set whose reuse distance lies between 2 and 8 MB. bfs's ~3 MB of
vertex-indexed structures sits exactly in that window and becomes resident; sssp
works one delta-stepping bucket at a time, already fits 2 MB, and its remaining
traffic is a 58 MB edge stream no L2 will hold. The break-even DRAM miss penalty
makes this quantitative: **27.7 cycles for bfs, 122.4 for sssp** — bfs clears it
sevenfold, sssp barely twofold. And Part E Task 3 showed the verdict is a
property of the core as much as the cache: in-order, the advantage halves to
+14.4 % for bfs and **sssp turns negative at −1.8 %**, because an out-of-order
core hides 67–70 % of the hit-latency penalty but only 50–52 % of the miss
benefit. It discounts the cost of the trade more than the gain. The
uncomfortable consequence is that **STT-MRAM looks best on precisely the machine
best equipped to hide its weakness**, while the leakage argument that motivates
it applies most strongly to the simple, low-power cores where Part E says the
trade is marginal or negative. Part D is the final qualifier: on the same DDR4
channel and the same 100 000 accesses, the address mapping alone is worth
**15.6×** and the scheduler 5.0× — both larger than any bitcell effect measured
here except leakage. If the miss stream does not shrink, the memory controller,
not the L2 cell, is what sets performance.

## (ii) The three assumptions I would attack first as a reviewer

**First, the 8 MB is a write-current assumption wearing a density result's
clothing.** The 54 F² cell area is not a property of the MTJ, which occupies no
silicon footprint at all; it is the area of the transistor needed to push 200 µA
through it, and NVSim treats it as a pure input with no link to the write current
at all — halving `-ResetCurrent` changed not one digit of any output. Doing the
chain by hand, 400 µA needs a 12 F access device and an ~85 F² cell, at which
point the array is 4.151 mm² per 2 MB, **8 MB no longer fits in the SRAM's
11.474 mm², and the entire capacity premise of Part E disappears.** Since write
current is coupled to retention through the same barrier that sets write time,
"200 µA with ten-year retention" is the claim the whole result rests on, and it
is asserted by the cell file, not measured. **Second, the hit latency that makes
the trade work is not derived from the cell.** NVSim sets `senseVoltage =
cell->minSenseVoltage` — a constant read from the file — and adds a hard-coded
803 ps IV-converter delay; doubling the TMR from 2:1 to 3:1 moved the sense-amp
latency by **exactly zero femtoseconds** and made every reported metric slightly
*worse*. So the 2.967 ns that I compared against CACTI's 2.902 ns contains no
information about the resistances, and it is a cross-tool comparison between two
different peripheral models besides. That is why Part E ran the 12-cycle
configuration at all, and it is the reason sssp's verdict is not safe: its margin
is +16.2 % or +3.6 % depending on which number is believed, and −1.8 % if the
core changes too. **Third, and worst, gem5 never charged the write cost.** gem5's
cache has a single tag/data/response latency applied to reads and writes alike,
so an L2 whose measured write latency is 10.871 ns — 22 cycles at 2 GHz, 92 % of
it the cell file's 10 ns switching pulse — was simulated as if writes completed
in 6 or 12. The write energy is worse than unmodelled: NVSim reports 0.497 nJ per
line write against a **1.024 nJ floor implied by its own cell file** (2.0 pJ/bit
× 512 bits), because `SubArray.cpp` charges only 128 bits of one subarray and
never scales to the line. And endurance — the failure mode that actually kills
STT-MRAM as a last-level cache — appears in none of the five tools. A reviewer
should ask for `system.l2.WritebackDirty::total` and re-derive the result with
writes priced at 22 cycles and 1.024 nJ; on a writeback L2 fed by graph kernels
with scattered updates, that alone could reverse the sssp verdict and materially
narrow bfs's.

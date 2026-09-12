# Part D, Task 3 — Row bits below bank bits

Ramulator 2.0a ships both mappings, so this one is a genuine config change:
`AddrMapper: { impl: RoBaRaCoCh }` → `{ impl: ChRaBaRoCo }`. Scheduler back to
FR-FCFS, everything else as Task 1.

Field order, low bit first, for this organisation (DDR4_8Gb_x8, 2 ranks: 0
channel bits, 1 rank, 2 bank-group, 2 bank, 16 row, 7 column after the 64 B
transfer granularity):

| Mapping | Byte-address bit assignment |
|---|---|
| `RoBaRaCoCh` | col 6–12, **rank 13, bg 14–15, bank 16–17**, row 18–33 |
| `ChRaBaRoCo` | col 6–12, **row 13–28**, bank 29–30, bg 31–32, rank 33 |

`ChRaBaRoCo` is the requested arrangement: the 16 row bits sit below the bank
bits instead of above them.

## Bank-level parallelism, measured directly

The `TraceRecorder` plugin logs every issued command with its full address
vector, so the number of banks actually touched can be counted rather than
argued:

| Stream | Mapping | Distinct banks used | Busiest bank's share of commands |
|---|---|---|---|
| `seq` | RoBaRaCoCh | **32** | 3.2 % |
| `seq` | ChRaBaRoCo | **1** | 100 % |
| `rand` | RoBaRaCoCh | **32** | 3.2 % |
| `rand` | ChRaBaRoCo | **1** | 100 % |
| `mixed` | RoBaRaCoCh | **32** | 3.5 % |
| `mixed` | ChRaBaRoCo | **3** | 58.1 % |

3.2 % is 1/32 — RoBaRaCoCh spreads the stream perfectly evenly over all 2 ranks
× 4 bank groups × 4 banks. ChRaBaRoCo collapses it onto one.

**Why one and not, say, eight.** With row bits below bank bits, the first bank
bit is address bit 29. These traces have a 256 MB footprint, so no address
reaches bit 28 and the bank, bank-group and rank fields are *never non-zero*.
Under this mapping a workload needs a 512 MB footprint before it touches a
second bank, and 16 GB before it uses all 32. The row field — 16 bits, 64 MB
of address space — has to be exhausted before any bank bit moves. That is the
whole mechanism: putting a large field below a small one buries the small one
beyond the reach of any realistic working set.

## The cost

| Stream | Cycles | Avg read latency | Bandwidth | Channel utilisation |
|---|---|---|---|---|
| `seq` RoBaRaCoCh | 697 849 | 332.9 cyc (208 ns) | 14.67 GB/s | 57.3 % |
| `seq` ChRaBaRoCo | 1 010 287 | 470.2 cyc (294 ns) | 10.14 GB/s | 39.6 % |
| `rand` RoBaRaCoCh | 519 900 | 290.0 cyc (181 ns) | 19.70 GB/s | 76.9 % |
| `rand` ChRaBaRoCo | **8 113 015** | **3613.6 cyc (2258 ns)** | **1.26 GB/s** | **4.9 %** |
| `mixed` RoBaRaCoCh | 779 326 | 380.4 cyc (238 ns) | 13.14 GB/s | 51.3 % |
| `mixed` ChRaBaRoCo | 2 783 649 | 1261.0 cyc (788 ns) | 3.68 GB/s | 14.4 % |

| Stream | Slowdown | Latency | Banks |
|---|---|---|---|
| `seq` | 1.45× | 1.41× | 32 → 1 |
| `rand` | **15.60×** | **12.46×** | 32 → 1 |
| `mixed` | 3.57× | 3.32× | 32 → 3 |

Row-buffer hit rates barely move (99.1 → 97.8, 0.1 → 0.1, 58.9 → 52.6). As in
Task 2, **the row buffer is not where the damage is.**

## Quantified against the timing constraints

Cycles per access makes the mechanism arithmetic rather than rhetorical:

| Bound | Constraint | Cycles/access |
|---|---|---|
| Data bus | nBL | 4.00 |
| Column commands, same bank group | nCCD_L | 8.00 |
| Activations, one bank | **nRC** | **74.00** |

| Stream | RoBaRaCoCh | ChRaBaRoCo |
|---|---|---|
| `seq` | 6.98 | 10.10 |
| `rand` | **5.20** | **81.13** |
| `mixed` | 7.79 | 27.84 |

**`rand` under ChRaBaRoCo runs at 81.1 cycles per access against nRC = 74.** It
is exactly tRC-bound: every access is a row conflict, all conflicts land on one
bank, and a bank cannot be re-activated until nRC = 74 cycles after its last
activation. The excess over 74 is refresh. The DRAM is doing one thing at a
time.

**The same stream under RoBaRaCoCh runs at 5.20 cycles per access against
nBL = 4.** The conflicts have not gone away — 91 479 of them, essentially the
same count — but they are spread over 32 banks, so bank *n*'s tRP and tRCD
elapse while banks *n+1…n+31* are transferring data. The 74-cycle occupancy is
hidden behind the bus, and the bus becomes the limit instead.

So bank-level parallelism converts a tRC-bound workload into a bus-bound one,
and the measured overlap factor is **74 / 5.20 = 14.2 banks deep** — the
controller keeps about fourteen banks in flight at once out of the 32 available,
the shortfall being queue depth (36 reads) and read/write turnaround.

**That ratio is the answer:** losing bank-level parallelism costs up to
**15.6×**, and it costs it by exposing nRC rather than by losing row hits.

## Why `seq` only loses 1.45×

`seq` was never conflict-bound. With 99 % row hits it issues almost pure column
commands, and consecutive columns in the same bank group are limited by
nCCD_L = 8 — twice the nBL = 4 the bus could sustain. Its 6.98 cycles/access
under RoBaRaCoCh is close to that nCCD_L ceiling, not to the bus floor. Moving
to one bank changes which bank group the column commands go to but not the
nCCD_L constraint, so it only loses the rank interleaving (6.98 → 10.10).

This also corrects the explanation given in Task 1. `seq` is *not* slower than
`rand` under RoBaRaCoCh because it lacks bank parallelism — the command trace
shows it using all 32 banks, evenly. It is slower because a stream with perfect
row locality issues back-to-back column commands into one bank group and is
throttled by **nCCD_L = 8 against a bus that wants one transfer every
nBL = 4 cycles**. Perfect row-buffer locality wastes half the data bus. `rand`,
by scattering across bank groups, mostly pays nCCD_S = 4, which matches the bus
exactly — which is why it reaches 76.9 % channel utilisation with a 0.1 % hit
rate.

## The three results together

Across Tasks 1–3, on the same DRAM and the same 100 000 accesses:

| Knob | Best | Worst | Spread |
|---|---|---|---|
| Address stream (Task 1) | 5.20 | 7.79 cyc/access | 1.5× |
| Scheduler (Task 2) | 5.20 | 26.03 | 5.0× |
| Address mapping (Task 3) | 5.20 | 81.13 | **15.6×** |

None of these is a DRAM-device property. They are all decisions in the memory
controller, and the worst of them costs more than an order of magnitude — more
than any bitcell difference measured in Part C. A DRAM simulator contains no
charge and no sense amplifier, and this is what it is for: the timing table is
the same in every row above, and only the order in which legal commands get
issued changed.

# Part D, Task 2 — FR-FCFS → FCFS

Same config as Task 1, one line changed: `Scheduler: { impl: FCFS }`.

Still the synthetic bracketing streams — the real CommMonitor trace replaces them.

## Ramulator 2.0a ships no FCFS

Only `FRFCFS` is registered (`generic_scheduler.cpp:10`); the other files in
`impl/scheduler/` are BLISS, BlockHammer, PRAC and a blocking scheduler. So the
task's one-line change does not exist as a config option and the scheduler has
to be written. `fcfs_scheduler.cpp` (35 lines, added to
`src/dram_controller/CMakeLists.txt`) is FR-FCFS with the *first-ready* half
removed:

```cpp
// FRFCFS::compare       -- ready requests are promoted over older ones
if (ready1 ^ ready2) { return ready1 ? req1 : req2; }
if (req1->arrive <= req2->arrive) ...

// FCFS::compare         -- arrival order only
if (req1->arrive <= req2->arrive) { return req1; } else { return req2; }
```

The controller then calls `check_ready()` on whatever the scheduler hands it
(`generic_dram_controller.cpp:346`) and issues nothing if the command is
illegal — so a blocked request at the head stalls the whole channel. That is
exactly the FCFS semantics wanted.

## A statistic that must not be used

`avg_read_latency_0` is wrong in Ramulator 2.0a. `finalize()` computes

```cpp
s_avg_read_latency = (float) s_read_latency / (float) s_num_read_reqs;
```

but `s_num_read_reqs++` sits in `send()` (line 118), which fires on **every**
send attempt including the ones rejected because the buffer is full. Under
backpressure the frontend retries every tick, so the denominator counts retries:
75 069 actual reads against 1 835 999 counted "requests" in the `seq` FR-FCFS
run, a 24× inflation.

This matters because it inverts the answer. As printed, `avg_read_latency_0`
*falls* under FCFS (13.61 → 13.35) — FCFS looks faster. It isn't: FCFS causes
more retries, which inflates the denominator faster than the numerator. The
correct average is `read_latency_0 / total_num_read_requests`, and it rises
sharply. The Task 1 table is corrected accordingly.

## Results

| Stream | Scheduler | Cycles | Row-buffer hit rate | Conflicts | Read latency, total | **True avg** |
|---|---|---|---|---|---|---|
| `seq` | FR-FCFS | 697 849 | 99.1 % | 0 | 24 992 147 | **332.9** |
| `seq` | FCFS | 880 890 | 99.1 % | 0 | 31 024 297 | **413.3** |
| `rand` | FR-FCFS | 519 900 | 0.1 % | 91 479 | 21 767 213 | **290.0** |
| `rand` | FCFS | 2 602 507 | 0.1 % | 93 308 | 89 502 049 | **1192.3** |
| `mixed` | FR-FCFS | 779 326 | 58.9 % | 36 571 | 28 540 021 | **380.4** |
| `mixed` | FCFS | 2 340 803 | 45.7 % | 48 429 | 80 110 108 | **1067.6** |

**The latency cost, in cycles (tCK = 625 ps):**

| Stream | Avg read latency | Change | Execution time |
|---|---|---|---|
| `seq` | 332.9 → 413.3 cycles (208 → 258 ns) | **+80.4 cycles, 1.24×** | 1.26× |
| `rand` | 290.0 → 1192.3 cycles (181 → 745 ns) | **+902.3 cycles, 4.11×** | 5.01× |
| `mixed` | 380.4 → 1067.6 cycles (238 → 667 ns) | **+687.3 cycles, 2.81×** | 3.00× |

## The row-buffer hit rate does not collapse

The task predicts it will. It does not, in two of the three streams:

- `seq`: **99.1 % under both schedulers.** Requests arrive in row order, so
  arrival order already *is* row order. Reordering has nothing to find.
- `rand`: **0.1 % under both.** There was no locality to lose.
- `mixed`: 58.9 % → 45.7 %, a real but partial drop of 13.2 points.

Yet `rand` is the stream that suffers most — 4.11× on latency with its
row-buffer behaviour completely unchanged. **Row-buffer hit rate is not the
mechanism.** Whatever FCFS costs, it costs it somewhere else.

## tRCD and tRP: what a reordering actually saves

DDR4_3200AA: nCL = 22, nRCD = 22, nRP = 22, nRAS = 52, nRC = 74, nBL = 4,
nCCD_S = 4, nCCD_L = 8.

| Case | Commands | Cycles to data |
|---|---|---|
| Row hit | `RD` | nCL + nBL = **26** |
| Row miss (bank idle, row closed) | `ACT`, `RD` | nRCD + nCL + nBL = **48** |
| Row conflict (wrong row open) | `PRE`, `ACT`, `RD` | nRP + nRCD + nCL + nBL = **70** |

So the row-buffer part of the story is worth **nRP + nRCD = 44 cycles = 27.5 ns**
per access converted from conflict to hit — and a bank is unavailable for
nRC = 74 cycles between successive activations, which is the harder limit.

Now check that against the measurement. `mixed` gains 11 858 extra conflicts
under FCFS. At 44 cycles each that is 521 752 cycles. The observed slowdown is
1 561 477 cycles. **Lost row hits account for only 33 % of the damage.**

## Where the other two thirds come from

Head-of-line blocking. FCFS hands the controller the oldest request whatever its
state; if that request needs `PRE` + `ACT`, the controller issues nothing for
nRP + nRCD = 44 cycles while it waits — and during those 44 cycles it will not
issue a command for any *other* request either, including ones whose bank is
idle and whose row is already open.

This is what destroys `rand`. With 2 ranks × 4 bank groups × 4 banks = 32 banks,
random addresses spread across all of them, and FR-FCFS overlaps the
`ACT`/`PRE` of one bank with the `RD` of another — 32 banks' worth of tRCD and
tRP hidden behind each other. That is why `rand` was the *fastest* stream in
Task 1 despite a 0.1 % hit rate. FCFS serialises those 32 banks into one queue:
each conflict's 44 cycles is now exposed end to end instead of overlapped, and
the channel runs at 26.0 cycles per access instead of 5.20.

The same arithmetic explains why `seq` barely notices, at 1.24×. It uses one
bank, so it had no parallelism for FCFS to take away — only a small loss from
read/write turnaround reordering.

**Summary in tRCD/tRP terms:** FR-FCFS wins twice. It *avoids* nRP + nRCD by
batching accesses to an open row, worth 44 cycles each and responsible for a
third of the gap; and it *hides* the nRP + nRCD it cannot avoid by issuing them
on banks that are idle, worth the other two thirds. The second effect is larger
and is invisible in the row-buffer hit rate, which is why the statistic the task
points at is the wrong one to watch.

## Note for Part E

The spread here — 1.24× to 5.01× from one scheduler line, on the same DRAM and
the same 100 000 accesses — is wider than the SRAM-vs-STT difference in any
metric from Part C except leakage. Whatever Part E concludes about the bitcell,
the memory-controller policy and the address stream have comparable leverage,
and the honest version of the argument has to say so.

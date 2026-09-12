# Part D — Ramulator findings, caveats and open gaps

## Open gap: the trace is synthetic

The assignment says twice that `l2miss.trace` comes from the CommMonitor on
gem5's L2 memory-side port. These runs use three constructed streams from
`gen_trace.py` instead:

| Stream | Definition | Role |
|---|---|---|
| `seq` | pure sequential 64 B line stride | upper bound on row-buffer hits |
| `rand` | uniform random over 256 MB | lower bound |
| `mixed` | 4 interleaved sequential streams + 30 % random | plausible middle |

25 % writes in each, representing dirty writebacks from an 8-way writeback L2.

**What this does and does not license.** The row-buffer hit rate Ramulator
reports is a property of the address stream, not of the DRAM model, so an
invented stream produces an invented hit rate. Every *absolute* number in Tasks
1–4 is therefore provisional. The *mechanisms* — nCCD_L pacing, head-of-line
blocking, bank-field burial, Little's-law queueing — are properties of the
timing table and the controller and do not depend on which of the three streams
is realistic.

Part E ran gem5 successfully, so the real trace is obtainable. To generate it:
insert a `CommMonitor` between the L2 and the memory bus with a trace listener
attached, run gem5, then `util/decode_packet_trace.py l2miss.trc.gz l2miss.csv`,
keep the address and command columns, emit `<addr> <R|W>` lines, and pipe them
through `to_ramulator.py`. Everything downstream — `ddr4.yaml`, `run.sh`,
`stats.py` — is already in place and needs no change.

## Open gap: the tool is not in this tree

There is no `ramulator2` binary, no `.ls` trace files and no build script here.
Part D cannot currently be re-executed from this repository alone; only the
`.stats` files and the analysis are reproducible artifacts. Build with:

```bash
git clone --depth 1 -b v2.0a https://github.com/CMU-SAFARI/ramulator2.git
cd ramulator2 && mkdir build && cd build && cmake .. && make -j
```

**Use tag `v2.0a`, not `main`.** `main` is 2.1 and has replaced the YAML CLI with
a Python API, so `./ramulator2 -f ddr4.yaml` only exists on the 2.0 line.

## Open gap: the Task 4 sensitivity dumps were truncated

`task4/sens/*.stats` contain only `read_latency_0` and `read_latency_1` — two
lines each, ~57 bytes. The ratio table in `task4/task4.md` was computed from
`memory_system_cycles`, which is not in those files, so **that table cannot be
regenerated from what is stored here.**

Latency-based ratios recomputed from the surviving fragments track the same
trends and support every conclusion drawn:

| Parameter halved | `seq` | `rand` | `mixed` |
|---|---|---|---|
| nRCD | 1.004 | 1.060 | 1.095 |
| nRP | 0.998 | 1.031 | 1.053 |
| nRAS | 1.000 | 0.978 | 0.939 |
| nRC | 1.000 | 1.000 | 1.000 |
| nCCD_L | **1.611** | 1.000 | **1.391** |
| nBL | 1.156 | 1.051 | 1.145 |

nCCD_L still dominates, nRC is still exactly 1.000×, nRAS still goes the wrong
way for `rand` and `mixed`. Re-run with full stats dumps kept if the table needs
to be defensible line by line.

## Two things in the handout that do not run as written

### The trace format matches no Ramulator frontend

There are three, and the handout's `0x7f2a4c00 R` is none of them:

| Frontend | Format | |
|---|---|---|
| `SimpleO3` | `<bubble_count> <load_addr> [<store_addr>]` | what the handout's YAML selects |
| `ReadWriteTrace` | `<R\|W> <addr_vec>` | R/W, but a comma-separated DRAM coordinate vector, not a flat address |
| `LoadStoreTrace` | `<LD\|ST> <address>` | what an L2 miss stream actually is |

The handout uses the op letters of `ReadWriteTrace`, the flat address of
`LoadStoreTrace`, the reverse token order of both, and declares `SimpleO3`, which
wants a third format entirely. `SimpleO3` is also wrong on its own terms: it
models a core *and an LLC*, so feeding it an L2 miss stream would filter the
misses through a second cache. `to_ramulator.py` converts the handout format to
`LD`/`ST` and the config uses `LoadStoreTrace`.

### The handout YAML omits required keys

`Translation`, `RowPolicy` and `AddrMapper` have no defaults in Ramulator 2.0 and
must be supplied. `ddr4.yaml` adds `NoTranslation`, `OpenRowPolicy` and
`RoBaRaCoCh`.

## `avg_read_latency_N` is wrong and inverts the Task 2 answer

`finalize()` computes

```cpp
s_avg_read_latency = (float) s_read_latency / (float) s_num_read_reqs;
```

but `s_num_read_reqs++` sits in `send()` (`generic_dram_controller.cpp:118`),
which fires on **every** send attempt including ones rejected because the buffer
is full. Under backpressure the frontend retries every tick, so the denominator
counts retries: 75 069 actual reads against 1 835 999 counted "requests" in the
`seq` FR-FCFS run — a **24× inflation**, printing 13.61 instead of 332.9.

This inverts the Task 2 comparison. As printed, `avg_read_latency_0` *falls*
under FCFS (13.61 → 13.35), making FCFS look faster. It is not: FCFS causes more
retries, which inflates the denominator faster than the numerator.

**Always use `read_latency_0 / total_num_read_requests`.** Every average in Part
D is computed that way.

## Ramulator 2.0 has no write-latency statistic

The controller registers `read_latency_N` and `avg_read_latency_N` only
(`generic_dram_controller.cpp:109`). Writes are retired when the command issues —
there is no round trip to time — so the task's "total read/write latency" can
only be answered for reads. The write side is visible as `num_write_reqs_0` and
through its effect on read latency via bus turnaround.

## Ramulator 2.0a ships no FCFS scheduler

Only `FRFCFS` is registered (`generic_scheduler.cpp:10`); the other files in
`impl/scheduler/` are BLISS, BlockHammer, PRAC and a blocking scheduler. Task 2's
one-line config change does not exist as an option, so the scheduler was written:
`task2/fcfs_scheduler.cpp` (35 lines, registered via `task2/fcfs_cmake.patch`) is
FR-FCFS with the first-ready half removed:

```cpp
// FRFCFS::compare  -- ready requests are promoted over older ones
if (ready1 ^ ready2) { return ready1 ? req1 : req2; }
if (req1->arrive <= req2->arrive) ...

// FCFS::compare    -- arrival order only
if (req1->arrive <= req2->arrive) { return req1; } else { return req2; }
```

The controller then calls `check_ready()` on whatever the scheduler hands it
(`generic_dram_controller.cpp:346`) and issues nothing if the command is illegal,
so a blocked request at the head stalls the whole channel — exactly the FCFS
semantics wanted.

## Note for Part E

The spread in Part D — 1.5× from the address stream, 5.0× from the scheduler,
15.6× from the address mapping, on the same DRAM and the same 100 000 accesses —
is wider than the SRAM-vs-STT difference in any Part C metric except leakage.
Whatever Part E concludes about the bitcell, memory-controller policy and the
address stream have comparable leverage, and the argument has to say so.

## The real trace: how it was obtained, and its one approximation

Part D now runs on the gem5 CommMonitor stream the assignment asks for, taken
from the SRAM 2 MB / 6-cycle baseline (config A) at `FF=10000000`,
`MAXI=20000000`. Recipe and scripts: `../PartE/gen_l2_trace.sh`.

**The read stream is exact.** Reads recovered from the trace match gem5's own
counters to the unit:

| kernel | trace reads | `system.l2.overallMisses::total` |
|---|---|---|
| bfs | 160 569 | 160 569 |
| sssp | 208 852 | 208 852 |

**The write stream is count-exact but not identity-exact,** and this is the one
approximation in Part D. The L2 puts *every* eviction on its memory-side port,
where the CommMonitor sees it — but only dirty evictions become DRAM writes.
`WritebackClean` and `CleanEvict` are coherence notifications that the memory
controller drops. Measured on bfs: **160 808 evictions cross the port, 23 892
reach DRAM** (`system.l2.writebacks::total` = `system.mem_ctrls.writeReqs` =
23 892). For a kernel that streams a 29 MB read-only edge array that ratio is
exactly what you would expect — most evicted lines are clean.

The two kinds are **indistinguishable in the trace**: requestor id 0, size 64,
flags 0, and command letter `u` for both. gem5's `decode_packet_trace.py` maps
only `ReadReq`/`WriteReq` to letters, so every command an L2 memory-side port
issues — `ReadSharedReq`, `ReadExReq`, `WritebackDirty`, `WritebackClean`,
`CleanEvict` — flattens to `u`. No per-packet filter exists.

`decode_l2_trace.py --write-target N` therefore keeps evenly spaced evictions
until the count matches `system.l2.writebacks::total` from the same run
(deterministic, no RNG). The result: read addresses and read count exact, write
count exact, write addresses drawn from the real eviction stream. What is not
preserved is *which* evictions were dirty.

**Why that is acceptable here.** Writes are 13 % of DRAM traffic, and every
mechanism Part D demonstrates is read-side: nCCD_L pacing, head-of-line
blocking under FCFS, bank-field burial under ChRaBaRoCo, and Little's-law
queueing. Writes enter those arguments through their *count* and *address
distribution* — which are preserved — via bus turnaround and write-queue
pressure, not through the identity of individual lines.

**What would remove the approximation.** Putting the CommMonitor on the memory
controller's port instead of the L2's, where by construction only DRAM-bound
traffic exists. That deviates from the assignment's literal wording ("the
CommMonitor on gem5's L2 memory-side port"), which is why the L2-side monitor
was kept and the correction applied afterwards from gem5's own counters.

### Requestor-id classification

Reads and evictions are separated by **requestor id, not command**: gem5
attributes every eviction to a dedicated `writebacks` requestor (id 0, named in
the trace header), while fills carry the id of whoever missed
(`switch_cpus.data`, `switch_cpus.inst`). This is more robust than the command
field, which is unusable as described above.

### Warm-up exclusion

The monitor records the atomic fast-forward phase as well as the detailed
region, but gem5 resets its stats at the CPU switch. Left unfiltered the trace
covers a different region than the stats it is checked against — 646 030
packets against 211 944 L2 accesses for bfs. `gen_l2_trace.sh` greps
`Switched CPUS @ tick N` from the run log and passes it as `--skip-ticks`, so
both cover the same region. That is why the read counts above agree exactly.

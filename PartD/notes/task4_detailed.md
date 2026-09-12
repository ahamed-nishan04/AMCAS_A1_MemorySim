# Part D, Task 4 — Double the channel count

`org: { ..., channel: 2 }`, everything else as Task 1 (FR-FCFS, RoBaRaCoCh,
DDR4_3200AA). Peak bandwidth goes 25.6 → 51.2 GB/s.

## Throughput doubles, latency does not

| Stream | Cycles | Cyc/access | Bandwidth | % of peak | **Avg read latency** |
|---|---|---|---|---|---|
| `seq` 1 ch | 697 849 | 6.98 | 14.67 GB/s | 57.3 % | 332.9 cyc (208 ns) |
| `seq` 2 ch | 353 172 | 3.53 | 28.99 GB/s | 56.6 % | **303.3 cyc (190 ns)** |
| `rand` 1 ch | 519 900 | 5.20 | 19.70 GB/s | 76.9 % | 290.0 cyc (181 ns) |
| `rand` 2 ch | 269 369 | 2.69 | 38.01 GB/s | 74.2 % | **247.8 cyc (155 ns)** |
| `mixed` 1 ch | 779 326 | 7.79 | 13.14 GB/s | 51.3 % | 380.4 cyc (238 ns) |
| `mixed` 2 ch | 496 993 | 4.97 | 20.60 GB/s | 40.2 % | **389.0 cyc (243 ns)** |

| Stream | Throughput gain | Latency gain |
|---|---|---|
| `seq` | **1.98×** | 1.10× |
| `rand` | **1.93×** | 1.17× |
| `mixed` | 1.57× | **0.98× — worse** |

Channel utilisation is essentially unchanged (57.3 → 56.6 %, 76.9 → 74.2 %), so
the second channel is being used properly. The work is finishing in half the
time and each individual read is waiting just as long.

## Why latency cannot improve here, and how the output shows it

Latency in these runs is almost entirely **queueing**, and queueing is set by
load, not by channel count. Little's law, W = L/λ, checks out against
Ramulator's own statistics — `read_queue_len_avg_N` gives L and
`total_num_read_requests / memory_system_cycles` gives λ:

| Stream | L (queue) | λ (reads/cyc) | L/λ | Measured W |
|---|---|---|---|---|
| `seq` 1 ch | 35.80 | 0.1076 | 332.8 | **332.9** |
| `seq` 2 ch | 64.44 | 0.2126 | 303.2 | **303.3** |
| `rand` 1 ch | 36.75 | 0.1444 | 254.5 | 290.0 |
| `rand` 2 ch | 59.83 | 0.2787 | 214.7 | 247.8 |
| `mixed` 1 ch | 35.50 | 0.0963 | 368.7 | 380.4 |
| `mixed` 2 ch | 57.14 | 0.1510 | 378.4 | 389.0 |

Both L and λ roughly double, so W is invariant. Adding a channel adds a
*queue* along with the bandwidth, and `LoadStoreTrace` is an open-loop source —
it retries every tick, so both queues stay full regardless. **The second channel
raises the service rate and the offered load by the same factor.**

This is the first thing to check from the output and it takes one division:
if `read_queue_len_avg` scales with the channel count while `avg latency` does
not, the workload is throughput-limited and latency is a queueing artefact, not
a DRAM-timing result. Channels cannot fix it; only reducing the offered load or
the service time per access can.

## Which timing parameter is binding

Service time per access per channel is what a second channel replicates rather
than shortens, so that is where the DRAM timings bite. Rather than argue it,
halve each candidate one at a time — Ramulator 2.0a accepts individual timing
overrides alongside a preset (`DDR4.cpp:418`), e.g.

```yaml
timing:
  preset: DDR4_3200AA
  nCCDL: 4
```

All at 2 channels, versus that baseline:

| Parameter halved | `seq` | `rand` | `mixed` |
|---|---|---|---|
| nRCD 22 → 11 | 1.00× | 1.03× | 1.10× |
| nRP 22 → 11 | 1.00× | 1.04× | 1.07× |
| nRAS 52 → 26 | 1.00× | 0.95× | 0.91× |
| nRC 74 → 37 | 1.00× | 1.00× | 1.00× |
| **nCCD_L 8 → 4** | **1.57×** | 1.01× | **1.45×** |
| nBL 4 → 2 | 1.14× | 1.03× | 1.18× |

**For the row-local streams the binding parameter is tCCD — specifically
tCCD_L.** Halving it is worth 1.57× on `seq` and 1.45× on `mixed`, while tRCD,
tRP and tRAS together are worth nothing. That is the same conclusion Task 3
reached from the command trace: a stream with good row locality issues
back-to-back column commands into one bank group, tCCD_L = 8 paces them, and the
data bus wants one every nBL = 4. Half the bus sits idle and no amount of
channel count changes the per-channel pacing.

Two details in that table are worth reading rather than skipping:

**nRC halved changes nothing, exactly (1.000×).** Not because bank cycle time is
irrelevant but because it is redundant: the ACT→PRE→ACT path is already
constrained by nRAS + nRP = 52 + 22 = 74, which is nRC. Overriding nRC alone
leaves the binding pair untouched. A sensitivity sweep has to respect which
constraints are derived from which — this is the trap in the method.

**nRAS halved makes `rand` and `mixed` *slower*** (0.95×, 0.91×). Shortening the
minimum time a row must stay open lets FR-FCFS precharge sooner, which closes
rows that later requests in the queue would have hit. A timing parameter getting
tighter is not always a speedup, and a sweep that only looks for improvements
will miss it.

**`rand` is insensitive to all six** (0.95–1.04×). It is not DRAM-timing-limited
at all at 2 channels: with every access a conflict scattered over 32 banks, it
is limited by queue depth and read/write turnaround. For that stream the honest
answer to "which timing is binding" is *none* — and the way to tell is exactly
this table, where nothing moves.

## How to determine this from the output, in order

1. **Compare cycles/access per channel.** 6.98 → 3.53 total for `seq` is 7.06
   and 7.06 per channel. Unchanged per-channel service time means the bottleneck
   is inside the channel, so more channels buy throughput and nothing else.
2. **Check Little's law** against `read_queue_len_avg_N` and
   `memory_system_cycles`. If L/λ reproduces the measured latency, latency is
   queueing and the DRAM timings are not what you are measuring.
3. **Compare the row statistics.** `row_hits/misses/conflicts` are nearly
   identical at 1 and 2 channels here (99.1 → 99.1 %, 58.9 → 58.0 %), confirming
   the extra channel changed scheduling opportunity, not row behaviour.
4. **Sweep the timings one at a time** and read off which one moves the number,
   remembering that derived constraints (nRC = nRAS + nRP) will not respond when
   overridden alone, and that some parameters help in the wrong direction.

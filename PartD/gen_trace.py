#!/usr/bin/env python3
"""
Synthetic L2 miss streams, used ONLY to bracket the answer until the real
CommMonitor trace from gem5 is available.

The row-buffer hit rate Ramulator reports is a property of the address stream,
not of the DRAM model, so a made-up stream produces a made-up hit rate. These
three streams are deliberately chosen as bounds rather than as a guess at any
particular workload:

  seq     pure sequential 64 B line stride  -> upper bound on row-buffer hits
  rand    uniform random over 256 MB        -> lower bound
  mixed   4 interleaved sequential streams
          plus 30 % random                  -> a plausible middle

Writes are 25 % of accesses in each, representing dirty-line writebacks from
an 8-way writeback L2.

Usage: gen_trace.py <seq|rand|mixed> <n_accesses> <out.trace>
Output is in the handout's format (<addr> <R|W>); run it through
to_ramulator.py before feeding Ramulator.
"""
import random
import sys

LINE = 64
SPAN = 256 << 20        # 256 MB footprint
WRITE_FRAC = 0.25


def gen(kind, n, rng):
    if kind == "seq":
        base = 0x10000000
        for i in range(n):
            yield base + i * LINE
    elif kind == "rand":
        for _ in range(n):
            yield rng.randrange(0, SPAN, LINE)
    elif kind == "mixed":
        streams = [0x10000000, 0x24000000, 0x38000000, 0x4C000000]
        for _ in range(n):
            if rng.random() < 0.30:
                yield rng.randrange(0, SPAN, LINE)
            else:
                s = rng.randrange(len(streams))
                addr = streams[s]
                streams[s] += LINE
                yield addr
    else:
        sys.exit(f"unknown kind {kind}")


def main(kind, n, out):
    rng = random.Random(20260911)
    with open(out, "w") as f:
        for addr in gen(kind, int(n), rng):
            op = "W" if rng.random() < WRITE_FRAC else "R"
            f.write(f"0x{addr:x} {op}\n")
    print(f"{kind}: {n} accesses -> {out}")


if __name__ == "__main__":
    main(*sys.argv[1:4])

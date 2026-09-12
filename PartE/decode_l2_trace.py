#!/usr/bin/env python3
# Turn the CSV from gem5's decode_packet_trace.py into the handout's L2 miss
# format, as a DRAM request stream.
#
# CSV columns, confirmed against a real CommMonitor trace:
#
#     requestor_id , cmd_letter , addr , size , req_flags , tick
#
# Three things that layout does NOT give you:
#
#   * cmd_letter is 'u' for every packet. gem5's letter mapping knows only
#     ReadReq/WriteReq, while an L2 memory-side port issues ReadSharedReq,
#     ReadExReq, WritebackDirty, WritebackClean and CleanEvict -- all of which
#     fall through to "unknown". Useless for classification.
#
#   * field 0 is the requestor id, not the command. Requestor 0 is the
#     dedicated "writebacks" requestor (named in the trace header); fills
#     carry the id of whoever missed. That gives read vs eviction.
#
#   * it cannot tell a DIRTY eviction from a CLEAN one. The L2 puts every
#     eviction on the memory-side port, but the controller only accepts the
#     ones carrying data; WritebackClean and CleanEvict are coherence
#     notifications and are dropped. Measured on bfs: 160,808 evictions cross
#     the port, 23,892 reach DRAM. Dirty and clean are identical in the trace
#     (requestor 0, size 64, flags 0), so no per-packet filter exists.
#
# --write-target fixes the third problem statistically: keep evenly spaced
# evictions until the count matches what gem5 says DRAM actually saw
# (system.l2.writebacks::total == mem_ctrls.writeReqs). The read stream stays
# exact, the write count becomes exact, and write addresses are drawn from the
# real eviction stream. What is not preserved is which specific evictions were
# dirty -- which affects nothing Part D measures, since writes matter there
# through their count, address distribution and bus turnaround, not identity.
#
# Usage:
#     decode_l2_trace.py <decoded.csv> <out.trace> [options]
#     decode_l2_trace.py <decoded.csv> --histogram
#
# Options:
#     --max N            cap total accesses emitted (0 = all)
#     --skip-ticks T     drop packets before tick T (the CPU-switch tick, so
#                        the atomic warm-up is excluded as it is in the stats)
#     --write-target N   keep only N evictions, evenly spaced. Pass
#                        system.l2.writebacks::total from the same run.
#     --write-id N       requestor id for evictions (default 0)
#     --histogram        print the requestor mix and exit

import argparse
import collections
import sys

REQ_ID, CMD, ADDR, SIZE, FLAGS, TICK = range(6)


def rows(path, skip_ticks):
    bad = 0
    for line in open(path):
        f = line.rstrip("\n").split(",")
        if len(f) < 6:
            bad += 1
            continue
        try:
            rid, addr, tick = int(f[REQ_ID]), int(f[ADDR]), int(f[TICK])
        except ValueError:
            bad += 1
            continue
        if tick < skip_ticks:
            continue
        yield rid, addr
    if bad:
        print("  note: %d unparseable lines skipped" % bad, file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--max", type=int, default=0)
    ap.add_argument("--skip-ticks", type=int, default=0)
    ap.add_argument("--write-target", type=int, default=0)
    ap.add_argument("--write-id", type=int, default=0)
    ap.add_argument("--histogram", action="store_true")
    a = ap.parse_args()

    if a.histogram:
        h = collections.Counter(rid for rid, _ in rows(a.src, a.skip_ticks))
        tot = sum(h.values())
        if not tot:
            sys.exit("no packets at tick >= %d -- check --skip-ticks" % a.skip_ticks)
        print("%d packets at tick >= %d" % (tot, a.skip_ticks))
        for rid, n in h.most_common():
            kind = "evictions" if rid == a.write_id else "fills (reads)"
            print("  requestor %3d  %-15s %9d  %5.1f %%" % (rid, kind, n, 100.0 * n / tot))
        return

    if not a.dst:
        sys.exit("an output path is required unless --histogram is given")

    # Pass 1: count evictions so the keep-ratio can be computed.
    keep_every = 1.0
    if a.write_target > 0:
        total_w = sum(1 for rid, _ in rows(a.src, a.skip_ticks) if rid == a.write_id)
        if total_w > a.write_target:
            keep_every = total_w / float(a.write_target)
            print("  evictions on the L2 port: %d; DRAM writes: %d -> keeping 1 in %.2f"
                  % (total_w, a.write_target, keep_every))
        else:
            print("  evictions (%d) <= target (%d); keeping all" % (total_w, a.write_target))

    nr = nw = seen_w = 0
    nxt = 0.0
    with open(a.dst, "w") as out:
        for rid, addr in rows(a.src, a.skip_ticks):
            if rid == a.write_id:
                # Evenly spaced selection, no RNG: deterministic and reproducible.
                if seen_w >= nxt:
                    out.write("0x%x W\n" % addr)
                    nw += 1
                    nxt += keep_every
                seen_w += 1
            else:
                out.write("0x%x R\n" % addr)
                nr += 1
            if a.max and nr + nw >= a.max:
                break

    n = nr + nw
    print("%d accesses -> %s" % (n, a.dst))
    if not n:
        sys.exit("empty trace -- run with --histogram to see what is in it")
    print("  reads  %8d  (%.1f %%)" % (nr, 100.0 * nr / n))
    print("  writes %8d  (%.1f %%)" % (nw, 100.0 * nw / n))


if __name__ == "__main__":
    main()

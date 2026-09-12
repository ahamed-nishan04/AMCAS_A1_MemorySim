#!/usr/bin/env python3
"""
Convert an L2 miss trace in the handout's format

    0x7f2a4c00 R
    0x7f2a5000 W

into the format Ramulator 2.0's LoadStoreTrace frontend actually parses

    LD 0x7f2a4c00
    ST 0x7f2a5000

Neither Ramulator trace frontend accepts the handout's layout:
  LoadStoreTrace  expects  <LD|ST> <addr>     -- op first, LD/ST not R/W
  ReadWriteTrace  expects  <R|W> <addr_vec>   -- R/W, but a comma-separated
                                                 DRAM coordinate vector
                                                 (channel,rank,bank,row,col),
                                                 not a flat address
and SimpleO3, which the handout's YAML selects, expects a third format:
  <bubble_count> <load_addr> [<store_addr>]

Usage: to_ramulator.py in.trace out.trace
"""
import sys


def main(src, dst):
    out, bad = [], 0
    for line in open(src):
        if line.lstrip().startswith("#"):
            continue
        t = line.split()
        if not t:
            continue
        if len(t) != 2:
            bad += 1
            continue
        addr, op = t
        if op.upper() in ("R", "LD"):
            out.append(f"LD {addr}")
        elif op.upper() in ("W", "ST"):
            out.append(f"ST {addr}")
        else:
            bad += 1
    open(dst, "w").write("\n".join(out) + "\n")
    msg = f"{len(out)} accesses written to {dst}"
    if bad:
        msg += f", {bad} lines skipped"
    print(msg)


if __name__ == "__main__":
    main(*sys.argv[1:3])

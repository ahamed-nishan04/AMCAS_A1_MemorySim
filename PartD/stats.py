#!/usr/bin/env python3
"""
Pull the Part D Task 1 numbers out of a Ramulator 2.0 stats dump.

    run.sh <trace.ls>            # runs ramulator, writes <name>.stats
    stats.py <name>.stats ...    # tabulates

Stat names come from generic_DRAM_system.cpp and generic_dram_controller.cpp:
  memory_system_cycles, total_num_read_requests, total_num_write_requests,
  read_latency_0, avg_read_latency_0, row_hits_0, row_misses_0, row_conflicts_0
"""
import re
import sys

KEYS = ["memory_system_cycles", "total_num_read_requests", "total_num_write_requests",
        "read_latency_0", "avg_read_latency_0", "row_hits_0", "row_misses_0",
        "row_conflicts_0", "read_row_hits_0", "write_row_hits_0",
        "num_read_reqs_0", "num_write_reqs_0"]


def parse(path):
    txt = open(path).read()
    d = {}
    for k in KEYS:
        m = re.search(rf"^\s*{re.escape(k)}:\s*([\d.eE+-]+)\s*$", txt, re.M)
        if m:
            d[k] = float(m.group(1))
    return d


def main(paths):
    hdr = f"{'run':10}{'mem cycles':>12}{'reads':>9}{'writes':>8}{'rd lat tot':>12}{'rd lat avg':>11}{'RB hit%':>9}"
    print(hdr)
    print("-" * len(hdr))
    for p in paths:
        d = parse(p)
        name = p.rsplit("/", 1)[-1].replace(".stats", "")
        hits = d.get("row_hits_0", 0)
        acts = hits + d.get("row_misses_0", 0) + d.get("row_conflicts_0", 0)
        rb = 100 * hits / acts if acts else float("nan")
        print(f"{name:10}{d.get('memory_system_cycles',0):12.0f}"
              f"{d.get('total_num_read_requests',0):9.0f}"
              f"{d.get('total_num_write_requests',0):8.0f}"
              f"{d.get('read_latency_0',0):12.0f}"
              f"{d.get('avg_read_latency_0',0):11.2f}"
              f"{rb:9.1f}")


if __name__ == "__main__":
    main(sys.argv[1:])

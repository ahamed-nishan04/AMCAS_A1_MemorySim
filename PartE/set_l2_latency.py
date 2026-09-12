#!/usr/bin/env python3
"""
Set the L2 hit latency in a gem5 checkout.

se.py has no --l2-hit-latency option -- _get_cache_opts() in
configs/common/CacheConfig.py forwards only size, assoc and prefetcher, so the
handout's command line is rejected by argparse. L2 latency lives in the
L2Cache class in configs/common/Caches.py (defaults 20/20/20 cycles, in the
CPU clock domain since CacheConfig.py builds the L2 with
clk_domain=system.cpu_clk_domain).

This rewrites those three fields, following gem5's own convention of setting
tag, data and response latency to the same value.

Usage: set_l2_latency.py <gem5_dir> <cycles>
"""
import re
import sys

gem5, cycles = sys.argv[1], int(sys.argv[2])
path = f"{gem5}/configs/common/Caches.py"
src = open(path).read()

m = re.search(r"(class L2Cache\(Cache\):.*?)(?=\nclass )", src, re.S)
if not m:
    sys.exit("could not find class L2Cache in " + path)

block = m.group(1)
for field in ("tag_latency", "data_latency", "response_latency"):
    block, n = re.subn(rf"^(\s*){field} = \d+", rf"\g<1>{field} = {cycles}",
                       block, count=1, flags=re.M)
    if n != 1:
        sys.exit(f"could not set {field}")

open(path, "w").write(src[:m.start(1)] + block + src[m.end(1):])
print(f"L2Cache tag/data/response latency = {cycles} cycles")

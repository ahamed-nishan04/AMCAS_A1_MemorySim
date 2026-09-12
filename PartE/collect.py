#!/usr/bin/env python3
"""Pull IPC, L2 miss rate and simSeconds out of gem5 stats.txt files."""
import re
import sys

def g(t, pat):
    m = re.search(rf"^{pat}\s+([\d.eE+-]+)", t, re.M)
    return float(m.group(1)) if m else None

rows = []
for p in sys.argv[1:]:
    t = open(p).read()
    name = p.split("/")[-2] if "/" in p else p
    ipc = g(t, r"system\.cpu\.ipc") or g(t, r"system\.switch_cpus\.ipc")
    sec = g(t, r"simSeconds")
    # gem5 prints overallMissRate::total for the L2
    mr = g(t, r"system\.l2\.overallMissRate::total")
    if mr is None:
        hits = g(t, r"system\.l2\.overallHits::total") or 0
        miss = g(t, r"system\.l2\.overallMisses::total") or 0
        mr = miss / (hits + miss) if (hits + miss) else None
    rows.append((name, ipc, mr, sec))

print(f"{'config':22}{'IPC':>8}{'L2 miss rate':>14}{'simSeconds':>13}")
print("-" * 57)
for n, i, m, s in rows:
    print(f"{n:22}{i if i is None else f'{i:8.4f}':>8}"
          f"{m if m is None else f'{m*100:13.2f}%':>14}"
          f"{s if s is None else f'{s:13.6f}':>13}")

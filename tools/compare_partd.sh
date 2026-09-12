#!/usr/bin/env bash
# Compare a fresh Part D run against the numbers committed in the task files.
# Usage: bash tools/compare_partd.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$A1_ROOT/PartD"
python3 - <<'PY'
import re, glob, os
def parse(p):
    d={}
    for l in open(p):
        m=re.match(r'\s*([A-Za-z_0-9]+):\s*([-\d.eE+]+)\s*$',l)
        if m:
            try: d[m.group(1)]=float(m.group(2))
            except ValueError: pass
    return d
def agg(d,pre): return sum(v for k,v in d.items() if k.startswith(pre))

# what the committed task1.md claims, for the synthetic streams
REF = {"t_seq":  (697849, 332.9, 99.1),
       "t_rand": (519900, 290.0,  0.1),
       "t_mixed":(779326, 380.4, 58.9)}

print(f"{'stream':10}{'cycles':>12}{'ref':>12}{'avg lat':>10}{'ref':>9}"
      f"{'rb hit':>9}{'ref':>8}")
for name,(rc,rl,rh) in REF.items():
    f=f"{name}.stats"
    if not os.path.exists(f):
        print(f"{name:10}  (not run)"); continue
    d=parse(f)
    c=d.get("memory_system_cycles",0)
    r=d.get("total_num_read_requests",1)
    lat=agg(d,"read_latency_")/r
    h=agg(d,"row_hits_"); mi=agg(d,"row_misses_"); co=agg(d,"row_conflicts_")
    hit=100*h/(h+mi+co) if (h+mi+co) else 0
    flag = "" if abs(c-rc)/rc < 0.001 else "   <-- DIFFERS"
    print(f"{name:10}{c:12.0f}{rc:12.0f}{lat:10.1f}{rl:9.1f}{hit:9.2f}{rh:8.1f}{flag}")
PY

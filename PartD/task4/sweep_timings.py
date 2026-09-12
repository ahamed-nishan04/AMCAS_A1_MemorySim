#!/usr/bin/env python3
"""
Part D Task 4: DRAM timing sensitivity sweep, at 2 channels.

The committed sens/*.stats files were grep-filtered down to their read_latency
lines, so the ratio table in task4.md cannot be regenerated from them.  This
rewrites the sweep keeping the FULL stats dump for every run, so every column
of that table -- memory_system_cycles, queue depths, row counters -- is
recoverable.

Ramulator 2.0a accepts individual timing overrides alongside a preset
(DDR4.cpp:418), so each variant is the 2-channel baseline with exactly one
parameter halved.

    python3 sweep_timings.py <trace.ls> [<trace.ls> ...]

Writes sens/<param>_<trace>.yaml and sens/<param>_<trace>.stats, then prints
the ratio table.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
os.environ["LD_LIBRARY_PATH"] = os.pathsep.join(filter(None, [
    os.path.abspath(os.path.join(HERE, "..")),
    os.environ.get("RAMULATOR_DIR", ""),
    os.environ.get("LD_LIBRARY_PATH", "")]))
PARTD = os.path.abspath(os.path.join(HERE, ".."))
BASE_YAML = os.path.join(PARTD, "task4", "ddr4_2ch.yaml")
TRACES = os.path.join(PARTD, "traces")
RAMULATOR = os.path.join(PARTD, "ramulator2")
OUT = os.path.join(HERE, "sens")

# DDR4_3200AA preset values, halved one at a time.
SWEEP = {
    "base":   None,
    "nRCD":  ("nRCD", 11),
    "nRP":   ("nRP", 11),
    "nRAS":  ("nRAS", 26),
    "nRC":   ("nRC", 37),
    "nCCDL": ("nCCDL", 4),
    "nBL":   ("nBL", 2),
}


def make_cfg(trace, name, override):
    src = open(BASE_YAML).read()
    src = re.sub(r"^(\s*)path:.*$", r"\g<1>path: " + trace, src, count=1, flags=re.M)
    if override:
        key, val = override
        # insert the override as a sibling of `preset:` inside the timing block
        m = re.search(r"^(\s*)preset:\s*DDR4_3200AA\s*$", src, re.M)
        if not m:
            sys.exit("could not find `preset: DDR4_3200AA` in " + BASE_YAML)
        indent = m.group(1)
        src = src[:m.end()] + f"\n{indent}{key}: {val}" + src[m.end():]
    path = os.path.join(OUT, f"{name}_{os.path.basename(trace)}.yaml")
    open(path, "w").write(src)
    return path


def parse(path):
    d = {}
    for line in open(path):
        m = re.match(r"\s*([A-Za-z_0-9]+):\s*([-\d.eE+]+)\s*$", line)
        if m:
            try:
                d[m.group(1)] = float(m.group(2))
            except ValueError:
                pass
    return d


def agg(d, prefix):
    return sum(v for k, v in d.items() if k.startswith(prefix))


def main(traces):
    traces = [t if os.path.exists(os.path.join(PARTD, t)) else os.path.join("traces", os.path.basename(t)) for t in traces]
    if not os.path.exists(RAMULATOR):
        sys.exit(f"missing {RAMULATOR} -- run tools/build_tools.sh ramulator")
    os.makedirs(OUT, exist_ok=True)

    results = {}
    for trace in traces:
        for name, override in SWEEP.items():
            cfg = make_cfg(trace, name, override)
            stats = cfg[:-5] + ".stats"
            print(f"  {name:6s} {os.path.basename(trace)}", flush=True)
            with open(stats, "w") as fh:
                subprocess.run([RAMULATOR, "-f", cfg], stdout=fh, stderr=subprocess.STDOUT,
                               check=True)
            results[(trace, name)] = parse(stats)

    # ---- the table
    params = [p for p in SWEEP if p != "base"]
    print("\nSpeedup vs the 2-channel baseline (memory_system_cycles ratio)\n")
    hdr = "| Parameter halved | " + " | ".join(os.path.basename(t) for t in traces) + " |"
    print(hdr)
    print("|---|" + "---|" * len(traces))
    for p in params:
        row = [f"| {p:6s}"]
        for t in traces:
            b = results[(t, "base")].get("memory_system_cycles", 0)
            v = results[(t, p)].get("memory_system_cycles", 0)
            row.append(f" {b/v:.2f}x" if v else " n/a")
        print(" |".join(row) + " |")

    print("\nSame, by total read latency per read (the metric the truncated "
          "dumps could still support)\n")
    print(hdr)
    print("|---|" + "---|" * len(traces))
    for p in params:
        row = [f"| {p:6s}"]
        for t in traces:
            db, dv = results[(t, "base")], results[(t, p)]
            b = agg(db, "read_latency_") / max(db.get("total_num_read_requests", 1), 1)
            v = agg(dv, "read_latency_") / max(dv.get("total_num_read_requests", 1), 1)
            row.append(f" {b/v:.3f}x" if v else " n/a")
        print(" |".join(row) + " |")

    print("\nBaseline absolutes\n")
    print("| trace | cycles | reads | avg read latency | cyc/access |")
    print("|---|---|---|---|---|")
    for t in traces:
        d = results[(t, "base")]
        r = d.get("total_num_read_requests", 0)
        w = d.get("total_num_write_requests", 0)
        c = d.get("memory_system_cycles", 0)
        lat = agg(d, "read_latency_") / r if r else 0
        print(f"| {os.path.basename(t)} | {c:.0f} | {r:.0f} | {lat:.1f} | "
              f"{c/(r+w) if r+w else 0:.2f} |")

    print(f"\nFull stats dumps kept in {OUT}/")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])

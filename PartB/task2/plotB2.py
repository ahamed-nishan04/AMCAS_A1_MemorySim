#!/usr/bin/env python3
"""
Part B Task 2 figure. Run after sweep.sh has produced sweep/o_<kB>.txt.

    python3 plotB2.py

Writes figB2_capacity.png
"""
import re
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SIZES = [256, 512, 1024, 2048, 4096, 8192, 16384]   # kB
FO4 = 15e-3                                          # ns, 45 nm ITRS-HP, see taskB2.md


def parse(kb):
    t = open(f"sweep/o_{kb}.txt").read()
    ds = t.split("Data side (with Output driver)")[1].split("Tag side")[0]
    g = lambda p: float(re.search(p + r".*?:\s*([\d.eE+-]+)", ds).group(1))
    return dict(
        acc=float(re.search(r"Access time \(ns\):\s*([\d.]+)", t).group(1)),
        hin=g("H-tree input delay"),
        dec=g(r"Decoder \+ wordline delay"),
        bl=g("Bitline delay"),
        sa=g("Sense Amplifier delay"),
        hout=g("H-tree output delay"),
    )


d = [parse(k) for k in SIZES]
x = np.log2(np.array(SIZES) * 1024)          # log2(bytes)
acc = np.array([r["acc"] for r in d])

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 3.8))

# ---- left: access time vs log2(capacity), against one gate delay per doubling
ax1.plot(x, acc, "o-", color="C0", label="CACTI access time")
ref = acc[0] + FO4 * (x - x[0])
ax1.plot(x, ref, "--", color="C3",
         label=f"1 FO4 per doubling ({FO4*1e3:.0f} ps)")
for xi, yi, kb in zip(x, acc, SIZES):
    lab = f"{kb//1024} MB" if kb >= 1024 else f"{kb} kB"
    ax1.annotate(lab, (xi, yi), textcoords="offset points", xytext=(4, -10),
                 fontsize=7)
ax1.set_xlabel("$\\log_2$(capacity in bytes)")
ax1.set_ylabel("access time (ns)")
ax1.set_title("Access time vs capacity")
ax1.legend(fontsize=7, loc="upper left")
ax1.grid(alpha=0.3)

# ---- right: where the delay goes
parts = [("H-tree in", "hin"), ("Decoder + WL", "dec"), ("Bitline", "bl"),
         ("Sense amp", "sa"), ("H-tree out", "hout")]
bot = np.zeros(len(SIZES))
for lab, key in parts:
    v = np.array([r[key] for r in d])
    ax2.bar(x, v, bottom=bot, width=0.72, label=lab)
    bot += v
ax2.bar(x, acc - bot, bottom=bot, width=0.72, color="0.75",
        label="not itemised by CACTI")
ax2.set_xlabel("$\\log_2$(capacity in bytes)")
ax2.set_ylabel("delay (ns)")
ax2.set_title("Data-side delay breakdown")
ax2.legend(fontsize=7, loc="upper left")
ax2.grid(alpha=0.3, axis="y")

fig.tight_layout()
fig.savefig("figB2_capacity.png", dpi=200)

# ---- table for the writeup
print(f"{'kB':>6} {'access':>7} {'Δ (ps)':>8} {'array':>7} {'H-tree':>7} {'H-tree %':>9}")
prev = None
for kb, r in zip(SIZES, d):
    arr = r["dec"] + r["bl"] + r["sa"]
    ht = r["hin"] + r["hout"]
    dd = f"{(r['acc']-prev)*1e3:8.0f}" if prev else "       -"
    print(f"{kb:6d} {r['acc']:7.4f} {dd} {arr:7.4f} {ht:7.4f} {100*ht/r['acc']:8.1f}%")
    prev = r["acc"]
print("\nwrote figB2_capacity.png")

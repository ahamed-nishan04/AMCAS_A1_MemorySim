#!/usr/bin/env python3
"""
Part A figures. Run after the five netlists have produced their CSVs:

    ngspice -b task1.sp && ngspice -b task2.sp && ngspice -b task2_snm.sp
    ngspice -b task3.sp && ngspice -b task4.sp
    python3 plots.py

Writes figA1_read.png, figA2_disturb.png, figA3_butterfly.png, figA4_margin.png
"""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

T_SENSE = 1.115e-9      # fixed sense instant, 65 ps after the WL edge
T_ASSIGN = 2.0e-9       # sampling point named in Task 1
OFFSET = 0.025          # sense-amp input offset, Lecture 5


def wrdata(path):
    """wrdata writes (scale, value) column pairs, one pair per vector."""
    d = np.loadtxt(path)
    return d[:, 0], [d[:, i] for i in range(1, d.shape[1], 2)]


# ---------------------------------------------------------------- Fig A1
t, (bl, blb, q, qb) = wrdata("task1/read1.csv")
fig, ax = plt.subplots(figsize=(6, 3.4))
ax.plot(t * 1e9, bl, label="v(BL)")
ax.plot(t * 1e9, blb, label="v(BLB)")
ax.plot(t * 1e9, q, label="v(Q)")
ax.plot(t * 1e9, qb, label="v(QB)")
for tt, lab in ((T_SENSE, "sense, 65 ps"), (T_ASSIGN, "t = 2 ns")):
    ax.axvline(tt * 1e9, color="k", ls=":", lw=0.8)
    ax.text(tt * 1e9 + 0.03, 0.62, lab, fontsize=7, rotation=90)
ax.set_xlim(0.5, 4)          # first 200 fs cropped: uic start-up transient only
ax.set_xlabel("time (ns)")
ax.set_ylabel("V")
ax.set_title("Read transient, $V_{DD}$ = 1.1 V, 27 °C, $W_{MA}$ = 0.16 µm")
ax.legend(fontsize=7, ncol=4)
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig("task1/figA1_read.png", dpi=200)

# ---------------------------------------------------------------- Fig A2
t2, (_, _, q2, _) = wrdata("task2/read2.csv")
fig, ax = plt.subplots(figsize=(6, 3.2))
ax.plot(t * 1e9, q * 1e3, label="$W_{MA}$ = 0.16 µm (CR 1.25), peak 205.5 mV")
ax.plot(t2 * 1e9, q2 * 1e3, label="$W_{MA}$ = 0.24 µm (CR 0.83), peak 271.2 mV")
ax.axhline(527, color="k", ls="--", lw=0.8)
ax.text(3.0, 535, "read trip point, 527 mV", fontsize=7)
ax.set_xlim(0.9, 4)
ax.set_xlabel("time (ns)")
ax.set_ylabel("v(Q)  (mV)")
ax.set_title("Read disturb on the storage node")
ax.legend(fontsize=7)
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig("task2/figA2_disturb.png", dpi=200)

# ---------------------------------------------------------------- Fig A3
def snm(vin, vout):
    """Largest axis-aligned square in the lobe. Bisection, not a grid."""
    F = lambda x: np.interp(x, vin, vout)
    Finv = lambda x: np.interp(x, vout[::-1], vin[::-1])
    best, best_a = 0.0, 0.0
    for a in np.linspace(0.0, vin.max(), 4001):
        lo, hi = 0.0, vin.max() - a
        for _ in range(50):
            mid = 0.5 * (lo + hi)
            if F(a + mid) - Finv(a) - mid >= 0:
                lo = mid
            else:
                hi = mid
        if lo > best:
            best, best_a = lo, a
    return best, best_a


fig, axes = plt.subplots(1, 3, figsize=(9, 3.2), sharex=True, sharey=True)
for ax, (f, title) in zip(axes, [
        ("task2/vtc_hold.csv", "hold (WL off)"),
        ("task2/vtc_read_016.csv", "read, $W_{MA}$ = 0.16 µm"),
        ("task2/vtc_read_024.csv", "read, $W_{MA}$ = 0.24 µm")]):
    d = np.loadtxt(f)
    x, y = d[:, 0], d[:, 1]
    s, a = snm(x, y)
    print(f"{f:22s} SNM = {s * 1e3:6.1f} mV")
    ax.plot(x, y, lw=1.2)
    ax.plot(y, x, lw=1.2)          # mirror
    b = np.interp(a, y[::-1], x[::-1])
    ax.add_patch(plt.Rectangle((a, b), s, s, fill=False, color="k", lw=1.0))
    ax.set_title(f"{title}\nSNM = {s*1e3:.1f} mV", fontsize=8)
    ax.set_xlabel("v(Q)  (V)")
    ax.grid(alpha=0.3)
axes[0].set_ylabel("v(QB)  (V)")
fig.tight_layout()
fig.savefig("task2/figA3_butterfly.png", dpi=200)

# ---------------------------------------------------------------- Fig A4
d3 = np.loadtxt("task3/task3_sweep.csv")
vdd, dv_s, dv_2n = d3[:, 0], d3[:, 1], d3[:, 3]
d4 = np.loadtxt("task4/task4_sweep.csv")
dv_85 = d4[:, 1]

fig, ax = plt.subplots(figsize=(6, 3.6))
ax.plot(vdd, dv_s * 1e3, "o-", label="ΔV at 65 ps sense window, 27 °C")
ax.plot(vdd, dv_85 * 1e3, "s-", label="ΔV at 65 ps sense window, 85 °C")
ax.plot(vdd, dv_2n * 1e3, "^--", color="grey",
        label="ΔV at t = 2 ns, 27 °C (never crosses)")
ax.axhline(OFFSET * 1e3, color="r", ls="--", lw=1.0)
ax.text(0.61, 27, "25 mV sense-amp offset", color="r", fontsize=7)
for v, lab, c in ((0.7264, "0.726 V", "C0"), (0.7948, "0.795 V", "C1")):
    ax.plot([v], [OFFSET * 1e3], "*", ms=11, color=c)
    ax.annotate(lab, (v, OFFSET * 1e3), textcoords="offset points",
                xytext=(-4, -14), fontsize=7, color=c)
ax.set_yscale("log")
ax.set_xlabel("$V_{DD}$ (V)")
ax.set_ylabel("ΔV(BLB − BL)  (mV)")
ax.set_title("Sense margin vs supply and temperature")
ax.legend(fontsize=7, loc="upper left")
ax.grid(alpha=0.3, which="both")
fig.tight_layout()
fig.savefig("task3/figA4_margin.png", dpi=200)

print("wrote figA1_read.png figA2_disturb.png figA3_butterfly.png figA4_margin.png")

#!/usr/bin/env python3
"""
Part B Task 4: hand-check CACTI's bitline delay against 0.38*R*C*L^2.

Reads bldbg.txt, produced by the instrumented binary:

    cd cacti && git apply ../bitline_debug.patch && make -j
    (cd cacti && BL_DEBUG=1 ./cacti -infile ../forced.cfg 2>&1 >/dev/null) \
        | sort -u > bldbg.txt
    python3 bl_handcheck.py

forced.cfg pins the Task 1 winner (Ndwl 4 / Ndbl 2 / Nspd 1 / Ndcm 1 /
Ndsam 8,1) so the reported numbers belong to that organisation.
"""
import math
import sys

CACTI_BITLINE_NS = 0.406901   # "Bitline delay (ns)" for the Task 1 winner
ROWS, COLS = 512, 1152        # winning data subarray


def load(path="bldbg.txt"):
    for line in open(path):
        if f"rows={ROWS} " in line and f"cols={COLS} " in line:
            d = {}
            for tok in line.split():
                if "=" in tok:
                    k, v = tok.split("=", 1)
                    d[k] = float(v)
            return d
    sys.exit(f"no line for rows={ROWS} cols={COLS} in {path}")


d = load()
L = d["L_um"]
r, c_w = d["r_per_um"], d["c_per_um"]
R_wire, C_wire = r * L, c_w * L
C_bl, R_bl = d["C_bl"], d["R_bl"]
R_drive = d["R_pd"] + d["R_acc"]

hand_wire = 0.38 * R_wire * C_wire
hand_cbl = 0.38 * R_wire * C_bl

print(f"Bitline geometry: {ROWS} rows x {d['cell_h_um']} um = {L:.3f} um")
print(f"  r = {r:.4f} ohm/um   ->  R = {R_wire:8.1f} ohm")
print(f"  c = {c_w:.4g} F/um   ->  C_wire = {C_wire*1e15:6.2f} fF")
print(f"  CACTI C_bl (wire + cell drains) = {C_bl*1e15:6.2f} fF"
      f"  ({(C_bl-C_wire)/C_bl*100:.0f} % is cell drain)")
print()
print(f"Hand calc 0.38*R*C*L^2, wire C only : {hand_wire*1e12:7.2f} ps")
print(f"Hand calc 0.38*R*C*L^2, CACTI C_bl  : {hand_cbl*1e12:7.2f} ps")
print(f"CACTI bitline delay                 : {CACTI_BITLINE_NS*1e3:7.2f} ps")
print(f"  discrepancy vs wire-only C: {CACTI_BITLINE_NS*1e3/(hand_wire*1e12):.1f}x")
print(f"  discrepancy vs CACTI C_bl : {CACTI_BITLINE_NS*1e3/(hand_cbl*1e12):.1f}x")
print()
print("Why -- CACTI's tau, term by term:")
t_drive = R_drive * C_bl
t_wire = R_bl * C_bl / 2
print(f"  (R_pulldown + R_access) * C_bl = {t_drive*1e9:.4f} ns"
      f"   [R = {R_drive:.0f} ohm, {R_drive/R_wire:.1f}x the wire]")
print(f"  R_bl * C_bl / 2                = {t_wire*1e9:.4f} ns"
      f"   [{t_wire/(t_drive+t_wire)*100:.1f} % of the two]")
print(f"  tau (incl. sense-amp caps)     = {d['tau']*1e9:.4f} ns")
lg = math.log(d["Vbitpre"] / (d["Vbitpre"] - d["Vbsense"]))
print(f"  x ln(Vpre/(Vpre-Vsense)) = ln({d['Vbitpre']:.0f}/"
      f"({d['Vbitpre']:.0f}-{d['Vbsense']:.2f})) = {lg:.4f}")
print(f"  = tstep                        = {d['tstep']*1e9:.4f} ns")
print(f"  Horowitz, wordline slew        -> {CACTI_BITLINE_NS:.4f} ns"
      f"  ({CACTI_BITLINE_NS/(d['tstep']*1e9):.2f}x)")

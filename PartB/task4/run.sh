#!/usr/bin/env bash
# Part B Task 4: bitline delay hand-check against 0.38*R*C*L^2.
# Uses the shipped bldbg.txt.  To regenerate it instead:
#   git -C ../cacti apply ../task4/bitline_debug.patch && make -C ../cacti -j
#   (cd ../cacti && BL_DEBUG=1 ./cacti -infile ../task4/forced.cfg 2>&1 >/dev/null) | sort -u > bldbg.txt
#   git -C ../cacti checkout mat.cc
set -e
cd "$(dirname "$0")"
python3 bl_handcheck.py

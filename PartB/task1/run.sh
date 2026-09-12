#!/usr/bin/env bash
# Part B Task 1: CACTI baseline for the 2 MB SRAM L2.
# cacti resolves tech_params/ relative to the CWD, so it is run from inside cacti/.
set -e
cd "$(dirname "$0")"
(cd ../cacti && ./cacti -infile ../cache.cfg) | tee cacti_out.txt
grep -E "Access time|Cycle time|dynamic read energy|dynamic write energy|Total leakage power of a bank|Cache height|Best Nd|Best Nt|H-tree|Decoder|Bitline delay|Sense Amp" cacti_out.txt

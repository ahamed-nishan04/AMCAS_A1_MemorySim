#!/usr/bin/env bash
# Part A - ngspice 6T SRAM read margin.  Run from this directory.
#
#   bash run.sh
#
# Each deck runs inside its own taskN/ directory so the CSVs it writes land
# next to it; the shared PTM model card is ../45nm_bulk.txt from there.
# plots.py then reads across the task directories and writes the four figures.
set -e

run () {  # dir  deck
    echo "=== $1/$2"
    (cd "$1" && ngspice -b "$2.sp")
}

run task1 task1
run task2 task2
run task2 task2_snm
run task3 task3
run task4 task4

python3 plots.py

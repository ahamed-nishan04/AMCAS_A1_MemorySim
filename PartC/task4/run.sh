#!/usr/bin/env bash
# Part C Task 4: halve ResetCurrent, and the write-current -> access-width chain.
#   STT_4bank_reset100  ResetCurrent 100 uA, SetCurrent still 200 uA
#   STT_4bank_both100   both halved to 100 uA
#   cfg_100..400        write current 100/200/300/400 uA with the access device
#                       width scaled as a device engineer would size it
set -e
cd "$(dirname "$0")"
../nvsim STT_4bank_reset100.cfg > out_4bank_reset100.txt
../nvsim STT_4bank_both100.cfg  > out_4bank_both100.txt
for n in 100 200 300 400; do
    ../nvsim "cfg_$n.cfg" > "out_$n.txt"
done
grep -H -m1 "Total Area" out_4bank_reset100.txt out_4bank_both100.txt \
    out_100.txt out_200.txt out_300.txt out_400.txt

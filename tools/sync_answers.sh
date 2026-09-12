#!/usr/bin/env bash
# Refresh answers/ from the part directories after a verification run.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$A1_ROOT"
for p in A B C D E; do
  P=Part$p; A=answers/Part$p; mkdir -p "$A"
  for n in 1 2 3 4; do
    [ -f "$P/task$n/task$n.md" ] && cp "$P/task$n/task$n.md" "$A/task$n.md"
  done
  [ -f "$P/findings.md" ] && cp "$P/findings.md" "$A/findings.md"
  [ -f "$P/summary.md" ]  && cp "$P/summary.md"  "$A/summary.md"
  find "$P" -name "*.png" -not -path "*/notes/*" -exec cp {} "$A/" \; 2>/dev/null || true
done
echo "answers/ refreshed"

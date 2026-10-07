#!/usr/bin/env bash
# usage: scripts/sweep.sh [extra make vars, e.g. SMOKE=1]
#   MODES="A2B B2A" SHARES_LIST="2 3 4" PERIODS="2.0 1.5" scripts/sweep.sh
set -uo pipefail
MODES=${MODES:-"A2B B2A"}
SHARES_LIST=${SHARES_LIST:-"2 3 4 5 6"}
PERIODS=${PERIODS:-"2.0"}
mkdir -p results
for m in $MODES; do
  for n in $SHARES_LIST; do
    for p in $PERIODS; do
      echo "=== MODE=$m SHARES=$n CLK_PERIOD=$p ==="
      make synth MODE="$m" SHARES="$n" CLK_PERIOD="$p" "$@" \
        || echo "FAILED: MODE=$m SHARES=$n CLK_PERIOD=$p" | tee -a results/failures.log
    done
  done
done
echo "Done. See results/summary.csv"

#!/usr/bin/env bash
# Epoch driver: run benchmark tasks through rollout + score, then aggregate.
#
# Usage: skillopt/run.sh [--split train|val|all] [--out DIR] [--score-only]
#   --split       which tasks to run (default: all)
#   --out         where workspaces and results go (default: skillopt/out)
#   --score-only  skip rollouts, re-score existing workspaces
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

split=all
out="$HERE/out"
score_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --split) split="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    --score-only) score_only=1; shift ;;
    *) echo "usage: $0 [--split train|val|all] [--out DIR] [--score-only]" >&2; exit 2 ;;
  esac
done
case "$split" in train | val | all) ;; *) echo "bad --split: $split" >&2; exit 2 ;; esac

mkdir -p "$out/rollouts"
tsv="$out/results.tsv"
printf 'task\tsplit\tscore\tmax\n' >"$tsv"

for task in "$HERE"/tasks/*.task.md; do
  id="$(basename "$task" .task.md)"
  tsplit="$(head -n 1 "$task" | awk '{ print $2 }')"
  case "$tsplit" in train | val) ;; *) echo "WARN: $id has bad split '$tsplit', skipping" >&2; continue ;; esac
  [ "$split" = all ] || [ "$split" = "$tsplit" ] || continue

  ws="$out/rollouts/$id"
  if [ "$score_only" -eq 0 ]; then
    echo "== rollout: $id ($tsplit)"
    "$HERE/rollout.sh" "$task" "$ws" >"$out/rollouts/$id.score.txt" 2>&1 ||
      echo "WARN: rollout failed for $id — scoring whatever exists" >&2
  fi

  line="$("$HERE/score.sh" "$ws" | tail -n 1)"
  n="$(printf '%s' "$line" | awk '{ print $2 }')"
  m="$(printf '%s' "$line" | awk '{ print $3 }')"
  printf '%s\t%s\t%s\t%s\n' "$id" "$tsplit" "$n" "$m" >>"$tsv"
  echo "   $id ($tsplit): $n/$m"
done

echo "-- aggregate --"
awk -F'\t' 'NR > 1 { s[$2] += $3; mx[$2] += $4; c[$2]++ }
  END { for (k in s) printf "%s mean: %.1f%% over %d task(s)\n", k, 100 * s[k] / mx[k], c[k] }' "$tsv"
echo "results: $tsv"

#!/usr/bin/env bash
# Run one benchmark task through the SPDD pipeline in a throwaway consumer
# repo, driving the claude CLI through smithy's stage gates.
#
# Usage: skillopt/rollout.sh <task-file> <workspace-dir>
# Env:
#   CLAUDE_BIN             claude CLI to invoke (default: claude)
#   SKILLOPT_MAX_GATES     max gate-confirmation turns to send (default: 8)
#   SKILLOPT_CLAUDE_FLAGS  flags for every claude call
#                          (default: --permission-mode acceptEdits)
set -euo pipefail

DAMASCUS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
MAX_GATES="${SKILLOPT_MAX_GATES:-8}"
CLAUDE_FLAGS="${SKILLOPT_CLAUDE_FLAGS:---permission-mode acceptEdits}"

[ $# -eq 2 ] || { echo "usage: $0 <task-file> <workspace-dir>" >&2; exit 2; }
TASK="$1"
[ -f "$TASK" ] || { echo "no such task file: $TASK" >&2; exit 2; }
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || {
  echo "claude CLI not found — install and authenticate it before running rollouts" >&2
  exit 2
}

# task file format: "split: train|val", a "---" line, then the raw feature prompt
prompt="$(awk 'flag { print } /^---$/ { flag = 1 }' "$TASK")"
[ -n "$prompt" ] || { echo "task file has no prompt body after ---: $TASK" >&2; exit 2; }

mkdir -p "$2"
WS="$(cd "$2" && pwd -P)"
LOGDIR="$WS/.skillopt"
mkdir -p "$LOGDIR"

# throwaway consumer repo with damascus installed, mirroring tests/smoke.sh
(
  cd "$WS"
  [ -d .git ] || git init -q .
  bash "$DAMASCUS/install.sh"
)

current_score() {
  "$DAMASCUS/skillopt/score.sh" "$WS" | tail -n 1
}

driver="Use the smithy skill to run the SPDD pipeline for this feature, starting at forge. Halt at every stage gate as the skill requires; I will confirm each stage.

Feature request:
$prompt"

echo "rollout: turn 0 (feature request)"
# shellcheck disable=SC2086  # CLAUDE_FLAGS is intentionally word-split
(cd "$WS" && $CLAUDE_BIN -p "$driver" $CLAUDE_FLAGS) >"$LOGDIR/turn-0.log" 2>&1 || true

i=1
while [ "$i" -le "$MAX_GATES" ]; do
  line="$(current_score)"
  n="$(printf '%s' "$line" | awk '{ print $2 }')"
  m="$(printf '%s' "$line" | awk '{ print $3 }')"
  [ "$n" = "$m" ] && break
  echo "rollout: turn $i (gate confirmation, score $n/$m)"
  # shellcheck disable=SC2086
  (cd "$WS" && $CLAUDE_BIN --continue -p "y — proceed to the next stage." $CLAUDE_FLAGS) \
    >"$LOGDIR/turn-$i.log" 2>&1 || true
  i=$((i + 1))
done

"$DAMASCUS/skillopt/score.sh" "$WS"

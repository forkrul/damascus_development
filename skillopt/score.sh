#!/usr/bin/env bash
# Deterministic scorer for one SPDD rollout workspace.
# Each check encodes a stage-gate contract from skills/*/SKILL.md as a
# mechanical test over the artifacts a pipeline run leaves on disk.
#
# Usage:
#   skillopt/score.sh <workspace-dir>   # PASS/FAIL per check, then "SCORE n m"
#   skillopt/score.sh --self-test       # verify the scorer against fixtures
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

WS=""
PRD=""
SPECDIR=""
PASS=0
TOTAL=0

run_check() { # <label> <fn> [args...]
  label="$1" fn="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  if "$fn" "$@"; then
    PASS=$((PASS + 1))
    printf 'PASS %s\n' "$label"
  else
    printf 'FAIL %s\n' "$label"
  fi
}

has_reasons_sections() { # <file>
  [ -f "$1" ] || return 1
  for h in Requirements Entities Approach Structure Operations Norms Safeguards; do
    grep -qE "^#{1,3} .*$h" "$1" || return 1
  done
}

c_prd_exists() { [ -n "$PRD" ] && [ -s "$PRD" ]; }

c_prd_reasons() { has_reasons_sections "$PRD"; }

c_prd_no_assumed() {
  [ -f "$PRD" ] || return 1
  ! grep -q '\[ASSUMED' "$PRD"
}

c_triplet_exists() {
  [ -n "$SPECDIR" ] || return 1
  [ -s "$SPECDIR/spec.md" ] && [ -s "$SPECDIR/plan.md" ] && [ -s "$SPECDIR/tasks.md" ]
}

c_spec_has_frs() { [ -f "$SPECDIR/spec.md" ] && grep -qE 'FR-[0-9]{3}' "$SPECDIR/spec.md"; }

c_spec_has_scs() { [ -f "$SPECDIR/spec.md" ] && grep -qE 'SC-[0-9]{3}' "$SPECDIR/spec.md"; }

c_plan_reasons() { has_reasons_sections "$SPECDIR/plan.md"; }

c_tasks_ids() { [ -f "$SPECDIR/tasks.md" ] && grep -qE 'T[0-9]{3}' "$SPECDIR/tasks.md"; }

c_fr_mapping() {
  s="$SPECDIR/spec.md" t="$SPECDIR/tasks.md"
  { [ -f "$s" ] && [ -f "$t" ]; } || return 1
  frs="$(grep -oE 'FR-[0-9]+[a-z]?' "$s" | sort -u)"
  [ -n "$frs" ] || return 1
  while IFS= read -r fr; do
    grep -q "$fr" "$t" || return 1
  done <<<"$frs"
}

log_exists() { # <review-log>
  [ -f "$1" ] && grep -qE '^## Round' "$1"
}

log_rating_appp() { # <review-log>
  [ -f "$1" ] || return 1
  last="$(grep -iE 'rating:' "$1" | tail -n 1 || true)"
  printf '%s' "$last" | grep -q 'A++'
}

log_convergence() { # <review-log>
  [ -f "$1" ] || return 1
  n="$(grep -cE '^## Round' "$1" || true)"
  [ "${n:-0}" -ge 2 ]
}

c_bdd_feature() { ls "$WS"/tests/features/*.feature >/dev/null 2>&1; }

c_tasks_done() {
  f="$SPECDIR/tasks.md"
  [ -f "$f" ] || return 1
  grep -qiE '^[[:space:]]*- \[x\]' "$f" || return 1
  ! grep -qE '^[[:space:]]*- \[ \]' "$f"
}

score_workspace() {
  WS="$1"
  PRD="$(find "$WS/.prd" -maxdepth 1 -name '[0-9][0-9][0-9]_*.md' 2>/dev/null | sort | head -n 1 || true)"
  SPECDIR="$(find "$WS/specs" -maxdepth 1 -type d -name '[0-9][0-9][0-9]-*' 2>/dev/null | sort | head -n 1 || true)"
  [ -n "$SPECDIR" ] || SPECDIR="$WS/specs/none"

  run_check prd-exists c_prd_exists
  run_check prd-reasons-complete c_prd_reasons
  run_check prd-no-unconfirmed-assumptions c_prd_no_assumed
  run_check spec-triplet-exists c_triplet_exists
  run_check spec-has-FRs c_spec_has_frs
  run_check spec-has-SCs c_spec_has_scs
  run_check plan-reasons-complete c_plan_reasons
  run_check tasks-use-T-ids c_tasks_ids
  run_check fr-task-mapping c_fr_mapping
  run_check review-log-exists log_exists "$SPECDIR/review.md"
  run_check review-rating-A++ log_rating_appp "$SPECDIR/review.md"
  run_check review-convergence-2-rounds log_convergence "$SPECDIR/review.md"
  run_check bdd-feature-exists c_bdd_feature
  run_check all-tasks-checked c_tasks_done
  run_check code-review-log-exists log_exists "$SPECDIR/code-review.md"
  run_check code-review-rating-A++ log_rating_appp "$SPECDIR/code-review.md"
  run_check code-review-convergence-2-rounds log_convergence "$SPECDIR/code-review.md"

  printf 'SCORE %d %d\n' "$PASS" "$TOTAL"
}

self_test() {
  got="$(bash "$0" "$HERE/fixtures/complete" | tail -n 1)"
  [ "$got" = "SCORE 17 17" ] || {
    printf 'self-test FAIL: complete fixture scored "%s", want "SCORE 17 17"\n' "$got" >&2
    exit 1
  }
  got="$(bash "$0" "$HERE/fixtures/incomplete" | tail -n 1)"
  [ "$got" = "SCORE 2 17" ] || {
    printf 'self-test FAIL: incomplete fixture scored "%s", want "SCORE 2 17"\n' "$got" >&2
    exit 1
  }
  echo "scorer self-test: OK"
}

case "${1:-}" in
  --self-test) self_test ;;
  '') echo "usage: $0 <workspace-dir> | --self-test" >&2; exit 2 ;;
  *) score_workspace "$1" ;;
esac

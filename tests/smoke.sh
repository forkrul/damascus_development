#!/usr/bin/env bash
# End-to-end smoke test for install.sh, run against a throwaway consumer repo.
# Encodes the guarantees the README makes: idempotent install, ownership
# (never touches non-damascus files), stale-link pruning, --verify, --dry-run,
# and clean uninstall.
#
# Usage: tests/smoke.sh
#   SMOKE_BASH=/bin/bash tests/smoke.sh   # exercise a specific bash (e.g. macOS 3.2)
#
# Requires vendor submodules to be initialized in the damascus checkout.
set -euo pipefail

DAMASCUS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SMOKE_BASH="${SMOKE_BASH:-bash}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
damascus() { "$SMOKE_BASH" "$DAMASCUS/install.sh" "$@"; }

cd "$TMP"
git init -q .

# plant consumer-owned content that install must never touch
mkdir -p .claude/skills
echo keep > .claude/skills/my-own-skill
ln -s /nonexistent-foreign-target .claude/skills/foreign-link

# --- install ---
damascus

for name in forge anvil temper quench hone smithy prd-authoring speckit-decomposition \
            adversarial-review-loop bdd-tdd-execution code-review-loop spdd-pipeline; do
  [ -L ".claude/skills/$name" ] || fail "skills/$name not linked"
  [ -e ".claude/skills/$name" ] || fail "skills/$name is a broken link"
  [ -f ".claude/skills/$name/SKILL.md" ] || fail "skills/$name has no SKILL.md"
done
for agent in bdd-scenario-writer tdd-test-generator playwright-e2e-tester \
             fastapi-implementer labcoat; do
  [ -L ".claude/agents/$agent.md" ] || fail "agents/$agent.md not linked"
  [ -e ".claude/agents/$agent.md" ] || fail "agents/$agent.md is a broken link"
done
[ -L ".claude/skills/systematic-debugging" ] || fail "superpowers KEEP skills not linked"
for deny in brainstorming writing-plans executing-plans requesting-code-review \
            using-superpowers subagent-driven-development; do
  [ -e ".claude/skills/$deny" ] && fail "DENY-class superpowers skill was linked: $deny"
done

# every damascus-owned link is relative: a committed .claude/ must survive a fresh clone
for l in .claude/skills/* .claude/agents/*.md; do
  [ -L "$l" ] || continue
  [ "$l" != .claude/skills/foreign-link ] || continue # the planted foreign fixture is absolute by design
  case "$(readlink "$l")" in
    /*) fail "$l is an absolute symlink" ;;
  esac
done

# ownership guarantee
[ "$(cat .claude/skills/my-own-skill)" = keep ] || fail "consumer file modified"
[ -L .claude/skills/foreign-link ] || fail "foreign symlink removed"

# --- idempotent re-run ---
damascus
[ "$(cat .claude/skills/my-own-skill)" = keep ] || fail "re-run modified consumer file"

# --- verify passes on a healthy install ---
damascus --verify || fail "--verify failed on a healthy install"

# --- dry-run changes nothing ---
before="$(find .claude | sort)"
damascus --dry-run
damascus --uninstall --dry-run
after="$(find .claude | sort)"
[ "$before" = "$after" ] || fail "--dry-run mutated .claude"

# --- prune: a damascus-owned link with a retired name is swept on install ---
ln -s "$DAMASCUS/skills/forge" .claude/skills/retired-old-name
damascus
[ -L .claude/skills/retired-old-name ] && fail "stale damascus-owned link not pruned"

# --- verify detects breakage, install repairs it ---
rm .claude/skills/forge
damascus --verify >/dev/null 2>&1 && fail "--verify passed with a missing link"
damascus
damascus --verify || fail "--verify failed after repair"

# --- a non-damascus path in the way is skipped, reported, and fails the run ---
mkdir -p .claude/skills/hone-shadow && mv .claude/skills/hone .claude/skills/hone-shadow/ \
  && mkdir .claude/skills/hone && echo mine > .claude/skills/hone/SKILL.md
damascus >/dev/null 2>&1 && fail "install exited 0 despite a skipped link"
[ "$(cat .claude/skills/hone/SKILL.md)" = mine ] || fail "install touched a consumer-owned directory"
rm -r .claude/skills/hone && mv .claude/skills/hone-shadow/hone .claude/skills/ && rmdir .claude/skills/hone-shadow
damascus --verify || fail "--verify failed after restoring the shadowed link"

# --- uninstall removes everything owned, nothing else ---
damascus --uninstall
remaining="$(find .claude/skills -mindepth 1 -maxdepth 1 -exec basename {} \; | sort | xargs)"
[ "$remaining" = "foreign-link my-own-skill" ] || fail "unexpected leftovers in skills/: $remaining"
[ -z "$(find .claude/agents -mindepth 1 -print)" ] || fail "agents/ not emptied"
[ "$(cat .claude/skills/my-own-skill)" = keep ] || fail "uninstall touched consumer file"
[ -L .claude/skills/foreign-link ] || fail "uninstall removed foreign symlink"

# shellcheck disable=SC2016 # $BASH_VERSION must expand in the target bash, not this one
echo "smoke test: OK ($("$SMOKE_BASH" -c 'echo "bash $BASH_VERSION"') on $(uname -s))"

#!/usr/bin/env bash
# damascus install — symlink the SPDD pipeline skills + agents into a consumer
# repo's .claude/ directory.
#
# Usage (from the CONSUMER repo root, after adding damascus as a submodule):
#   git submodule add <damascus-url> vendor/damascus
#   git submodule update --init --recursive
#   ./vendor/damascus/install.sh            # install / refresh symlinks
#   ./vendor/damascus/install.sh --uninstall
#
# Idempotent: re-running refreshes links. Only touches symlinks it owns
# (links that resolve into this damascus checkout).
set -euo pipefail

DAMASCUS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONSUMER_ROOT="$(pwd -P)"

STAGE_SKILLS=(forge anvil temper quench smithy)
declare -A ALIASES=(
  [prd-authoring]=forge
  [speckit-decomposition]=anvil
  [adversarial-review-loop]=temper
  [bdd-tdd-execution]=quench
  [spdd-pipeline]=smithy
)
AGENTS=(bdd-scenario-writer tdd-test-generator playwright-e2e-tester fastapi-implementer labcoat)
# KEEP-class superpowers skills (DENY-class brainstorming/writing-plans/executing-plans
# are intentionally NOT linked — forge/anvil/quench replace them).
SUPERPOWERS_KEEP=(
  systematic-debugging subagent-driven-development dispatching-parallel-agents
  verification-before-completion requesting-code-review receiving-code-review
  finishing-a-development-branch using-git-worktrees writing-skills
  using-superpowers test-driven-development
)

SKILLS_DIR="$CONSUMER_ROOT/.claude/skills"
AGENTS_DIR="$CONSUMER_ROOT/.claude/agents"

err()  { printf '\033[0;31m[ERR]\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
info() { printf '[..] %s\n' "$*"; }

rel_or_abs() { # rel_or_abs <target> <linkdir> — relative path if possible
  local target=$1 linkdir=$2
  realpath --relative-to="$linkdir" "$target" 2>/dev/null || printf '%s' "$target"
}

owned_by_damascus() { # true if existing path is a symlink resolving into damascus
  local p=$1
  [ -L "$p" ] && case "$(readlink -f "$p" 2>/dev/null || true)" in
    "$DAMASCUS_ROOT"/*) return 0 ;;
  esac
  return 1
}

link() { # link <target> <linkpath>
  local target=$1 linkpath=$2
  if [ -e "$linkpath" ] || [ -L "$linkpath" ]; then
    if owned_by_damascus "$linkpath"; then
      rm "$linkpath"
    else
      err "skip $linkpath — exists and is not a damascus-owned symlink"
      return 0
    fi
  fi
  ln -s "$(rel_or_abs "$target" "$(dirname "$linkpath")")" "$linkpath"
  ok "linked $(basename "$linkpath")"
}

unlink_owned() {
  local p=$1
  if owned_by_damascus "$p"; then rm "$p" && ok "removed $(basename "$p")"; fi
}

preflight() {
  if [ "$CONSUMER_ROOT" = "$DAMASCUS_ROOT" ]; then
    err "run this from the CONSUMER repo root, not from inside damascus"
    exit 1
  fi
  if ! git -C "$CONSUMER_ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
    err "current directory is not a git repository"
    exit 1
  fi
  if [ ! -f "$DAMASCUS_ROOT/vendor/superpowers/skills/using-superpowers/SKILL.md" ]; then
    err "vendor/superpowers is empty — run inside the damascus checkout:"
    err "  git -C '$DAMASCUS_ROOT' submodule update --init --recursive"
    exit 1
  fi
  if [ ! -f "$DAMASCUS_ROOT/vendor/spec-kit/templates/spec-template.md" ]; then
    err "vendor/spec-kit is empty — run inside the damascus checkout:"
    err "  git -C '$DAMASCUS_ROOT' submodule update --init --recursive"
    exit 1
  fi
}

install() {
  preflight
  mkdir -p "$SKILLS_DIR" "$AGENTS_DIR"

  info "stage skills"
  for s in "${STAGE_SKILLS[@]}"; do
    link "$DAMASCUS_ROOT/skills/$s" "$SKILLS_DIR/$s"
  done

  info "stage aliases"
  for a in "${!ALIASES[@]}"; do
    link "$DAMASCUS_ROOT/skills/${ALIASES[$a]}" "$SKILLS_DIR/$a"
  done

  info "quench agents"
  for a in "${AGENTS[@]}"; do
    link "$DAMASCUS_ROOT/agents/$a.md" "$AGENTS_DIR/$a.md"
  done

  info "superpowers (KEEP-class only)"
  for s in "${SUPERPOWERS_KEEP[@]}"; do
    link "$DAMASCUS_ROOT/vendor/superpowers/skills/$s" "$SKILLS_DIR/$s"
  done

  ok "damascus installed into $SKILLS_DIR and $AGENTS_DIR"
  info "entrypoint: invoke the 'smithy' skill (or 'forge' to start a PRD)"
}

uninstall() {
  for s in "${STAGE_SKILLS[@]}" "${!ALIASES[@]}" "${SUPERPOWERS_KEEP[@]}"; do
    unlink_owned "$SKILLS_DIR/$s"
  done
  for a in "${AGENTS[@]}"; do
    unlink_owned "$AGENTS_DIR/$a.md"
  done
  ok "damascus symlinks removed"
}

case "${1:-}" in
  --uninstall) uninstall ;;
  ""|--install) install ;;
  *) err "unknown flag: $1 (use --install or --uninstall)"; exit 1 ;;
esac

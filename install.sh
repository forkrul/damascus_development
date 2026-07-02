#!/usr/bin/env bash
# damascus install — symlink the SPDD pipeline skills + agents into a consumer
# repo's .claude/ directory.
#
# Usage (from the CONSUMER repo root, after adding damascus as a submodule):
#   git submodule add <damascus-url> vendor/damascus
#   git submodule update --init --recursive
#   ./vendor/damascus/install.sh              # install / refresh symlinks
#   ./vendor/damascus/install.sh --uninstall  # remove every link it owns
#   ./vendor/damascus/install.sh --verify     # report link health; exit 1 on problems
#   ./vendor/damascus/install.sh --dry-run    # print planned actions, touch nothing
#
# Idempotent: re-running refreshes links and prunes damascus-owned links whose
# names are no longer shipped. Only ever touches symlinks it owns (links that
# resolve into this damascus checkout). Runs on bash 3.2+ (stock macOS).
set -euo pipefail

DAMASCUS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONSUMER_ROOT="$(pwd -P)"
DRY_RUN=0

STAGE_SKILLS=(forge anvil temper quench smithy)
# alias:stage pairs (plain array, not `declare -A` — bash 3.2 compatible)
ALIASES=(
  prd-authoring:forge
  speckit-decomposition:anvil
  adversarial-review-loop:temper
  bdd-tdd-execution:quench
  spdd-pipeline:smithy
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

run() { # execute, or narrate under --dry-run
  if [ "$DRY_RUN" -eq 1 ]; then info "would: $*"; else "$@"; fi
}

say_done() { [ "$DRY_RUN" -eq 1 ] || ok "$*"; }

resolve() { # portable readlink -f: canonicalize a path, following symlinks
  local p=$1 dir target hops=0
  while [ -L "$p" ] && [ "$hops" -lt 40 ]; do
    dir="$(cd "$(dirname "$p")" && pwd -P)" || return 1
    target="$(readlink "$p")"
    case $target in /*) p=$target ;; *) p="$dir/$target" ;; esac
    hops=$((hops + 1))
  done
  if dir="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)"; then
    printf '%s/%s' "$dir" "$(basename "$p")"
  else
    printf '%s' "$p" # dangling target — report it unresolved
  fi
}

rel_or_abs() { # rel_or_abs <target> <linkdir> — relative path if possible
  local target=$1 linkdir=$2
  realpath --relative-to="$linkdir" "$target" 2>/dev/null || printf '%s' "$target"
}

owned_by_damascus() { # true if existing path is a symlink resolving into damascus
  local p=$1
  [ -L "$p" ] || return 1
  case "$(resolve "$p")" in
    "$DAMASCUS_ROOT"/*) return 0 ;;
  esac
  return 1
}

expected_skill_names() { # every name damascus ships into .claude/skills/
  local s pair
  for s in "${STAGE_SKILLS[@]}" "${SUPERPOWERS_KEEP[@]}"; do printf '%s\n' "$s"; done
  for pair in "${ALIASES[@]}"; do printf '%s\n' "${pair%%:*}"; done
}

link() { # link <target> <linkpath>
  local target=$1 linkpath=$2
  if [ -e "$linkpath" ] || [ -L "$linkpath" ]; then
    if owned_by_damascus "$linkpath"; then
      run rm "$linkpath"
    else
      err "skip $linkpath — exists and is not a damascus-owned symlink"
      return 0
    fi
  fi
  run ln -s "$(rel_or_abs "$target" "$(dirname "$linkpath")")" "$linkpath"
  say_done "linked $(basename "$linkpath")"
}

prune() { # remove damascus-owned links whose names are no longer shipped
  local p name
  for p in "$SKILLS_DIR"/*; do
    [ -L "$p" ] || continue
    name="$(basename "$p")"
    if owned_by_damascus "$p" && ! expected_skill_names | grep -Fxq "$name"; then
      run rm "$p"
      say_done "pruned stale link $name"
    fi
  done
  for p in "$AGENTS_DIR"/*.md; do
    [ -L "$p" ] || continue
    name="$(basename "$p" .md)"
    if owned_by_damascus "$p" && ! printf '%s\n' "${AGENTS[@]}" | grep -Fxq "$name"; then
      run rm "$p"
      say_done "pruned stale link $(basename "$p")"
    fi
  done
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
  run mkdir -p "$SKILLS_DIR" "$AGENTS_DIR"

  info "stage skills"
  local s pair a
  for s in "${STAGE_SKILLS[@]}"; do
    link "$DAMASCUS_ROOT/skills/$s" "$SKILLS_DIR/$s"
  done

  info "stage aliases"
  for pair in "${ALIASES[@]}"; do
    link "$DAMASCUS_ROOT/skills/${pair#*:}" "$SKILLS_DIR/${pair%%:*}"
  done

  info "quench agents"
  for a in "${AGENTS[@]}"; do
    link "$DAMASCUS_ROOT/agents/$a.md" "$AGENTS_DIR/$a.md"
  done

  info "superpowers (KEEP-class only)"
  for s in "${SUPERPOWERS_KEEP[@]}"; do
    link "$DAMASCUS_ROOT/vendor/superpowers/skills/$s" "$SKILLS_DIR/$s"
  done

  info "pruning stale damascus-owned links"
  prune

  say_done "damascus installed into $SKILLS_DIR and $AGENTS_DIR"
  info "entrypoint: invoke the 'smithy' skill (or 'forge' to start a PRD)"
}

uninstall() { # remove EVERY damascus-owned link, including stale names
  local p
  for p in "$SKILLS_DIR"/* "$AGENTS_DIR"/*.md; do
    if owned_by_damascus "$p"; then
      run rm "$p"
      say_done "removed $(basename "$p")"
    fi
  done
  say_done "damascus symlinks removed"
}

PROBLEMS=0

check_link() { # check_link <linkpath> <expected-target>
  local linkpath=$1 target=$2
  if [ ! -L "$linkpath" ]; then
    if [ -e "$linkpath" ]; then
      err "$linkpath exists but is not a symlink"
    else
      err "missing: $linkpath"
    fi
    PROBLEMS=$((PROBLEMS + 1))
    return 0
  fi
  if ! owned_by_damascus "$linkpath"; then
    err "$linkpath does not resolve into this damascus checkout"
    PROBLEMS=$((PROBLEMS + 1))
    return 0
  fi
  if [ ! -e "$linkpath" ]; then
    err "broken link: $linkpath"
    PROBLEMS=$((PROBLEMS + 1))
    return 0
  fi
  if [ "$(resolve "$linkpath")" != "$(resolve "$target")" ]; then
    err "$linkpath resolves to the wrong target"
    PROBLEMS=$((PROBLEMS + 1))
    return 0
  fi
  ok "$(basename "$linkpath")"
}

verify() { # report link health; include the env facts a bug report needs
  info "damascus: $DAMASCUS_ROOT"
  info "bash $BASH_VERSION on $(uname -s)"

  local s pair a p name
  for s in "${STAGE_SKILLS[@]}"; do
    check_link "$SKILLS_DIR/$s" "$DAMASCUS_ROOT/skills/$s"
  done
  for pair in "${ALIASES[@]}"; do
    check_link "$SKILLS_DIR/${pair%%:*}" "$DAMASCUS_ROOT/skills/${pair#*:}"
  done
  for a in "${AGENTS[@]}"; do
    check_link "$AGENTS_DIR/$a.md" "$DAMASCUS_ROOT/agents/$a.md"
  done
  for s in "${SUPERPOWERS_KEEP[@]}"; do
    check_link "$SKILLS_DIR/$s" "$DAMASCUS_ROOT/vendor/superpowers/skills/$s"
  done

  for p in "$SKILLS_DIR"/* "$AGENTS_DIR"/*.md; do
    name="$(basename "$p" .md)"
    if owned_by_damascus "$p" \
      && ! expected_skill_names | grep -Fxq "$name" \
      && ! printf '%s\n' "${AGENTS[@]}" | grep -Fxq "$name"; then
      err "stale damascus-owned link: $p"
      PROBLEMS=$((PROBLEMS + 1))
    fi
  done

  if [ "$PROBLEMS" -eq 0 ]; then
    ok "all links healthy"
  else
    err "$PROBLEMS problem(s) found — re-run install.sh to repair"
    exit 1
  fi
}

usage() {
  cat <<'EOF'
usage: install.sh [--install | --uninstall | --verify] [--dry-run]

Run from the CONSUMER repo root (not from inside damascus).

  --install    (default) symlink skills + agents into .claude/, prune stale links
  --uninstall  remove every damascus-owned symlink
  --verify     report link health; exit 1 if anything needs repair
  --dry-run    print planned actions without touching anything
EOF
}

MODE=install
for arg in "$@"; do
  case $arg in
    --install)   MODE=install ;;
    --uninstall) MODE=uninstall ;;
    --verify)    MODE=verify ;;
    --dry-run)   DRY_RUN=1 ;;
    -h|--help)   usage; exit 0 ;;
    *) err "unknown flag: $arg (use --install, --uninstall, --verify, --dry-run)"; exit 1 ;;
  esac
done

"$MODE"

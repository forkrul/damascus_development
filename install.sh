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
ALL_HARNESSES=0

STAGE_SKILLS=(forge anvil temper quench hone smithy)
# alias:stage pairs (plain array, not `declare -A` — bash 3.2 compatible)
ALIASES=(
  prd-authoring:forge
  speckit-decomposition:anvil
  adversarial-review-loop:temper
  bdd-tdd-execution:quench
  code-review-loop:hone
  spdd-pipeline:smithy
)
AGENTS=(bdd-scenario-writer tdd-test-generator playwright-e2e-tester fastapi-implementer labcoat)
# KEEP-class superpowers skills. DENY-class skills are intentionally NOT linked:
# brainstorming/writing-plans/executing-plans/requesting-code-review overlap a stage
# (forge/anvil/quench/hone replace them), and using-superpowers/subagent-driven-development
# route back into those DENY skills. See the policy table in README.md.
SUPERPOWERS_KEEP=(
  systematic-debugging dispatching-parallel-agents
  verification-before-completion receiving-code-review
  finishing-a-development-branch using-git-worktrees writing-skills
  test-driven-development
)

SKILLS_DIR="$CONSUMER_ROOT/.claude/skills"
AGENTS_DIR="$CONSUMER_ROOT/.claude/agents"
PROBLEMS=0 # counted by install (skipped/missing links) and verify (unhealthy links)

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

relpath() { # relpath <target> <from-dir> — relative path between two absolute, physical paths.
  # Pure bash: `realpath --relative-to` is GNU-only, and an absolute fallback would leave
  # links that break as soon as the consumer repo is cloned somewhere else.
  local target=${1%/} from=${2%/} up='' rest
  [ "$target" = "$from" ] && { printf '.'; return 0; }
  while :; do
    case $target in
      "$from"/*) rest=${target#"$from"/}; break ;;
    esac
    from=${from%/*}
    up="../$up"
  done
  printf '%s%s' "$up" "$rest"
}

physical_dir() { # physical (symlink-free) path of a directory; falls back to the given path
  (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"
}

owned_by_damascus() { # true if existing path is a symlink resolving into damascus
  local p=$1
  [ -L "$p" ] || return 1
  case "$(resolve "$p")" in
    "$DAMASCUS_ROOT"/*) return 0 ;;
  esac
  return 1
}

# Membership is answered in-process, never through a pipe. `... | grep -Fxq`
# matches correctly but exits on the first hit, so every name emitted after it
# writes into a closed pipe; under `set -o pipefail` that EPIPE becomes the
# pipeline's exit status, and a name damascus DOES ship reads as one it does
# not. Only a match that is not the last line emitted can trigger it, and only
# when the producer is slower than grep — which is why it surfaced as an
# intermittent macOS-only "stale damascus-owned link" against a healthy install.
is_expected_skill() { # true if $1 is a name damascus ships into .claude/skills/
  local name=$1 s pair
  for s in "${STAGE_SKILLS[@]}" "${SUPERPOWERS_KEEP[@]}"; do
    if [ "$s" = "$name" ]; then return 0; fi
  done
  for pair in "${ALIASES[@]}"; do
    if [ "${pair%%:*}" = "$name" ]; then return 0; fi
  done
  return 1
}

is_expected_agent() { # true if $1 is a name damascus ships into .claude/agents/
  local name=$1 a
  for a in "${AGENTS[@]}"; do
    if [ "$a" = "$name" ]; then return 0; fi
  done
  return 1
}

link() { # link <target> <linkpath>
  local target=$1 linkpath=$2
  if [ ! -e "$target" ]; then
    err "skip $(basename "$linkpath") — target missing: $target (upstream renamed or removed it?)"
    PROBLEMS=$((PROBLEMS + 1))
    return 0
  fi
  if [ -e "$linkpath" ] || [ -L "$linkpath" ]; then
    if owned_by_damascus "$linkpath"; then
      run rm "$linkpath"
    else
      err "skip $linkpath — exists and is not a damascus-owned symlink"
      PROBLEMS=$((PROBLEMS + 1))
      return 0
    fi
  fi
  run ln -s "$(relpath "$target" "$(physical_dir "$(dirname "$linkpath")")")" "$linkpath"
  say_done "linked $(basename "$linkpath")"
}

prune() { # remove damascus-owned links whose names are no longer shipped
  local p name
  for p in "$SKILLS_DIR"/*; do
    [ -L "$p" ] || continue
    name="$(basename "$p")"
    if owned_by_damascus "$p" && ! is_expected_skill "$name"; then
      run rm "$p"
      say_done "pruned stale link $name"
    fi
  done
  for p in "$AGENTS_DIR"/*.md; do
    [ -L "$p" ] || continue
    name="$(basename "$p" .md)"
    if owned_by_damascus "$p" && ! is_expected_agent "$name"; then
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
  if [ ! -f "$DAMASCUS_ROOT/vendor/superpowers/skills/systematic-debugging/SKILL.md" ]; then
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

install_harness_dir() { # install_harness_dir <skills_dir> <agents_dir>
  local s_dir=$1 a_dir=$2 s pair a
  run mkdir -p "$s_dir" "$a_dir"
  for s in "${STAGE_SKILLS[@]}"; do
    link "$DAMASCUS_ROOT/skills/$s" "$s_dir/$s"
  done
  for pair in "${ALIASES[@]}"; do
    link "$DAMASCUS_ROOT/skills/${pair#*:}" "$s_dir/${pair%%:*}"
  done
  for a in "${AGENTS[@]}"; do
    link "$DAMASCUS_ROOT/agents/$a.md" "$a_dir/$a.md"
  done
  for s in "${SUPERPOWERS_KEEP[@]}"; do
    link "$DAMASCUS_ROOT/vendor/superpowers/skills/$s" "$s_dir/$s"
  done
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

  if [ "${ALL_HARNESSES:-0}" -eq 1 ] || [ -d "$CONSUMER_ROOT/.agents" ]; then
    info "vendor-neutral .agents harness"
    install_harness_dir "$CONSUMER_ROOT/.agents/skills" "$CONSUMER_ROOT/.agents/agents"
  fi
  if [ "${ALL_HARNESSES:-0}" -eq 1 ] || [ -d "$CONSUMER_ROOT/.gemini" ]; then
    info "gemini .gemini harness"
    install_harness_dir "$CONSUMER_ROOT/.gemini/skills" "$CONSUMER_ROOT/.gemini/agents"
  fi

  info "pruning stale damascus-owned links"
  prune

  if [ "$PROBLEMS" -gt 0 ]; then
    err "$PROBLEMS link(s) could not be installed (see [ERR] lines above)"
    exit 1
  fi
  say_done "damascus installed into $SKILLS_DIR and $AGENTS_DIR"
  info "entrypoint: invoke the 'smithy' skill (or 'forge' to start a PRD)"
}

uninstall() { # remove EVERY damascus-owned link, including stale names
  local p
  for p in "$SKILLS_DIR"/* "$AGENTS_DIR"/*.md \
           "$CONSUMER_ROOT/.agents/skills"/* "$CONSUMER_ROOT/.agents/agents"/*.md \
           "$CONSUMER_ROOT/.gemini/skills"/* "$CONSUMER_ROOT/.gemini/agents"/*.md; do
    if owned_by_damascus "$p"; then
      run rm "$p"
      say_done "removed $(basename "$p")"
    fi
  done
  say_done "damascus symlinks removed"
}

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
      && ! is_expected_skill "$name" \
      && ! is_expected_agent "$name"; then
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

print_root() {
  printf '%s\n' "$DAMASCUS_ROOT"
}

usage() {
  cat <<'EOF'
usage:
  install.sh [--install | --uninstall | --verify | --print-root] [--all-harnesses] [--dry-run]
  install.sh <agent-run | revert-proof | proof-coverage | test-lock | bdd-check | upgrade-consumers | eval> [args...]

Run from the CONSUMER repo root (not from inside damascus).

  --install        (default) symlink skills + agents into .claude/ (and .agents/ / .gemini/ if present)
  --all-harnesses  also create and populate .agents/{skills,agents} and .gemini/{skills,agents}
  --uninstall      remove every damascus-owned symlink
  --verify         report link health; exit 1 if anything needs repair
  --print-root     print the canonical damascus repository root path and exit
  --dry-run        print planned actions without touching anything

Subcommands (model-agnostic CLI harnesses):
  agent-run          probe or dispatch to local (Ollama, llama.cpp, vLLM) or cloud models
  revert-proof       worktree-isolated tri-state (RED/GREEN/INCONCLUSIVE) revert-proof verifier
  proof-coverage     verify 100% of changed production files have a RED revert-proof
  test-lock          lock/verify SHA-256 Amber test freeze manifest (.damascus/locks/)
  bdd-check          verify .feature files are bound to executable step definitions
  upgrade-consumers  inspect or upgrade downstream Damascus consumer repositories
  eval               run Damascus meta-autoresearch benchmark harness
EOF
}

main() {
  local mode=install arg sub
  case "${1:-}" in
    agent-run|revert-proof|proof-coverage|test-lock|bdd-check|upgrade-consumers)
      sub=$1; shift
      exec python3 "$DAMASCUS_ROOT/scripts/damascus-$sub" "$@" ;;
    eval)
      shift
      exec python3 "$DAMASCUS_ROOT/evals/run_eval.py" "$@" ;;
  esac
  for arg in "$@"; do
    case $arg in
      --install)       mode=install ;;
      --uninstall)     mode=uninstall ;;
      --verify)        mode=verify ;;
      --print-root)    mode=print_root ;;
      --all-harnesses) ALL_HARNESSES=1 ;;
      --dry-run)       DRY_RUN=1 ;;
      -h|--help)       usage; exit 0 ;;
      *) err "unknown flag: $arg (use --help for usage)"; exit 1 ;;
    esac
  done
  "$mode"
}

# When sourced (CI reads the STAGE_SKILLS/ALIASES/AGENTS/SUPERPOWERS_KEEP manifests
# from here so they cannot drift from the script), define everything and do nothing.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi

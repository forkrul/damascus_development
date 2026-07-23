# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

Damascus packages the **SPDD pipeline** (forge → anvil → temper → quench → hone, orchestrated by smithy) as Claude Code skills, consumed by other repos as a `vendor/damascus` submodule via `install.sh`. There is no build step — "running" this repo means exercising `install.sh` and the SKILL.md files; `tests/smoke.sh` is the test suite.

## Working here

- The six skills under `skills/` (five stages + smithy) are the product. Keep them concise; every behavioral contract lives in the SKILL.md body, not in external docs.
- `skills/<alias>` entries are relative symlinks to stage dirs — preserve them.
- `vendor/superpowers` and `vendor/spec-kit` are **pinned submodules**. Bump deliberately (checkout a tag, commit the pointer); never edit vendor content. Dependabot opens monthly bump PRs — only merge bumps that land on an upstream **tag**, and when superpowers adds or renames skills, re-check the DENY/KEEP/CONDITIONAL table in the README (a new upstream skill overlapping a stage becomes DENY; a renamed KEEP skill needs the `SUPERPOWERS_KEEP` array in `install.sh` updated — CI's smoke test fails until it is).
- `install.sh` must stay idempotent, bash 3.2 compatible (no `declare -A`, no GNU-only flags without a fallback), and only ever touch symlinks that resolve into this checkout. `tests/smoke.sh` encodes these guarantees against a throwaway repo — run it locally before pushing; CI runs it on Ubuntu and macOS (including stock bash 3.2).
- Every PR updates `CHANGELOG.md` under `[Unreleased]` (Common Changelog categories). CI enforces this.
- Branch → PR → squash merge. Never push to `master` directly.
- The temper and hone stages are **local-only by design** — do not reintroduce external-API review dependencies.

## Releasing

Semver. Breaking changes to a skill contract or to `install.sh` behavior bump the major version (the minor version while pre-1.0). To cut a release from `master`:

1. Move the `[Unreleased]` section of `CHANGELOG.md` under a `## [X.Y.Z] - YYYY-MM-DD` heading (via a normal PR).
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. Create a GitHub Release from the tag; the body is that changelog section verbatim.

Consumers pin tags (see the README install/upgrading sections) — never point them at `master`.

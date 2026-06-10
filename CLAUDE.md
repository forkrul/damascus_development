# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

Damascus packages the **SPDD pipeline** (forge → anvil → temper → quench, orchestrated by smithy) as Claude Code skills, consumed by other repos as a `vendor/damascus` submodule via `install.sh`. There is no build step or test runner — "running" this repo means exercising `install.sh` and the SKILL.md files.

## Working here

- The five stage skills under `skills/` are the product. Keep them concise; every behavioral contract lives in the SKILL.md body, not in external docs.
- `skills/<alias>` entries are relative symlinks to stage dirs — preserve them.
- `vendor/superpowers` and `vendor/spec-kit` are **pinned submodules**. Bump deliberately (checkout a tag, commit the pointer); never edit vendor content.
- `install.sh` must stay idempotent and only ever touch symlinks that resolve into this checkout. Test with a throwaway repo:
  ```bash
  mkdir -p /tmp/t && cd /tmp/t && git init -q && /path/to/damascus/install.sh && /path/to/damascus/install.sh --uninstall
  ```
- Every PR updates `CHANGELOG.md` under `[Unreleased]` (Common Changelog categories).
- Branch → PR → squash merge. Never push to `master` directly.
- The temper stage is **local-only by design** — do not reintroduce external-API review dependencies.

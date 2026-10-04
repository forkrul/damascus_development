# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

Damascus packages the **SPDD pipeline** (forge → anvil → temper → quench → hone, orchestrated by smithy) as Claude Code skills, consumed by other repos as a `vendor/damascus` submodule via `install.sh`. There is no build step — "running" this repo means exercising `install.sh` and the SKILL.md files; `tests/smoke.sh` is the test suite.

## Working here

- The six skills under `skills/` (five stages + smithy) are the product. Keep them concise; every behavioral contract lives in the SKILL.md body, not in external docs. The same goes for `agents/*.md`: a contract plus one short example per concept, no code catalogs — every line is context cost on each dispatch.
- `skills/<alias>` entries are relative symlinks to stage dirs — preserve them.
- `docs/` is a Sphinx site (MyST Markdown) that must build with zero warnings: `sphinx-build -W --keep-going -n -b html docs docs/_build/html`, after `pip install -r docs/requirements.txt`. CI runs exactly that. Pages for the skills, agents, README, example trail and changelog are generated into `docs/_generated/` by `docs/_ext/damascus_sources.py` — never copy a contract into `docs/`; add a new shipped file to that extension's `SOURCES` instead. Hand-written pages (`docs/architecture.md`) must also read on GitHub: diagrams are ` ```mermaid ` blocks, and links to files outside `docs/` are absolute GitHub URLs.
- `examples/cart-discounts/` is a worked artifact trail through all five gates. When a skill changes an artifact format (PRD template, task line, log entry), update the example to match — CI checks the trail is complete, and readers copy it.
- `vendor/superpowers` and `vendor/spec-kit` are **pinned submodules**. Bump deliberately (checkout a tag, update the README vendored-submodules table, note it in the changelog, commit the pointer); never edit vendor content. CI fails unless each pointer sits exactly on an upstream tag that the README names. Dependabot opens monthly bump PRs that target head commits — treat them as a signal that a new upstream tag exists, not as mergeable: close them and bump to the tag by hand. When superpowers adds or renames skills, re-check the DENY/KEEP/CONDITIONAL table in the README (a new upstream skill overlapping a stage, or routing into a DENY skill, becomes DENY; a renamed KEEP skill needs the `SUPERPOWERS_KEEP` array in `install.sh` updated) — CI fails until every upstream skill is either KEEP in `install.sh` or a DENY row in the README.
- `install.sh` must stay idempotent, bash 3.2 compatible (no `declare -A`, no `readlink -f`, no `realpath --relative-to`, no GNU-only flags without a fallback), only ever touch symlinks that resolve into this checkout, create only relative links, and exit non-zero when a link could not be placed. `tests/smoke.sh` encodes these guarantees against a throwaway repo — run it locally before pushing; CI runs it on Ubuntu and macOS (including stock bash 3.2). CI also `source`s `install.sh` to read its name arrays, so keep the sourcing guard at the bottom of the script.
- Every PR updates `CHANGELOG.md` under `[Unreleased]` (Common Changelog categories). CI enforces this.
- Branch → PR → squash merge. Never push to `master` directly.
- When a step doesn't need the maintainer, keep going and put status notes in the same message as the next action. Stop and ask only when you can't continue without them, or before anything destructive or outward-facing: force-pushing, pushing or moving a tag (a tag push publishes a Release), or deleting a branch, tag or release.
- The temper and hone stages are **local-only by design** — do not reintroduce external-API review dependencies.

## Releasing

Semver. Breaking changes to a skill contract or to `install.sh` behavior bump the major version (the minor version while pre-1.0). To cut a release from `master`:

1. Move the `[Unreleased]` section of `CHANGELOG.md` under a `## [X.Y.Z] - YYYY-MM-DD` heading (via a normal PR), rewrite or drop its notice (for 0.1.0: `_Initial release._`), and add an `[X.Y.Z]: …/releases/tag/vX.Y.Z` link definition at the bottom. Leave an empty `## [Unreleased]` above it. Entries follow [Common Changelog](https://common-changelog.org/): one line, imperative, each with a PR or commit link, no CI/dotfile noise — keeping `[Unreleased]` is this repo's one deliberate deviation.
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. The `Release` workflow creates the GitHub Release with that changelog section as its body. It fails if the tag has no matching changelog heading — fix the changelog and re-tag rather than editing the release by hand.

Consumers pin tags (see the README install/upgrading sections) — never point them at `master`.

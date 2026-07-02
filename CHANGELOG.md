# Changelog

All notable changes to this project are documented here, following [Common Changelog](https://common-changelog.org/).

## [Unreleased]

### Added

- Add the five SPDD pipeline skills: `forge` (PRD authoring), `anvil` (spec/plan/tasks decomposition), `temper` (adversarial review loop), `quench` (BDD-first red-amber-green execution), `smithy` (state-machine orchestrator)
- Add invocation aliases: `prd-authoring`, `speckit-decomposition`, `adversarial-review-loop`, `bdd-tdd-execution`, `spdd-pipeline`
- Add the five quench dispatch agents: `bdd-scenario-writer`, `tdd-test-generator`, `playwright-e2e-tester`, `fastapi-implementer`, `labcoat`
- Add `install.sh` for symlinking skills and agents into a consumer repo's `.claude/`
- Vendor [obra/superpowers](https://github.com/obra/superpowers) v4.3.1 and [github/spec-kit](https://github.com/github/spec-kit) v0.10.1 as pinned submodules
- Add `docs/production-readiness.md` — phased single-founder plan (licensing, CI, releases, installer hardening, automated maintenance)
- Add MIT `LICENSE` (vendored submodules retain their upstream licenses)
- Add CI workflow: shellcheck + syntax checks, alias-symlink and frontmatter integrity, install/uninstall smoke test on Ubuntu and macOS (including stock bash 3.2), and a changelog-updated gate on PRs
- Add `tests/smoke.sh` — end-to-end installer test against a throwaway consumer repo (idempotency, ownership guarantee, pruning, verify, dry-run, uninstall)
- Add `install.sh --verify` (link health report for bug reports) and `--dry-run` (print planned actions without touching anything)
- Add stale-link pruning: install now sweeps damascus-owned links whose names are no longer shipped; uninstall removes every owned link, not just known names
- Add Dependabot config for monthly vendor-submodule and GitHub Actions bumps, and a bug-report issue template
- Add README sections: requirements, pinned-tag install, upgrading, support posture and licensing; document the release ritual and submodule bump policy in CLAUDE.md

### Changed

- Make `install.sh` portable to bash 3.2 / stock macOS (replace `declare -A` and `readlink -f` with portable equivalents)
- Replace the external-API review gate in `temper` with a fully local adversarial panel (3 critic lenses + judge; A++ = two consecutive zero-blocking rounds, max 5 rounds)

### Fixed

- Make the README hero image background transparent (renders cleanly on dark and light themes)

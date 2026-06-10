# Changelog

All notable changes to this project are documented here, following [Common Changelog](https://common-changelog.org/).

## [Unreleased]

### Added

- Add the five SPDD pipeline skills: `forge` (PRD authoring), `anvil` (spec/plan/tasks decomposition), `temper` (adversarial review loop), `quench` (BDD-first red-amber-green execution), `smithy` (state-machine orchestrator)
- Add invocation aliases: `prd-authoring`, `speckit-decomposition`, `adversarial-review-loop`, `bdd-tdd-execution`, `spdd-pipeline`
- Add the five quench dispatch agents: `bdd-scenario-writer`, `tdd-test-generator`, `playwright-e2e-tester`, `fastapi-implementer`, `labcoat`
- Add `install.sh` for symlinking skills and agents into a consumer repo's `.claude/`
- Vendor [obra/superpowers](https://github.com/obra/superpowers) v4.3.1 and [github/spec-kit](https://github.com/github/spec-kit) v0.10.1 as pinned submodules

### Changed

- Replace the external-API review gate in `temper` with a fully local adversarial panel (3 critic lenses + judge; A++ = two consecutive zero-blocking rounds, max 5 rounds)

### Fixed

- Make the README hero image background transparent (renders cleanly on dark and light themes)

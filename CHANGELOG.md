# Changelog

All notable changes to this project are documented here, following [Common Changelog](https://common-changelog.org/).

## [Unreleased]

### Added

- Add `hone` (alias `code-review-loop`) — stage 5: local adversarial review of the implementation diff (spec-conformance / security / simplicity lenses with mandatory active procedures, ≤400-changed-line review units, A++ = two consecutive zero-blocking rounds, max 3 rounds), between quench and merge
- Add quench hardening gates: diff-scoped mutation testing (line coverage reported, never gated), host-repo static/type/security checks, an FR ↔ test traceability sweep (`@pytest.mark.fr("FR-NNN")` / `@FR-NNN` Gherkin tags), and a stable-green rule (new tests pass 3× in randomized order; a flake is red, never a retry)
- Add the test freeze: from amber onward a test changes only after `spec.md`/`tasks.md` change first; test agents never write implementation and `fastapi-implementer` treats test files as read-only
- Add `specs/NNN-<slug>/quench-log.md` — append-only per-task cycle log (red/amber/green timestamps, amber's failure message, diff size, gate results, waivers)
- Add property-based tests (Hypothesis) derived from PRD Safeguards and SC invariants, characterization-test-first handling for `[REFACTOR]` tasks, and sample-and-select (2–3 independent candidates judged by the frozen tests) for `[HARD]` tasks
- Add active reading procedures to temper's critics (re-derive sections, trace a data flow, draft per-FR test skeletons — findings without the artifact are discarded) and a capture-recapture overlap signal that caps near-disjoint rounds at B+ in both review loops

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
- Change forge's Norms section to require machine-checkable form (the tool + config that enforces each norm, installed as gates by quench) and mark each Safeguard as the source of a property test or runtime assertion
- Change anvil's task format: optional `[UX]`/`[REFACTOR]`/`[HARD]` tags and a ≤400-changed-line sizing budget per task (oversized tasks come back as anvil feedback via the quench log)
- Change smithy's state machine to drive hone after quench and halt on hone's 3-round cap
- Move `superpowers:requesting-code-review` from KEEP to DENY — `hone` replaces it; `receiving-code-review` stays KEEP for applying findings
- Replace the 95% line-coverage gate in `tdd-test-generator`'s pytest config with mutation-testing guidance and a registered `fr` marker for requirement traceability

### Fixed

- Make the README hero image background transparent (renders cleanly on dark and light themes)
- Fix three quench agents (`tdd-test-generator`, `labcoat`, `fastapi-implementer`) that defined Amber as "minimal implementation", contradicting quench's fails-for-the-right-reason contract

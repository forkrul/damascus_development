# Changelog

## [Unreleased]

### Changed

- Drop "Don't do this" items and sentences that restate a rule already given in its own section of the same skill (forge, anvil, temper, quench, hone), and merge temper's and hone's Convergence Rule and Iteration Cap sections. No rule is removed; hone is back within the 260-line prompt budget, so `./install.sh eval` scores 100 ([#31](https://github.com/forkrul/damascus_development/pull/31))

## [0.1.1] - 2026-10-17

### Changed

- Rewrite the README around a quick start: the real clone URL, how to start a feature with smithy, red-amber-green next to the gates it belongs to, a table of the `damascus` commands, and a `vX.Y.Z` upgrade example instead of a release that doesn't exist ([#28](https://github.com/forkrul/damascus_development/pull/28))
- Mark `docs/production-readiness.md` as a record of the original plan, with `master` protected by a repository ruleset, and describe the docs as harness-agnostic rather than Claude Code-only ([#28](https://github.com/forkrul/damascus_development/pull/28))

### Added

- Add `docs/reference.md`, a configuration and CLI reference written from the code: model routing through `.damascus/models.conf` and `DAMASCUS_*` variables, every gate's flags, exit codes and file formats, stage addenda, and the evaluation harness with the live critic benchmark ([#28](https://github.com/forkrul/damascus_development/pull/28))
- Add `evals/run_eval.py --check-corpus`, run in CI, which fails when echoing the prompt earns credit, when a defect is not matched by its own description or is matched by a sibling's, or when a NIT counts as BLOCKING ([#27](https://github.com/forkrul/damascus_development/pull/27))

### Fixed

- Make `upgrade-consumers` run each repo's own `vendor/damascus/install.sh`, so its links keep pointing at its pinned submodule instead of the checkout running the command; skip a repo without one unless `--link-to-this-checkout` is given, and exit 1 when an install or verify fails ([#29](https://github.com/forkrul/damascus_development/pull/29))
- Cap a review round at B+ in the eval's reference adjudicator at under 25 % overlap, as the temper and hone skills specify, instead of 20 % ([#29](https://github.com/forkrul/damascus_development/pull/29))
- Stop `damascus agent-run` from falling back to a hardcoded Ollama model name; with no model pulled, configured or in `OLLAMA_MODEL`, it now says so and exits 1 ([#29](https://github.com/forkrul/damascus_development/pull/29))
- Correct the `test-lock` manifest name in its docstring to `.damascus/locks/amber-tests.sha256.json` ([#29](https://github.com/forkrul/damascus_development/pull/29))
- Fix the README's install and upgrade snippets, which committed whatever `master` was instead of the pinned tag: initialise damascus's submodules from inside `vendor/damascus` rather than from the repo root ([#28](https://github.com/forkrul/damascus_development/pull/28))
- Make `./install.sh eval --live-llm` measure something: a seeded defect now counts only when a `[BLOCKING]` finding names it and diagnoses it in words absent from the prompt. Before, any keyword anywhere in the reply counted, and echoing the prompt scored 12/12. The clean control is now scored for false positives, the echo baseline is reported, and every prompt and raw reply is saved under `.damascus/eval-runs/`. The corpus `keywords` field becomes `anchors` + `diagnosis` (corpus 0.3.0) ([#27](https://github.com/forkrul/damascus_development/pull/27))
- Fix the clean control's FR-001, which did not say how to round, so INV-001 failed for sub-cent subtotals; it now rounds down ([#27](https://github.com/forkrul/damascus_development/pull/27))

## [0.1.0] - 2026-10-16

_Initial release._

### Added

- Add the five SPDD stage skills `forge`, `anvil`, `temper`, `quench` and `hone`, and the `smithy` orchestrator that resumes any feature from its disk artifacts ([#1](https://github.com/forkrul/damascus_development/pull/1))
- Add `install.sh` to symlink the skills, aliases, agents and KEEP-class superpowers skills into a consumer's `.claude/` with relative links ([#1](https://github.com/forkrul/damascus_development/pull/1), [#3](https://github.com/forkrul/damascus_development/pull/3))
- Support stock macOS bash 3.2 in `install.sh` ([#3](https://github.com/forkrul/damascus_development/pull/3))
- Add `--verify`, `--dry-run` and `--uninstall` to `install.sh`, which touches only links it owns and exits non-zero when a link cannot be placed ([#3](https://github.com/forkrul/damascus_development/pull/3), [#19](https://github.com/forkrul/damascus_development/pull/19))
- Vendor `obra/superpowers` 7.0.0 and `github/spec-kit` 1.2.0 as submodules pinned to upstream tags ([#18](https://github.com/forkrul/damascus_development/pull/18), [#26](https://github.com/forkrul/damascus_development/pull/26)) ([`e17bbff`](https://github.com/forkrul/damascus_development/commit/e17bbff))
- Add the DENY / KEEP / CONDITIONAL policy that keeps seven superpowers skills out of the install, including the transcript analyser `diagnosing-superpowers` ([#1](https://github.com/forkrul/damascus_development/pull/1), [#26](https://github.com/forkrul/damascus_development/pull/26)) ([`e17bbff`](https://github.com/forkrul/damascus_development/commit/e17bbff))
- Add the quench dispatch agents `bdd-scenario-writer`, `tdd-test-generator`, `playwright-e2e-tester`, `fastapi-implementer` and `labcoat` ([#1](https://github.com/forkrul/damascus_development/pull/1)) ([`cc17dc9`](https://github.com/forkrul/damascus_development/commit/cc17dc9))
- Add the aliases `prd-authoring`, `speckit-decomposition`, `adversarial-review-loop`, `bdd-tdd-execution`, `code-review-loop` and `spdd-pipeline` ([#1](https://github.com/forkrul/damascus_development/pull/1)) ([`cc17dc9`](https://github.com/forkrul/damascus_development/commit/cc17dc9))
- Add red-amber-green to quench: tests freeze at amber, then mutation, static, traceability and stable-green gates ([`cc17dc9`](https://github.com/forkrul/damascus_development/commit/cc17dc9))
- Add temper's mandatory critic procedures and overlap signal; A++ takes two consecutive clean rounds ([`cc17dc9`](https://github.com/forkrul/damascus_development/commit/cc17dc9))
- Add hone, which reviews the diff in units of at most 400 lines and shows every fix failing without itself ([#12](https://github.com/forkrul/damascus_development/pull/12)) ([`cc17dc9`](https://github.com/forkrul/damascus_development/commit/cc17dc9))
- Add smithy's finish step, which updates README and CHANGELOG, runs Atlas when installed and logs `FINISH:` ([`ebfc01e`](https://github.com/forkrul/damascus_development/commit/ebfc01e))
- Add stopping rules for long runs: keep going between gates; stop at a gate, a refusal or before anything destructive ([#22](https://github.com/forkrul/damascus_development/pull/22))
- Lead every gate message with a "Needs your call" block ([#22](https://github.com/forkrul/damascus_development/pull/22))
- Require a repro or an implementer's question on blocking findings, and add the `UNCONFIRMED` finding class ([#22](https://github.com/forkrul/damascus_development/pull/22))
- Run quench's `[P]` tasks in parallel git worktrees and merge them one at a time ([#22](https://github.com/forkrul/damascus_development/pull/22))
- Add `examples/cart-discounts/`, one feature's artifact trail through all five gates ([`e17bbff`](https://github.com/forkrul/damascus_development/commit/e17bbff))
- Add `damascus agent-run`, a stdlib-only runner that sends a critic, judge or implementer prompt to a local OpenAI-compatible server (llama.cpp, vLLM, LM Studio, SGLang, LocalAI), Ollama or an agent CLI (`claude`, `gemini`, `codex`, `opencode`, `llm`), with `--probe`, `.damascus/models.conf` routing and model/provider self-identification stripped for blind judging ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Add mechanized gates as `install.sh` subcommands: `revert-proof` (each fix reverted in an isolated worktree must turn its test RED, not GREEN or INCONCLUSIVE), `proof-coverage` (every changed production file has such a proof), `test-lock` (amber tests frozen by SHA-256, verified at green) and `bdd-check` (every `.feature` file is bound to a step runner) ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Add `install.sh upgrade-consumers` to inspect or upgrade downstream repos' damascus installs, skipping read-only mounts ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Add `./install.sh eval` (`evals/run_eval.py`), a scored harness over the smoke test, the mechanized gates, skill invariants and a prompt-size budget, with a seeded-defect corpus and an autoresearch-style `evals/program.md` ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Add `--all-harnesses` to also link skills and agents into `.agents/` and `.gemini/` (linked automatically when those directories exist), and `--print-root` ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Add `.damascus/addenda/<stage>.md` hooks so a host repo can add domain checks or a fourth critic lens to any stage without forking it ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Add `[DELTA]` / `[INVARIANT]` requirement tags and `INV-NNN` safeguards to anvil, a vacuity check for every SC in temper's testability lens, and a one-round M0 micro-temper for localized spec changes (`SCR-NNN`) ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Cap a review round at B+ for low overlap only when at least four distinct blocking findings were raised and under 25 % of them by two or more critics, so disjoint nits can no longer block convergence ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Keep critics blind to the round number and prior grade, pass only the previous round's diff after round 1, and rotate a critic on the A+ → A++ confirmation round ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Add a bounded autoresearch keep/revert loop to quench for `[HARD]` tasks with a quantitative target ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Switch the dispatch agents to `model: inherit`, cut each to at most 150 lines, and teach Pydantic v2, SQLAlchemy 2.0, timezone-aware UTC and property-based tests for `INV-NNN` safeguards ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Add `references/`, the research notes behind these changes, and `tests/dogfood_e2e.sh`, an end-to-end run of every gate on a throwaway project ([#24](https://github.com/forkrul/damascus_development/pull/24))
- Document the pipeline in a Sphinx site with mermaid architecture diagrams, generated from the shipped files ([#23](https://github.com/forkrul/damascus_development/pull/23))
- Document install, upgrades, pins and the superpowers policy in the README ([#1](https://github.com/forkrul/damascus_development/pull/1)) ([`e17bbff`](https://github.com/forkrul/damascus_development/commit/e17bbff))
- Document the single-founder production-readiness plan ([#3](https://github.com/forkrul/damascus_development/pull/3))
- License the project under MIT; vendored submodules keep their upstream licenses ([#3](https://github.com/forkrul/damascus_development/pull/3))

[Unreleased]: https://github.com/forkrul/damascus_development/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/forkrul/damascus_development/releases/tag/v0.1.1
[0.1.0]: https://github.com/forkrul/damascus_development/releases/tag/v0.1.0

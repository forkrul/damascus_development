# Changelog

## [Unreleased]

_Initial release, to be published as 0.1.0 (see the release ritual in `CLAUDE.md`)._

### Added

- Add the five SPDD stage skills `forge`, `anvil`, `temper`, `quench` and `hone`, and the `smithy` orchestrator that resumes any feature from its disk artifacts ([#1](https://github.com/forkrul/damascus_development/pull/1))
- Add `install.sh` to symlink the skills, aliases, agents and KEEP-class superpowers skills into a consumer's `.claude/` with relative links ([#1](https://github.com/forkrul/damascus_development/pull/1), [#3](https://github.com/forkrul/damascus_development/pull/3))
- Support stock macOS bash 3.2 in `install.sh` ([#3](https://github.com/forkrul/damascus_development/pull/3))
- Add `--verify`, `--dry-run` and `--uninstall` to `install.sh`, which touches only links it owns and exits non-zero when a link cannot be placed ([#3](https://github.com/forkrul/damascus_development/pull/3), [#19](https://github.com/forkrul/damascus_development/pull/19))
- Vendor `obra/superpowers` 6.3.0 and `github/spec-kit` 1.0.6 as submodules pinned to upstream tags ([#18](https://github.com/forkrul/damascus_development/pull/18)) ([`e17bbff`](https://github.com/forkrul/damascus_development/commit/e17bbff))
- Add the DENY / KEEP / CONDITIONAL policy that keeps six overlapping superpowers skills out of the install ([#1](https://github.com/forkrul/damascus_development/pull/1)) ([`e17bbff`](https://github.com/forkrul/damascus_development/commit/e17bbff))
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
- Document the pipeline in a Sphinx site with mermaid architecture diagrams, generated from the shipped files (#PR)
- Document install, upgrades, pins and the superpowers policy in the README ([#1](https://github.com/forkrul/damascus_development/pull/1)) ([`e17bbff`](https://github.com/forkrul/damascus_development/commit/e17bbff))
- Document the single-founder production-readiness plan ([#3](https://github.com/forkrul/damascus_development/pull/3))
- License the project under MIT; vendored submodules keep their upstream licenses ([#3](https://github.com/forkrul/damascus_development/pull/3))

[Unreleased]: https://github.com/forkrul/damascus_development/commits/master

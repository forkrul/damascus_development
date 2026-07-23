---
name: quench
description: Use after temper has signed off on A++ and before code review. Quenches the tempered spec into hardened code via BDD-first, red-amber-green TDD with frozen tests and mutation/static hardening gates, with Playwright for any UX-tagged task. Stage 4 of the SPDD pipeline (forge → anvil → temper → quench → hone, orchestrated by smithy).
effort: high
---

# Quench — Stage 4: BDD/TDD Execution

## Overview

Quenches the A++-tempered spec triplet into working, tested code. This is the **execution stage**: BDD scenarios first, then red-amber-green TDD per task, with Playwright for any UX-tagged work. Output: passing tests + implementation + green CI, hardened by the gates below and handed to `hone` for adversarial diff review.

**Announce at start:** "I'm using the quench skill to execute the spec via BDD/TDD."

**Save artifacts to:**
- BDD: `tests/features/<feature-slug>.feature` (Gherkin)
- Unit/integration tests: per project convention
- Playwright (if UX): `tests/e2e/<feature-slug>.spec.ts`
- Cycle log: `specs/NNN-<feature-slug>/quench-log.md` (append-only, one entry per task)

## When to use

- `temper` has signed off (`review.md` ends in A++)
- The user invokes `/quench`, `/bdd-tdd-execution` (alias), or asks to "implement the spec"
- You are explicitly instructed to skip earlier stages (e.g. `smithy --start-from quench` for a fast hotfix)

## When NOT to use

- A++ rating is not present in `review.md` → run `temper` first (refuse with that message)
- The task is a one-line typo fix → just fix it; quench is overkill
- The user wants exploratory code (notebooks, prototypes) → use a separate experimental flow, not quench

## Upstream Superpowers Policy (DENY redirect + KEEP override)

- `superpowers:executing-plans` is **DENY**. **If you would have invoked it, invoke `quench` (or `smithy` for cross-stage execution) instead.** Quench's BDD-first / red-amber-green discipline supersedes the upstream skill's looser execution model.
- `superpowers:test-driven-development` is **CONDITIONAL** (red-green only). Quench **overrides** it with **red-amber-green** (see below). Refer to it for general TDD philosophy; do not use its specific cycle definition.

## Entry Preconditions

Refuse if:

1. `specs/NNN-<slug>/{spec,plan,tasks}.md` do not all exist
2. `specs/NNN-<slug>/review.md` does not exist OR its latest round rating is not **A++**
3. The user has not committed (or at least staged) the tempered spec

## The Red-Amber-Green Cycle

Standard TDD says **red → green → refactor**. Quench inserts **amber** between red and green.

| Phase | Test status | What it means | What you do |
|-------|-------------|---------------|-------------|
| **Red** | Fails | Test fails, possibly for the wrong reason (syntax error, import missing, NameError) | Make the test *exist* and run; don't write impl yet |
| **Amber** | Fails for the right reason | Test fails with the **assertion you actually care about** (e.g. `AssertionError: expected 42, got None`), not because of plumbing | This is the proof that the test is real. Stop here and confirm before going green |
| **Green** | Passes | Test passes via minimal implementation | Write only enough code to flip amber → green |
| **Refactor** | Passes | Code cleaned up, tests still pass | Optional but encouraged |

**Why amber matters**: Most "TDD" sessions skip from red to green and never confirm the test would actually fail if the impl were wrong. Amber is the moment you trust the test.

**Amber freezes the test.** From amber onward, a test changes only after `spec.md`/`tasks.md` change first (Golden Rule), with the exception noted in the quench log. Authorship stays separated: test agents (`tdd-test-generator`, `labcoat`) never write implementation; the implementer (`fastapi-implementer`) never edits tests. If the host repo has a drift-detection hook, point it at `tests/**` as well as `src/**` — a test edit without a spec edit is drift.

Announce each red/amber/green transition as you make it **and append it to the quench log** (timestamps, amber's failure message, diff stats at green — format below). If the host repo provides a phase-signalling helper (e.g. a tmux status-bar script), call it at each transition; skip silently if absent — it never gates anything.

## BDD-First Ordering

For each user story in `spec.md`:

1. **Write the Gherkin scenario** in `tests/features/<feature>.feature`. Use plain English; no implementation references.
2. **Run the scenario** — it must fail because no step definitions exist yet (Red).
3. **Stub the step definitions** that match the Given/When/Then clauses.
4. **Run again** — now the scenario fails because the assertions don't match real behavior (Amber).
5. **Drop into TDD per task** in `tasks.md`: each unit-level task gets red-amber-green. Where a spec Safeguard or SC states an invariant ("must never…", "always…"), encode it as a property-based test (e.g. Hypothesis) alongside the example tests — a property explores the input space; examples sample it.
6. **Re-run the BDD scenario** when all tasks are green — it should pass end-to-end.

## Playwright Trigger (UX tasks)

If a task in `tasks.md` is tagged `[UX]` or touches `frontend/`, `web/`, or `ui/`:

1. Write a Playwright `.spec.ts` covering the user flow as a real browser interaction
2. Apply red-amber-green to the Playwright spec just like unit tests
3. Run in both Firefox and Chromium (per `playwright-e2e-tester` agent convention)

If no task is UX-tagged, skip Playwright. Don't add E2E tests speculatively.

## Task Tags

Beyond `[P]` and `[UX]`, `tasks.md` may carry two tags anvil assigns:

- **`[REFACTOR]`** — the task changes existing behavior-bearing code. Before touching it, write **characterization (golden-master) tests** pinning current observable behavior; they play amber's role for code that already exists. Only then run red-amber-green for the new behavior.
- **`[HARD]`** — genuinely tricky logic. Use **sample-and-select**: dispatch 2–3 independent implementation attempts (separate subagents, no shared context), run the frozen tests + hardening gates against each, keep the winner. Record the selection and reasoning in the quench log.

## Green Means Stable-Green

A test that passed once has not passed. At green, run the new/changed tests **3 times**, in randomized order if the runner supports it (e.g. `pytest-randomly`). Any flicker sends the task back to red: find the root cause (order dependence, time, concurrency, unseeded randomness) and fix it. **Never rerun a flaky test until it passes** — a flake is a bug report, not noise.

## Hardening Gates (at green, before a task is checked off)

1. **Static gates** — run what the host repo configures: type checker (strict), linter, security scanner (e.g. bandit/semgrep), dependency audit. Any finding on lines this feature changed = red. If the host repo configures none, record the gap in the quench log — and note that PRD Norms naming tool config get installed here.
2. **Mutation gate** — if a mutation tool is available (mutmut / cosmic-ray for Python, Stryker for JS/TS), run it **scoped to the files this feature changed**. A surviving mutant on a changed line = a weak or missing test: strengthen it via the Golden Rule path (spec → tasks → test) or waive it explicitly in the quench log with reasoning. No tool available → record `mutation: not run`. Line coverage is *reported* in the log, never gated — a % gate invites assertion-free tests.
3. **FR ↔ test traceability** — every test names its FR (`@pytest.mark.fr("FR-NNN")`, `@FR-NNN` Gherkin tags, or the FR id in the test name/docstring). At completion, check every FR is verified:

   ```bash
   for fr in $(grep -oE 'FR-[0-9]+[a-z]*' specs/NNN-<slug>/spec.md | sort -u); do
     grep -rqE "$fr" tests/ || echo "UNTESTED: $fr"
   done
   ```

   An untested FR means the feature is not done — write the test (starting at red), or if the FR turns out unverifiable, that's a spec defect: back through the Golden Rule.

## The Quench Log

`specs/NNN-<slug>/quench-log.md`, append-only, one entry per task:

```markdown
## T007 — 2026-07-23
- red:   14:02  fails (collection: ImportError — step defs missing)
- amber: 14:06  AssertionError: expected 42, got None
- green: 14:19  diff +84/−12 across 3 files · 5 tests · stable-green 3/3
- gates: mypy ok · ruff ok · bandit ok · mutation 0 survivors (7 killed) · coverage 91% (reported)
```

The log is the pipeline's flight recorder: it proves amber happened (the failure message), keeps diffs sized for review (`hone` reviews per task in ≤400-changed-line units — a task that lands bigger is logged as anvil feedback), and records every waiver, freeze exception, and sample-and-select decision.

## Agent Dispatch Table

Quench composes with the agents that ship in this repo's `agents/` directory. Dispatch as follows:

| Task type | Agent |
|-----------|-------|
| Gherkin scenarios | `bdd-scenario-writer` |
| Failing pytest tests | `tdd-test-generator` |
| Playwright `.spec.ts` | `playwright-e2e-tester` |
| Implementation (FastAPI) | `fastapi-implementer` |
| Test coverage / mocks | `labcoat` |

Don't dispatch agents you don't have a task for.

## Don't do this

- **Don't skip the amber phase.** It's the whole point. Going red → green hides broken tests; you have no proof the test would catch a real bug.
- **Don't write the test and the implementation in the same edit.** Two edits, two test runs, two confirmations. This is non-negotiable.
- **Don't refactor across red/amber/green boundaries.** Refactor only when green. Refactoring during red conflates concerns and obscures what's actually broken.
- **Don't add tests beyond what tasks.md specifies.** Speculative test coverage is bloat. If you find a gap, edit `tasks.md` first (Golden Rule), then add the test.
- **Don't write implementation code without a failing test in front of you.** No exceptions. If you find yourself about to "just add this small thing", stop and write the test first.
- **Don't dispatch all the agents at once.** Quench is sequential per task, not parallel. Parallel agent dispatch is for `dispatching-parallel-agents` (an upstream skill), not quench.
- **Don't mark a task complete until BDD + unit tests + (Playwright, if UX) all pass.** Partial green is not green.
- **Don't invoke `superpowers:executing-plans`.** It is DENY-listed. Use quench's BDD-first / red-amber-green discipline.
- **Don't silently downgrade red-amber-green to red-green.** If you find yourself doing it, you've slipped into upstream `test-driven-development` mode. Re-read this skill's Cycle table.
- **Don't edit a test after amber without a spec/tasks change first.** Weakened assertions are how broken code reaches green. The freeze is the contract; exceptions go through the Golden Rule and into the quench log.
- **Don't gate on coverage %.** Report it in the log; gate on mutation survivors and FR ↔ test traceability instead.
- **Don't rerun a flaky test until it passes.** A flake is red. Fix the root cause or the task isn't done.

## Refusal Behavior

If the user wants to "just write the code, skip the tests this once", refuse. Quench is the test discipline; without it you're not in quench. Offer `smithy --skip quench` (which records the bypass), but make clear: skipping quench means there is no test artifact for this feature.

## Gate to Completion

Quench is **complete** when:

- [ ] Every task in `tasks.md` is checked off
- [ ] BDD scenarios for every user story pass
- [ ] Unit/integration tests for every FR pass (traceability check reports no UNTESTED FR)
- [ ] Playwright tests pass (if any UX tasks existed)
- [ ] Hardening gates passed per task (static, mutation-or-waiver, stable-green 3/3)
- [ ] `quench-log.md` has a red/amber/green entry for every task
- [ ] CI is green
- [ ] All code + tests are committed
- [ ] If the host repo ships a board/state projection (e.g. a kanban sync script), run its sync once here. Skip silently if absent. (Any post-merge sync belongs to the host repo's merge tooling, not to quench.)

When complete, say:

> "Quench complete: N tasks executed, M tests passing, all FRs verified, CI green. Next stage: **hone** (adversarial diff review to A++). Run it now? (y/N)"

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

Inside quench, the Golden Rule has a specific form: **when a failing test reveals a missing requirement, edit `spec.md` and `tasks.md` first**, then write the test, then the code. Most TDD sessions silently expand scope by adding tests for things never specced. Quench refuses that path.

## Composition

- Reads the A++-tempered triplet from `temper`
- Composes with: `bdd-scenario-writer`, `tdd-test-generator`, `playwright-e2e-tester`, `fastapi-implementer`, `labcoat` (shipped in `agents/`)
- Hands off to `hone` (adversarial diff review); hone hands off to `superpowers:finishing-a-development-branch` (KEEP)
- Composes with `superpowers:systematic-debugging` (KEEP) when a test fails ambiguously

## References

- Fowler, M. *Structured Prompt-Driven Development* — Golden Rule

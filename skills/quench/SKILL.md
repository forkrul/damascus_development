---
name: quench
description: Use after temper has signed off on A++ and before merging. Quenches the tempered spec into hardened code via BDD-first, red-amber-green TDD, with Playwright for any UX-tagged task. Stage 4 (final) of the SPDD pipeline (forge → anvil → temper → quench, orchestrated by smithy).
effort: high
---

# Quench — Stage 4: BDD/TDD Execution

## Overview

Quenches the A++-tempered spec triplet into working, tested code. This is the **execution stage**: BDD scenarios first, then red-amber-green TDD per task, with Playwright for any UX-tagged work. Output: passing tests + implementation + green CI.

**Announce at start:** "I'm using the quench skill to execute the spec via BDD/TDD."

**Save artifacts to:**
- BDD: `tests/features/<feature-slug>.feature` (Gherkin)
- Unit/integration tests: per project convention
- Playwright (if UX): `tests/e2e/<feature-slug>.spec.ts`

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

Announce each red/amber/green transition as you make it. If the host repo provides a phase-signalling helper (e.g. a tmux status-bar script), call it at each transition; skip silently if absent — it never gates anything.

## BDD-First Ordering

For each user story in `spec.md`:

1. **Write the Gherkin scenario** in `tests/features/<feature>.feature`. Use plain English; no implementation references.
2. **Run the scenario** — it must fail because no step definitions exist yet (Red).
3. **Stub the step definitions** that match the Given/When/Then clauses.
4. **Run again** — now the scenario fails because the assertions don't match real behavior (Amber).
5. **Drop into TDD per task** in `tasks.md`: each unit-level task gets red-amber-green.
6. **Re-run the BDD scenario** when all tasks are green — it should pass end-to-end.

## Playwright Trigger (UX tasks)

If a task in `tasks.md` is tagged `[UX]` or touches `frontend/`, `web/`, or `ui/`:

1. Write a Playwright `.spec.ts` covering the user flow as a real browser interaction
2. Apply red-amber-green to the Playwright spec just like unit tests
3. Run in both Firefox and Chromium (per `playwright-e2e-tester` agent convention)

If no task is UX-tagged, skip Playwright. Don't add E2E tests speculatively.

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

## Refusal Behavior

If the user wants to "just write the code, skip the tests this once", refuse. Quench is the test discipline; without it you're not in quench. Offer `smithy --skip quench` (which records the bypass), but make clear: skipping quench means there is no test artifact for this feature.

## Gate to Completion

Quench is **complete** when:

- [ ] Every task in `tasks.md` is checked off
- [ ] BDD scenarios for every user story pass
- [ ] Unit/integration tests for every FR pass
- [ ] Playwright tests pass (if any UX tasks existed)
- [ ] CI is green
- [ ] All code + tests are committed
- [ ] If the host repo ships a board/state projection (e.g. a kanban sync script), run its sync once here. Skip silently if absent. (Any post-merge sync belongs to the host repo's merge tooling, not to quench.)

When complete, say:

> "Quench complete: N tasks executed, M tests passing, CI green. Pipeline complete. Use `superpowers:finishing-a-development-branch` for merge/PR (KEEP-listed)."

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

Inside quench, the Golden Rule has a specific form: **when a failing test reveals a missing requirement, edit `spec.md` and `tasks.md` first**, then write the test, then the code. Most TDD sessions silently expand scope by adding tests for things never specced. Quench refuses that path.

## Composition

- Reads the A++-tempered triplet from `temper`
- Composes with: `bdd-scenario-writer`, `tdd-test-generator`, `playwright-e2e-tester`, `fastapi-implementer`, `labcoat` (shipped in `agents/`)
- Hands off to `superpowers:finishing-a-development-branch` (KEEP) for merge/PR
- Composes with `superpowers:systematic-debugging` (KEEP) when a test fails ambiguously

## References

- Fowler, M. *Structured Prompt-Driven Development* — Golden Rule

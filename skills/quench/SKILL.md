---
name: quench
description: Use after temper has signed off on A++ and before code review. Quenches the tempered spec into hardened code via BDD-first, red-amber-green TDD with frozen tests and mutation/static hardening gates, with Playwright for any UX-tagged task. Stage 4 of the SPDD pipeline (forge → anvil → temper → quench → hone, orchestrated by smithy).
effort: high
---

# Quench — Stage 4: BDD/TDD Execution

## Overview

Quenches the A++-tempered spec triplet into working, tested code. This is the **execution stage**: BDD scenarios first, then red-amber-green TDD per task, with Playwright for any UX-tagged work. Output: passing tests + implementation + green CI, hardened by the gates below and handed to `hone` for adversarial diff review.

`damascus <cmd>` below means the damascus checkout's `install.sh <cmd>` — from a consumer repo root usually `vendor/damascus/install.sh <cmd>`, inside damascus itself `./install.sh <cmd>`. No global `damascus` command is installed.

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

If the host repository defines `.damascus/addenda/quench.md`, read it before execution and enforce its domain-specific test/build gates.

## The Red-Amber-Green Cycle

Standard TDD says **red → green → refactor**. Quench inserts **amber** between red and green.

| Phase | Test status | What it means | What you do |
|-------|-------------|---------------|-------------|
| **Red** | Fails | Test fails, possibly for the wrong reason (syntax error, import missing, NameError) | Make the test *exist* and run; don't write impl yet |
| **Amber** | Fails for the right reason | Test fails with the **assertion you actually care about** (e.g. `AssertionError: expected 42, got None`), not because of plumbing | This is the proof that the test is real. Check the failure message yourself, log it, and freeze the tests with `damascus test-lock lock --task <ID>` before any implementation exists |
| **Green** | Passes | Test passes via minimal implementation, and `damascus test-lock verify` confirms the frozen tests were not altered | Write only enough code to flip amber → green |
| **Refactor** | Passes | Code cleaned up, tests still pass | Optional but encouraged |

**Why amber matters**: Most "TDD" sessions skip from red to green and never confirm the test would actually fail if the impl were wrong. Amber is the moment you trust the test.

**Amber mechanically freezes the test (`damascus test-lock`).** At the end of Amber, lock all test files via `damascus test-lock lock --task <ID>` (which records SHA-256 digests in `.damascus/locks/amber-tests.sha256.json`). At Green, run `damascus test-lock verify` to guarantee zero silent test edits occurred during implementation. A test changes only after `spec.md`/`tasks.md` change first (Golden Rule / 1-round M0 Micro-Temper), unlocked via `damascus test-lock unlock --reason "<SCR-NNN>"` and logged in `quench-log.md`. Authorship stays separated: test agents (`tdd-test-generator`, `labcoat`) never write implementation; implementers never edit tests.

Amber is a checkpoint you verify, not a pause for the user. Run task after task without stopping to report: put each transition's status note in the same message as your next action, and halt only at quench's gate, a refusal, a Golden Rule spec edit, or before anything destructive (deleting data, force-pushing, rewriting history).

Announce each red/amber/green transition as you make it **and append it to the quench log** (timestamps, amber's failure message, diff stats at green — format below). If the host repo provides a phase-signalling helper (e.g. a tmux status-bar script), call it at each transition; skip silently if absent — it never gates anything.

## BDD-First Ordering & Collection Gate

For each user story in `spec.md`:

1. **Write the Gherkin scenario** in `tests/features/<feature>.feature`. Use plain English; no implementation references.
2. **Run the scenario** — it must fail because no step definitions exist yet (Red).
3. **Stub the step definitions** that match the Given/When/Then clauses and bind the `.feature` file (`scenarios(...)` / `@scenario(...)`).
4. **Run `damascus bdd-check` and the test runner** — `damascus bdd-check` verifies every `.feature` file is bound (preventing unbound features from passing `pytest` silently with 0 collected scenarios), and the runner must fail on the assertion (Amber).
5. **Drop into TDD per task** in `tasks.md`: each unit-level task gets red-amber-green. Where a spec Safeguard (`INV-NNN`) or SC states an invariant ("must never…", "always…"), encode it as a **property-based test** (e.g. Python `hypothesis`, TypeScript `fast-check`, Rust `proptest`) alongside example tests — feeding minimal shrunk counterexamples back on failure.
6. **Re-run `damascus bdd-check` and the BDD scenario** when all tasks are green — it must pass end-to-end.

## Playwright Trigger (UX tasks)

If a task in `tasks.md` is tagged `[UX]` or touches `frontend/`, `web/`, or `ui/`:

1. Write a Playwright `.spec.ts` covering the user flow as a real browser interaction
2. Apply red-amber-green to the Playwright spec just like unit tests
3. Run in both Firefox and Chromium (per `playwright-e2e-tester` agent convention)

If no task is UX-tagged, skip Playwright. Don't add E2E tests speculatively.

## Task Tags & In-Pipeline Karpathy `autoresearch`

Beyond `[P]` and `[UX]`, `tasks.md` may carry three specialized tags `anvil` assigns:

- **`[REFACTOR]` / `[INVARIANT]`** — the task changes or preserves existing behavior-bearing code. Before touching production code, write **characterization (golden-master) tests** pinning current observable behavior (`GREEN` on `HEAD`), lock them via `damascus test-lock lock`, and verify they remain `GREEN` after the change (plus Red → Amber → Green for any `[DELTA]` requirements).
- **`[HARD]`** — genuinely tricky architecture, algorithm, or performance logic. Choose the appropriate scientific search mode:
  1. **Architectural design choice → Sample-and-Select:** Dispatch 2–3 independent implementation attempts (separate subagents or models via `damascus agent-run`, no shared context), run the frozen Amber tests + hardening gates against each, keep the simplest winner.
  2. **Quantitative metric target (latency in $\text{ms}$, memory in $\text{MB}$, throughput, or mutation kill score) → Bounded Karpathy `autoresearch` Ratchet:** Freeze the Amber tests and benchmark command as the read-only harness, and run up to $N \le 5$ fixed-budget hypothesis → edit → evaluate → keep/revert (`git reset --hard`) iterations via `labcoat`. Log every iteration (`commit`, `metric`, `delta`, `status: KEEP|REVERT`, `hypothesis`) to `specs/NNN-<slug>/autoresearch-<task-id>.tsv`.

## Parallel Tasks (`[P]`)

Inside one task the cycle is sequential: test agent, then implementer. Across tasks, the `[P]` tasks of the current phase whose prerequisites are green may run side by side:

1. Give each `[P]` task its own git worktree (`superpowers:using-git-worktrees`, KEEP) and its own agents running the full cycle — red, amber, green, gates.
2. Check each result before accepting it, as for any agent report: re-run its amber and its stable-green yourself in its worktree.
3. Merge finished tasks onto the feature branch **one at a time**, re-running the full suite (stable-green 3×) and the static gates after each merge. Tick the task in `tasks.md` and write its quench-log entry on the feature branch at merge, never in the worktree (both files would conflict on every merge), noting `parallel with T00x`, so the log stays in merge order.
4. A merge conflict, or a suite that goes red only after a merge, means the `[P]` tag was wrong: log it as anvil feedback and redo that task sequentially on the merged branch.

## Green Means Stable-Green

A test that passed once has not passed. At green, run `damascus test-lock verify` and run the new/changed tests **3 times**, in randomized order if the runner supports it (e.g. `pytest-randomly`). Any flicker sends the task back to red: find the root cause (order dependence, time, concurrency, unseeded randomness) and fix it. **Never rerun a flaky test until it passes** — a flake is a bug report, not noise.

## Hardening Gates (at green, before a task is checked off)

1. **Test-freeze & BDD binding gates** — `damascus test-lock verify` (confirming Amber-frozen tests were not edited during Green) and `damascus bdd-check` (when `.feature` files exist).
2. **Static gates** — run what the host repo configures: type checker (strict), linter, security scanner (e.g. bandit/semgrep), dependency audit. Any finding on lines this feature changed = red. If the host repo configures none, record the gap in the quench log — and note that PRD Norms naming tool config get installed here.
3. **Mutation gate** — if a mutation tool is available (`mutmut` / `cosmic-ray` for Python, `Stryker` for JS/TS, `cargo-mutants` for Rust), run it **scoped to the files this feature changed**. A surviving mutant on a changed line = a weak or missing test: strengthen it via the Golden Rule path (spec → tasks → test) or waive it explicitly in the quench log with reasoning. No tool available → record `mutation: not run`. Line coverage is *reported* in the log, never gated — a % gate invites assertion-free tests.
4. **FR & INV ↔ test traceability** — every test names its FR or INV (`@pytest.mark.fr("FR-NNN")`, `@FR-NNN` Gherkin tags, or the FR/INV id in the test name/docstring). At completion, check every FR and `INV-NNN` is verified:

   ```bash
   for id in $(grep -oE '(FR|INV)-[0-9]+[a-z]*' specs/NNN-<slug>/spec.md | sort -u); do
     grep -rqE "$id" tests/ || echo "UNTESTED: $id"
   done
   ```

   An untested FR or INV means the feature is not done — write the test (starting at red), or if the FR turns out unverifiable, that's a spec defect: back through the Golden Rule (or 1-round M0 Micro-Temper).

## The Quench Log

`specs/NNN-<slug>/quench-log.md`, append-only, one entry per task:

```markdown
## T007 — 2026-07-23
- red:   14:02  fails (collection: ImportError — step defs missing)
- amber: 14:06  AssertionError: expected 42, got None · test-lock locked (5 files)
- green: 14:19  diff +84/−12 across 3 files · 5 tests · test-lock verified · stable-green 3/3
- gates: bdd-check ok · mypy ok · ruff ok · bandit ok · mutation 0 survivors (7 killed) · coverage 91% (reported)
```

The log is the pipeline's flight recorder: it proves amber happened (the failure message), keeps diffs sized for review (`hone` reviews per task in ≤400-changed-line units — a task that lands bigger is logged as anvil feedback), and records every waiver, freeze exception, and sample-and-select decision.

## Agent Dispatch Table

Quench composes with the agents that ship in this repo's `agents/` directory. The shipped agents are shaped for a **Python / pytest / FastAPI** host with Playwright for the browser; the *cycle* is stack-agnostic. Dispatch as follows:

| Task type | Agent |
|-----------|-------|
| Gherkin scenarios | `bdd-scenario-writer` |
| Failing unit/integration tests | `tdd-test-generator` (pytest); another stack → a test-writer subagent bound by the same contract: owns red and amber, records amber's failure message, never writes implementation |
| Playwright `.spec.ts` | `playwright-e2e-tester` |
| Implementation | `fastapi-implementer` (FastAPI); another stack → an implementer subagent bound by the same contract: enters at amber, minimal code to green, never edits tests |
| Test coverage / mocks | `labcoat` |

For a non-Python host, dispatch a general subagent with the corresponding agent file's contract sections (cycle, freeze, gates) pasted into its prompt — the contract is what quench depends on, not the framework. Don't dispatch agents you don't have a task for.

**An agent's report is a claim, not evidence.** When a test agent reports amber, re-run its tests yourself and log *your* failure message; when the implementer reports green, re-run the suite and the stable-green 3× yourself before the gates. A report that doesn't reproduce goes back to that agent with your output.

## Don't do this

- **Don't skip the amber phase.** It's the whole point. Going red → green hides broken tests; you have no proof the test would catch a real bug.
- **Don't write the test and the implementation in the same edit.** Two edits, two test runs, two logged results. This is non-negotiable.
- **Don't refactor across red/amber/green boundaries.** Refactor only when green. Refactoring during red conflates concerns and obscures what's actually broken.
- **Don't add tests beyond what tasks.md specifies.** Speculative test coverage is bloat. If you find a gap, edit `tasks.md` first (Golden Rule), then add the test.
- **Don't write implementation code without a failing test in front of you.** No exceptions. If you find yourself about to "just add this small thing", stop and write the test first.
- **Don't dispatch all the agents at once.** The cycle inside a task is sequential, and only `[P]` tasks run side by side, each in its own worktree and merged one at a time (see Parallel Tasks). Never run a task in parallel with a task anvil didn't tag `[P]`.
- **Don't mark a task complete until BDD + unit tests + (Playwright, if UX) all pass.** Partial green is not green.

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

When complete, lead with **Needs your call** — mutation waivers, freeze exceptions, sample-and-select picks, gates recorded as not run, tasks logged as anvil feedback — or "nothing", then say:

> "Quench complete: N tasks executed, M tests passing, all FRs verified, CI green. Next stage: **hone** (adversarial diff review to A++). Run it now? (y/N)"

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

Inside quench, the Golden Rule has a specific form: **when a failing test reveals a missing requirement, edit `spec.md` and `tasks.md` first**, then write the test, then the code. Most TDD sessions silently expand scope by adding tests for things never specced. Quench refuses that path.

## Composition

- Reads the A++-tempered triplet from `temper`
- Composes with: `bdd-scenario-writer`, `tdd-test-generator`, `playwright-e2e-tester`, `fastapi-implementer`, `labcoat` (shipped in `agents/`)
- Hands off to `hone` (adversarial diff review); hone hands off to `superpowers:finishing-a-development-branch` (KEEP)
- Composes with `superpowers:systematic-debugging` (KEEP) when a test fails ambiguously, and `superpowers:using-git-worktrees` (KEEP) for `[P]` tasks

## References

- Fowler, M. *Structured Prompt-Driven Development* — Golden Rule

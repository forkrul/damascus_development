---
name: hone
description: Use after quench has produced green, gated code and before merge. Hones the implementation diff through a local adversarial code-review panel until it earns an A++ rating. No external APIs. Stage 5 of the SPDD pipeline (forge → anvil → temper → quench → hone, orchestrated by smithy).
effort: medium
---

# Hone — Stage 5: Adversarial Diff Review

## Overview

Hones the implementation diff produced by `quench` through repeated **local adversarial
code-review rounds** until it earns an **A++** rating. Temper reviews the *spec* before
code exists; hone is the same machinery pointed at the *code* — the pipeline's second
quality gate, between green tests and merge. Each round: heat (critics try to refute the
diff against the spec) → adjudicate (a judge dedupes and rates) → cool (apply fixes with
tests re-run, log the round).

The loop is fully local — critics and judge are subagents of the current session. No
external API, key, or network access is required.

**Announce at start:** "I'm using the hone skill to review the implementation diff to A++."

**Save review trail to:** `specs/NNN-<feature-slug>/code-review.md` (append-only, one entry per round)

## When to use

- `quench` is complete (all tasks checked, tests green, hardening gates passed)
- The user invokes `/hone`, `/code-review-loop` (alias), or asks to "review the code before merge"
- Any time the diff feels off but tests are green — green proves behavior, not quality

## When NOT to use

- Quench has not completed → run `quench` first (refuse with that message)
- A one-line hotfix that skipped the pipeline → hone is part of SPDD, not a universal gate
- The user wants to skip review for a throwaway spike → `smithy --skip hone` records the bypass

## Upstream Superpowers Policy (DENY redirect)

The upstream `superpowers:requesting-code-review` skill is **DENY** under this pipeline.

**If you would have invoked `superpowers:requesting-code-review`, invoke `hone` instead.**
Hone reviews with three distinct lenses instead of one reviewer, converges on an explicit
rating, and leaves an append-only trail in `code-review.md`. The companion
`superpowers:receiving-code-review` stays KEEP — use its posture when applying findings
in the Cool phase.

## Entry Preconditions

Refuse if:

1. `specs/NNN-<slug>/{spec,plan,tasks}.md` or `review.md` (A++) do not exist
2. `specs/NNN-<slug>/quench-log.md` does not exist or any task lacks a green entry
3. The test suite is not currently green
4. The diff is uncommitted — hone reviews commits, not a dirty tree

## Review Units and the Diff Budget

Review the feature diff **task by task** (quench-log records each task's commits and
diff size). **No review unit may exceed ~400 changed lines** — beyond that, reviewer
defect-detection collapses and findings degrade into style notes. If a single task's
diff exceeds the budget, split the review by commit; log the oversized task as feedback
to `anvil` (the task was cut too big) in `code-review.md`.

## The Adversarial Round

### 1. Heat — critic panel (parallel)

Dispatch **3 critic subagents in parallel**, each with a distinct lens, an **active
procedure**, and an explicit mandate to **refute** the diff, not affirm it:

| Critic | Lens | Active procedure (mandatory, artifact attached) |
|--------|------|------------------------------------------------|
| **Conformance** | code ↔ spec drift | For every FR the unit claims to satisfy, cite the `file:line` implementing it. Behavior with no FR, or an FR with no lines, = finding |
| **Security** | vulnerabilities & unsafe defaults | Walk each external input from entry point to its sinks: validation, authn/authz, injection, secrets handling, error leakage, risky dependencies |
| **Simplicity** | maintainability | Propose concrete deletions/simplifications — dead code, needless abstraction, duplication, complexity — or state explicitly why none exist |

Each critic receives the review unit's diff plus the spec triplet, and returns findings
as **BLOCKING** (would be wrong to merge) or **NIT** (cosmetic), each with `file:line`.
"Looks good" with no findings requires the critic to show its procedure's artifact and
state what it tried and failed to break. Opinions without the artifact are discarded.

### 2. Adjudicate — judge (single)

Dispatch **1 judge subagent** with all critic findings. The judge:

- Dedupes overlapping findings
- Kills non-substantive nits and critic theater (manufactured objections)
- Discards any finding whose critic did not attach its procedure artifact
- Computes the **overlap signal**: D = distinct findings after dedupe, m = findings
  raised independently by ≥2 critics. If D ≥ 4 and m/D < 25%, the panel is sampling a
  larger defect pool than it is exhausting — cap the round's rating at **B+** regardless
  of blocking count
- Assigns the round's rating on the ladder below

### 3. Cool — apply and log

- Apply every surviving BLOCKING finding as a code edit (or explicitly reject it in the
  log with reasoning)
- **After each fix, the full test suite must be green again.** The test freeze holds
  through hone: a fix never edits a test unless `spec.md`/`tasks.md` changed first
- A finding that reveals a *spec* gap is not fixed here — Golden Rule: halt and route
  back through smithy to `anvil`/`temper`
- Append the round to `code-review.md`; if not converged, run the next round

## Critic Prompt Template

```
You are an adversarial code reviewer. Your job is to REFUTE this diff against
its spec, not to affirm it. Lens: <conformance|security|simplicity>.

Execute your active procedure FIRST and attach its artifact:
<FR→file:line trace | input→sink walk | deletion/simplification list>

Merge bar: this diff implements exactly the tempered spec — no more, no less —
with no vulnerability and nothing a maintainer would delete. Find every place
that bar fails.

Return:
- Findings, each: [BLOCKING|NIT] <file>:<line> — <specific issue> — <what would fix it>
- If you found nothing: your procedure artifact plus the 3 attack angles you
  tried and why each failed.

--- spec.md / plan.md / tasks.md ---
<paste>
--- diff (review unit) ---
<paste>
```

## The Rating Ladder

| Rating | Meaning |
|--------|---------|
| **F**  | Diff does not implement the spec, or breaks it |
| **C**  | Works, but drifts from the spec or carries security smells |
| **B**  | Faithful to spec; structural or clarity issues remain |
| **B+** | Solid, or rating capped by the overlap signal |
| **A**  | Every FR traced to code; no unspecced behavior; no security findings |
| **A+** | Tight; first zero-blocking round (clean pass 1 of 2) |
| **A++** | Two consecutive zero-blocking rounds — nothing left a reviewer would block a merge on |

## Convergence Rule

**A++ requires two consecutive rounds with zero BLOCKING findings.** A single clean
round earns at most A+; the second confirms the first wasn't luck. A round capped by the
overlap signal cannot count as clean — disjoint findings mean undiscovered defects remain.

## Iteration Cap

**Maximum 3 rounds**, then escalate to the user with the stuck findings. Quench's
mechanical gates already caught what tools can catch; three rounds of human-shaped
review that fail to converge usually mean an upstream problem — an under-specified
spec (back to `temper`) or an oversized task (back to `anvil`).

## Don't do this

- **Don't review the diff yourself in the main session.** You (or your subagents) wrote
  this code; fresh critics without the authoring context are the point.
- **Don't let a fix touch a test file.** The freeze from quench holds. If a finding says
  a test is wrong, that's a spec conversation (Golden Rule), not a hone edit.
- **Don't fix beyond the findings.** Refactor-while-you're-in-there at this stage is
  scope creep on green code; put it in the log as a NIT for a future feature.
- **Don't review a unit larger than ~400 changed lines.** Split by task/commit first.
- **Don't accept conformance findings without the FR → file:line trace** (nor any
  critic's finding without its procedure artifact). Evidence, not vibes.
- **Don't merge on A or A+.** A++ is the gate, same as temper. Tempted to ship at A+
  means the convergence rule caught something; stop and escalate.
- **Don't edit `code-review.md` retroactively.** Append-only, like `review.md`.
- **Don't invoke `superpowers:requesting-code-review`.** It is DENY-listed; hone replaces it.

## Refusal Behavior

If the user asks to skip hone "just this once", remind them: green tests prove the code
does what the tests say, not that it should be merged. Offer `smithy --skip hone`, which
records the bypass in the orchestrator log so the team knows where the QA gap is. Don't
silently bypass.

## Gate to Completion

Hone is **complete** when:

- [ ] `code-review.md` exists and its latest round is **A++** (two consecutive zero-blocking rounds)
- [ ] Every applied fix is committed and the full suite is green (quench's hardening gates re-pass)
- [ ] If the host repo ships a board/state projection (e.g. a kanban sync script), run its sync once here. Skip silently if absent.

When complete, say:

> "Hone complete: A++ reached after N round(s). Pipeline complete. Use
> `superpowers:finishing-a-development-branch` for merge/PR (KEEP-listed)."

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

Hone's findings split cleanly under the Golden Rule: code that diverges from the spec is
fixed *here*; a spec that diverges from what the code needed to be is fixed *upstream* —
halt, route back through smithy, re-temper, and let the change flow forward. Never patch
the code into a shape the spec doesn't describe.

## Composition

- Reads the diff produced by `quench` (via `quench-log.md`'s per-task record)
- Critics/judge dispatch via the session's subagent mechanism; pairs with
  `superpowers:dispatching-parallel-agents` (KEEP)
- Applies findings with the posture of `superpowers:receiving-code-review` (KEEP)
- Hands off to `superpowers:finishing-a-development-branch` (KEEP) for merge/PR

## References

- Fowler, M. *Structured Prompt-Driven Development* — Golden Rule
- Cohen, J. *Best Kept Secrets of Peer Code Review* (SmartBear/Cisco study) — the ~400-line review-unit budget

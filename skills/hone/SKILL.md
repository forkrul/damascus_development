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

`damascus <cmd>` below means the damascus checkout's `install.sh <cmd>` — from a consumer repo root usually `vendor/damascus/install.sh <cmd>`, inside damascus itself `./install.sh <cmd>`. No global `damascus` command is installed.

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

If the host repository defines `.damascus/addenda/hone.md`, read it before dispatching critics and attach any domain-specific checks or optional 4th critic lens (`critic-d`).

## Model-Agnostic Critic & Judge Dispatch (Local + Cloud)

Before each round, write the unit's **round bundle** `specs/NNN-<slug>/diff-bundle.md` — the spec triplet, the unit's diff including the previous round's fix commits, and any carried UNCONFIRMED check; nothing from `code-review.md` or commit messages, and no triplet line that names a hone round (an amendment note's trigger). When the previous round fixed nothing in the unit, say nothing about fix commits: "no fixes" tells a critic the last review was clean. Dispatch each critic as the read-only **`hone-critic`** agent (Read, Glob, Grep; Bash only for repros in a throwaway worktree) and the judge as **`review-judge`** on an anonymized findings file; where a harness ignores agent `tools:` lines, their no-edit rule still binds. Or route either via `damascus agent-run` to local models (Ollama, `llama.cpp`, `vLLM`, `LM Studio`) or cloud CLIs (`claude`, `gemini`, `codex`, `opencode`, `llm`):

```bash
damascus agent-run --probe
damascus agent-run --role critic-a --prompt "<critic-a prompt>" --input-file specs/NNN-<slug>/diff-bundle.md
```

`damascus agent-run` automatically strips model and provider self-identification headers from critic outputs so the Judge evaluates findings **blind** to which model produced them. Never use the implementing/repairing context as the Judge. Output containing a `> rule-auditor fallback` line (`agent-run --backend auto` found no model and substituted its deterministic checks, with a `[WARN]` on stderr) is not a critic review — re-dispatch to a model or a native subagent before counting the round, or pass `--no-fallback` to make that an error.

## Review Units and the Diff Budget

Pack the feature diff into **review units**: consecutive tasks in `quench-log.md` order (it records each task's commits and diff size), each unit **at most ~400 changed lines** — beyond that, reviewer defect-detection collapses (especially on local models with 8k–32k KV caches) and findings degrade into style notes. A single task over the budget is split by commit and logged in `code-review.md` as feedback to `anvil` (the task was cut too big). List the units at the top of `code-review.md`.

The panel and judge run **per unit**, and the overlap signal is computed per unit. A unit is **done** after two consecutive clean reviews (the convergence rule below, per unit). Round 1 reviews every unit; later rounds review only units not yet done. A fix makes **every unit whose files it touches** not done, and its diff joins that unit (re-split if it then exceeds the budget).

Each round logs one line per reviewed unit and a feature `- Rating:` line: the lowest unit rating, a done unit counting as A++. Smithy reads only that feature line.

## The Adversarial Round

### 1. Heat — critic panel (parallel)

Dispatch **3 `hone-critic` agents in parallel** (plus optional `critic-d` if defined in `.damascus/addenda/hone.md`), each with a distinct lens (80% effort), a **20% shared core correctness sweep** (calibrating cross-critic overlap on genuine blocking bugs), an **active procedure**, and an explicit mandate to **refute** the diff, not affirm it:

| Critic | Lens | Active procedure (mandatory, artifact attached) |
|--------|------|------------------------------------------------|
| **Conformance** (`critic-a`) | code ↔ spec drift | For every FR and `INV-NNN` safeguard the unit claims to satisfy, cite the `file:line` implementing it. Behavior with no FR, or an FR/INV with no lines, = finding |
| **Security** (`critic-b`) | vulnerabilities & unsafe defaults | Walk each external input from entry point to its sinks: validation, authn/authz, injection, secrets handling, error leakage, resource pairing, risky dependencies |
| **Simplicity** (`critic-c`) | maintainability | Propose concrete deletions/simplifications — dead code, needless abstraction, duplication, complexity — or state explicitly why none exist |

**Anti-Sycophancy & Local-Model Context Hygiene:**
- **Round & Grade Blindness:** Never tell Critics A, B, or C the current round number or prior round's rating (`A` / `A+`).
- **Fresh-Critic Rotation on `A+ → A++`:** On the confirmation round following an `A+`, rotate model assignment or inject a red-team falsification framing into one critic slot. The framing names no earlier review: "assume the diff hides a defect", never "a previous reviewer was too lenient".

Each critic reads the round bundle (diff + spec triplet), and returns findings
as **BLOCKING** (would be wrong to merge) or **NIT** (cosmetic), each with `file:line`.
A BLOCKING finding must show how it fails — a failing test, a repro input, or a command
and its output. A suspicion the critic couldn't show is **UNCONFIRMED**, with where it
looked and what it couldn't check.

### 2. Adjudicate — judge (single, blind)

Dispatch **1 fresh `review-judge`** (never the implementer/repair author context) with anonymized critic findings. The judge:

- Dedupes overlapping findings
- Kills non-substantive nits and critic theater (manufactured objections)
- Discards any finding whose critic did not attach its procedure artifact
- Treats a BLOCKING finding with no way to show it fails as UNCONFIRMED
- Settles each UNCONFIRMED: confirms it (BLOCKING or NIT), kills it when the evidence
  contradicts it, carries it into the next round as a targeted check for that lens, or —
  when the session cannot check it at all (it needs data or access the session doesn't
  have) — logs it as open
- Computes the **stratified BLOCKING overlap signal**: let $D_B$ = distinct **BLOCKING** findings after dedupe, and $m_B$ = **BLOCKING** findings raised independently by ≥2 critics.
  - **If $D_B \ge 4$ and $m_B / D_B < 25\%$**: the panel is sampling a blocking defect pool it hasn't exhausted — cap the round's rating at **B+**.
  - **If $D_B = 0$**: the overlap cap **does not apply**. Disjoint NITs never cap a 0-BLOCKING round at B+.
- Assigns the round's rating on the ladder below

### 3. Cool — apply, mechanize revert-proofs, and log

- Apply every surviving BLOCKING finding as a code edit (or explicitly reject it in the
  log with reasoning). The critic's repro is the seed for the test that guards the fix
- **After each fix, the full test suite must be green again.** The test freeze holds
  through hone: a fix never edits an existing test unless `spec.md`/`tasks.md` changed first (`damascus test-lock verify --allow-new` proves the locked tests are untouched while permitting new test files; when the Golden Rule does require changing a locked test, run `damascus test-lock unlock --reason …`, log the AMBER-AMEND in `quench-log.md`, edit, then `damascus test-lock lock` again)
- **Every fix must be shown to fail without itself.** Revert the fix, watch the guarding
  test go red, restore it. A fix whose test passes with the fix removed has not been
  verified — only asserted — and does not count as applied. Do it mechanically — prose
  claims in `code-review.md` do not count — and record both reports in the log:
  ```bash
  # 1. Each fix, reverted in an isolated worktree, must turn its guarding test RED (not GREEN, not an INCONCLUSIVE import/collection error):
  damascus revert-proof --cases specs/NNN-<slug>/cases.json --report-out specs/NNN-<slug>/revert-proof-report.json

  # 2. Every production file the round changed must be covered by a verified RED revert-proof:
  damascus proof-coverage --base-ref <round-base-sha> --fix-ref HEAD --report specs/NNN-<slug>/revert-proof-report.json
  ```
- A finding that reveals a *spec* gap is not fixed here — Golden Rule: halt and run a 1-round **M0 Micro-Temper** (for a localized `SCR-NNN` clarification) or route back through smithy to `anvil`/`temper`
- Append the round to `code-review.md`; if not converged, run the next round straight
  away. A round boundary is not a gate: the only stops are A++, the round cap, and a
  finding that routes back upstream

**The repair is the least-reviewed code in the pipeline, and it is written under the
worst conditions.** It is authored at the end of a session, against a defect just
understood, by the author of that defect, under pressure to close it — and then merged
because it "fixes the finding". The critics scrutinised the implementation; nobody
scrutinises the repair. In the run that produced this rule, **four of six blocking
findings in round 3 were regressions rounds 1 and 2 had introduced, three of them
credential leaks, every one under a fully green suite.** Two guards follow:

- **Round N+1's panel reviews round N's fixes as part of the diff**, not just the
  original implementation. A round whose fixes went unreviewed is not a clean round.
- **A fix that moves a threshold must re-measure BOTH directions**, including the one
  that was fine before. Optimising for the failure you were just shown, without
  re-checking its opposite, is how a fix aimed at over-masking opened a credential leak.

**A spec edit written to justify a code change is the highest-risk edit in the pipeline**,
because it removes the very thing that would otherwise have contradicted the code. If a
fix requires amending an A++-tempered artifact, the amendment's premise must be
*measured and the measurement shown* — not reasoned, however obvious it sounds. Halt and
re-temper instead where the change is a real requirement change.

## Critic Prompt Template

```
You are an adversarial code reviewer. Your job is to REFUTE this diff against
its spec, not to affirm it. Lens: <conformance|security|simplicity> (80%) +
Shared Core Correctness Sweep (20%).

Execute your active procedure FIRST and attach its artifact:
<FR→file:line trace | input→sink walk | deletion/simplification list>

Merge bar: this diff implements exactly the tempered spec — no more, no less —
with no vulnerability and nothing a maintainer would delete. Find every place
that bar fails.

Return:
- Findings, each: [BLOCKING|NIT] <file>:<line> — <specific issue> — <what would fix it>
  A BLOCKING finding also gives how to show it fails: a failing test, a repro input,
  or a command and its output.
- What you suspect but couldn't show, each: [UNCONFIRMED] <file>:<line> —
  <suspected issue> — <where you looked and what you couldn't check>
- If you found nothing: your procedure artifact plus the 3 attack angles you
  tried and why each failed.

--- round bundle: specs/NNN-<slug>/diff-bundle.md (read it and the source it touches) ---
```

## The Rating Ladder

| Rating | Meaning |
|--------|---------|
| **F**  | Diff does not implement the spec, or breaks it |
| **C**  | Works, but drifts from the spec or carries security smells |
| **B**  | Faithful to spec; structural or clarity issues remain |
| **B+** | Solid, or rating capped by the BLOCKING overlap signal ($D_B \ge 4, m_B/D_B < 25\%$) |
| **A**  | Every FR traced to code; no unspecced behavior; no security findings |
| **A+** | Tight; first zero-blocking round ($D_B = 0$, clean pass 1 of 2) |
| **A++** | Two consecutive zero-blocking rounds ($D_B = 0$) — nothing left a reviewer would block a merge on |

## Convergence Rule and Cap

**A unit reaches A++ after two consecutive reviews with zero BLOCKING findings ($D_B = 0$); the feature, when every unit has.** One clean
review earns at most A+; the second confirms the first wasn't luck. A review capped by the overlap signal cannot count as clean.

**A round that carries an UNCONFIRMED forward is not clean.** The next round's targeted
check must settle it: shown (BLOCKING) or not reproduced (killed, with the check's output
in the log). One logged as open does not block convergence; the gate lists it under Needs
your call.

**A round is clean only if the previous round's fixes were verified by `damascus revert-proof` + `damascus proof-coverage` and were in the diff its critics reviewed.** Zero blocking findings against code nobody looked at is not a signal. This is the same principle as the overlap cap: the rating measures what the panel *examined*, not what it happened to return.

**Maximum 3 rounds**, then escalate to the user with the stuck findings. Quench's
mechanical gates already caught what tools can catch; three rounds of human-shaped
review that fail to converge usually mean an upstream problem — an under-specified
spec (back to `temper`) or an oversized task (back to `anvil`).

## Don't do this

- **Don't review the diff yourself in the main session.** You (or your subagents) wrote
  this code; fresh critics without the authoring context are the point.
- **Don't fix beyond the findings.** Refactor-while-you're-in-there at this stage is
  scope creep on green code; put it in the log as a NIT for a future feature.
- **Don't merge on A or A+.** A++ is the gate, same as temper. Tempted to ship at A+
  means the convergence rule caught something; stop and escalate.
- **Don't edit `code-review.md` retroactively.** Append-only, like `review.md`.

## Refusal Behavior

If the user asks to skip hone "just this once", remind them: green tests prove the code does what the tests say, not that it should be merged. Offer `smithy --skip hone`, which records the bypass in the orchestrator log so the team knows where the QA gap is. Don't silently bypass.

## Gate to Completion

Hone is **complete** when:
- [ ] `code-review.md` exists and its latest round is **A++** (every unit: two consecutive zero-blocking reviews)
- [ ] Every applied fix is committed, verified by `damascus revert-proof` + `damascus proof-coverage`, and the full suite is green
- [ ] If the host repo ships a board/state projection (e.g. a kanban sync script), run its sync once here. Skip silently if absent.

When complete, lead with **Needs your call** — findings rejected in the log, UNCONFIRMED
findings logged as open, NITs deferred as follow-ups, any amendment to a tempered
artifact, tasks logged as anvil feedback — or "nothing", then say:

> "Hone complete: A++ reached after N round(s). Pipeline complete. Use `superpowers:finishing-a-development-branch` for merge/PR (KEEP-listed)."

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

Hone's findings split cleanly under the Golden Rule: code that diverges from the spec is fixed *here*; a spec that diverges from what the code needed to be is fixed *upstream* (via a 1-round M0 Micro-Temper or routing back through smithy). Never patch the code into a shape the spec doesn't describe.

## Composition

- Reads the diff produced by `quench` (via `quench-log.md`'s per-task record)
- Critics/judge dispatch via `damascus agent-run` or the session's subagent mechanism; pairs with `superpowers:dispatching-parallel-agents` (KEEP)
- Applies findings with the posture of `superpowers:receiving-code-review` (KEEP)

## References

- Fowler, M. *Structured Prompt-Driven Development* — Golden Rule
- Cohen, J. *Best Kept Secrets of Peer Code Review* (SmartBear/Cisco study) — the ~400-line review-unit budget

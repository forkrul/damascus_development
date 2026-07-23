---
name: temper
description: Use after spec/plan/tasks exist and before any code. Temper iteratively heats and cools the spec triplet through a local adversarial review panel until it earns an A++ rating. No external APIs. Stage 3 of the SPDD pipeline (forge → anvil → temper → quench → hone, orchestrated by smithy).
effort: medium
---

# Temper — Stage 3: Adversarial Review Loop

## Overview

Tempers the `spec.md` / `plan.md` / `tasks.md` triplet produced by `anvil` through repeated **local adversarial review rounds** until it earns an **A++** rating. Each round: heat (a panel of critic subagents tries to refute the triplet) → adjudicate (a judge dedupes and rates) → cool (apply fixes, log the round). This is the pipeline's quality gate; nothing reaches `quench` (and therefore code) until temper signs off.

The loop is fully local — critics and judge are subagents of the current session. No external API, key, or network access is required.

**Announce at start:** "I'm using the temper skill to iterate the spec to A++ via adversarial review."

**Save review trail to:** `specs/NNN-<feature-slug>/review.md` (append-only, one entry per round)

## When to use

- `anvil` has produced `specs/NNN-<feature-slug>/{spec,plan,tasks}.md`
- The user invokes `/temper`, `/adversarial-review-loop` (alias), or asks to "review the spec until A++"
- Any time the triplet feels unfinished but you can't pinpoint what

## When NOT to use

- No spec triplet exists → run `anvil` first (refuse with that message)
- The triplet is for a tiny throwaway feature where A++ is overkill → user can `--skip temper` via smithy
- The user has already iterated externally and just wants to ship → confirm, then skip

## Entry Preconditions

Refuse if:

1. `specs/NNN-<slug>/spec.md` does not exist
2. `specs/NNN-<slug>/plan.md` does not exist
3. `specs/NNN-<slug>/tasks.md` does not exist
4. Any of the three is empty or contains only template scaffolding

## The Adversarial Round

Each round has three phases:

### 1. Heat — critic panel (parallel)

Dispatch **3 critic subagents in parallel**, each with a distinct lens, an **active procedure**, and an explicit mandate to **refute** the triplet, not affirm it:

| Critic | Lens | Active procedure (mandatory, artifact attached) | Hunts for |
|--------|------|------------------------------------------------|-----------|
| **Completeness** | ambiguity & gaps | Re-derive the Entities and Operations lists from the Requirements section *alone*; every mismatch with the written sections = finding | unstated requirements, undefined terms, FRs that aren't testable, SCs without a verification method, missing failure modes |
| **Feasibility** | architecture & ordering | Trace one full data flow (input → processing → storage → output) through the plan's phases; every step needing an unstated decision = finding | plan steps that can't work as written, hidden dependencies, phase-ordering errors, handwaved migrations or integrations |
| **Testability** | decomposition & verification | Draft a one-line test skeleton per FR from the spec text *alone*; every FR whose skeleton can't be written without asking the author = finding | tasks not independently verifiable, missing file paths, FRs unmapped to tasks, BDD scenarios that could never fail, scope creep |

Each critic receives the full triplet and returns findings classified as **BLOCKING** (a competent implementer would have to ask the author) or **NIT** (cosmetic). Critics must attempt refutation; "looks good" with no findings requires the critic to attach its procedure artifact and state what it tried and failed to break. Opinions without the artifact are discarded by the judge.

The procedures differ per critic **on purpose**: same-model critics correlate, so varying *what each one does* with the artifact buys more independence than varying the adjective in its prompt.

### 2. Adjudicate — judge (single)

Dispatch **1 judge subagent** with all critic findings. The judge:

- Dedupes overlapping findings
- Kills non-substantive nits and critic theater (manufactured objections)
- Discards any finding whose critic did not attach its procedure artifact
- Classifies survivors as BLOCKING or NIT
- Computes the **overlap signal** (capture-recapture logic): D = distinct findings after dedupe, m = findings raised independently by ≥2 critics. If D ≥ 4 and m/D < 25%, the critics are sampling a defect pool they haven't exhausted — near-disjoint finding sets mean more defects remain undiscovered. Cap the round's rating at **B+** regardless of blocking count
- Assigns the round's rating on the ladder below

### 3. Cool — apply and log

- Apply every surviving BLOCKING finding to `spec.md`/`plan.md`/`tasks.md` (or explicitly reject it in the log with reasoning)
- Append the round to `review.md`
- If not converged, run the next round

## Critic Prompt Template

```
You are an adversarial reviewer. Your job is to REFUTE this spec/plan/tasks
triplet, not to affirm it. Lens: <completeness|feasibility|testability>.

Execute your active procedure FIRST and attach its artifact:
<re-derived Entities+Operations | end-to-end data-flow trace | per-FR test skeletons>

A++ bar: a competent engineer could implement this without asking the author
a single question. Find every place that bar fails.

Return:
- Your procedure artifact
- Findings, each: [BLOCKING|NIT] <artifact>:<section> — <specific issue> — <what would fix it>
- If you found nothing: the artifact plus the 3 attack angles you tried and why each failed.

--- spec.md ---
<paste>
--- plan.md ---
<paste>
--- tasks.md ---
<paste>
```

## Review Log Format

```markdown
# Adversarial Review Log — <feature title>

## Round 1 — YYYY-MM-DD HH:MM
- Critics: completeness, feasibility, testability
- Blocking: 4  Nits: 7 (5 killed by judge)
- Overlap: 2/6 (33% — no cap)
- Rating: B+
- Findings applied:
  1. spec.md FR-007 conflated two concerns (split into FR-007a/FR-007b)
  2. plan.md "Approach" handwaved the auth migration
- Findings rejected:
  1. feasibility#3 — proposed YAGNI abstraction; rejected, out of scope

## Round 2 — …
- Blocking: 0  Nits: 2 (killed)
- Rating: A+  (clean pass 1 of 2)

## Round 3 — …
- Blocking: 0  Nits: 0
- Rating: A++  ← exit (clean pass 2 of 2)
```

## The Rating Ladder

| Rating | Meaning |
|--------|---------|
| **F**  | Spec is incoherent or contradicts itself |
| **D**  | Major gaps; reader cannot reconstruct intent |
| **C**  | Acceptable but vague; multiple ambiguous FRs |
| **B**  | Most FRs are testable; some gaps; tasks underspecified |
| **B+** | Solid; one or two structural issues |
| **A**  | Clear, mostly testable, all FRs mapped to tasks |
| **A+** | Tight; SCs measurable; assumptions explicit |
| **A++** | Reader implementing this would not need to ask the author a question |

## Convergence Rule and Cap

**A++ requires two consecutive rounds with zero BLOCKING findings.** A single clean round earns at most A+ — the second consecutive clean round confirms the first wasn't luck and upgrades to A++. This is loop-until-dry, not loop-until-lucky.

The overlap signal feeds this rule: a round capped at B+ for low overlap can never count as clean — when the critics' finding sets are near-disjoint, the pool of undiscovered defects is larger than the pool they surfaced, whatever the blocking count says.

**Maximum 5 rounds**, then escalate to the user with the stuck findings. If 5 rounds fail to converge, the bottleneck is usually upstream — return to `anvil` (or even `forge`) to fix the underlying ambiguity. **Don't grind temper indefinitely.**

## Don't do this

- **Don't review the triplet yourself in the main session.** The adversarial separation is the point: critics must be fresh subagents without your authoring context, or they inherit your blind spots.
- **Don't run fewer than 3 critics or merge the lenses.** Diverse lenses catch failure modes redundancy can't.
- **Don't accept findings without their procedure artifacts.** The re-derivation, the trace, the test skeletons — the artifact is what separates evidence from critic theater.
- **Don't accept critiques uncritically.** The judge kills manufactured objections; you may also reject a finding — but only explicitly, in the log, with reasoning. Silent partial application leaves the spec worse than before.
- **Don't edit the review log retroactively.** Append-only. Past rounds are evidence of how the spec evolved.
- **Don't proceed to quench on an A or A+.** A++ is the gate. If you're tempted to ship at A+, the convergence rule caught a real problem; stop and escalate.
- **Don't let critics rewrite the user's prose.** Findings are pointers; apply fixes preserving the author's voice.

## Refusal Behavior

If the user asks you to skip temper "just this once", remind them: A++ is the canonical gate. Offer `smithy --skip temper` instead, which records the bypass in the orchestrator log so the team knows where the QA gap is. Don't silently bypass.

## Gate to Next Stage

Temper is **complete** when:

- [ ] `review.md` exists in the spec directory
- [ ] Latest round's rating is **A++** (two consecutive zero-blocking rounds)
- [ ] All applied edits are committed (or at least staged)
- [ ] If the host repo ships a board/state projection (e.g. a kanban sync script), run its sync once here. Skip silently if absent.

When complete, say:

> "Temper complete: A++ reached after N round(s). Next stage: **quench** (BDD/TDD execution). Run it now? (y/N)"

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

Temper is the *most direct* enforcement of the Golden Rule in the pipeline. Every finding the panel surfaces is a divergence between the prompt (the spec) and reality (a competent reader's understanding). Fix the prompt — never proceed to code with the issue unresolved.

## Composition

- Reads the triplet produced by `anvil`
- Hands off to `quench` (the A++-tempered triplet becomes quench's input)
- Critics/judge dispatch via the session's subagent mechanism (e.g. the Agent/Task tool); pairs with `superpowers:dispatching-parallel-agents` (KEEP)

## References

- Fowler, M. *Structured Prompt-Driven Development* — Golden Rule

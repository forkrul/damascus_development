---
name: smithy
description: Use when running a feature end-to-end through the SPDD pipeline (forge → anvil → temper → quench) with state-machine resumption. The smithy houses all four stages and decides which one to run based on disk artifacts. Wrap a feature in one invocation; halt at every gate.
---

# Smithy — End-to-End SPDD Orchestrator

## Overview

The smithy houses the forge, anvil, temper, and quench. Smithy is the orchestrator: it inspects the artifacts on disk, figures out which stage you're in, runs the next one, and halts at every gate for user signoff. One command takes a raw idea to merged PR.

**Announce at start:** "I'm using the smithy skill to orchestrate the full SPDD pipeline."

**State lives in:** the disk artifacts themselves. Smithy is stateless — it reads `.prd/`, `specs/`, and `review.md` to determine the current stage.

## When to use

- The user says "let's build feature X" and wants the whole pipeline
- The user invokes `/smithy`, `/spdd-pipeline` (alias), or `smithy --resume` after a halt
- Any time you'd otherwise manually chain `forge → anvil → temper → quench`

## When NOT to use

- The user wants tight control over a single stage → invoke that stage directly (`forge`, `anvil`, etc.)
- A one-line bug fix or hotfix → just fix it, no orchestration
- The user is mid-cycle on an existing feature with their own workflow → don't hijack it

## State Machine

Smithy reads disk and decides which stage to invoke:

```
┌─────────────────────────────┬─────────────────┬─────────────────────┐
│ Disk state                  │ Current stage   │ Next action         │
├─────────────────────────────┼─────────────────┼─────────────────────┤
│ no .prd/NNN_*.md            │ —               │ run forge           │
│ PRD exists, not all sections│ forge incomplete│ continue forge      │
│ PRD complete, no specs/NNN/ │ forge done      │ run anvil           │
│ specs/NNN/ partial          │ anvil incomplete│ continue anvil      │
│ spec/plan/tasks all present │ anvil done      │ run temper          │
│ no review.md                │ temper not run  │ run temper          │
│ review.md, last < A++       │ temper iterating│ continue temper     │
│ review.md, A++              │ temper done     │ run quench          │
│ tasks.md has unchecked items│ quench in progress │ continue quench  │
│ all tasks checked, CI green │ quench done     │ hand off to finish  │
└─────────────────────────────┴─────────────────┴─────────────────────┘
```

## Gates (halt + ask user)

Smithy **always** halts at these moments:

1. **Stage exit** — after each of forge/anvil/temper/quench completes, halt and confirm before proceeding.
2. **A++ not reached after 5 adversarial rounds** — temper escalates to user; smithy does not auto-retry.
3. **Scope change mid-implementation** — if the user mid-quench says "actually let's also do X", halt; offer to return to forge for a fresh PRD or to amend the current one.
4. **Spec ambiguity surfaced during quench** — Golden Rule: halt, edit spec/tasks first, then resume.
5. **Drift detected** — if the host repo has a drift detector (e.g. a pre-commit hook warning that `src/**` changed without `specs/**` change) and it fires, halt and require justification.

Each halt prints the handoff message below (stage exited, artifact path, resume command).

## Escape Hatches

| Flag | Effect | Logs as |
|------|--------|---------|
| `--skip <stage>` | Skip a stage; record the bypass in `smithy-log.md` | "BYPASS: <stage> skipped at <timestamp> by user" |
| `--start-from <stage>` | Begin at this stage, assume earlier ones done (or N/A) | "OVERRIDE: started from <stage>" |
| `--resume` | Read disk state and continue from current stage | "RESUME: detected stage=<x>" |
| `--dry-run` | Print plan; make no changes | (no log entry) |

`smithy-log.md` lives at `specs/NNN-<slug>/smithy-log.md` and is append-only.

## Composition

Smithy invokes each stage Skill **directly**; it does not duplicate their bodies. The contract is:

- Smithy decides **when** to run a stage (state machine)
- Each stage Skill decides **how** to run itself (its own SKILL.md body)
- Smithy never overrides a stage's refusal behavior. If `temper` refuses (no spec triplet), smithy reports the refusal and halts.

## Don't do this

- **Don't run two stages without halting between them.** The halt is where the user catches mistakes; removing it removes the safety.
- **Don't auto-retry temper past 5 rounds.** Per `temper`'s contract, 5 rounds without A++ means the bottleneck is upstream. Smithy halts and asks the user; it does not loop indefinitely.
- **Don't make scope changes silently.** If quench reveals a missing FR, smithy halts and routes back through anvil (or forge if the change is structural). Don't append-and-hope.
- **Don't duplicate stage Skill bodies inside smithy.** Smithy is an orchestrator, not a copy. If a stage's behavior should change, edit *that stage's SKILL.md*, not smithy.
- **Don't lose track of which feature you're orchestrating.** Smithy works on one feature (one NNN sequence) at a time. Multi-feature orchestration is out of scope; use multiple smithy invocations.
- **Don't infer state from memory.** Always re-read disk on each stage transition; the user may have edited artifacts manually between halts.
- **Don't proceed past a stage's refusal.** If forge refuses (e.g. user gave only a one-word idea), halt and surface the refusal verbatim.
- **Don't invoke `superpowers:executing-plans`.** It is DENY-listed for the same reasons quench overrides it. Smithy uses quench, not executing-plans.

## Board projection (single call site)

Each stage that smithy drives runs **its own** board/state sync at its "Gate to Next Stage" — and only if the host repo ships one. **Smithy therefore adds NO sync call of its own** — doing so would double-sync every transition. Any post-merge sync belongs to the host repo's merge tooling.

## Handoff Messages

After every stage exit, smithy prints:

```
✓ Stage <name> complete.
  Artifact: <path>
  Next stage: <name> — run? (y/N)
  To resume later: smithy --resume
  To skip the next stage: smithy --skip <name>
```

After full pipeline completion:

```
✓ SPDD pipeline complete for feature NNN-<slug>.
  - PRD: .prd/NNN_<slug>.md
  - Spec: specs/NNN-<slug>/{spec,plan,tasks}.md
  - Reviews: specs/NNN-<slug>/review.md (A++ in N rounds)
  - Tests: <count>
  - Implementation commits: <count>
  Next: superpowers:finishing-a-development-branch
```

## Refusal Behavior

If the user invokes smithy without specifying a feature and there are multiple incomplete features on disk, **refuse** — list them, ask which to resume. Smithy works on one feature at a time.

If the user asks smithy to "just do everything without halting", **refuse** — the halts are the contract. Offer `--skip` per stage instead, which logs the bypass.

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

Smithy enforces the Golden Rule globally: **any code change without a corresponding artifact change halts the orchestrator** (via the drift gate). The pipeline cannot complete with code that doesn't trace back to a tempered spec.

## References

- The four stage Skills: `forge`, `anvil`, `temper`, `quench`
- Fowler, M. *Structured Prompt-Driven Development* — Golden Rule

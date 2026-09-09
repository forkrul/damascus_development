---
name: smithy
description: Use when running a feature end-to-end through the SPDD pipeline (forge → anvil → temper → quench → hone) with state-machine resumption. The smithy houses all five stages and decides which one to run based on disk artifacts. Wrap a feature in one invocation; halt at every gate.
effort: medium
---

# Smithy — End-to-End SPDD Orchestrator

## Overview

The smithy houses the forge, anvil, temper, quench, and hone. Smithy is the orchestrator: it inspects the artifacts on disk, figures out which stage you're in, runs the next one, and halts at every gate for user signoff. One command takes a raw idea to merged PR.

**Announce at start:** "I'm using the smithy skill to orchestrate the full SPDD pipeline."

**State lives in:** the disk artifacts themselves. Smithy is stateless — it reads `.prd/`, `specs/NNN-<slug>/` (`review.md`, `tasks.md`, `quench-log.md`, `code-review.md`, `smithy-log.md`) to determine the current stage. Every row of the state machine is decidable from those files alone; nothing depends on CI status or a memory of what happened last session.

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
│ all tasks checked, every    │ quench done     │ run hone            │
│  task has a quench-log green│                 │                     │
│ code-review.md, last < A++  │ hone iterating  │ continue hone       │
│ code-review.md ends A++,    │ hone done       │ run finish step     │
│  no FINISH in smithy-log.md │                 │                     │
│ smithy-log.md has FINISH    │ finish done     │ hand off to merge   │
└─────────────────────────────┴─────────────────┴─────────────────────┘
```

"Quench done" means `tasks.md` has no unchecked task **and** `quench-log.md` has a green entry (with gate results) for every task — that log is quench's own record that CI/gates passed, so smithy never needs to query CI. "Finish done" means `smithy-log.md` carries a `FINISH:` line (see the finish step), which is the only artifact the finish step is guaranteed to leave behind — README/CHANGELOG edits are not detectable on their own.

## Gates (halt + ask user)

Smithy **always** halts at these moments:

1. **Stage exit** — after each of forge/anvil/temper/quench/hone completes, halt and confirm before proceeding.
2. **A++ not reached within the round cap** — temper escalates after 5 adversarial rounds, hone after 3; smithy does not auto-retry either.
3. **Scope change mid-implementation** — if the user mid-quench says "actually let's also do X", halt; offer to return to forge for a fresh PRD or to amend the current one.
4. **Spec ambiguity surfaced during quench** — Golden Rule: halt, edit spec/tasks first, then resume.
5. **Drift detected** — if the host repo has a drift detector (e.g. a pre-commit hook warning that `src/**` changed without `specs/**` change) and it fires, halt and require justification.

Each halt prints:
- The stage just exited
- The artifact path created/updated
- The exact command to resume (`smithy --resume` or `smithy --start-from <stage>`)

## Escape Hatches

| Flag | Effect | Logs as |
|------|--------|---------|
| `--skip <stage>` | Skip a stage; record the bypass in `smithy-log.md` | "BYPASS: <stage> skipped at <timestamp> by user" |
| `--start-from <stage>` | Begin at this stage, assume earlier ones done (or N/A) | "OVERRIDE: started from <stage>" |
| `--resume` | Read disk state and continue from current stage | "RESUME: detected stage=<x>" |
| `--dry-run` | Print plan; make no changes | (no log entry) |
| (finish step) | Docs updated, Atlas run or skipped | "FINISH: docs updated · atlas <survey path \| skipped (atlas skill not available)>" |

`smithy-log.md` lives at `specs/NNN-<slug>/smithy-log.md` and is append-only.

## Composition

Smithy invokes each stage Skill **directly**; it does not duplicate their bodies. The contract is:

- Smithy decides **when** to run a stage (state machine)
- Each stage Skill decides **how** to run itself (its own SKILL.md body)
- Smithy never overrides a stage's refusal behavior. If `temper` refuses (no spec triplet), smithy reports the refusal and halts.

## Don't do this

- **Don't run two stages without halting between them.** The halt is where the user catches mistakes; removing it removes the safety.
- **Don't auto-retry temper past 5 rounds or hone past 3.** Per their contracts, hitting the cap without A++ means the bottleneck is upstream. Smithy halts and asks the user; it does not loop indefinitely.
- **Don't make scope changes silently.** If quench reveals a missing FR, smithy halts and routes back through anvil (or forge if the change is structural). Don't append-and-hope.
- **Don't duplicate stage Skill bodies inside smithy.** Smithy is an orchestrator, not a copy. If a stage's behavior should change, edit *that stage's SKILL.md*, not smithy.
- **Don't lose track of which feature you're orchestrating.** Smithy works on one feature (one NNN sequence) at a time. Multi-feature orchestration is out of scope; use multiple smithy invocations.
- **Don't infer state from memory.** Always re-read disk on each stage transition; the user may have edited artifacts manually between halts.
- **Don't proceed past a stage's refusal.** If forge refuses (e.g. user gave only a one-word idea), halt and surface the refusal verbatim.
- **Don't invoke `superpowers:executing-plans`.** It is DENY-listed for the same reasons quench overrides it. Smithy uses quench, not executing-plans.

## Board projection (single call site)

Each stage that smithy drives runs **its own** board/state sync at its "Gate to Next Stage" — and only if the host repo ships one. **Smithy therefore adds NO sync call of its own** — doing so would double-sync every transition. Any post-merge sync belongs to the host repo's merge tooling.

## Finish Step (post-hone, absolute end of the cycle)

After `hone` reaches A++ and its gate is signed off, the feature is complete. Before
handing off to `superpowers:finishing-a-development-branch`, smithy runs one final step:

1. **Update `README.md` and `CHANGELOG.md`** for the completed feature (NNN). CHANGELOG
   gets a single-line entry under `[Unreleased]` in the host repo's changelog convention;
   README gets whatever the feature changed in user-facing behavior (skip README if the
   feature is purely internal). This is the cycle's documentation gate.
2. **Run Atlas, if available.** Every completed pipeline run is a major feature, so once
   the docs are updated, smithy checks whether the **`atlas` skill is available in this
   environment**. If it is, invoke it **scoped to the just-completed feature (NNN)** —
   Atlas surveys that feature's artifacts (its PRD, spec triplet, review trails) and
   verifies them against the shipped code, producing an intent-vs-reality map for the
   handover. If `atlas` is **not** available, **skip silently** — exactly like the kanban
   sync. Atlas is not vendored by Damascus; this step is a no-op wherever the consumer
   has not installed it.

3. **Log it.** Append `FINISH: docs updated · atlas <survey path | skipped (atlas skill not available)>`
   to `smithy-log.md`. This line is how a later `smithy --resume` knows the finish step ran.

This step runs **after** the hone gate signoff and is the last thing smithy does before
the merge handoff. It adds no board sync of its own (see the single-call-site rule above).

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
  - Spec reviews: specs/NNN-<slug>/review.md (A++ in N rounds)
  - Cycle log: specs/NNN-<slug>/quench-log.md (all tasks red→amber→green, gates passed)
  - Code reviews: specs/NNN-<slug>/code-review.md (A++ in N rounds)
  - Tests: <count>
  - Implementation commits: <count>
  - Docs: README.md + CHANGELOG.md updated for NNN
  - Atlas: <survey path> | skipped (atlas skill not available)
  Next: superpowers:finishing-a-development-branch
```

## Refusal Behavior

If the user invokes smithy without specifying a feature and there are multiple incomplete features on disk, **refuse** — list them, ask which to resume. Smithy works on one feature at a time.

If the user asks smithy to "just do everything without halting", **refuse** — the halts are the contract. Offer `--skip` per stage instead, which logs the bypass.

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

Smithy enforces the Golden Rule globally: **any code change without a corresponding artifact change halts the orchestrator** (via the drift gate). The pipeline cannot complete with code that doesn't trace back to a tempered spec.

## References

- The five stage Skills: `forge`, `anvil`, `temper`, `quench`, `hone`
- Fowler, M. *Structured Prompt-Driven Development* — Golden Rule

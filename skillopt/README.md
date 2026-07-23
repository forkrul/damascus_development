# SkillOpt harness

An optimization loop for the stage skills, after
[microsoft/SkillOpt](https://github.com/microsoft/SkillOpt): the SKILL.md
files are the trainable parameters, rollouts of the pipeline on benchmark
tasks produce scores, and skill edits are only accepted through a
validation gate.

## Layout

```
skillopt/
  tasks/*.task.md     benchmark feature requests (train / val split)
  rollout.sh          run one task through the pipeline in a throwaway repo
  score.sh            deterministic scorer over the artifacts a run leaves on disk
  run.sh              epoch driver: rollout + score every task, aggregate
  fixtures/           known-good / known-bad workspaces for the scorer self-test
  rejected-edits.md   buffer of edits that failed the validation gate
  out/                rollout workspaces + results (gitignored)
```

## Requirements

Rollouts drive the `claude` CLI headlessly — it must be installed and
authenticated, and each rollout spends real tokens (a full pipeline run is
several stages of multi-agent work). Scoring is pure bash and free.
Vendor submodules must be initialized (`git submodule update --init --recursive`).

## Running

```bash
skillopt/score.sh --self-test        # verify the scorer (no network, runs in CI)
skillopt/run.sh --split train        # rollout + score the training tasks
skillopt/run.sh --split val          # rollout + score the held-out tasks
skillopt/run.sh --score-only         # re-score existing workspaces in out/
skillopt/rollout.sh skillopt/tasks/001-token-bucket-rate-limiter.task.md /tmp/ws  # one task
```

The rollout driver respects smithy's halting contract: it sends the initial
feature request, then answers each stage gate with a confirmation turn
(`claude --continue -p "y…"`), up to `SKILLOPT_MAX_GATES` (default 8) turns
or until the workspace scores full marks. Transcripts land in
`<workspace>/.skillopt/turn-N.log`.

## Scoring rubric

Each check encodes a stage-gate contract from a SKILL.md, evaluated
mechanically against the artifacts on disk — 1 point each:

| Check | Contract source |
|-------|-----------------|
| PRD file exists under `.prd/` | forge output contract |
| PRD has all 7 REASONS sections | forge gate |
| No unconfirmed `[ASSUMED` markers | forge gate |
| `spec.md`/`plan.md`/`tasks.md` all present, non-empty | anvil output contract |
| spec.md defines `FR-NNN` requirements | anvil adaptation rules |
| spec.md defines `SC-NNN` success criteria | anvil adaptation rules |
| plan.md has all 7 REASONS sections | anvil gate |
| tasks.md uses `TNNN` IDs | anvil adaptation rules |
| Every FR in spec.md is mapped in tasks.md | anvil gate |
| `review.md` exists with ≥1 round | temper output contract |
| Final rating is A++ | temper gate |
| A++ earned over ≥2 rounds | temper convergence rule |
| A Gherkin `.feature` file exists | quench BDD-first ordering |
| All tasks checked off | quench completion gate |
| `code-review.md` exists with ≥1 round | hone output contract |
| Final code-review rating is A++ | hone gate |
| Code-review A++ earned over ≥2 rounds | hone convergence rule |

## The optimization loop

One epoch:

1. **Rollout** — `run.sh --split train`; record the per-task scores.
2. **Reflect** — read the failing checks and the turn logs; identify the
   highest-frequency failure patterns across tasks (not one-off noise).
3. **Edit** — propose bounded edits to `skills/*/SKILL.md` under a textual
   learning-rate budget: at most 4 edits per skill per epoch, preferring
   delete/replace over add, never hardcoding task-specific names or values,
   never weakening a behavioral contract to make a check pass.
4. **Validate** — `run.sh --split val` before and after the edit. Accept only
   if the val mean **strictly improves**; otherwise revert and record the
   edit in `rejected-edits.md` so it is not re-proposed without new evidence.
5. Repeat, or stop when an epoch produces no accepted edits.

Train tasks may inform edits; val tasks may only ever gate them. If val
tasks start informing edits, rotate in fresh ones.

To use the upstream framework instead of this manual loop, point a
microsoft/SkillOpt config at a stage SKILL.md as the skill document and wire
`rollout.sh` + `score.sh` in as a custom benchmark backend.

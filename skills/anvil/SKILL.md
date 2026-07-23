---
name: anvil
description: Use after a PRD exists and before any code. Hammers a PRD into a structured spec/plan/tasks triplet, using GitHub spec-kit slash commands when available, or the vendored spec-kit templates as fallback. Stage 2 of the SPDD pipeline (forge → anvil → temper → quench, orchestrated by smithy).
effort: medium
---

# Anvil — Stage 2: Speckit Decomposition

## Overview

Hammers the PRD produced by `forge` into a structured `spec.md` + `plan.md` + `tasks.md` triplet under `specs/NNN-<slug>/`. This is the second stage of the SPDD pipeline; nothing downstream starts until the triplet exists and is internally consistent.

**Announce at start:** "I'm using the anvil skill to decompose the PRD into spec/plan/tasks."

**Save artifacts to:** `specs/NNN-<feature-slug>/{spec,plan,tasks}.md`

## When to use

- A PRD exists at `.prd/NNN_<feature-slug>.md` with all 7 REASONS sections populated
- The user invokes `/anvil`, `/speckit-decomposition` (alias), or asks to "turn this PRD into a plan"
- Any time `forge` exits and the user wants to keep going

## When NOT to use

- No PRD exists → run `forge` first (refuse with that exact message)
- PRD has empty REASONS sections → return to `forge` (refuse)
- The user already has spec/plan/tasks → skip to `temper`

## Upstream Superpowers Policy (DENY redirect)

The upstream `superpowers:writing-plans` skill is **DENY** under this pipeline.

**If you would have invoked `superpowers:writing-plans`, invoke `anvil` instead.** Anvil produces a 3-file artifact set (spec/plan/tasks) instead of a single plan, mirrors GitHub spec-kit's structure, and gates the temper stage.

## Entry Preconditions

Anvil **MUST refuse to start** if any of the following fail:

1. `.prd/NNN_<feature-slug>.md` exists
2. The PRD contains all 7 REASONS sections (Requirements, Entities, Approach, Structure, Operations, Norms, Safeguards)
3. No section is empty
4. No `[ASSUMED]` markers remain unconfirmed

If any check fails: print the failure, point at `forge`, and stop.

## Output Contract

A directory `specs/NNN-<feature-slug>/` containing:

- `spec.md` — user stories, functional requirements (`FR-NNN`), success criteria (`SC-NNN`), assumptions, dependencies
- `plan.md` — REASONS-Canvas-structured: one section per REASONS letter, plus a "Phases" section that lists ordered phases of work
- `tasks.md` — task list with format `[ID] [P?] [Story] Description` (P = parallel-safe, Story = which user story it belongs to). Each task has: file paths to touch, FR(s) it satisfies, gate criteria.

NNN is the next available sequence number under `specs/`.

## Invocation Order

The three artifacts MUST be produced in this order:

1. `spec.md` — translates PRD into formal user stories + FRs + SCs
2. `plan.md` — translates `spec.md` into REASONS Canvas + ordered phases
3. `tasks.md` — translates `plan.md` phases into discrete tasks

Reverse order leaks information; later artifacts derive from earlier ones.

## Slash-Command Path (preferred)

If GitHub spec-kit slash commands are available in this Claude Code session, use them:

```
/speckit.specify  — generates spec.md from the PRD
/speckit.plan     — generates plan.md from spec.md
/speckit.tasks    — generates tasks.md from plan.md
```

**To check availability:** look for `.claude/commands/speckit.*` files in the host repo or check the active plugins. If `/speckit.specify` does not autocomplete, use the fallback below.

## Fallback Path (vendored spec-kit templates)

When the slash commands are not registered, generate the artifacts from the **vendored spec-kit templates** that ship with this repo:

```
vendor/spec-kit/templates/spec-template.md   → basis for spec.md
vendor/spec-kit/templates/plan-template.md   → basis for plan.md
vendor/spec-kit/templates/tasks-template.md  → basis for tasks.md
```

The templates live in the damascus checkout. If the skill is installed as a symlink, resolve the real path first:

```bash
DAMASCUS="$(dirname "$(readlink -f .claude/skills/anvil)")/../.."
ls "$DAMASCUS/vendor/spec-kit/templates/"
```

If `vendor/spec-kit/` is empty, the submodule is not initialized — run `git submodule update --init --recursive` inside the damascus checkout.

**Adaptation rules when filling the templates:**

- `spec.md`: keep user stories, `FR-NNN` functional requirements, `SC-NNN` success criteria. Every FR must trace to a user story; every SC must name how it is verified.
- `plan.md`: replace the template's technical-context body with the 7-section REASONS Canvas (Requirements, Entities, Approach, Structure, Operations, Norms, Safeguards) followed by ordered Phases.
- `tasks.md`: keep spec-kit's `T001`-style IDs and `[P]` parallel markers; add `[Story]` linkage and a `Satisfies: FR-NNN` + `Gate:` line per task.

## Refusal Behavior

If the user pushes you to skip the PRD ("just make me a spec"), explain: forging is a 5-minute step that prevents 50 minutes of rework. Then offer: forge → anvil in one go.

## Don't do this

- **Don't write code or pseudocode in any of the three artifacts.** Tasks reference file paths and describe steps; they do not contain implementation. Code belongs to `quench`.
- **Don't skip the FR ↔ task mapping check.** Every FR must map to ≥1 task; every task must declare which FR(s) it satisfies. An unmapped FR will be invisible during temper.
- **Don't invent your own task ID scheme.** Use `T001, T002, …`; downstream stages (temper, smithy) parse this format.
- **Don't proceed to temper without committing the artifacts.** Uncommitted artifacts mean temper might iterate on stale state.

## Gate to Next Stage

Anvil is **complete** when:

- [ ] `spec.md`, `plan.md`, `tasks.md` all exist under `specs/NNN-<slug>/`
- [ ] Each FR in spec.md maps to at least one task in tasks.md
- [ ] Each task in tasks.md has explicit file paths and satisfies-FR linkage
- [ ] plan.md REASONS Canvas is complete (all 7 sections non-empty)
- [ ] All artifacts are committed (or at least staged)
- [ ] If the host repo ships a board/state projection (e.g. a kanban sync script), run its sync once here. Skip silently if absent.

When complete, say:

> "Spec/plan/tasks complete under `specs/NNN-<slug>/`. Next stage: **temper** (adversarial review until A++ rating). Run it now? (y/N)"

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

Spec/plan/tasks are downstream of the PRD. If anvil reveals that the PRD is incomplete (a question only emerges when you try to write FRs), **stop and edit the PRD first**, then resume anvil. Do not paper over PRD gaps with assumptions in spec.md.

## Composition

- Reads the PRD produced by `forge` (entry contract)
- Hands off to `temper` (the spec/plan/tasks become temper's input)
- References upstream `superpowers:writing-plans` for *style* (bite-sized tasks, exact file paths) but NEVER invokes it (DENY)

## References

- GitHub spec-kit: https://github.com/github/spec-kit (vendored at `vendor/spec-kit`, templates under `templates/`)

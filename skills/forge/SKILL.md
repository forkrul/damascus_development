---
name: forge
description: Use when starting any non-trivial feature, before any code or spec. Forges a raw idea into a structured PRD using Fowler's REASONS Canvas. Stage 1 of the SPDD pipeline (forge → anvil → temper → quench, orchestrated by smithy).
effort: high
---

# Forge — Stage 1: PRD Authoring

## Overview

Forges a raw user idea into a structured Product Requirements Document (PRD) populated against Fowler's REASONS Canvas. This is the **entry stage** of the SPDD pipeline. Nothing downstream (spec, plan, tasks, code) starts until a complete PRD exists.

**Announce at start:** "I'm using the forge skill to author the PRD."

**Save PRDs to:** `.prd/NNN_<feature-slug>.md` (NNN = zero-padded sequence: 001, 002, …)

## When to use

- Starting any new feature, refactor, or system change with non-obvious scope
- Receiving an idea phrased as "wouldn't it be cool if…" or "we need X"
- The user invokes `/forge`, `/prd-authoring` (alias), or asks to "write a PRD"

## When NOT to use

- Bug fixes with clear repro and a single-file change → just fix it
- Hotfixes during incidents → ship first, write the postmortem after
- Trivial refactors (renames, moves, formatting) → just do it
- The user already has a PRD or spec in hand → skip to `anvil`

## Upstream Superpowers Policy (DENY redirect)

The upstream `superpowers:brainstorming` skill is **DENY** under this pipeline.

**If you would have invoked `superpowers:brainstorming`, invoke `forge` instead.** Forge covers structured ideation and produces a durable artifact (the PRD). Brainstorming's loose Q&A is folded into the REASONS Canvas elicitation below.

## Entry Preconditions

None. This is the entry stage. The user gives you a raw idea; that's enough.

## Output Contract

A markdown file at `.prd/NNN_<feature-slug>.md` containing **all 7 REASONS sections populated**:

1. **R**equirements — what the user needs (functional + non-functional)
2. **E**ntities — the data shapes/objects involved
3. **A**pproach — the high-level solution direction
4. **S**tructure — how the solution decomposes (modules, layers, services)
5. **O**perations — what actions/methods/endpoints exist
6. **N**orms — quality bars, conventions, principles to follow
7. **S**afeguards — what must NOT happen; failure modes; security/privacy guards

Empty section = forge has not exited. The next stage (`anvil`) refuses to start on an incomplete PRD.

## REASONS Canvas Template

Copy this into the new PRD file and elicit answers from the user section by section. If the user answers "you decide" for any section, propose your best guess and explicitly mark it `[ASSUMED — confirm before anvil]`.

```markdown
# PRD NNN: <feature title>

**Status:** Draft (forge)
**Sequence:** NNN
**Author:** <user>
**Created:** YYYY-MM-DD

## Requirements

### Functional
- FR-1:
- FR-2:

### Non-Functional
- NFR-1 (performance):
- NFR-2 (security):
- NFR-3 (usability):

## Entities

| Name | Description | Key fields |
|------|-------------|------------|
|      |             |            |

## Approach

<2-4 sentences on the high-level solution direction>

## Structure

```
<module/file/service tree showing the proposed decomposition>
```

## Operations

| Operation | Input | Output | Notes |
|-----------|-------|--------|-------|
|           |       |        |       |

## Norms

- Coding conventions:
- Quality bar:
- Referenced principles (DRY, YAGNI, TDD, etc.):

## Safeguards

- Must-not:
- Failure modes considered:
- Security/privacy:

---

## Open Questions

- [ ]

## Assumptions (mark each as confirmed before anvil)

- [ASSUMED]
```

## Elicitation Strategy

1. Read the user's raw idea once. Do not paraphrase yet.
2. Create the PRD file with the template above + the user's idea quoted at the top.
3. Walk the 7 sections **in order**. For each section, ask 1–3 targeted questions in menu format (a/b/c/other).
4. Capture answers directly into the file as you go. Re-read after each section to confirm.
5. End with a recap: "Here are 3 assumptions I made — please confirm or correct."

## Don't do this

- **Don't paraphrase the user's idea before writing it down.** Quote their exact words at the top of the PRD. Paraphrasing leaks your priors into the artifact.
- **Don't skip sections you find boring.** Norms and Safeguards are exactly where bugs hide. If a section feels empty, that's a signal to ask another question, not skip it.
- **Don't fill in `[ASSUMED]` markers and then forget about them.** Every assumption must be confirmed before the next stage. Track them in the "Assumptions" block.
- **Don't write FRs, SCs, or tasks here.** Those belong to `anvil`. Forge produces a PRD, full stop. If you find yourself writing FR-001, you have crossed a stage boundary.
- **Don't merge multiple ideas into one PRD.** One feature = one PRD. If the user mixes "and also we should…", create a second PRD.
- **Don't proceed to anvil without explicit user confirmation.** Forge halts; the user starts anvil.

## Gate to Next Stage

Forge is **complete** when ALL of the following hold:

- [ ] All 7 REASONS sections have non-empty content
- [ ] No `[ASSUMED]` markers remain (or the user has explicitly green-lit each)
- [ ] PRD file is committed (or at least staged) — you are not editing in a void
- [ ] If the host repo ships a board/state projection (e.g. a kanban sync script), run its sync once here. Skip silently if absent.

When complete, say:

> "PRD complete and saved to `.prd/NNN_<feature-slug>.md`. Next stage: **anvil** (decompose this PRD into spec/plan/tasks). Run it now? (y/N)"

## Golden Rule (Fowler)

> When reality diverges from the prompt, fix the prompt before the code.

If the user mid-forge says "actually let's also do X", update the PRD — do not just remember it. The PRD is the artifact; everything else is a derivation of it.

## References

- Fowler, M. *Structured Prompt-Driven Development*, https://martinfowler.com/articles/structured-prompt-driven/ — REASONS Canvas + Golden Rule

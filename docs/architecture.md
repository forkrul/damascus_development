# Architecture

The pipeline's contracts, drawn. Each diagram is a picture of rules that live in a
`SKILL.md` body or in `install.sh` — those files are the source of truth, and each
section links the one it draws. Every diagram is a ` ```mermaid ` block, so this page
renders the same on GitHub and in the Sphinx build.

## The pipeline and its artifacts

Five stages, each halting at a gate for your signoff. Every stage reads the artifact the
previous one wrote and refuses to start without it; state lives on disk, never in a
session's memory.

```mermaid
flowchart TD
    idea([raw idea]) --> forge["<b>forge</b><br/>.prd/NNN_slug.md · REASONS Canvas PRD"]
    forge -- gate --> anvil["<b>anvil</b><br/>spec.md · plan.md · tasks.md"]
    anvil -- gate --> temper["<b>temper</b><br/>review.md, rated A++"]
    temper -- gate --> quench["<b>quench</b><br/>tests + code · quench-log.md"]
    quench -- gate --> hone["<b>hone</b><br/>code-review.md, rated A++"]
    hone -- gate --> finish["<b>finish step</b><br/>README · CHANGELOG · Atlas if installed"]
    finish --> merge([merge handoff])
    smithy{{"<b>smithy</b><br/>reads disk, runs the next stage,<br/>halts at every gate"}} -.- forge & anvil & temper & quench & hone
```

Source: [`skills/smithy/SKILL.md`](https://github.com/forkrul/damascus_development/blob/master/skills/smithy/SKILL.md)

## Smithy's state machine

Smithy is stateless: every state below is decided from the files under `.prd/` and
`specs/NNN-slug/` alone, so `smithy --resume` works after any halt, in any session.

```mermaid
stateDiagram-v2
    [*] --> Forge: no PRD
    Forge --> Forge: PRD has empty sections
    Forge --> Anvil: all 7 REASONS sections filled
    Anvil --> Anvil: triplet partial
    Anvil --> Temper: spec, plan, tasks present
    Temper --> Temper: last round below A++
    Temper --> Quench: review.md ends A++
    Quench --> Quench: unchecked task in tasks.md
    Quench --> Hone: every task checked and green in quench-log.md
    Hone --> Hone: last round below A++
    Hone --> Finish: code-review.md ends A++
    Finish --> [*]: FINISH line in smithy-log.md
```

Between two states smithy always halts, and the handoff leads with **Needs your call** —
waivers, freeze exceptions, rejected or open findings, unconfirmed assumptions, bypasses —
before **Changed** and **Found**. Inside a stage it does not stop: a finished quench task
or review round is not a gate.

Source: [`skills/smithy/SKILL.md`](https://github.com/forkrul/damascus_development/blob/master/skills/smithy/SKILL.md)

## The adversarial review round (temper and hone)

Temper reviews the spec triplet; hone reviews the implementation diff in units of at
most ~400 changed lines. Both run the same round, entirely local.

```mermaid
sequenceDiagram
    autonumber
    participant M as Main session
    participant C as 3 critics (parallel)
    participant J as Judge
    M->>C: artifact + lens + active procedure
    Note over C: each critic must REFUTE, not affirm
    C-->>J: BLOCKING / NIT / UNCONFIRMED findings,<br/>each with its procedure artifact
    Note over J: dedupe, kill critic theater,<br/>discard findings without artifacts
    J->>J: settle each UNCONFIRMED:<br/>confirm, kill, carry forward, or log as open
    J->>J: overlap signal: D ≥ 4 and m/D under 25% caps the round at B+
    J-->>M: rating for the round
    M->>M: cool: apply BLOCKING fixes (or reject them in the log), append the round
    alt not converged and under the round cap
        M->>C: next round straight away, including this round's fixes
    else two consecutive clean rounds
        M-->>M: A++, then halt at the gate
    end
```

A round is **clean** only with zero BLOCKING findings, no UNCONFIRMED carried forward, no
overlap cap — and, in hone, only if the previous round's fixes were in the diff its critics
saw. Temper's blocking findings quote the question an implementer would have to ask; hone's
carry a repro (a failing test, an input or a command), and every hone fix is shown to fail
without itself. Temper caps at 5 rounds, hone at 3; hitting the cap escalates to you.

Sources: [`skills/temper/SKILL.md`](https://github.com/forkrul/damascus_development/blob/master/skills/temper/SKILL.md) ·
[`skills/hone/SKILL.md`](https://github.com/forkrul/damascus_development/blob/master/skills/hone/SKILL.md)

## Red-amber-green, per task

Standard TDD goes red → green. Quench inserts **amber**: the test must fail for the
right reason before any implementation exists — and from amber on, the test is frozen.

```mermaid
stateDiagram-v2
    [*] --> Red: test agent writes the test
    Red --> Red: fails for the wrong reason (import, fixture)
    Red --> Amber: fails on the assertion that matters
    Amber --> Green: implementer writes minimal code
    Green --> Red: stable-green run flickers
    Green --> Gated: passes 3x in random order
    Gated --> Red: static finding on a changed line
    Gated --> [*]: gates pass or are waived in the log, task checked off
    note right of Amber
        test frozen: it changes only after
        spec.md or tasks.md changes first
    end note
    note right of Gated
        a surviving mutant means a weak test:
        strengthen it via spec, tasks, test
        or waive it in quench-log.md
    end note
```

Quench re-runs every amber and green an agent reports before it counts; the agent's
report is a claim, not evidence. Test agents never write implementation, and the
implementer never edits tests. When every task is done, the FR ↔ test traceability sweep
must report no untested FR.

Source: [`skills/quench/SKILL.md`](https://github.com/forkrul/damascus_development/blob/master/skills/quench/SKILL.md)

## Parallel `[P]` tasks

Inside a task the cycle is sequential. Across tasks, the `[P]` tasks of one phase may
run side by side — and still land one at a time.

```mermaid
flowchart TD
    phase["phase with [P] tasks,<br/>prerequisites green"] --> wt1["worktree: T002<br/>red → amber → green → gates"]
    phase --> wt2["worktree: T003<br/>red → amber → green → gates"]
    wt1 --> verify["quench re-runs amber and<br/>stable-green in each worktree"]
    wt2 --> verify
    verify --> merge["merge ONE task onto the feature branch"]
    merge --> suite{"full suite 3x<br/>+ static gates"}
    suite -- green --> log["tick tasks.md, append quench-log.md<br/>on the feature branch"]
    log --> more{more finished tasks?}
    more -- yes --> merge
    more -- no --> next([next phase])
    suite -- "red, or merge conflict" --> wrong["the [P] tag was wrong:<br/>log anvil feedback,<br/>redo the task sequentially"]
```

Source: [`skills/quench/SKILL.md`](https://github.com/forkrul/damascus_development/blob/master/skills/quench/SKILL.md)

## How `install.sh` places a link

The installer only ever touches symlinks that resolve into the damascus checkout, writes
only relative links, and exits non-zero if any link could not be placed.

```mermaid
flowchart TD
    pre["preflight: run from the consumer repo root,<br/>a git repo, vendor submodules initialised"] --> start
    start([next skill, alias, agent or KEEP skill]) --> tgt{target exists<br/>in damascus?}
    tgt -- no --> miss["ERR: target missing<br/>count a problem"]
    tgt -- yes --> exists{something already<br/>at the link path?}
    exists -- no --> ln["ln -s with a relative path"]
    exists -- yes --> owned{a symlink resolving<br/>into damascus?}
    owned -- yes --> replace["remove it, then ln -s relative"]
    owned -- no --> skip["ERR: not damascus-owned<br/>left untouched, count a problem"]
    ln --> more{more to link?}
    replace --> more
    miss --> more
    skip --> more
    more -- yes --> start
    more -- no --> prune
    prune["prune damascus-owned links<br/>whose names are no longer shipped"] --> done{problems > 0?}
    done -- yes --> fail([exit 1])
    done -- no --> okay([exit 0])
```

`--verify` walks the same list and reports missing, foreign, broken, mis-targeted and stale
links; `--uninstall` removes every damascus-owned link and nothing else; `--dry-run` prints
the plan and touches nothing.

Source: [`install.sh`](https://github.com/forkrul/damascus_development/blob/master/install.sh)

## Superpowers policy

Six upstream [obra/superpowers](https://github.com/obra/superpowers) skills are never
linked, because a stage replaces them or they route into one that does.

```mermaid
flowchart LR
    subgraph DENY["DENY: not linked"]
        b[brainstorming]
        wp[writing-plans]
        ep[executing-plans]
        rcr[requesting-code-review]
        us[using-superpowers]
        sdd[subagent-driven-development]
    end
    b --> forge
    wp --> anvil
    ep --> quench
    sdd --> quench
    rcr --> hone
    us --> smithy
    tdd["test-driven-development<br/>(CONDITIONAL)"] -. "linked, red-green<br/>overridden by red-amber-green" .-> quench
```

The seven KEEP skills (`systematic-debugging`, `dispatching-parallel-agents`,
`verification-before-completion`, `receiving-code-review`, `finishing-a-development-branch`,
`using-git-worktrees`, `writing-skills`) are linked as-is. CI fails when an upstream skill is
neither KEEP in `install.sh` nor a DENY row in the README.

Source: [`README.md`](https://github.com/forkrul/damascus_development/blob/master/README.md#superpowers-policy-deny--keep--conditional)

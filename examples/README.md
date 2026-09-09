# Examples

One feature's complete artifact trail through the SPDD pipeline, exactly as it sits on disk in a consumer repo after `smithy` has driven it from raw idea to merge handoff. Nothing here is a template: every number, timestamp, finding and gate result is the output of one run of `forge → anvil → temper → quench → hone` on a small FastAPI shop.

The feature is **cart discount codes**: percentage and fixed-amount codes, expiry, single-use per customer, and one Safeguard — "a discount must never increase the price or take it below zero" — that becomes a Hypothesis property test in quench. Deliberately small: 3 user stories, 5 FRs, 3 SCs, 6 tasks (one `[P]`, one `[HARD]`, no `[UX]`).

The trail contains **only the pipeline's artifacts**. There is no implementation code, no test code and no migration here; the logs describe them (diff sizes, test counts, failure messages) the way a real run would.

## Layout

```
cart-discounts/
  .prd/001_cart-discount-codes.md              forge   — REASONS Canvas PRD, all assumptions confirmed
  specs/001-cart-discount-codes/
    spec.md                                    anvil   — user stories, FR-001…FR-005, SC-001…SC-003
    plan.md                                    anvil   — REASONS Canvas + ordered phases
    tasks.md                                   anvil   — T001…T006, all checked off at pipeline end
    review.md                                  temper  — 3 rounds: B+ (overlap-capped) → A+ → A++
    quench-log.md                              quench  — red/amber/green per task, gates, one waiver, one sample-and-select
    code-review.md                             hone    — 3 rounds: C → A+ → A++, one blocking finding fixed and shown to fail without its fix
    smithy-log.md                              smithy  — START/GATE/RESUME/HALT entries and the FINISH line
```

The layout mirrors a consumer repo's root: `.prd/` and `specs/` sit where `install.sh` and the stage skills expect them.

## Reading it gate by gate

Read the files in pipeline order. Each one is the *proof* that a gate was passed, and each is what `smithy` inspects to decide where a feature stands — the README's "Which stage do I start at?" table is the same logic in the other direction.

| Gate | Artifact that proves it | What smithy reads to detect that state |
|------|-------------------------|----------------------------------------|
| forge complete | `.prd/001_cart-discount-codes.md` | file exists; all 7 REASONS headings non-empty; no `[ASSUMED]` marker left |
| anvil complete | `specs/001-…/spec.md`, `plan.md`, `tasks.md` | all three present and past template scaffolding; every FR appears in the tasks' `Satisfies:` lines |
| temper complete | `specs/001-…/review.md` | the last round's `- Rating:` line is `A++` (two consecutive zero-blocking rounds) |
| quench complete | `specs/001-…/tasks.md` + `quench-log.md` | no `- [ ]` left in tasks.md **and** a `green:` line with gate results for every task ID |
| hone complete | `specs/001-…/code-review.md` | the last round's `- Rating:` line is `A++` |
| finish done | `specs/001-…/smithy-log.md` | a `FINISH: docs updated · atlas …` line — the only trace the finish step is guaranteed to leave |

Things worth noticing as you read:

- **PRD → spec drift is caught, not prevented.** The PRD's open question fixed the rounding rule; anvil dropped it; temper round 1 found the gap and it became spec.md FR-002's "half-up" clause and the 151.5 → 152 edge case. The PRD numbers its requirements `FR-1…`; formal `FR-001…` IDs first appear in spec.md — that boundary is deliberate.
- **The overlap cap in temper round 1.** Three blocking findings, but only one raised by two critics (1/5 = 20 %): the judge capped the round at B+ even though its uncapped grade was A. Round 2 was clean (A+), round 3 confirmed it (A++).
- **A rejected finding stays in the log.** Feasibility's Redis-cache suggestion was refused with reasoning in review.md so no later round re-raises it.
- **Amber is a quoted failure message**, never "the test fails". Every quench-log entry records it, including the Hypothesis counterexample for the `[HARD]` task.
- **Sample-and-select for T003.** Three independent attempts; one had the wrong rounding rule, one carried a dead branch that left a surviving mutant, one was selected. The reasoning is in the log.
- **A flake is red.** T006 went stable-green 2/3, was sent back to red, and the root cause was in the implementation — the test was never touched.
- **One waiver, with reasoning.** T004's surviving mutant only rewrote a log message; the log says why that is not a weak test.
- **Hone's one blocking finding went the long way round.** The missing ownership check on `DELETE` had no test, so the fix could not simply be written: `tasks.md`'s T004 gate was amended first, the test agent added the test (the freeze exception is in `quench-log.md`), the implementer fixed the router, and the log shows the revert-check — fix out, test red; fix in, test green. Round 2 reviewed that fix as part of its diff; round 3 confirmed.
- **Ratings measure what the panel examined.** Hone round 1 was C on one finding; a round is "clean" only if the previous round's fixes were in the diff its critics saw, which is why A++ took three rounds, not two.
- **Smithy never needed CI.** Every RESUME entry was decided from the files above; the session that halted mid-quench resumed from `tasks.md`'s two unchecked items.

## Which stage do I start at?

Look at what you already have on disk and enter the pipeline there — the stages refuse to run without their inputs, so guessing wrong costs nothing but a message.

| You have | Start with |
|----------|------------|
| nothing written — a raw idea | `forge` |
| a PRD with all 7 REASONS sections filled and no unconfirmed assumptions | `anvil` |
| the spec triplet (`spec.md` + `plan.md` + `tasks.md`) | `temper` |
| `review.md` whose last round is A++ | `quench` |
| `quench-log.md` with a green entry for every task, all tasks checked | `hone` |
| any of the above and you are not sure which | `smithy --resume` — it reads the same files as the table above and tells you |

If you skip a stage on purpose, do it with `smithy --skip <stage>` so the bypass lands in `smithy-log.md`; this example's log has no BYPASS or OVERRIDE lines because none were used.

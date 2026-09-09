# Quench Log — Cart discount codes

Runner: pytest 8 + pytest-randomly · gates from pyproject: `mypy --strict`, `ruff`, `bandit -r src`, `mutmut` (scope `src/shop/discounts/`) · phase-signalling helper: none in host repo (skipped) · Playwright: no `[UX]` tasks (skipped)

## BDD — 2026-03-10 10:45
- feature: `tests/features/cart-discount-codes.feature` by `bdd-scenario-writer` — 9 scenarios (US1 ×3, US2 ×3, US3 ×3), tagged `@FR-001`…`@FR-005`
- red:   10:52  9 scenarios fail (StepDefinitionNotFoundError — no step defs)
- amber: 11:07  step defs stubbed; 9 fail on their assertions (e.g. `assert resp.status_code == 200` → got 404: route not registered)
- frozen from here; scenarios re-run at the end of every task that lists the feature file

## T001 — 2026-03-10
- red:   11:14  fails (collection: ImportError — `shop.discounts.models` missing)
- amber: 11:21  `Failed: DID NOT RAISE <class 'sqlalchemy.exc.IntegrityError'>` (second insert of the same `(code_id, customer_id)`)
- green: 11:49  diff +148/−2 across 4 files · 4 tests · stable-green 3/3
- gates: mypy ok · ruff ok · bandit ok · mutation 0 survivors (3 killed) · coverage 100 % models.py (reported)
- migration: upgrade/downgrade round-trip ok on empty DB; head `a41f9c2e` → `20260310_discount_codes`

## T002 [P] — 2026-03-10
- red:   11:58  fails (collection: ImportError — `shop.discounts.repository` missing)
- amber: 12:03  `AssertionError: expected DiscountCode(code='SPRING20'), got None` (lookup of `spring20`)
- green: 12:26  diff +96/−0 across 2 files · 6 tests · stable-green 3/3
- gates: mypy ok · ruff ok · bandit ok · mutation 0 survivors (11 killed) · coverage 97 % (reported) · EXPLAIN shows `Index Scan using ix_discount_codes_code`

## T003 [HARD] — 2026-03-10
- red:   12:44  fails (collection: ImportError — `shop.discounts.pricing` missing)
- amber: 12:51  `AssertionError: expected 152, got None` (15 % of 1010, half-up); Hypothesis property fails first at `subtotal=0, kind='fixed', value=1` → `TypeError: '<=' not supported between 'int' and 'NoneType'`
- sample-and-select: 3 independent attempts, frozen tests + gates run against each
  | attempt | tests | mutation | verdict |
  |---------|-------|----------|---------|
  | A | 16/17 | — | `Decimal` with `ROUND_HALF_EVEN`; fails `test_fr002_half_up_rounds_2_5_to_3` (2.5 → 2). Not selected. |
  | B | 17/17 | 0 survivors (19 killed) | integer arithmetic `(subtotal * value + 50) // 100`, clamp last; 41 lines. **Selected.** |
  | C | 17/17 | 1 survivor (18 killed) | same result, plus an unreachable `if subtotal < 0: raise` guard — mutant `<` → `<=` survives because the strategy never generates negative subtotals; dead code, larger diff. Not selected. |
  Reasoning: B is the only attempt that is fully green with no survivor and no dead branch; A's rounding is the wrong rule per FR-002; C's guard duplicates the type contract and would need a waiver.
- green: 13:38  diff +171/−0 across 2 files · 17 tests (12 examples + 1 property @ 10 000 examples + 4 parametrised) · stable-green 3/3
- gates: mypy ok · ruff ok (banned-`float` rule clean) · bandit ok · mutation 0 survivors (19 killed) · coverage 100 % (reported)

## T004 — 2026-03-10
- red:   14:09  fails (collection: AttributeError — `shop.discounts` has no attribute `router`, raised on app import)
- amber: 14:17  `AssertionError: expected total_minor 3200, got 4000` (stub route returned the cart unchanged); US1 scenarios 0/3
- green: 15:12  diff +139/−3 across 4 files · 7 tests + US1 scenarios 3/3 · stable-green 3/3
- gates: mypy ok · ruff ok · bandit ok · mutation 1 survivor (14 killed) — **WAIVED**: mutant rewrote the `logger.info("discount applied cart=%s")` message string; no FR or SC constrains log text, and asserting on it would be a test beyond tasks.md. NFR-2 (codes never logged) is covered by `test_fr001_no_code_in_log_output`, which the mutant does not touch · coverage 94 % (reported)
- 15:40 session halted after this task (see smithy-log.md); T005–T006 unchecked

## T005 — 2026-03-11
- red:   08:24  fails (collection: fixture `expired_code` not found)
- amber: 08:31  `assert resp.status_code == 422` → got 200 (expired code accepted); US2 scenarios 0/3
- green: 08:58  diff +74/−6 across 3 files · 6 tests + US2 scenarios 3/3 · stable-green 3/3
- gates: mypy ok · ruff ok · bandit ok · mutation 0 survivors (9 killed — the boundary mutant `<=` → `<` was killed by the exact-instant test) · coverage 96 % (reported)

## T006 — 2026-03-11
- red:   09:09  fails (collection: ImportError — cannot import `record_redemption_for_checkout` from `shop.checkout`)
- amber: 09:16  `assert resp.status_code == 409` → got 200 (second apply by the same customer accepted); US3 scenarios 0/3
- green: 09:47  **stable-green 2/3 → back to red.** The concurrent-checkout test flickered: one run surfaced the unique violation as a 500. Root cause (impl, not test): the `IntegrityError` was caught outside the `session.begin()` block, so under one interleaving it escaped the transaction scope before being mapped to 409. Fix: catch inside the block. No test edited.
- green: 10:05  diff +118/−9 across 4 files · 8 tests + US3 scenarios 3/3 · stable-green 3/3 (concurrency test additionally run 20× in a row, 20/20)
- gates: mypy ok · ruff ok · bandit ok · mutation 0 survivors (13 killed) · coverage 88 % checkout.py (reported)

## Completion — 2026-03-11 10:20
- BDD: 9/9 scenarios green end to end
- traceability sweep over FR-001…FR-005: 0 `UNTESTED` (SC-003 met)
- suite: 57 tests (48 unit/api + 9 scenarios) · CI run #412 green
- diff sizes: largest task 171 changed lines — all six under the 400-line budget; no anvil feedback
- freeze exceptions: none · waivers: 1 (T004 log string) · property test (SC-001): 10 000 examples, no counterexample

## Freeze exception — 2026-03-11 10:58 (hone round 1, T004)
- trigger: code-review.md round 1 security#1 (BLOCKING) — `DELETE /cart/{cart_id}/discount` mounted without `require_cart_owner`
- Golden Rule path: spec.md unchanged (plan.md Safeguards already state the ownership rule) → tasks.md T004 gate clause added first → then the test
- test: `tests/api/test_discount_router.py::test_fr005_delete_refuses_foreign_session` added by `tdd-test-generator`; the implementer did not touch it
- red:   11:02  fails (fixture `other_customer_session` not found)
- amber: 11:06  `assert resp.status_code == 404` → got 204 (foreign session cleared the discount)
- green: 11:14  fix commit `7c2e41d` (+2/−1, `router.py` only) · 58 tests · stable-green 3/3
- gates: mypy ok · ruff ok · bandit ok · mutation 0 survivors (2 new killed) · coverage unchanged (reported)

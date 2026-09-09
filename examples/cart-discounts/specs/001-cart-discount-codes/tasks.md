# Tasks: Cart discount codes

**Input**: `specs/001-cart-discount-codes/{spec,plan}.md`
**Status**: all tasks complete — quench 2026-03-11, see quench-log.md

## Format: `[ID] [P?] [Story] [Tag?] Description`

- **[P]**: parallel-safe — different files, no dependency on another unchecked task in its phase
- **[Story]**: US1 / US2 / US3 from spec.md
- **Tags**: `[UX]` browser-facing → Playwright in quench · `[REFACTOR]` changes existing behaviour → characterization tests first · `[HARD]` genuinely tricky → quench sample-and-select
- Every task: file paths, `Satisfies:` FR(s), `Gate:` (true before it is checked off). Budget: ≤ ~400 changed lines per task.

## Phase 1: Foundation

- [x] T001 [US1] Add `DiscountCode` and `Redemption` models and the Alembic migration creating both tables plus `carts.discount_code_id`
  - Files: `src/shop/discounts/__init__.py`, `src/shop/discounts/models.py`, `alembic/versions/20260310_discount_codes.py`, `tests/unit/test_models.py`
  - Satisfies: FR-001 (stored applied code), FR-004 (Redemption uniqueness)
  - Gate: migration upgrade/downgrade round-trips on an empty DB; a duplicate `(code_id, customer_id)` insert raises `IntegrityError`; `mypy --strict` clean

## Phase 2: Core

- [x] T002 [P] [US1] Repository: find an active code case-insensitively via the unique index; check and record redemptions
  - Files: `src/shop/discounts/repository.py`, `tests/unit/test_repository.py`
  - Satisfies: FR-003 (unknown/inactive → none), FR-004 (`has_redeemed`, `record_redemption`)
  - Gate: `spring20` finds `SPRING20`; inactive code → none; record then `has_redeemed` → true; query plan shows the index; 0 mutation survivors
- [x] T003 [US1] [HARD] Pure discount computation: `percent` with half-up rounding, `fixed`, clamp to `[0, subtotal]`, applied to the post-sale subtotal
  - Files: `src/shop/discounts/pricing.py`, `tests/unit/test_pricing.py`
  - Satisfies: FR-002
  - Gate: example tests for every spec edge case (0, 100 %, 151.5 → 152, 2.5 → 3, fixed > subtotal); Hypothesis property `0 ≤ discount ≤ subtotal` green at `max_examples=10000` (SC-001); ruff banned-`float` rule clean; 0 mutation survivors

## Phase 3: API

- [x] T004 [US1] Router: `POST /cart/{cart_id}/discount` (apply / replace) and `DELETE /cart/{cart_id}/discount`; response recomputes amounts from the stored code
  - Files: `src/shop/discounts/router.py`, `src/shop/main.py` (include router), `tests/api/test_discount_router.py`, `tests/features/cart-discount-codes.feature` (US1 steps)
  - Satisfies: FR-001, FR-005
  - Gate: US1 acceptance scenarios 1–3 green end to end; DELETE idempotent (`204` twice); response model has exactly the four fields; nothing stored but `discount_code_id`; both routes refuse a foreign customer's session with `404` *(gate clause added 2026-03-11 in hone round 1 — see code-review.md; the plan's ownership Safeguard had no task gate)*
- [x] T005 [US2] Apply-time refusals: unknown/inactive → `404 code_not_found`; `expires_at ≤ now` (UTC) → `422 code_expired`; refused apply leaves the cart unchanged
  - Files: `src/shop/discounts/router.py`, `tests/api/test_discount_router.py`, `tests/features/cart-discount-codes.feature` (US2 steps)
  - Satisfies: FR-003
  - Gate: US2 scenarios 1–3 green including the exact-instant case; `discount_code_id` unchanged after each refusal; `detail` strings match spec.md verbatim

## Phase 4: Checkout

- [x] T006 [US3] Checkout hook: re-check expiry, write the Redemption inside the checkout transaction, map a unique violation to `409 code_already_redeemed`; apply-time `409` for a customer who already redeemed; guests skip
  - Files: `src/shop/checkout.py`, `src/shop/discounts/router.py`, `tests/api/test_checkout_redemption.py`, `tests/features/cart-discount-codes.feature` (US3 steps)
  - Satisfies: FR-003 (checkout re-check), FR-004
  - Gate: US3 scenarios 1–3 green; two concurrent checkouts yield exactly one Redemption row and one `409`; guest checkout writes no Redemption; suite stable-green 3/3

## FR → task map

| FR | Tasks |
|----|-------|
| FR-001 | T001, T004 |
| FR-002 | T003 |
| FR-003 | T002, T005, T006 |
| FR-004 | T001, T002, T006 |
| FR-005 | T004 |

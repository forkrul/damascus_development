# Feature Specification: Cart discount codes

**Feature Branch**: `001-cart-discount-codes`
**Created**: 2026-03-09
**Status**: Tempered A++ (review.md round 3, 2026-03-10)
**Input**: PRD `.prd/001_cart-discount-codes.md`

## User Scenarios & Testing

### User Story 1 - Apply a code and see the discounted total (Priority: P1)

A shopper with items in their cart enters a code; the cart answers with subtotal, discount and total.

**Why this priority**: it is the feature. Nothing else is observable without it.

**Independent Test**: seed one `percent` and one `fixed` code, POST each against a cart, check the three amounts.

**Acceptance Scenarios**:

1. **Given** a cart with subtotal 4000 (minor units) and active code `SPRING20` (percent, 20), **When** the shopper applies `spring20`, **Then** the response is `{subtotal_minor: 4000, discount_minor: 800, total_minor: 3200, code: "SPRING20"}`.
2. **Given** a cart with subtotal 300 and active code `FIVER` (fixed, 500), **When** `FIVER` is applied, **Then** `discount_minor` is 300 and `total_minor` is 0 — never negative.
3. **Given** a cart that already carries `SPRING20`, **When** `FIVER` is applied, **Then** the cart carries only `FIVER` and the total reflects it alone.

---

### User Story 2 - Unknown or expired codes are refused with a reason (Priority: P2)

A shopper enters a code that does not exist or has expired; the cart is unchanged and the storefront gets a stable reason string.

**Why this priority**: without it, US1 silently accepts junk; but it delivers no value until US1 exists.

**Independent Test**: POST an unknown code and an expired code; assert status, `detail`, and that `discount_code_id` is unchanged.

**Acceptance Scenarios**:

1. **Given** code `XMAS25` with `expires_at` 2025-12-26T00:00:00Z and now 2026-03-10T09:00:00Z, **When** applied, **Then** `422 {"detail": "code_expired"}` and the cart is unchanged.
2. **Given** no code `NOPE` exists, **When** applied, **Then** `404 {"detail": "code_not_found"}`.
3. **Given** a code whose `expires_at` equals the current instant, **When** applied, **Then** `422 code_expired` (validity is strictly before `expires_at`).

---

### User Story 3 - A code is single-use per customer (Priority: P3)

A customer who has already checked out with a code cannot apply it again; other customers can.

**Why this priority**: prevents abuse of US1 but only matters once checkouts with codes happen.

**Independent Test**: complete a checkout with `SPRING20` as customer C, then apply it again as C and as D.

**Acceptance Scenarios**:

1. **Given** customer C completed checkout with `SPRING20`, **When** C applies `SPRING20` to a new cart, **Then** `409 {"detail": "code_already_redeemed"}`.
2. **Given** C redeemed `SPRING20`, **When** customer D applies it, **Then** `200`.
3. **Given** C has `SPRING20` applied to a cart but has not checked out, **When** C applies it to a second cart, **Then** `200` — redemption happens at checkout, not at apply.

### Edge Cases

- Subtotal 0 → discount 0, total 0, `200`.
- `percent` value 100 → discount equals subtotal, total 0.
- A percentage yielding a half minor unit (15 % of 1010 = 151.5) → 152; (25 % of 10 = 2.5) → 3. Half-up, never banker's.
- Code submitted in any case matches; the response echoes the stored upper-case form.
- Code expires between apply and checkout → checkout refuses with `code_expired`; the cart keeps the code so the shopper can remove it.
- Two concurrent checkouts by the same customer with the same code → exactly one Redemption row; the other checkout fails with `code_already_redeemed`.
- Guest cart (no `customer_id`) → codes apply normally; no Redemption is written and no single-use check runs.

## Requirements

### Functional Requirements

- **FR-001**: System MUST accept `POST /cart/{cart_id}/discount` with body `{"code": string}` and respond `200` with integer `subtotal_minor`, `discount_minor`, `total_minor` and the canonical `code`. Applying a code to a cart that already carries one replaces it; at most one `discount_code_id` is stored per cart.
- **FR-002**: System MUST compute the discount in integer minor units from the post-sale subtotal: `percent` → `subtotal × value / 100` rounded half-up to the nearest minor unit; `fixed` → `value`. The result MUST then be clamped to `[0, subtotal]`, so `total_minor = subtotal − discount` is never negative and never exceeds the subtotal. The discount is recomputed from the stored code on every cart read and is never persisted.
- **FR-003**: System MUST refuse an unknown or inactive code with `404 {"detail": "code_not_found"}`, and a code whose `expires_at` is set and `≤ now` (UTC, timezone-aware) with `422 {"detail": "code_expired"}`. A refused apply leaves the cart unchanged. Expiry is checked at apply time and again inside checkout.
- **FR-004**: System MUST, inside the checkout transaction, write a Redemption `(code_id, customer_id, order_id, redeemed_at)` enforced unique on `(code_id, customer_id)`. An apply or checkout by a customer who already has a Redemption for that code MUST be refused with `409 {"detail": "code_already_redeemed"}`. Guest carts skip this entirely.
- **FR-005**: System MUST expose `DELETE /cart/{cart_id}/discount`, returning `204` and clearing `discount_code_id`; calling it when no code is applied is also `204`.

### Key Entities

- **DiscountCode**: `id`, `code` (unique, stored upper-case), `kind` ∈ {`percent`, `fixed`}, `value` (int; 1–100 for percent, ≥ 1 for fixed), `expires_at` (nullable, UTC), `active` (bool).
- **Redemption**: `id`, `code_id` → DiscountCode, `customer_id`, `order_id`, `redeemed_at`; unique `(code_id, customer_id)`.
- **Cart** (existing): gains nullable `discount_code_id` → DiscountCode.

## Success Criteria

- **SC-001**: For 10 000 Hypothesis-generated `(subtotal, kind, value)` cases, `0 ≤ discount ≤ subtotal` holds with no counterexample. Verified by `tests/unit/test_pricing.py::test_fr002_property_never_negative_never_exceeds` (`max_examples=10000` locally, 2000 in CI).
- **SC-002**: Applying a code to a 50-line cart completes in < 100 ms p95 over 200 requests against local Postgres. Verified by `tests/perf/test_discount_latency.py` (marked `perf`; nightly CI job).
- **SC-003**: Every FR-001…FR-005 is named by at least one passing test; quench's traceability sweep prints no `UNTESTED:` line. Verified at quench completion and recorded in `quench-log.md`.

## Assumptions

- Staff create codes with the existing admin CLI; no code-management API here (PRD, confirmed).
- `expires_at` is exclusive: a code is valid strictly before it (PRD, confirmed).
- Guest carts may apply codes; single-use applies only to identified customers (PRD, confirmed).
- Line-level sale prices are already reflected in `subtotal_minor`; the code applies on top (PRD, confirmed).

## Dependencies

- Existing `Cart` model and `POST /checkout` flow in `src/shop/checkout.py`.
- Alembic migration chain (current head `a41f9c2e`).
- Dev dependencies to add: `hypothesis`, `mutmut`, `pytest-randomly`.

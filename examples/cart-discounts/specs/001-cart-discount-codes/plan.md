# Implementation Plan: Cart discount codes

**Branch**: `001-cart-discount-codes` | **Date**: 2026-03-09 | **Spec**: `specs/001-cart-discount-codes/spec.md`

## Summary

Add a `discounts` package to the FastAPI shop: two tables, a pure pricing function, one router with apply/remove, and a redemption hook inside the existing checkout transaction. All money is integer minor units; the Safeguard invariant `0 ≤ discount ≤ subtotal` is a Hypothesis property test.

## REASONS Canvas

### Requirements

FR-001–FR-005 as in spec.md. Plan-level consequences: the apply endpoint must hit exactly one indexed lookup (NFR-1); refusal strings are constants in one module so the storefront can rely on them (NFR-3); no endpoint ever returns a list of codes or another customer's redemption state (NFR-2).

### Entities

| Table | Columns | Constraints |
|-------|---------|-------------|
| `discount_codes` | `id`, `code`, `kind`, `value`, `expires_at`, `active` | `code` unique; `kind` enum; `value` check ≥ 1; `expires_at` timestamptz nullable |
| `redemptions` | `id`, `code_id`, `customer_id`, `order_id`, `redeemed_at` | unique `(code_id, customer_id)`; FKs to `discount_codes`, `customers`, `orders` |
| `carts` (existing) | + `discount_code_id` | nullable FK; `ON DELETE SET NULL` |

### Approach

Pure core / imperative shell. `pricing.compute_discount(subtotal_minor, kind, value)` is the only arithmetic and has no I/O; everything else is lookup, validation and persistence. The discount is never stored — the cart response recomputes it from `discount_code_id` on every read, so a changed subtotal can never leave a stale discount behind. Codes are stored upper-case and looked up by exact match on the upper-cased input, so the unique index is used and no `ilike` scan is needed.

### Structure

```
src/shop/discounts/__init__.py
src/shop/discounts/models.py       DiscountCode, Redemption
src/shop/discounts/repository.py   find_active_code, has_redeemed, record_redemption
src/shop/discounts/pricing.py      compute_discount (pure)
src/shop/discounts/router.py       POST / DELETE /cart/{cart_id}/discount; refusal constants
src/shop/checkout.py               existing; call the redemption hook inside its transaction
alembic/versions/20260310_discount_codes.py
tests/features/cart-discount-codes.feature
tests/unit/test_models.py test_repository.py test_pricing.py
tests/api/test_discount_router.py test_checkout_redemption.py
tests/perf/test_discount_latency.py
```

### Operations

| Operation | Where | Input → output |
|-----------|-------|----------------|
| find active code | `repository.py` | code string → `DiscountCode` or none (inactive counts as none) |
| has redeemed | `repository.py` | `(code_id, customer_id)` → bool |
| record redemption | `repository.py` | `(code_id, customer_id, order_id)` → row, inside caller's transaction |
| compute discount | `pricing.py` | `(subtotal_minor, kind, value)` → `discount_minor` in `[0, subtotal_minor]` |
| apply | `router.py` | lookup → expiry check → redemption check (non-guest) → store `discount_code_id` → respond with computed amounts |
| remove | `router.py` | clear `discount_code_id` → `204` |
| checkout hook | `checkout.py` | if cart has a code: re-check expiry, record redemption, map unique-violation to `409` |

### Norms

Gates quench installs from the PRD: `mypy --strict`, `ruff` (E/F/I/B/UP + banned `float` in `src/shop/discounts/`), `bandit -r src`, `mutmut` scoped to `src/shop/discounts/`, `pytest-randomly`. Every test names its FR via `@pytest.mark.fr("FR-NNN")` or a Gherkin `@FR-NNN` tag.

### Safeguards

- `0 ≤ discount ≤ subtotal` → Hypothesis property in `test_pricing.py`, strategies: `subtotal ≥ 0`, `kind ∈ {percent, fixed}`, `value` in each kind's valid range (SC-001).
- Double redemption → DB unique constraint is the source of truth; the application check is an early exit, not the guard. A concurrency test drives two checkouts at once and asserts exactly one row.
- Expiry drift between apply and checkout → checkout re-validates; refusal string identical to apply-time.
- No floats: enforced by the ruff banned-api rule, not by review.
- Cart ownership → both discount routes mount under the existing cart router's `require_cart_owner` dependency; a request against another customer's cart is `404` (same as an unknown cart, so nothing is disclosed — NFR-2).

## Phases

| Phase | Tasks | Delivers |
|-------|-------|----------|
| 1 Foundation | T001 | tables, migration, models |
| 2 Core | T002 [P], T003 [HARD] | repository; pure pricing with property test (parallel-safe: disjoint files, both depend only on T001) |
| 3 API | T004, T005 | apply/remove endpoint; refusals (US1, US2 scenarios green) |
| 4 Checkout | T006 | redemption hook, single-use (US3 scenarios green) |

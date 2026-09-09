# PRD 001: Cart discount codes

**Status:** Complete (forge) — all assumptions confirmed 2026-03-09
**Sequence:** 001
**Author:** mara
**Created:** 2026-03-09

> Raw idea, quoted verbatim: "we need discount codes on the cart — percentage ones like SPRING20 and fixed ones like a fiver off. they should expire, and a customer should only get to use a code once. and it must never make the cart cheaper than free or, god forbid, more expensive."

## Requirements

### Functional
- FR-1: A shopper can apply one discount code to their cart and see the discounted total.
- FR-2: Two code kinds: percentage (1–100 % of the cart subtotal) and fixed amount (integer minor units, e.g. 500 = £5.00).
- FR-3: A code carries an optional expiry instant; applying it at or after that instant is refused with a reason the storefront can show.
- FR-4: A code is single-use per customer: once a checkout completes with it, the same customer cannot apply it again. Other customers are unaffected.
- FR-5: A cart holds at most one code; applying a second replaces the first. Codes do not stack with each other, but they do apply on top of existing line-level sale prices.

### Non-Functional
- NFR-1 (performance): applying a code adds no more than 100 ms p95 to the cart endpoint on a 50-line cart.
- NFR-2 (security): codes are looked up server-side only; there is no listing endpoint, and error responses never reveal another customer's redemptions.
- NFR-3 (usability): refusal reasons are stable machine-readable strings (`code_not_found`, `code_expired`, `code_already_redeemed`) so the storefront can localise them.

## Entities

| Name | Description | Key fields |
|------|-------------|------------|
| DiscountCode | A redeemable code created by staff | `code` (unique, matched case-insensitively), `kind` (`percent`/`fixed`), `value` (int), `expires_at` (UTC, nullable), `active` |
| Redemption | A customer consumed a code at checkout | `code_id`, `customer_id`, `order_id`, `redeemed_at`; unique on (`code_id`, `customer_id`) |
| Cart (existing) | The shopper's cart; gains one optional applied code | `id`, `customer_id` (nullable for guests), `lines[]`, `subtotal_minor`, `discount_code_id` (new, nullable) |

## Approach

Add a `discounts` package to the existing FastAPI shop. Pricing is a pure function: cart subtotal + code in, discount in integer minor units out, clamped to `[0, subtotal]`. The router does lookup and validation (expiry, redemption state) and stores the applied code on the cart; the existing checkout records the Redemption inside its transaction. No floats anywhere in money math.

## Structure

```
src/shop/discounts/
  models.py       # DiscountCode, Redemption (SQLAlchemy 2.0)
  repository.py   # case-insensitive lookup; has_redeemed / record_redemption
  pricing.py      # the only arithmetic: compute_discount(subtotal, code)
  router.py       # POST + DELETE /cart/{cart_id}/discount
src/shop/checkout.py            # existing; gains the redemption hook
alembic/versions/               # one migration: two tables + carts.discount_code_id
tests/features/cart-discount-codes.feature
tests/unit/  tests/api/  tests/perf/
```

## Operations

| Operation | Input | Output | Notes |
|-----------|-------|--------|-------|
| Apply code | `POST /cart/{cart_id}/discount` `{code}` | `200 {subtotal_minor, discount_minor, total_minor, code}` | replaces any prior code (FR-5) |
| Remove code | `DELETE /cart/{cart_id}/discount` | `204` | idempotent |
| Refuse | as Apply | `404 code_not_found` · `422 code_expired` · `409 code_already_redeemed` | reason string in `detail` |
| Checkout hook | internal, from existing checkout | Redemption row written | inside the checkout transaction; re-checks expiry |

## Norms

- Coding conventions: existing shop style — Pydantic v2 models, SQLAlchemy 2.0 typed ORM, money as `int` minor units, timezone-aware UTC datetimes only.
- Quality bar: every FR named by a test; every Safeguard a property test or constraint; no mutation survivor on a changed line without a logged waiver.
- Referenced principles: TDD (red-amber-green per quench), YAGNI (no code-management API, no multi-code stacking), pure core / imperative shell.
- Machine-checked: `mypy --strict` (`[tool.mypy]`), `ruff` rules E/F/I/B/UP plus a banned-api rule forbidding `float` in `src/shop/discounts/` (`[tool.ruff]`), `bandit -r src` (`bandit.yaml`), `mutmut` scoped to `src/shop/discounts/` (`[tool.mutmut]`), `pytest-randomly` for stable-green.

## Safeguards

<!-- each Must-not becomes a property test or runtime assertion in quench -->
- Must-not: a discount must never increase the price or take it below zero — for every subtotal `s ≥ 0` and every code, `0 ≤ discount ≤ s`. (→ Hypothesis property test.)
- Must-not: a customer must never redeem the same code twice, even under concurrent checkouts. (→ DB unique constraint + concurrency test.)
- Failure modes considered: code expires between apply and checkout (checkout re-validates); subtotal changes after apply (discount is recomputed from the stored code on every read, never persisted); DB failure mid-checkout (single transaction, no partial Redemption).
- Security/privacy: refusal codes do not disclose other customers' redemptions; codes never appear in logs; no enumeration endpoint.

---

## Open Questions

- [x] Rounding rule for percentage discounts? → half-up to the nearest minor unit (mara, 2026-03-09).
- [x] Do codes stack with line-level sale prices? → yes, the code applies to the post-sale subtotal (mara, 2026-03-09).

## Assumptions (mark each as confirmed before anvil)

- Confirmed 2026-03-09: staff create codes with the existing admin CLI; no admin API in this feature.
- Confirmed 2026-03-09: `expires_at` is exclusive — a code is valid strictly before that instant.
- Confirmed 2026-03-09: guest carts may apply codes; single-use is enforced only for identified customers.

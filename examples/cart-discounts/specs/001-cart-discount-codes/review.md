# Adversarial Review Log — Cart discount codes

## Round 1 — 2026-03-10 09:14
- Critics: completeness, feasibility, testability (all three attached their procedure artifacts)
- Blocking: 3  Nits: 6 (4 killed by judge)
- Overlap: 1/5 (20 % — D ≥ 4 and m/D < 25 % → **rating capped at B+**)
- Rating: B+ (judge's uncapped grade was A: two of the three blocking findings are one-line clarifications, but the near-disjoint finding sets say the critics have not exhausted the defect pool)
- Findings applied:
  1. spec.md FR-002 — no rounding rule for percentage discounts; the PRD's open question answered it (half-up) but anvil dropped it. Added "rounded half-up to the nearest minor unit" and the 151.5 → 152 / 2.5 → 3 edge cases. (raised by completeness *and* testability — the one overlapping finding)
  2. spec.md FR-003 — "expired" undefined at the boundary instant; a critic's test skeleton could not choose `<` or `≤`. Fixed to `expires_at ≤ now` (validity strictly before), added US2 scenario 3 and the guest-cart edge case. (completeness)
  3. tasks.md T006 — no file path for the checkout hook and no gate for the concurrent double-redemption Safeguard. Added `src/shop/checkout.py` and the "exactly one Redemption row" gate. (testability)
- Findings rejected:
  1. feasibility#2 — proposed caching code lookups in Redis to meet NFR-1; rejected: the unique index on `code` satisfies NFR-1 at any plausible table size, and a cache adds an invalidation path for expiry (YAGNI). Recorded here so it is not re-raised.
- Surviving nits (not applied, noted): plan.md Phases table could name the perf test's phase; spec.md Dependencies should pin the Alembic head — both applied anyway as cheap edits.

## Round 2 — 2026-03-10 09:58
- Critics: completeness, feasibility, testability
- Blocking: 0  Nits: 2 (both killed — completeness asked for a rate-limit FR: scope creep, not in the PRD; testability wanted `test_perf` renamed: cosmetic)
- Overlap: 0/2 (D < 4 — signal not computed, no cap)
- Rating: A+ (clean pass 1 of 2)
- Artifacts on file: completeness re-derived Entities/Operations from Requirements alone and matched all three tables and seven operations; feasibility traced `POST /cart/{id}/discount` → lookup → clamp → cart row → response → checkout → Redemption with no unstated decision; testability drafted a skeleton per FR (5/5) without a question for the author.

## Round 3 — 2026-03-10 10:24
- Critics: completeness, feasibility, testability
- Blocking: 0  Nits: 0
- Overlap: n/a (no findings)
- Rating: A++  ← exit (clean pass 2 of 2)
- Attack angles tried and failed: guest cart with a redeemed code (spec says guests skip FR-004 — consistent); subtotal changing after apply (FR-002 recomputes on read); code deleted after apply (`ON DELETE SET NULL` in plan.md Entities); percent value 0 (excluded by the `value ≥ 1` check constraint, spec Key Entities).

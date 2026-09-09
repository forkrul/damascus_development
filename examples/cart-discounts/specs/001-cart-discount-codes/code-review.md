# Adversarial Code Review Log — Cart discount codes

Review units, from quench-log.md diff sizes: T001 (150) · T002 (96) · T003 (171) · T004 (142) · T005 (80) · T006 (127). All under the ~400-changed-line budget; no unit split. Suite green at 57/57 before round 1 (CI #412).

## Round 1 — 2026-03-11 10:40
- Units reviewed: T001–T006, each with 3 critics + judge (18 critic reports, 6 judge verdicts)
- Critics: conformance, security, simplicity (all attached artifacts: FR → file:line traces, input → sink walks, deletion lists)
- Blocking: 1  Nits: 4 (3 killed by judge, 1 rejected)
- Overlap: 1/3 (D < 4 — signal not computed, no cap)
- Rating: C (a security finding; drifts from plan.md's ownership Safeguard)
- Findings applied:
  1. security#1 (BLOCKING) — `src/shop/discounts/router.py:71` registers `DELETE /cart/{cart_id}/discount` on the discounts `APIRouter` without the `require_cart_owner` dependency the `POST` route at `:38` carries; the security walk's `cart_id` path → sink trace ends at `cart_repo.get(cart_id)` with no ownership check, so any signed-in customer can clear another customer's discount by guessing an id. plan.md Safeguards require both routes under `require_cart_owner` with a `404` for a foreign session. No test could catch it: every FR-005 test used the owner's session, and tasks.md's T004 gate never asked for a foreign one. **Not a spec gap** — the plan states the rule — but a task-gate gap, so the fix goes through the Golden Rule rather than around the freeze:
     - tasks.md T004 gate clause added first ("both routes refuse a foreign customer's session with `404`")
     - `tdd-test-generator` added `test_fr005_delete_refuses_foreign_session`; red → amber `assert resp.status_code == 404` → got 204 (freeze exception logged in quench-log.md)
     - `fastapi-implementer` fix commit `7c2e41d`: `dependencies=[Depends(require_cart_owner)]` on the router itself, so both routes inherit it (+2/−1, `router.py` only; no test file in the diff)
     - suite 58/58 green · stable-green 3/3 · mypy/ruff/bandit ok · mutation 0 survivors
     - **Revert-check:** `git revert --no-commit 7c2e41d` → `test_fr005_delete_refuses_foreign_session` FAILED (`AssertionError: assert 204 == 404`), rest of suite green → restore → 58/58 green. The fix is verified, not asserted.
     - Both directions re-measured: owner's session still `204` on DELETE and `200` on POST (existing tests), foreign session now `404` on both (new test parametrised over the two routes); no threshold moved the other way.
- Findings rejected:
  1. security#2 (NIT) — rate-limit `POST /cart/{id}/discount` against code guessing. Not a fix for this diff: the PRD's NFR-2 covers disclosure, not brute force. Logged as a follow-up PRD candidate, not applied (a fix beyond the spec).
- Killed by judge: two style nits without file:line; one conformance "finding" that FR-005 lacks a test (it has two — critic misread the trace).
- Security walk, remaining sinks clean: `code` body field → Pydantic `str` (max 64) → `.upper()` → parameterised query; refusal `detail` strings are constants, no reflection of input; no code value written to logs (verified against the T004 waiver).

## Round 2 — 2026-03-11 11:35
- Units reviewed: T001–T006 **plus round 1's fix commit `7c2e41d` and the added test** — critics received the cumulative diff, not only the original implementation
- Critics: conformance, security, simplicity
- Blocking: 0  Nits: 1 (killed — docstring wording)
- Overlap: n/a (D < 4)
- Rating: A+ (clean pass 1 of 2)
- Round-1 fix review: conformance traced FR-005 → `router.py:38–74` and confirmed the dependency now sits on the router, not per route, so a future route cannot omit it; security re-ran the `cart_id` walk for both routes and repeated the revert-check independently (revert → 1 red → restore → green); simplicity proposed nothing further to delete and attached its empty deletion list with reasoning.

## Round 3 — 2026-03-11 12:10
- Units reviewed: T001–T006 + `7c2e41d` (unchanged since round 2)
- Critics: conformance, security, simplicity
- Blocking: 0  Nits: 0
- Overlap: n/a (no findings)
- Rating: A++  ← exit (clean pass 2 of 2, round cap reached exactly)
- Attack angles tried and failed: naive vs aware datetime comparison (`expires_at` is `timestamptz`, `now` built with `timezone.utc`); replaying a redeemed code on a guest cart (guests skip FR-004 by spec, no Redemption written); TOCTOU between `has_redeemed` and checkout (the unique constraint is the guard, the application check only an early exit — plan.md Safeguards); ownership bypass via the checkout hook (it receives the cart from the already-authorised checkout flow, never a raw id).

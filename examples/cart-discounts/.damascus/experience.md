# Experience

## 001-cart-discount-codes — Gate every owner-only route with a foreign-session test
- Stage: anvil
- Cue: plan.md has a Safeguard that limits a route or a resource to its owner
- Lesson: give every task that adds such a route a gate clause that sends another customer's session and expects the refusal the Safeguard names
- Evidence: [code-review.md](../specs/001-cart-discount-codes/code-review.md) round 1, security#1 — `DELETE /cart/{cart_id}/discount` shipped without `require_cart_owner`, because every T004 test used the owner's session; [tasks.md](../specs/001-cart-discount-codes/tasks.md) T004's foreign-session gate clause was added in that round
- Confidence: medium

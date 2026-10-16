#!/usr/bin/env bash
# tests/dogfood_e2e.sh — End-to-end Damascus v0.2 dogfooding validation run.
#
# Exercises all 5 stages (Forge -> Anvil -> Temper -> Quench -> Hone) and all
# 5 mechanized CLI harnesses (agent-run, bdd-check, test-lock, revert-proof,
# proof-coverage) on a realistic Checkout Coupon Service project.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
damascus() { "${SMOKE_BASH:-bash}" "$REPO_ROOT/install.sh" "$@"; }

pass=0
fail=0
check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  [PASS] $desc"
        pass=$((pass + 1))
    else
        echo "  [FAIL] $desc"
        fail=$((fail + 1))
    fi
}

echo "=== Damascus v0.2 End-to-End Dogfood Validation ==="

TMP_PROJECT="$(mktemp -d)"
trap 'rm -rf "$TMP_PROJECT"' EXIT

git -C "$TMP_PROJECT" init -q
git -C "$TMP_PROJECT" config user.email "dogfood@damascus.local"
git -C "$TMP_PROJECT" config user.name "Damascus Dogfood"

# 1. Install Damascus with --all-harnesses
echo "--- Stage 0: Multi-Harness Installation (.claude, .agents, .gemini) ---"
(cd "$TMP_PROJECT" && damascus --all-harnesses >/dev/null)
check ".claude/skills/temper linked" test -L "$TMP_PROJECT/.claude/skills/temper"
check ".agents/skills/temper linked" test -L "$TMP_PROJECT/.agents/skills/temper"
check ".gemini/skills/temper linked" test -L "$TMP_PROJECT/.gemini/skills/temper"
check "damascus --print-root resolves REPO_ROOT" test "$(damascus --print-root)" = "$REPO_ROOT"

# Create a project-local addendum hook (.damascus/addenda/temper.md)
mkdir -p "$TMP_PROJECT/.damascus/addenda"
cat > "$TMP_PROJECT/.damascus/addenda/temper.md" <<'EOF'
- Project Addendum: All monetary calculations MUST use `decimal.Decimal` in EUR.
EOF
check ".damascus/addenda/temper.md hook created" test -f "$TMP_PROJECT/.damascus/addenda/temper.md"

# 2. Stage 1-3: Forge / Anvil / Temper (Adversarial Spec Convergence)
echo "--- Stages 1-3: Forge, Anvil & Temper (Spec & Blind Critic Dispatch) ---"
mkdir -p "$TMP_PROJECT/specs/001-coupon-pricing"
cat > "$TMP_PROJECT/specs/001-coupon-pricing/spec.md" <<'EOF'
# Spec 001: Coupon Pricing Service

## Functional Requirements
- **FR-001 [DELTA]:** `apply_coupon(subtotal_eur, percent)` returns discounted total in EUR rounded to 0.01 EUR.
- **FR-002 [DELTA]:** Raise `ValueError` if `percent < 0` or `percent > 100` or `subtotal_eur < 0`.

## Safeguard Invariants
- **INV-001:** `Decimal("0.00") <= apply_coupon(subtotal_eur, percent) <= subtotal_eur` for all valid inputs.

## Success Criteria
- **SC-001:** `python3 -m unittest discover -s tests` passes (Falsifier: mutating `100 - percent` to `100 + percent` in `src/pricing.py` fails `test_inv_001_bounds`).
EOF

# Exercise damascus agent-run with a deterministic custom critic backend verifying blind header stripping
CRITIC_OUT="$(DAMASCUS_CUSTOM_CMD="cat" damascus agent-run --backend custom --role critic-a \
    --prompt "Model: qwen2.5-coder:32b
Provider: Ollama
No BLOCKING findings. Spec 001 satisfies FR-001, FR-002, INV-001, and SC-001 vacuity falsifier.")"
echo "$CRITIC_OUT" > "$TMP_PROJECT/specs/001-coupon-pricing/temper-report.md"
check "temper critic output strips model identity header" bash -c "! grep -q 'qwen2.5-coder' '$TMP_PROJECT/specs/001-coupon-pricing/temper-report.md'"
check "temper critic output retains role header" grep -q "### CRITIC A" "$TMP_PROJECT/specs/001-coupon-pricing/temper-report.md"

# 3. Stage 4: Quench (Red -> Amber -> Green with BDD Parity & SHA-256 Test Lock)
echo "--- Stage 4: Quench (Red -> Amber -> Green Mechanized Gates) ---"
mkdir -p "$TMP_PROJECT/src" "$TMP_PROJECT/tests/features"
touch "$TMP_PROJECT/src/__init__.py" "$TMP_PROJECT/tests/__init__.py"

# Write Gherkin feature file
cat > "$TMP_PROJECT/tests/features/coupon.feature" <<'EOF'
Feature: Coupon Pricing
  Scenario: Valid percentage discount
    Given a cart subtotal of 100.00 EUR
    When a 15 percent coupon is applied
    Then the discounted total is 85.00 EUR
EOF

# Verify bdd-check fails BEFORE step binding exists
if damascus bdd-check --repo "$TMP_PROJECT" >/dev/null 2>&1; then
    echo "  [FAIL] bdd-check should fail when .feature is unbound"
    fail=$((fail + 1))
else
    echo "  [PASS] bdd-check rejects unbound coupon.feature"
    pass=$((pass + 1))
fi

# Write unit + invariant test + BDD step binding (Red phase: src/pricing.py does not exist yet)
cat > "$TMP_PROJECT/tests/test_pricing.py" <<'EOF'
from decimal import Decimal
import unittest
from src.pricing import apply_coupon

# Bind features/coupon.feature for BDD parity
FEATURE_BINDING = "features/coupon.feature"


class TestCouponPricing(unittest.TestCase):
    def test_fr_001_valid_discount(self) -> None:
        self.assertEqual(apply_coupon(Decimal("100.00"), 15), Decimal("85.00"))

    def test_fr_002_rejects_invalid_percent(self) -> None:
        with self.assertRaises(ValueError):
            apply_coupon(Decimal("100.00"), 120)

    def test_inv_001_bounds(self) -> None:
        for subtotal_cents in (0, 1, 99, 10000, 99999):
            subtotal = Decimal(subtotal_cents) / Decimal(100)
            for pct in (0, 1, 15, 50, 99, 100):
                res = apply_coupon(subtotal, pct)
                self.assertGreaterEqual(res, Decimal("0.00"))
                self.assertLessEqual(res, subtotal)


if __name__ == "__main__":
    unittest.main()
EOF

check "bdd-check passes once coupon.feature is bound" damascus bdd-check --repo "$TMP_PROJECT"

# Verify Red phase: running tests before src/pricing.py exists fails
if (cd "$TMP_PROJECT" && python3 -m unittest discover -s tests) >/dev/null 2>&1; then
    echo "  [FAIL] Red phase tests should fail before src/pricing.py exists"
    fail=$((fail + 1))
else
    echo "  [PASS] Red phase tests fail as expected before implementation"
    pass=$((pass + 1))
fi

# Amber Gate: Freeze test suite SHA-256 manifest
check "test-lock locks Amber test suite" damascus test-lock lock --repo "$TMP_PROJECT"

# Green Phase: First commit a buggy implementation (seed for Hone revert-proof base_ref)
cat > "$TMP_PROJECT/src/pricing.py" <<'EOF'
from decimal import Decimal, ROUND_HALF_UP


def apply_coupon(subtotal_eur: Decimal, percent: int) -> Decimal:
    if subtotal_eur < Decimal("0.00") or percent < 0 or percent > 100:
        raise ValueError("Invalid subtotal or coupon percentage")
    # Buggy sign: 100 + percent instead of 100 - percent
    factor = Decimal(100 + percent) / Decimal("100")
    return (subtotal_eur * factor).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
EOF

git -C "$TMP_PROJECT" add .
git -C "$TMP_PROJECT" commit -q -m "Buggy pre-fix state for revert-proof base_ref"

# Now write the correct Green implementation
cat > "$TMP_PROJECT/src/pricing.py" <<'EOF'
from decimal import Decimal, ROUND_HALF_UP


def apply_coupon(subtotal_eur: Decimal, percent: int) -> Decimal:
    if subtotal_eur < Decimal("0.00") or percent < 0 or percent > 100:
        raise ValueError("Invalid subtotal or coupon percentage")
    factor = Decimal(100 - percent) / Decimal("100")
    return (subtotal_eur * factor).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
EOF

git -C "$TMP_PROJECT" add src/pricing.py
git -C "$TMP_PROJECT" commit -q -m "Green implementation of apply_coupon"

check "Green phase unit & invariant tests pass" bash -c "cd '$TMP_PROJECT' && python3 -m unittest discover -s tests"
check "test-lock verify confirms zero test tampering during Green" damascus test-lock verify --repo "$TMP_PROJECT"

# 4. Stage 5: Hone (Worktree-Isolated Revert-Proof & 100% Proof Coverage Gate)
echo "--- Stage 5: Hone (Worktree Revert-Proof & Proof Coverage Gate) ---"
REPORT_JSON="$TMP_PROJECT/.damascus/revert-proof-report.json"
check "revert-proof confirms [PASS:RED] when src/pricing.py is reverted to HEAD~1" \
    damascus revert-proof \
    --repo "$TMP_PROJECT" \
    --id "pricing-discount-fix" \
    --base-ref "HEAD~1" \
    --fix-ref "HEAD" \
    --prod-file "src/pricing.py" \
    --test-cmd "python3 -m unittest discover -s tests" \
    --report-out "$REPORT_JSON"

check "proof-coverage confirms 100% of changed production files have RED revert-proof" \
    damascus proof-coverage \
    --repo "$TMP_PROJECT" \
    --base-ref "HEAD~1" \
    --fix-ref "HEAD" \
    --report "$REPORT_JSON"

check "upgrade-consumers upgrades and verifies writable consumer repo" \
    damascus upgrade-consumers --repo "$TMP_PROJECT"

echo ""
echo "=== Dogfood Summary: $pass passed, $fail failed ==="
[[ $fail -eq 0 ]]

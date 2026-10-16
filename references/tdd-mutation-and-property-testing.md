# LLM Test-Driven Development, Mutation-Guided Testing, Property-Based Testing, and Mechanized Revert-Proofs

## 1. Primary References

### LLM Test-Driven Development (TDD)
1. **Mathews, N. S., & Nagappan, M. (2024).** *"Test-Driven Development for Code Generation."* In *Proceedings of the 39th IEEE/ACM International Conference on Automated Software Engineering (ASE 2024)*, `arXiv:2402.13521` (TGen framework).
2. **Mathews, N. S., & Nagappan, M. (2025).** *"Tests as Prompt: A Test-Driven-Development Benchmark for LLM Code Generation."* `arXiv:2505.09027`.

### Mutation-Guided LLM Test Generation & Scientific Debugging
3. **Harman, M., Alshahwan, N., Chheda, N., Fine, J., Godefroid, P., Just, R., Kintis, M., Mao, K., Papadakis, M., Peleg, H., et al. (Meta Platforms, 2025).** *"Mutation-Guided LLM-Based Test Generation at Meta."* In *Proceedings of the ACM International Conference on the Foundations of Software Engineering (FSE 2025 Industry Track)*, `arXiv:2501.12862` (Automated Compliance Hardening / ACH).
4. **Kang, S., Chen, B., Yoo, S., & Lou, J.-G. (2025).** *"Explainable Automated Debugging via Large Language Model-Driven Scientific Debugging."* *Empirical Software Engineering* / `arXiv:2503.08182` (AutoSD — automated hypothesis-test loop for root-cause verification).

### Property-Based Testing (PBT) with LLMs
5. **He, J., Sikka, P., et al. (2025).** *"Property-Generated Solver:orte / Property-Based Testing for LLM Code Generation via Minimal Counterexample Feedback (PGS)."* `arXiv:2506.18315` (Demonstrates $23.1\%\text{–}37.3\%$ relative gains over standard TDD by separating property generation from validation and feeding minimal shrunk counterexamples back to the generator).
6. **Empirical Evaluation of LLM-Generated Property-Based Tests vs. Example-Based Tests (2025).** *"Assessing the Bug-Finding Power and Oracle Quality of LLM-Generated Property-Based Tests."* `arXiv:2510.25297`.

### Legacy & Characterization Testing
7. **Feathers, M. C. (2004).** *Working Effectively with Legacy Code.* Prentice Hall. (Characterization tests: lock existing behavior in place before refactoring).

---

## 2. Red-Amber-Green TDD & Why "Amber" is Essential for AI Agents

### 2.1 Findings from *Tests as Prompt* (Mathews & Nagappan, 2024, 2025)
Empirical studies of LLM-assisted TDD (`arXiv:2402.13521`, `arXiv:2505.09027`) establish two critical results:
1. Providing executable tests alongside problem specifications improves LLM functional pass rates significantly, **provided the tests do not share the same blind spots or hallucinated assumptions as the implementation**.
2. When the *same* agent writes both the test and the implementation simultaneously (or modifies the test while trying to make the implementation pass), **test oracle corruption** occurs in up to $28\%$ of failures: the agent weakens assertions, mocks out the unit under test, or deletes failing edge cases to achieve a green exit code.

### 2.2 Damascus's Red-Amber-Green State Machine (`quench`)
Damascus improves on classical 2-step Red-Green TDD by inserting an explicit **Amber** state in [`skills/quench/SKILL.md`](../skills/quench/SKILL.md):

| State | Definition in [`quench/SKILL.md`](../skills/quench/SKILL.md) | Failure Mode Prevented |
| :--- | :--- | :--- |
| **Red** | Test file exists; collection or import fails (`ImportError`, `ModuleNotFoundError`, missing route/symbol) because the target interface does not exist yet. | Writing implementation before tests exist. |
| **Amber** | Target symbol/stub exists with the right signature (raising `NotImplementedError` or returning placeholder); test **collects cleanly, executes, and fails on the assertion** (`AssertionError`) for the exact expected reason. | Syntax errors in tests, broken fixtures, or tautological tests that pass immediately (`GREEN` before implementation). |
| **Test Freeze** | From the moment Amber is recorded, **tests are frozen read-only**. | Test oracle corruption during implementation. |
| **Green** | Minimal production code written to turn the frozen Amber test(s) Green + clean refactor while staying Green. | Over-engineering or test dilution. |

### 2.3 Empirical Defects Found in Damascus's Current TDD Implementation
1. **Amber Definition Contradiction in Dispatch Agents (`/workspace` at `5bc1e99`):**
   - In `/workspace` (`5bc1e99`), [`agents/tdd-test-generator.md`](../agents/tdd-test-generator.md#L16-L18), [`agents/fastapi-implementer.md`](../agents/fastapi-implementer.md#L16-L18), and [`agents/labcoat.md`](../agents/labcoat.md#L22-L24) define **Amber = Minimal Implementation (tests pass)** and **Green = Refactor**. This directly contradicts [`skills/quench/SKILL.md`](../skills/quench/SKILL.md#L64-L66)! Commit `cc17dc9` in upstream `f77d070` fixes these three files and must be synchronized into `/workspace`.
2. **Dead / Unbound BDD Scenarios Passing Silently (a media service & an auth library):**
   - In `pytest-bdd`, a `.feature` file under `tests/bdd/features/` is **not executed by `pytest`** unless a Python `test_*.py` module invokes `scenarios("features/...")` or `@scenario(...)`.
   - In a media service's production-readiness review (T013) and an auth library (FR-10), `quench` thought BDD scenarios were passing when in fact `pytest` collected **0 scenarios** from the `.feature` file!
   - **Fix:** Add a mandatory **BDD Scenario Collection Gate** to `quench` and [`agents/bdd-scenario-writer.md`](../agents/bdd-scenario-writer.md): verify that `grep -c "^  Scenario" <feature_file>` equals the number of collected `pytest --collect-only -q <step_file>` items at both Amber and Green.

---

## 3. Property-Based Testing (PBT) & Minimal Counterexample Feedback (PGS)

### 3.1 Why Example-Based Tests (EBTs) Are Insufficient Against LLM Bugs
Example-based unit tests (`assert discount(100, 0.1) == 90`) check only a handful of point inputs. LLMs easily satisfy point examples while failing on boundary values, Unicode strings, NaN/Inf floats, empty collections, or state permutations (`arXiv:2510.25297`).

He et al. (2025, *Property-Generated Solver / PGS*, `arXiv:2506.18315`) show that:
1. Expressing specifications as **universal invariants** ($\forall x \in \mathcal{D}, P(x, f(x))$) and executing a property-based testing engine (e.g., Python `hypothesis`, TypeScript `fast-check`, Rust `proptest`, Go `rapid`) catches **3x–5x more subtle boundary bugs** than example-based tests alone.
2. **Shrinking to Minimal Counterexamples:** When a property fails on a complex generated input, the PBT engine automatically *shrinks* the failing input to the **minimal falsifying counterexample** (e.g., `x = [0, -1]`, `s = "\x00"`). Feeding this minimal counterexample back to the implementing agent improves bug-fix accuracy by **$23.1\%\text{–}37.3\%$** compared to raw random test failures.

### 3.2 Strengthening Damascus's `forge → anvil → quench` PBT Pipeline
Commits `ebfc01e` and `6c92bf1` added initial property-testing prose to `forge/SKILL.md` (*"each Must-not turns into a property test or runtime assertion"*) and `quench/SKILL.md`. To make this rigorous and verifiable:
1. **`anvil` Traceability:** In `spec.md` / `tasks.md`, tag every `Must-not` Safeguard from the PRD with an explicit invariant ID (`INV-NNN`) and link it to a task gate (`Gate: hypothesis property test for INV-001`).
2. **Dedicated PBT Section in `agents/tdd-test-generator.md`:** Currently, [`agents/tdd-test-generator.md`](../agents/tdd-test-generator.md) does not contain a single mention of Property-Based Testing (`hypothesis`, `fast-check`, `proptest`)! It must be updated with concrete patterns for:
   - Round-trip / encode-decode invariants (`decode(encode(x)) == x`)
   - Idempotence invariants (`f(f(x)) == f(x)`)
   - Metamorphic invariants (e.g., applying a valid filter never increases result count)
   - Oracle / differential invariants (comparing a fast new implementation against a simple reference implementation during `[REFACTOR]`).

---

## 4. Mutation-Guided Testing & Mechanized Revert-Proofs (`hone` & `quench`)

### 4.1 Meta's Mutation-Guided Test Generation (*ACH*, FSE 2025)
At Meta (Harman et al., 2025, `arXiv:2501.12862`), LLM-generated tests are evaluated not by line coverage (which is easily gamed by assertion-free smoke tests), but by **Mutation Kill Rate**:
- A mutant is a small syntactic fault injected into the code under test (or representing a specific privacy/security regression).
- A test suite is valid **if and only if** it passes on the original code (`GREEN`) and **fails (`RED`) when the mutant is present**.

### 4.2 Mechanizing Damascus's Revert-Proof & Proof-Coverage Protocol
In `skills/hone/SKILL.md` (commit `041164b`), Damascus introduced the **Revert-Proof Rule**:
> *"Every fix must be shown to fail without itself: after the fix is green, revert only the production change (keep the new test), run the test, confirm it fails for the expected reason, then restore the fix."*

However, empirical testing in a PCB-design repo revealed **three systematic ways subagents bypass prose-only revert-proof instructions**:
1. **Unverified Prose Claims:** Subagents write `"Revert-proof: verified test fails when fix is reverted"` in `review.md` without actually running `git checkout` / `git revert`.
2. **False `RED` via `INCONCLUSIVE` / Collection Errors:** When reverting a production change that also added a new symbol or changed an import, pytest exits non-zero at *collection* time (`ImportError`, exit code 2 or 4) before running the test body. A naive check (`exit_code != 0`) mistakes a broken import for an assertion failure!
3. **Partial Hunk Coverage (`Proof-Coverage` Escape):** An agent reverts only 1 out of 5 production diff hunks in Round $N$, leaving 4 changed files without any revert-proof test.

In that PCB-design repo, two compact Python verification scripts solved all three escapes and should be upstreamed directly into Damascus (`scripts/revert-proof.py` and `scripts/proof-coverage.py`):

#### `scripts/revert-proof.py` Contract
- Accepts a JSON manifest (`cases.json`) listing each fix ID, `base_ref`, `fix_ref`, `production_files`, `test_cmd`, and `expected_failure_regex`.
- Executes in an isolated temporary `git worktree` (never dirtying the user's working tree):
  1. **Step 1 (Forward Check at `fix_ref`):** Runs `test_cmd` and verifies exit code `== 0` (`GREEN`).
  2. **Step 2 (Selective Production Revert):** Checks out `production_files` from `base_ref` while keeping `tests/` at `fix_ref`.
  3. **Step 3 (Tri-State Classification):** Runs `test_cmd` and classifies the result strictly into one of three states:
     - **`RED` (Pass):** Test collected and executed, failed (`exit_code == 1`), and output matched `expected_failure_regex`.
     - **`GREEN` (Fail — Vacuous Test):** Test still passed (`exit_code == 0`) even with the production fix reverted!
     - **`INCONCLUSIVE` (Fail — Broken Collection/Harness):** `exit_code in (2, 3, 4)` or `ImportError`/`SyntaxError` before test execution.

#### `scripts/proof-coverage.py` Contract
- Compares `git diff --name-only <base_ref> <fix_ref>` (filtering out `tests/`, `specs/`, `docs/`) against the union of `production_files` covered by `RED` cases in `cases.json`.
- Fails with a non-zero exit code if **any** production file/hunk modified in the round lacks a verified `RED` revert-proof or an explicit, judge-audited exemption (`doc-only`, `type-annotation-only`).

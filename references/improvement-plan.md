# Systematic Review & Science-Based Improvement Plan for Damascus

> Planning record from 2026-10-16 (Antigravity session), kept for history. It was written against `f77d070`; master had moved on — see CHANGELOG.md for what actually landed. The optional owner-only submodules it describes were not published, and private repository names are anonymized.

> [!IMPORTANT]
> All scientific literature, mathematical derivations, and empirical case studies cited in this plan are stored in [`references/`](README.md):
> - [`references/karpathy-autoresearch.md`](karpathy-autoresearch.md) — Karpathy's `autoresearch` architecture & two-tier Damascus blueprints
> - [`references/prompt-and-skill-optimization.md`](prompt-and-skill-optimization.md) — GEPA (`arXiv:2507.19457`), DSPy/MIPROv2 (`arXiv:2406.11695`), and TextGrad (`arXiv:2406.07496`)
> - [`references/adversarial-review-and-llm-judges.md`](adversarial-review-and-llm-judges.md) — Capture-recapture statistics (Lincoln-Petersen, Chapman, Chao), anti-sycophancy, blind judging, and Parnas & Weiss (1985) active design reviews
> - [`references/tdd-mutation-and-property-testing.md`](tdd-mutation-and-property-testing.md) — *Tests as Prompt* (`arXiv:2505.09027`), Meta Mutation-Guided Testing (`arXiv:2501.12862`), Property-Based Testing (`arXiv:2506.18315`), and mechanized revert-proofs
> - [`references/spdd-and-requirements-engineering.md`](spdd-and-requirements-engineering.md) — Thoughtworks REASONS Canvas, `[DELTA]` vs. `[INVARIANT]`, vacuity checks, M0 micro-temper, and domain addenda
> - [`references/model-and-harness-agnosticism.md`](model-and-harness-agnosticism.md) — Vendor-neutral paths (`~/.local/bin`, `.damascus/`, `.agents/skills/`), unified cloud + local model runner (`damascus-agent-run`), small-model context ergonomics

---

## Part 1: Systematic Audit of Damascus (`5bc1e99` vs. `f77d070` & Field Evidence)

### 1.1 Repository & Git State Audit
1. **Upstream Divergence (`5bc1e99` vs. `f77d070`):**
   - `/workspace` was checked out at grafted commit `5bc1e99` (4-stage pipeline: `forge → anvil → temper → quench`), whereas the vendored checkout is 5 commits ahead at `f77d070` (`cc17dc9`, `ebfc01e`, `041164b`, `6c92bf1`, `f77d070`), introducing Stage 5 (`hone`), `quench-log.md`, test freeze at Amber, active critic reading procedures, capture-recapture overlap capping, the Amber definition fix in 3 dispatch agents, and the optional Atlas finish step.
2. **Optional Personal Subrepositories in `vendor/` (not published):**
   - The author keeps 10 personal sibling repositories as local, untracked clones under `vendor/`. The plan considered registering them as optional submodules (`update = none`, `ignore = all`); the published repository leaves them out.

### 1.2 Eight Empirical Flaws Identified Across Damascus & Consumer Repositories

| ID | Severity | Component | Defect / Failure Mode | Empirical Evidence |
| :--- | :--- | :--- | :--- | :--- |
| **F-01** | **CRITICAL** | [`skills/temper/SKILL.md`](../skills/temper/SKILL.md), `skills/hone/SKILL.md` | **Unstratified Capture-Recapture Overlap Cap (`m/D < 25%`):** Computing $m/D$ across `BLOCKING + NIT` findings causes lens-specific NITs (Completeness vs. Feasibility vs. Testability) to permanently cap rounds with **0 BLOCKING** findings at `B+`, preventing `A++` convergence. | An auth library's review.md (19 rounds; required owner override in Round 14) & an API service's review.md (failed 15 rounds across 3 runs). |
| **F-02** | **CRITICAL** | [`agents/tdd-test-generator.md`](../agents/tdd-test-generator.md), [`agents/fastapi-implementer.md`](../agents/fastapi-implementer.md), [`agents/labcoat.md`](../agents/labcoat.md) | **Amber Definition Contradiction (in `5bc1e99`):** Three agents define Amber = "Minimal Implementation" and Green = "Refactor", directly contradicting [`skills/quench/SKILL.md`](../skills/quench/SKILL.md) (Amber = test fails on assertion before implementation). | Fixed in `cc17dc9` (`f77d070`). |
| **F-03** | **HIGH** | [`install.sh`](../install.sh), [`skills/temper/SKILL.md`](../skills/temper/SKILL.md), `skills/hone/SKILL.md`, [`skills/anvil/SKILL.md`](../skills/anvil/SKILL.md) | **Model & Harness Lock-In (`.claude/` Coupling & No Local Model Support):** `install.sh` only links into `.claude/`; `anvil` hardcodes `readlink -f .claude/skills/anvil`; `temper` and `hone` hardcode `claude`/`codex`/`gemini` CLIs with no adapter for local open-weight models (`ollama`, `llama.cpp`, `vLLM`, `LM Studio`) or vendor-neutral `.agents/skills/` paths. | [`install.sh`](../install.sh), [`skills/anvil/SKILL.md`](../skills/anvil/SKILL.md#L91), [`skills/temper/SKILL.md`](../skills/temper/SKILL.md#L56-L69). |
| **F-04** | **HIGH** | `skills/hone/SKILL.md`, [`skills/quench/SKILL.md`](../skills/quench/SKILL.md) | **Unmechanized Revert-Proofs & Test Freeze:** Prose-only rules for "tests are frozen at Amber" and "every fix must fail without itself" are bypassed by subagents claiming revert-proofs without running them, mistaking `INCONCLUSIVE` import errors for `RED`, or omitting diff hunks. | Solved in a PCB-design repo via mechanized `revert-proof.py` and `proof-coverage.py`, which are missing from Damascus. |
| **F-05** | **HIGH** | [`skills/quench/SKILL.md`](../skills/quench/SKILL.md), [`agents/bdd-scenario-writer.md`](../agents/bdd-scenario-writer.md) | **Silent Unbound BDD `.feature` Scenarios:** `pytest` exits 0 when `.feature` files are not bound via `scenarios(...)` in a `test_*.py` module, creating a false Green gate. | A media service's review.md (T013) & an auth library (FR-10). |
| **F-06** | **HIGH** | [`agents/fastapi-implementer.md`](../agents/fastapi-implementer.md), [`agents/playwright-e2e-tester.md`](../agents/playwright-e2e-tester.md), [`agents/tdd-test-generator.md`](../agents/tdd-test-generator.md) | **Deprecated Idioms, Stack Lock-In & 600-Line Bloat Hostile to Local Models:** `fastapi-implementer.md` teaches deprecated Pydantic v1 (`@validator`, `class Config`), SQLAlchemy 1.x `db.query()`, FastAPI `Query(regex=...)`, and naive `datetime.utcnow()`. `playwright-e2e-tester.md` mixes `playwright.config.ts` with 500 lines of Python `pytest-playwright`. Three agents hardcode 500+ lines of MITRE ATT&CK STIX `T1059.001` examples (~$5\,500$ tokens that overflow local 8k–16k KV caches) and lack Property-Based Testing guidance. | A crud service's review.md (T013/T014 naive datetime & SQLAlchemy 2.0 regressions). |
| **F-07** | **MEDIUM** | [`skills/anvil/SKILL.md`](../skills/anvil/SKILL.md), [`skills/temper/SKILL.md`](../skills/temper/SKILL.md) | **Missing Brownfield `[DELTA]` vs. `[INVARIANT]` Tags, Vacuity Check, M0 Micro-Temper, and Domain Addenda Hook:** Brownfield specs lack `[INVARIANT]` preservation tags; SCs lack vacuity verification; Golden-Rule spec edits lack a 1-round M0 micro-temper; domain repos (`pcb-*`) have to fork all 5 skills to add a 4th critic lens. | Proven in an earlier analysis and a PCB-design repo. |
| **F-08** | **MEDIUM** | [`skills/anvil/SKILL.md`](../skills/anvil/SKILL.md#L91), [`docs/production-readiness.md`](../docs/production-readiness.md) | **Portability & Release Hygiene:** `skills/anvil/SKILL.md` line 91 uses non-portable `readlink -f` (fails on stock macOS BSD userland); `v0.1.0`/`v0.2.0` git tags and `examples/` walkthrough from `docs/production-readiness.md` remain uncompleted. | [`skills/anvil/SKILL.md`](../skills/anvil/SKILL.md#L91) & [`docs/production-readiness.md`](../docs/production-readiness.md). |

---

## Part 2: Architectural Decisions (Locked In)

1. **Optional Personal Subrepos (not published):**
   - Considered: register them in `.gitmodules` with `update = none` and `ignore = all` so external clones skip them. Decided against publishing them; the author keeps local, untracked clones.
2. **Vendor-Neutral Executable Tools (`~/.local/bin/`) & Project State (`.damascus/`):**
   - All mechanized verification and dispatch tools (`damascus`, `damascus-agent-run`, `damascus-revert-proof`, `damascus-proof-coverage`, `damascus-test-lock`, `damascus-bdd-check`) live in `scripts/` inside the Damascus repo and are symlinked into `~/.local/bin/` (`$BIN_DIR`) on `PATH` by [`install.sh`](../install.sh)—never inside `.claude/scripts/`.
   - All per-repo state, locks, and domain addenda live in `.damascus/` (`.damascus/addenda/<stage>.md`, `.damascus/locks/`, `.damascus/models.conf`).
   - [`install.sh`](../install.sh) installs skills across `.agents/skills/` (vendor-neutral cross-agent standard), `.claude/{skills,agents}`, and `.gemini/skills/`.
3. **Universal Cloud + Local Model Runner (`damascus-agent-run`):**
   - Both in-pipeline critic/subagent dispatches (`temper`, `hone`, `quench`) and the meta-autoresearch evaluation harness (`evals/run_eval.py`) route through `damascus-agent-run`, which supports:
     - **Local OpenAI-compatible servers** (`llama.cpp` / `llama-server`, `vLLM`, `SGLang`, `LM Studio`, `LocalAI` via `DAMASCUS_LOCAL_URL` / `OPENAI_BASE_URL`).
     - **Local Ollama** (`ollama run` / `http://127.0.0.1:11434/api/chat`).
     - **Cloud CLIs** (`claude -p`, `gemini -p`, `codex exec`, `opencode run`, `llm`).

---

## Part 3: Phased Implementation & Science Integration Plan

```mermaid
flowchart LR
    P0["Phase 0\nFast-Forward f77d070 &\nOptional Submodules"] --> P1["Phase 1\nModel-Agnostic Layout &\ndamascus-agent-run"]
    P1 --> P2["Phase 2\nFix Review & Spec Science\n(Overlap Cap, Vacuity, Blind Judge)"]
    P2 --> P3["Phase 3\nMechanize Harnesses\n(revert-proof, coverage, test-lock)"]
    P3 --> P4["Phase 4\nModernize & Compress\nAgents for Local Models"]
    P4 --> P5["Phase 5\nKarpathy Autoresearch +\nGEPA/TextGrad & Examples"]
```

---

### Phase 0: Fast-Forward to `f77d070` & Configure Optional Personal Submodules

**Objective:** Bring `/workspace` up to the 5-stage (`forge → anvil → temper → quench → hone`) baseline (`f77d070`), restore `vendor/spec-kit`.

1. **Fast-Forward `/workspace` `master` to `f77d070` & Restore `vendor/spec-kit`:**
   - Merge `f77d070` (`--ff-only`) into `/workspace` `master` and restore `vendor/spec-kit` from the vendored checkout.
2. **Register Optional Personal Subrepos:** not done in the published repository (see Part 2).
3. **Verification Gate:**
   - Test a fresh `git clone --recurse-submodules` in a temporary directory with network disabled to prove external clones skip all 10 private subrepos and succeed with exit code `0`.
   - Run `bash tests/smoke.sh` and confirm exit code `0`.

---

### Phase 1: Model & Harness Agnosticism (`damascus-agent-run`, `~/.local/bin`, `.agents/skills/`, `.damascus/`)

**Objective:** Eliminate `.claude/` coupling and enable seamless execution across local open-weight models (`ollama`, `llama.cpp`, `vLLM`, `LM Studio`) and all cloud CLIs (`F-03`, `F-08`).
*(See [`references/model-and-harness-agnosticism.md`](model-and-harness-agnosticism.md).)*

1. **Create `scripts/damascus-agent-run`:**
   - Zero-dependency Python 3 / POSIX adapter supporting `--probe`, `--role <critic-a|critic-b|critic-c|judge|implementer>`, `--backend <auto|local-openai|ollama|claude|gemini|codex|opencode|llm>`, `--model <id>`, `--system-file`, and `--input-file`.
   - Automatically strips model/provider headers from critic outputs to guarantee blind judging.
2. **Upgrade [`install.sh`](../install.sh) for Multi-Harness & `PATH` Tooling:**
   - Add `damascus --print-root` (returning the Damascus repo path portably without `readlink -f .claude/...`).
   - Symlink all `scripts/damascus-*` executables into `$BIN_DIR` (`~/.local/bin`).
   - Link skills into `.agents/skills/` (vendor-neutral standard) as well as `.claude/skills/` and `.gemini/skills/` (when present or requested).
3. **Update [`skills/anvil/SKILL.md`](../skills/anvil/SKILL.md), [`skills/temper/SKILL.md`](../skills/temper/SKILL.md), `skills/hone/SKILL.md`, [`skills/quench/SKILL.md`](../skills/quench/SKILL.md), and [`skills/smithy/SKILL.md`](../skills/smithy/SKILL.md):**
   - Replace `readlink -f .claude/skills/anvil` with `$(damascus --print-root)`.
   - Replace hardcoded `command -v claude codex gemini` critic dispatch blocks with `damascus-agent-run --probe` and `damascus-agent-run --role ...` so local Ollama / `llama.cpp` / `vLLM` models participate natively as first-class critics, judges, or implementers.

---

### Phase 2: Scientific Fixes to Adversarial Review (`temper` & `hone`) and Spec Engineering (`forge` & `anvil`)

**Objective:** Eliminate the empirical non-convergence bugs (`F-01`, `F-07`) using capture-recapture stratification, anti-sycophancy blind evaluation, vacuity checking, and brownfield `[DELTA]`/`[INVARIANT]` tagging.
*(See [`references/adversarial-review-and-llm-judges.md`](adversarial-review-and-llm-judges.md) and [`references/spdd-and-requirements-engineering.md`](spdd-and-requirements-engineering.md).)*

1. **Stratify Capture-Recapture Overlap Strictly Over `BLOCKING` Findings ([`skills/temper/SKILL.md`](../skills/temper/SKILL.md) & `skills/hone/SKILL.md`):**
   - Define $D_B$ = distinct `BLOCKING` findings after deduplication, $m_B$ = `BLOCKING` findings raised by $\ge 2$ critics.
   - Apply the `B+` overlap cap **if and only if** $D_B \ge 4$ and $m_B / D_B < 0.25$.
   - Explicitly specify that when $D_B = 0$, disjoint `NIT` findings **never** cap the round at `B+`.
   - Add a **20% Shared Core Checklist** to all 3 critics so cross-critic overlap on genuine `BLOCKING` defects is statistically calibrated.
2. **Enforce Anti-Sycophancy, Delta Context Passing & Blind Judge Evaluation:**
   - **Round & Grade Blindness for Critics:** Critics A, B, and C are never told the current round number or prior grade (`A`/`A+`).
   - **Delta Context Passing for Local-Model Efficiency:** Pass the current artifact + compact Round $r-1$ Fix Diff Manifest rather than the entire cumulative `review.md` history.
   - **Fresh-Critic Rotation on `A+ → A++`:** Rotate model assignment or inject a red-team falsification prompt on the confirmation round after `A+`.
3. **Add `[DELTA]` vs. `[INVARIANT]` Classification, Vacuity Checks & M0 Micro-Temper:**
   - Tag brownfield requirements as `[DELTA]` or `[INVARIANT]` in [`skills/anvil/SKILL.md`](../skills/anvil/SKILL.md).
   - Add a **Vacuity Check** column to Critic C's active reading table in [`skills/temper/SKILL.md`](../skills/temper/SKILL.md).
   - Add a single-round **M0 Micro-Temper** scoped to `Spec Change Records (SCR-NNN)` for mid-`quench` / mid-`hone` Golden Rule amendments.

---

### Phase 3: Mechanized Verification Harnesses (`scripts/damascus-*`)

**Objective:** Offload state verification from LLM prompt reasoning to immutable, deterministic CLI scripts on `PATH` (`F-04`, `F-05`), dramatically improving reliability on both frontier and local models.
*(See [`references/tdd-mutation-and-property-testing.md`](tdd-mutation-and-property-testing.md).)*

1. **`scripts/damascus-revert-proof` & `scripts/damascus-proof-coverage`:**
   - Worktree-isolated verification of `cases.json` in `hone` and `quench`.
   - Enforces tri-state classification (`RED` vs. `GREEN` vs. `INCONCLUSIVE`) so broken imports (`exit_code >= 2`) cannot pass as `RED`, and verifies 100% hunk coverage across changed production files.
2. **`scripts/damascus-test-lock` (Mechanized Amber Test Freeze in `quench`):**
   - Records `.damascus/locks/amber-tests.sha256` at Amber (`damascus-test-lock lock`) and verifies zero unauthorized test modifications at Green (`damascus-test-lock verify`).
3. **`scripts/damascus-bdd-check` (BDD Scenario Collection Gate):**
   - Verifies that every `Scenario:` / `Scenario Outline:` in `.feature` files is collected by the test runner (`pytest --collect-only` / Cucumber dry-run), preventing silent unbound `.feature` files.

---

### Phase 4: Modernize, Compress, and Add Property-Based Testing to Dispatch Agents (`agents/*.md`)

**Objective:** Eliminate deprecated library idioms, compress agent prompts to $\le 150$ lines so they fit comfortably in 8k–32k local model KV caches, and add Property-Based Testing (`F-06`).
*(See [`references/prompt-and-skill-optimization.md`](prompt-and-skill-optimization.md) and [`references/tdd-mutation-and-property-testing.md`](tdd-mutation-and-property-testing.md).)*

1. **Modernize [`agents/fastapi-implementer.md`](../agents/fastapi-implementer.md):**
   - Upgrade to Pydantic v2 (`@field_validator`, `ConfigDict(from_attributes=True)`), SQLAlchemy 2.0 (`select()`, `Session.scalars()`), FastAPI `Query(pattern=...)`, and timezone-aware `datetime.now(timezone.utc)`.
2. **Add Property-Based Testing (PBT) & Characterization Testing to [`agents/tdd-test-generator.md`](../agents/tdd-test-generator.md):**
   - Add patterns for compiling PRD **Safeguards (`Must-not` / `INV-NNN`)** into property-based tests (`hypothesis`, `fast-check`, `proptest`) with minimal counterexample shrinking (PGS, `arXiv:2506.18315`), plus Feathers characterization tests for `[REFACTOR]` and `[INVARIANT]` tasks.
3. **Align [`agents/playwright-e2e-tester.md`](../agents/playwright-e2e-tester.md) & Compress All 5 Agents to $\le 150$ Lines:**
   - Remove the 500+ lines of hardcoded cybersecurity STIX/MITRE ATT&CK boilerplate across all agents, reducing static prompt token overhead by $>75\%$ for local models.

---

### Phase 5: Karpathy `autoresearch` + GEPA/TextGrad Harness, Composable Addenda & Worked Example

**Objective:** Operationalize Karpathy's `autoresearch` at both Tier 1 (`evals/` meta-optimization) and Tier 2 (in-pipeline `[HARD]` task and mutation ratchets), wire `.damascus/addenda/<stage>.md`, and complete [`docs/production-readiness.md`](../docs/production-readiness.md).
*(See [`references/karpathy-autoresearch.md`](karpathy-autoresearch.md).)*

1. **Tier 1 Meta-Autoresearch Harness (`evals/`):**
   - `evals/program.md` + `evals/run_eval.py` (invoking `damascus-agent-run` so evaluations run identically on local Ollama/`llama.cpp` models or cloud CLIs) + seeded defect corpus (`evals/corpus/{temper,hone}/`) + `evals/results.tsv`.
2. **Tier 2 In-Pipeline `autoresearch` Loop ([`skills/quench/SKILL.md`](../skills/quench/SKILL.md) & [`agents/labcoat.md`](../agents/labcoat.md)):**
   - Bounded $N \le 5$ iteration keep/revert ratchet for `[HARD]` tasks with quantitative metrics and mutation-guided test hardening (`specs/NNN-<slug>/autoresearch-<task-id>.tsv`).
3. **Composable `.damascus/addenda/<stage>.md` Hook & Worked Example (`examples/cart-discounts/`):**
   - Allow host repos to attach domain-specific norms and extra critic lenses via `.damascus/addenda/<stage>.md` without forking Damascus skills.
   - Ship a complete end-to-end worked example under `examples/cart-discounts/` and add the stage-entry decision table to [`README.md`](../README.md).

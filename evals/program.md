# Damascus Meta-Autoresearch Program (`evals/program.md`)

This file is the **Karpathy `autoresearch` directive (`program.md`)** for scientifically evolving Damascus's stage skills ([`skills/*/SKILL.md`](../skills)) and dispatch agents ([`agents/*.md`](../agents)) using trace-driven reflection (**GEPA** `arXiv:2507.19457` & **TextGrad** `arXiv:2406.07496`).

---

## 1. Separation of Responsibilities (3-Component Topology)

| Role | Files | Mutability During Autoresearch |
| :--- | :--- | :--- |
| **Research Directives (`program.md`)** | `evals/program.md` | **Human-authored (Read-Only to Agent)** |
| **Editable Target (`train`)** | `skills/*/SKILL.md`, `agents/*.md` | **Agent-Editable** |
| **Evaluation Harness (`prepare`)** | `evals/run_eval.py`, `tests/smoke.sh`, `scripts/damascus-*` | **Strictly Immutable / Read-Only** |

> **Hard Invariant:** Never modify `evals/run_eval.py` or `tests/smoke.sh` during an optimization loop to make a failing metric pass. Goodharting the evaluator invalidates the run.

---

## 2. Scalar Objective Metric ($J_{\text{damascus}}$)

Run the immutable evaluation harness from the repository root:

```bash
./install.sh eval
# or with live LLM critic rollouts via any local (Ollama, llama.cpp, vLLM) or cloud backend:
./install.sh eval --live-llm --backend auto
```

`evals/run_eval.py` computes a deterministic composite score $J_{\text{damascus}} \in [0.0, 100.0]$ across four orthogonal components:

1. **Installer & Multi-Harness Smoke Suite ($25\text{ pts}$):** `tests/smoke.sh` exit code across `.claude/` and vendor-neutral `.agents/`.
2. **Mechanized Harness Seeded-Defect Recall & Precision ($35\text{ pts}$):** Live execution of `damascus revert-proof` (tri-state `RED`/`GREEN`/`INCONCLUSIVE`), `damascus proof-coverage` (uncovered hunk detection), `damascus test-lock` (Amber test-freeze tamper detection), `damascus bdd-check` (unbound `.feature` detection), and `damascus agent-run` (blind identity stripping).
3. **Scientific Protocol & Model-Agnosticism Invariants ($25\text{ pts}$):** Verifies BLOCKING-only capture-recapture stratification ($D_B, m_B$), vacuity falsification checks, M0 micro-temper, composable `.damascus/addenda/<stage>.md` hooks, `model: inherit` across all agents, and zero deprecated Pydantic v1 / SQLAlchemy 1.x / naive UTC patterns.
4. **Karpathy Simplicity Regularizer ($15\text{ pts}$):** Rewards concise, local-model-friendly prompts (penalizing any `agents/*.md` file exceeding $150$ lines or `skills/*/SKILL.md` file exceeding $260$ lines).

**Live critic benchmark (`--live-llm`, reported separately, not part of $J_{\text{damascus}}$).** Every case in `evals/corpus/seeded_cases.json`, the clean control included, goes to a real critic. A seeded defect counts as found only when one `[BLOCKING]` finding names it (an `anchors` term: its ID, task or symbol) **and** says what is wrong with a `diagnosis` term that occurs nowhere in the prompt. Words the critic could copy from its input earn nothing, so echoing the prompt scores 0. The report gives recall, BLOCKING findings on the clean control (false positives), other BLOCKING findings on seeded cases, and the echo baseline. Each prompt and raw reply is saved under `.damascus/eval-runs/` for audit. `--check-corpus` self-checks the scorer and corpus in CI: echo scores 0, every defect is matched by its own `description` and by no sibling's, and NIT lines never count. When adding a case, give every defect anchors and diagnosis terms that pass that check. `--runs N` sends the corpus N times and reports recall per run, its mean and range, and how often each defect was found; `--critic-timeout` sets how long one critic call may take (default 170 s). **Tuning the scorer:** a diagnosis term added after reading replies must come from a backend you are *not* about to report; then rerun the reported backend with the scorer frozen and quote only that run. Terms taken from the replies being scored fit the scorer to that model.

---

## 3. Autonomous Keep/Revert Ratchet Protocol

Each iteration $t = 1, 2, \dots$ executes the following state machine:

1. **Reflect on Failure Traces (GEPA / TextGrad Step):**
   - Inspect the diagnostic breakdown from `./install.sh eval` (or historical `review.md` / `quench-log.md` traces from consumer repositories).
   - Formulate a single falsifiable hypothesis explaining which instruction in `skills/<stage>/SKILL.md` or `agents/<agent>.md` caused the miss, false positive, or token bloat.
2. **Apply Candidate Mutation:**
   - Edit the target `SKILL.md` or `agents/*.md` file.
3. **Evaluate Under Fixed Budget:**
   - Run `./install.sh eval` (timeout $\le 120\text{ s}$).
4. **Keep or Revert Decision:**
   - **KEEP (`git commit`):** If $J_{\text{damascus}}^{(t)} > J_{\text{damascus}}^{\text{best}}$, OR if $J_{\text{damascus}}^{(t)} == J_{\text{damascus}}^{\text{best}}$ while strictly reducing total prompt line count (`total_prompt_lines`).
   - **REVERT (`git checkout -- skills/ agents/`):** Otherwise.
5. **Append to `evals/results.tsv`:**
   - Record `timestamp`, `commit`, `score`, `smoke_pts`, `harness_pts`, `protocol_pts`, `simplicity_pts`, `total_prompt_lines`, `status`, and `hypothesis`.

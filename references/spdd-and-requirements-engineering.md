# Specification-Driven Development (SPDD), REASONS Canvas, and Formal Requirements Engineering

## 1. Primary References

1. **Zhang, W., & Xia, J. J. (2025).** *"Specification-Driven Development (SPDD) and the REASONS Canvas: Structuring Requirements for AI-Native Software Delivery."* Thoughtworks / MartinFowler.com.
2. **GitHub Next / Spec-Kit Contributors (2025).** *`spec-kit`: Specification-Driven Development Templates and Slash Commands (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.analyze`).* Vendored in Damascus at `vendor/spec-kit`.
3. **Kupferman, O., & Vardi, M. Y. (2003).** *"Vacuity Detection in Temporal Model Checking."* *International Journal on Software Tools for Technology Transfer (STTT)*, 4(2), 224–233.
4. **Empirical Field Studies in Sibling Repositories:**
   - An earlier analysis (its PRD and README) — Transposing Damascus to brownfield enterprise requirements engineering (Delta vs. Invariant separation, Vacuity Checks, M0 Micro-Temper).
   - A pcb-design repo (its `pcb-{forge,anvil,temper,quench,hone}` skills) — Extending Damascus with domain-specific hardware/EDA addenda and a 4th critic lens (`manufacturability`).

---

## 2. The REASONS Canvas & Closing the Prose-to-Gate Gap

In Thoughtworks' SPDD methodology (Zhang & Xia, 2025), the **REASONS Canvas** structures every product specification across seven interdependent dimensions:

| Letter | Dimension | Stage 1 ([`forge`](../skills/forge/SKILL.md)) Output | Stage 2 ([`anvil`](../skills/anvil/SKILL.md)) / Stage 4 ([`quench`](../skills/quench/SKILL.md)) Gate |
| :--- | :--- | :--- | :--- |
| **R** | **Requirements** | User goals, explicit non-goals, acceptance stories | `spec.md` `FR-NNN` & `SC-NNN` $\to$ BDD `.feature` scenarios |
| **E** | **Entities** | Domain concepts, relationships, lifecycle states | Data models, state-transition unit & property tests |
| **A** | **Approach** | Chosen technical design + rejected alternatives | `plan.md` architecture & `[HARD]` sample-and-select / autoresearch |
| **S** | **Structure** | Modules/files touched, API/CLI contracts | `tasks.md` explicit file paths + $\le 400$-line task sizing |
| **O** | **Operations** | Deployment, config, observability, rollback | Health check / metrics / migration verification gates |
| **N** | **Norms** | Coding standards, typing, complexity limits | **Machine-checked linter/type-checker/scanner commands** |
| **S** | **Safeguards** | Must-nots, failure modes, security boundaries | **Property-based tests (`INV-NNN`) & negative security tests** |

### Why Prose Norms & Safeguards Fail Without Mechanization
Prior to commit `ebfc01e`, `Norms` and `Safeguards` in `forge` were written as prose adjectives (e.g., *"Follow PEP 8, high quality, never lose data"*). Implementing agents routinely ignored prose norms when under task pressure.
- **Upgrade Principle:** Every item under **Norms** must specify an executable CLI gate (e.g., `ruff check .`, `mypy --strict src/`, `bandit -r src/`), and every **Must-not** under **Safeguards** must compile into an `INV-NNN` property test or negative test assertion in `tasks.md`.

---

## 3. Formal Requirements Innovations from an Earlier Analysis

When Damascus is applied to **existing (brownfield) repositories** rather than greenfield prototypes, four specification failure modes arise that were solved in an earlier analysis and should be upstreamed into core Damascus:

### 3.1 `[DELTA]` vs. `[INVARIANT]` Requirement Classification
In brownfield systems, a specification must distinguish between:
- **`[DELTA]` Requirements:** Behavior that **must change** from the current baseline (so a test against the pre-change codebase **must fail** at Amber).
- **`[INVARIANT]` Requirements:** Existing behavior that **must be preserved** across the change (so a characterization test against the pre-change codebase **must pass** before and after the change).

**Why this matters in `quench`:**
If `anvil` does not tag requirements as `[DELTA]` vs. `[INVARIANT]`, `quench` tries to force every requirement through Red $\to$ Amber $\to$ Green. For an `[INVARIANT]` preservation requirement, the test *already passes* on the baseline codebase! Without the `[INVARIANT]` distinction, subagents either get confused why the test is already Green or artificially break existing code just to manufacture an Amber state.

### 3.2 Vacuity Detection for Success Criteria (`SC-NNN`)
Borrowing from formal verification (Kupferman & Vardi, 2003), a specification criterion `SC-NNN` is **vacuously satisfied** if an empty system, a constant stub (`return True`), or an unmodified baseline already satisfies the criterion's stated verification method.
- **Vacuity Check in `anvil` & `temper` (Critic C — Testability):**
  For every `SC-NNN` in `spec.md`, Critic C must answer:
  1. *What concrete single-line mutation or stub implementation would cause `SC-NNN`'s verification check to fail?*
  2. *For `[DELTA]` criteria, does `SC-NNN`'s check fail against `HEAD` prior to implementation?*
  If no concrete falsifying state exists, `SC-NNN` is flagged `BLOCKING (Vacuous Criterion)`.

### 3.3 M0 Micro-Temper for Golden-Rule Spec Amendments
In [`skills/quench/SKILL.md`](../skills/quench/SKILL.md) and `skills/hone/SKILL.md`, the **Golden Rule** states:
> *"When implementation reveals the spec is wrong or incomplete, stop coding, update `spec.md`/`plan.md`/`tasks.md` first, record the reason, then resume."*

However, in standard Damascus, if a developer or orchestrator updates `spec.md` mid-`quench` or mid-`hone`, either:
- They skip `temper` entirely (allowing an unreviewed, potentially contradictory spec edit into the baseline), or
- They re-run a full 5-round `temper` cycle (too heavy for a 5-line spec clarification).

**Solution — M0 Micro-Temper (`temper --amend`):**
When the Golden Rule triggers a localized spec amendment during `quench` or `hone`:
1. Record a structured **Spec Change Record (`SCR-NNN`)** at the bottom of `spec.md` (`Trigger`, `Changed FR/SC/Task`, `Blast Radius`).
2. Run a **single-round M0 Micro-Temper pass** scoped strictly to `SCR-NNN` and its neighboring FRs/tasks. If 0 `BLOCKING` findings are raised, the amendment is ratified in 1 round and `quench`/`hone` resumes immediately.

---

## 4. Extensible Domain Lens Addenda (`pcb-*` Pattern)

In a PCB-design repo (its `pcb-temper` skill), Damascus was adapted to hardware PCB design by layering **domain-specific addenda** onto the five core skills:
- `pcb-forge` added datasheet pinning and physical board constraints to the REASONS Canvas.
- `pcb-temper` added a **4th orthogonal critic lens (`manufacturability` — DFM/DRC/JLCPCB fabrication limits)** alongside Completeness, Feasibility, and Testability.
- `pcb-hone` added physical netlist-vs-schematic parity checks and IPC class rules.

Currently, consumer repositories had to **fork and duplicate** the entire Damascus skill directory (`pcb-forge`, `pcb-anvil`, `pcb-temper`, `pcb-quench`, `pcb-hone`) to add domain rules, causing immediate drift when Damascus updated upstream!

### Architectural Solution: Composable `.claude/damascus.local.md` / `.damascus/addenda/` Hooks
Instead of forking Damascus skills per domain, each Damascus stage skill (`forge`, `anvil`, `temper`, `quench`, `hone`) should check for an optional host-repo addendum file:
- `.damascus/addenda/<stage>.md` (e.g., `.damascus/addenda/temper.md`, `.damascus/addenda/hone.md`)
- If present, the stage skill dynamically loads the host repository's extra REASONS prompts, extra Critic D lens definition, or domain-specific gate commands—preserving a single upstream Damascus installation via `install.sh` with zero fork drift.

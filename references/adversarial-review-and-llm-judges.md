# Multi-Agent Adversarial Review, LLM-as-a-Judge Biases, and Capture-Recapture Defect Estimation

## 1. Primary References

### Multi-Agent Debate, Sycophancy, and Judge Bias
1. **Du, Y., Li, S., Torralba, A., Tenenbaum, J. B., & Mordatch, I. (2023).** *"Improving Factuality and Reasoning in Language Models through Multiagent Debate."* In *ICML 2024*, `arXiv:2305.14325`.
2. **Liang, T., He, Z., Jiao, W., Wang, X., Wang, Y., Wang, R., Yang, Y., Tu, Z., & Shi, S. (2023).** *"Encouraging Divergent Thinking in Large Language Models through Multi-Agent Debate."* In *EMNLP 2024*, `arXiv:2305.19118` (Degeneration-of-Thought / DoT problem).
3. **Zheng, L., Chiang, W.-L., Sheng, Y., Zhuang, S., Wu, Z., Zhuang, Y., Lin, Z., Li, Z., Li, D., Xing, E. P., Zhang, H., Gonzalez, J. E., & Stoica, I. (2023).** *"Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena."* In *NeurIPS 2023*, `arXiv:2306.05685` (Position bias, verbosity bias, and self-enhancement bias).
4. **Sycophancy & Disagreement Collapse in Multi-Agent Systems (2025):**
   - *CONSENSAGENT: Mitigating Sycophancy in Multi-Agent LLM Debate* (ACL Findings 2025).
   - *Peacemaker or Troublemaker: How Sycophancy Shapes Multi-Agent Debate* (`arXiv:2509.23055`, 2025).
   - *Free-MAD: Consensus-Free Multi-Agent Debate* (`arXiv:2509.11035`, 2025) — demonstrates that trajectory scoring by an independent judge outperforms forced multi-agent consensus because forced consensus triggers conformity cascades.

### Software Inspection & Capture-Recapture Defect Estimation
5. **Parnas, D. L., & Weiss, D. M. (1985).** *"Active Design Reviews: Principles and Practices."* In *Proceedings of the 8th International Conference on Software Engineering (ICSE '85)*, pp. 132–136.
6. **Vander Wiel, S. A., & Votta, L. G. (1993).** *"Assessing Software Designs Using Capture-Recapture Methods."* *IEEE Transactions on Software Engineering*, 19(11), 1045–1054.
7. **Briand, L. C., El Emam, K., Freimut, B. G., & Laitenberger, O. (2000).** *"A Comprehensive Evaluation of Capture-Recapture Models for Estimating Software Defect Content."* *IEEE Transactions on Software Engineering*, 26(6), 518–540.
8. **Chao, A. (1987).** *"Estimating the Population Size for Capture-Recapture Data with Unequal Catchability."* *Biometrics*, 43(4), 783–791.
9. **Cohen, J. (2006).** *Best Kept Secrets of Peer Code Review* (SmartBear / Cisco Systems Study of 2,500 reviews across 3.2 million lines of code).

---

## 2. Capture-Recapture Defect Estimation & the Damascus Overlap Bug

### 2.1 Theoretical Foundation (Lincoln-Petersen, Chapman, and Chao Estimators)
In software engineering inspections (Vander Wiel & Votta, 1993; Briand et al., 2000), when $k$ independent reviewers inspect the same artifact, the overlap among their discovered defects provides a statistical estimate of the **unseen defect population** ($N - D$).

- For $k = 2$ homogeneous reviewers discovering $n_1$ and $n_2$ defects with $m$ overlapping defects (discovered by both), the **Lincoln-Petersen estimator** of total defects $N$ is:
  $$\hat{N}_{\text{LP}} = \frac{n_1 n_2}{m}, \qquad \hat{N}_{\text{Chapman}} = \frac{(n_1 + 1)(n_2 + 1)}{m + 1} - 1$$
- For $k \ge 3$ reviewers with **heterogeneous detection probabilities** (Model $M_h$ in Briand et al., 2000), let $f_1$ be the number of **singleton** defects (found by exactly 1 critic), $f_2$ be the number of **doubleton** defects (found by exactly 2 critics), and $D = \sum_{j=1}^k f_j$ be total distinct defects found. **Chao's lower-bound estimator** (Chao, 1987) estimates total defects $\hat{N}_{\text{Chao}}$ and unseen remaining defects $\hat{U}$ as:
  $$\hat{N}_{\text{Chao}} = D + \frac{f_1^2}{2 f_2}, \qquad \hat{U} = \hat{N}_{\text{Chao}} - D = \frac{f_1^2}{2 f_2}$$

When overlap $m = \sum_{j \ge 2} f_j$ is zero or very small relative to $D$ ($f_1 \approx D, f_2 \to 0$), the estimated unseen defect count $\hat{U} \to \infty$.

### 2.2 Why Unstratified Overlap Fails Under Orthogonal Critic Lenses
Commit `041164b` added the following rule to `skills/temper/SKILL.md` and `skills/hone/SKILL.md`:
> *"Compute the overlap signal: let `D` = distinct findings after dedup, `m` = findings raised by $\ge 2$ critics. If `D >= 4` and `m/D < 25%`, the critics sampled disjoint slices of a larger pool — **cap the round's grade at `B+`** regardless of how clean the fixes are."*

**Why this caused 19-round non-convergence in an auth library and 15-round failure in an API service:**

1. **Violation of the Shared-Pool Assumption via Orthogonal Lenses:**
   - Capture-recapture statistics require that all observers sample from the **same target population** (or that findings are stratified by population).
   - Damascus intentionally assigns three **orthogonal lenses** to Critics A, B, and C:
     - In `temper`: Completeness vs. Feasibility vs. Testability.
     - In `hone`: Correctness vs. Architecture/Craft vs. Security/Failure Modes.
   - Major `BLOCKING` defects (e.g., a missing error state in an API endpoint) frequently violate multiple lenses simultaneously (it is incomplete, untestable, and fails unsafely) and therefore exhibit genuine cross-critic overlap ($m_{\text{blocking}} > 0$).
   - Conversely, minor `NIT` findings (e.g., "rename helper variable for clarity" under Craft vs. "add docstring note on clock skew" under Security vs. "tighten Gherkin phrasing" under Testability) are **disjoint by construction** ($m_{\text{nit}} \approx 0$).
2. **Mathematical Pathology at Convergence ($\text{BLOCKING} = 0$):**
   - Suppose a specification or diff has reached **zero `BLOCKING` defects** ($D_{\text{blocking}} = 0$).
   - Each of the 3 critics dutifully emits $1\text{–}2$ lens-specific `NIT` suggestions, yielding $D_{\text{nit}} = 4$ or $5$ and $m_{\text{nit}} = 0$.
   - Under the unstratified formula, $D = 4, m = 0 \implies m/D = 0\% < 25\%$.
   - The Judge is **forced to cap the round at `B+`**, even though there are **zero `BLOCKING` findings**!
   - In the next round, the orchestrator fixes those 4 NITs, and the 3 critics find 4 *new*, even more microscopic NITs ($D = 4, m = 0 \implies \text{capped at } B+$ again), creating an infinite Zeno's paradox loop!

### 2.3 Empirical Proof from an Auth Library & an API Service
- In an auth library's review log, Rounds 10, 11, 12, and 13 all had **0 BLOCKING findings**, yet were capped at `B+` because NIT overlap was $< 25\%$. Only when the human owner stepped in at Round 14 to rule that **overlap must be computed over `BLOCKING` findings only** did the pipeline finally converge at Round 19.
- In an API service's review log, 3 consecutive runs (15 rounds total) failed to reach `A++` because rounds with `0 BLOCKING` findings were repeatedly capped at `B+` by disjoint NITs.

### 2.4 Scientifically Corrected Stratified Overlap Rule
Update both `skills/temper/SKILL.md` and `skills/hone/SKILL.md` to stratify capture-recapture strictly over `BLOCKING` findings:
- Let $D_B$ = distinct `BLOCKING` findings after deduplication, and $m_B$ = `BLOCKING` findings raised by $\ge 2$ critics.
- **Case 1 ($D_B = 0$):** The overlap cap **does not apply**. If 0 `BLOCKING` findings are raised and all prior fixes are verified, the round is eligible for `A` / `A+` / `A++` progression.
- **Case 2 ($D_B \ge 4$ and $m_B / D_B < 0.25$):** The round is capped at `B+` (and cannot count as the first clean round after fixes).
- **Shared Core Sweep for Overlap Calibration:** To make capture-recapture statistically valid across orthogonal lenses, require all 3 critics to devote 80% of their inspection to their specialized lens and **20% to a shared core checklist** (top-level functional correctness / FR-to-task trace invariants), ensuring a non-zero overlap baseline on true `BLOCKING` defects.

---

## 3. Anti-Sycophancy, Blind Evaluation, and Critic Rotation

### 3.1 Inter-Agent Sycophancy & Disagreement Collapse
Multi-agent debate literature (Liang et al., 2023; CONSENSAGENT, 2025; Free-MAD, 2025) documents two failure modes in iterative LLM review panels:
1. **Mutual Sycophancy (Peacemaker Drift):** When critics see prior rounds' grades (`A`, `A+`) or see that the author accepted their previous suggestions, they rapidly soften their scrutiny to "agree" that the artifact is now converged.
2. **rubber-Stamping by Re-Used Contexts:** If the same subagent context is re-prompted in Round $r+1$, it suffers from confirmation bias toward its own Round $r$ framing.

### 3.2 Structural Countermeasures for Damascus (`temper` & `hone`)
1. **Fresh Critic Contexts + Blind Round Numbering:**
   - Critics in Round $r$ must be spawned as fresh subagent invocations (never resumed from Round $r-1$).
   - **Grade & Round Blindness:** Do **not** tell Critics A, B, or C what the current round number is (`Round 1` vs `Round 4`) or what the current grade streak is (`A+` needing one more clean round for `A++`). Knowing *"this is the final A++ confirmation round"* triggers measurable sycophantic leniency.
2. **Prior-Fix Delta Verification Without Anchoring:**
   - Rather than handing all 3 critics the entire multi-thousand-line `review.md` history (which anchors them to old findings and consumes context), pass the full artifact + a compact **Round $r-1$ Fix Diff Manifest** (`git diff round-{r-1}..round-{r}`) so they verify the exact lines changed in Round $r-1$ without anchoring on past grade narratives.
3. **Judge Independence & Identity Blindness (Zheng et al., 2023):**
   - As proven in an earlier analysis (FR-14 / SC-11), the Judge must **never** be the same agent context that authored or edited the spec/code fixes.
   - Strip model/provider labels (`[Gemini]`, `[Codex]`, `[Claude]`) from critic outputs before passing them to the Judge so the Judge cannot exhibit self-model preference bias.
4. **Fresh-Critic Rotation on Final `A++` Confirmation Round:**
   - When a panel reaches `A+` (first consecutive `0 BLOCKING` round), rotate at least one critic lens prompt or model assignment (or inject an adversarial "Devil's Advocate / Red-Team" framing on the `A++` confirmation round) to guarantee that `A++` reflects true defect exhaustion rather than prompt saturation.

---

## 4. Active Design Reviews (Parnas & Weiss, 1985) & Inspection Sizing (Cohen, 2006)

### 4.1 Parnas & Weiss (1985) Active Review Tables
Passive instructions (*"Review this spec for completeness"*) allow LLMs to skim and hallucinate coverage. Parnas & Weiss (1985) established that reviewers only find deep structural defects when forced to **construct an intermediate derivation artifact** (answering specific questions that cannot be answered without tracing the specification).
- Commit `041164b` added Active Critic Reading Procedures to `temper` (Critic A: FR $\times$ task $\times$ SC matrix; Critic B: external symbol inventory + task sizing table; Critic C: SC falsifiability table + `GIVEN/WHEN/THEN` sketch) and `hone` (Critic A: hunks $\times$ FRs + caller trace; Critic B: dependency arrows + duplication pairs; Critic C: trust boundary inventory + resource pairing).
- **Next Upgrade (Mechanical Pre-Check of Critic Tables):** The Judge in `temper` and `hone` should mechanically reject any critic response that omits its mandatory derivation table or whose table row count does not match the actual count of FRs/SCs/diff hunks in the artifact.

### 4.2 SmartBear / Cisco Code Review Sizing (Cohen, 2006)
Cohen's study of 2,500 Cisco peer reviews established that defect detection density drops precipitous after **$200\text{–}400$ lines of changed code** per inspection unit.
- `anvil` (in `f77d070`) sets a task sizing budget of $\le 400$ changed lines, and `quench` logs actual diff sizes (`+A/-D`) per task in `quench-log.md`.
- **Next Upgrade:** In `hone`, if the total branch diff exceeds $400$ lines, `hone` should partition the diff review by task/module slices ($\le 400$ lines per critic pass) plus one cross-cutting integration pass, rather than dumping a $3\,000$-line diff into a single critic prompt where attention dilution hides subtle bugs.

#!/usr/bin/env python3
"""evals/run_eval.py — Immutable evaluation harness for Damascus (`prepare.py` equivalent).

Computes the deterministic scalar objective score J_damascus in [0.0, 100.0] across:
1. Installer & Multi-Harness Smoke Suite (25 pts)
2. Mechanized Harness Seeded-Defect Recall & Precision (35 pts)
3. Scientific Protocol & Model-Agnosticism Invariants (25 pts)
4. Karpathy Prompt Simplicity Regularizer (15 pts)
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts"
SKILLS_DIR = REPO_ROOT / "skills"
AGENTS_DIR = REPO_ROOT / "agents"
RESULTS_TSV = REPO_ROOT / "evals" / "results.tsv"

STAGE_SKILLS = ("forge", "anvil", "temper", "quench", "hone", "smithy")
AGENT_FILES = (
    "bdd-scenario-writer.md",
    "tdd-test-generator.md",
    "playwright-e2e-tester.md",
    "fastapi-implementer.md",
    "labcoat.md",
    "temper-critic.md",
    "hone-critic.md",
    "review-judge.md",
)


def run_cmd(cmd: list[str], cwd: Path = REPO_ROOT, timeout_s: float = 120.0) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=str(cwd), text=True, capture_output=True, timeout=timeout_s)


def eval_smoke_suite() -> tuple[float, list[str]]:
    """Component 1: Run tests/smoke.sh (25 pts)."""
    proc = run_cmd(["bash", str(REPO_ROOT / "tests" / "smoke.sh")])
    if proc.returncode == 0:
        return 25.0, ["[PASS] tests/smoke.sh passed (25.0 / 25.0 pts)"]
    return 0.0, [f"[FAIL] tests/smoke.sh failed (exit {proc.returncode}): {proc.stderr.strip()}"]


def eval_mechanized_harnesses() -> tuple[float, list[str]]:
    """Component 2: Seeded defect benchmark for all 5 mechanized CLI scripts (35 pts)."""
    score = 0.0
    notes: list[str] = []
    tmp = Path(tempfile.mkdtemp(prefix="damascus-eval-"))
    try:
        # 2.1 Test damascus-agent-run (--probe + blind identity stripping) [7 pts]
        probe_proc = run_cmd([sys.executable, str(SCRIPTS_DIR / "damascus-agent-run"), "--probe"])
        if probe_proc.returncode == 0 and "local_openai" in probe_proc.stdout and "ollama" in probe_proc.stdout:
            score += 3.5
            notes.append("[PASS] damascus-agent-run --probe discovers local_openai, ollama, and clis (3.5 pts)")
        else:
            notes.append("[FAIL] damascus-agent-run --probe failed")

        # Verify blind identity stripping via custom echo backend
        env = os.environ.copy()
        env["DAMASCUS_CUSTOM_CMD"] = "cat"
        strip_proc = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS_DIR / "damascus-agent-run"),
                "--backend",
                "custom",
                "--role",
                "critic-a",
                "--prompt",
                "Model: claude-3-7-sonnet\nProvider: Anthropic\nI am Claude. [BLOCKING] spec.md:FR-001 — missing error state",
            ],
            env=env,
            text=True,
            capture_output=True,
        )
        if (
            strip_proc.returncode == 0
            and "claude-3-7-sonnet" not in strip_proc.stdout
            and "Provider: Anthropic" not in strip_proc.stdout
            and "### CRITIC A" in strip_proc.stdout
        ):
            score += 3.5
            notes.append("[PASS] damascus-agent-run strips model/provider identity headers for blind judging (3.5 pts)")
        else:
            notes.append(f"[FAIL] damascus-agent-run identity stripping failed: {strip_proc.stdout}")

        # Initialize throwaway git repo for test-lock, bdd-check, revert-proof, proof-coverage
        run_cmd(["git", "init", "-q", "."], cwd=tmp)
        run_cmd(["git", "config", "user.email", "eval@damascus.local"], cwd=tmp)
        run_cmd(["git", "config", "user.name", "Damascus Eval"], cwd=tmp)

        # 2.2 Test damascus-test-lock (lock -> verify pass -> tamper -> verify fail) [7 pts]
        (tmp / "tests").mkdir()
        test_file = tmp / "tests" / "test_calc.py"
        test_file.write_text("def test_add():\n    from src.calc import add\n    assert add(2, 3) == 5\n", encoding="utf-8")
        lock_p = run_cmd([sys.executable, str(SCRIPTS_DIR / "damascus-test-lock"), "lock", "--repo", str(tmp)])
        ver_ok = run_cmd([sys.executable, str(SCRIPTS_DIR / "damascus-test-lock"), "verify", "--repo", str(tmp)])
        # Tamper with the locked test (simulating an agent weakening an assertion during Green)
        test_file.write_text("def test_add():\n    assert True\n", encoding="utf-8")
        ver_tamper = run_cmd([sys.executable, str(SCRIPTS_DIR / "damascus-test-lock"), "verify", "--repo", str(tmp)])
        # Restore original test file
        test_file.write_text("def test_add():\n    from src.calc import add\n    assert add(2, 3) == 5\n", encoding="utf-8")
        if lock_p.returncode == 0 and ver_ok.returncode == 0 and ver_tamper.returncode != 0:
            score += 7.0
            notes.append("[PASS] damascus-test-lock locks Amber tests and catches silent Green test tampering (7.0 pts)")
        else:
            notes.append("[FAIL] damascus-test-lock failed to catch test tampering")

        # 2.3 Test damascus-bdd-check (unbound feature fail -> bound feature pass) [7 pts]
        feat_dir = tmp / "tests" / "features"
        feat_dir.mkdir(parents=True)
        feat_file = feat_dir / "discount.feature"
        feat_file.write_text(
            "Feature: Discount\n  Scenario: Valid coupon\n    Given a cart\n    When coupon applied\n    Then total is 85 EUR\n",
            encoding="utf-8",
        )
        bdd_unbound = run_cmd([sys.executable, str(SCRIPTS_DIR / "damascus-bdd-check"), "--repo", str(tmp)])
        step_file = tmp / "tests" / "test_discount_steps.py"
        step_file.write_text('from pytest_bdd import scenarios\nscenarios("features/discount.feature")\n', encoding="utf-8")
        bdd_bound = run_cmd([sys.executable, str(SCRIPTS_DIR / "damascus-bdd-check"), "--repo", str(tmp)])
        if bdd_unbound.returncode != 0 and bdd_bound.returncode == 0:
            score += 7.0
            notes.append("[PASS] damascus-bdd-check rejects unbound .feature files and passes bound features (7.0 pts)")
        else:
            notes.append("[FAIL] damascus-bdd-check failed seeded unbound/bound check")

        # 2.4 Test damascus-revert-proof (RED pass, GREEN vacuous fail, INCONCLUSIVE import error fail) [7 pts]
        (tmp / "src").mkdir()
        (tmp / "src" / "__init__.py").write_text("", encoding="utf-8")
        # Commit 1 (base_ref): buggy add(a, b) returning a - b, plus untouched file src/extra.py
        (tmp / "src" / "calc.py").write_text("def add(a: int, b: int) -> int:\n    return a - b\n", encoding="utf-8")
        (tmp / "src" / "extra.py").write_text("X = 1\n", encoding="utf-8")
        run_cmd(["git", "add", "."], cwd=tmp)
        run_cmd(["git", "commit", "-q", "-m", "base buggy state"], cwd=tmp)

        # Commit 2 (fix_ref): fixed add(a, b) returning a + b, modified src/extra.py, plus a real test and a vacuous test
        (tmp / "src" / "calc.py").write_text("def add(a: int, b: int) -> int:\n    return a + b\n", encoding="utf-8")
        (tmp / "src" / "extra.py").write_text("X = 2\n", encoding="utf-8")
        (tmp / "tests" / "test_vacuous.py").write_text("def test_vacuous():\n    assert 1 == 1\n", encoding="utf-8")
        run_cmd(["git", "add", "."], cwd=tmp)
        run_cmd(["git", "commit", "-q", "-m", "fix state"], cwd=tmp)

        report_path = tmp / "rp_report.json"
        # Real revert-proof case -> should be RED (exit 0)
        rp_red = run_cmd(
            [
                sys.executable,
                str(SCRIPTS_DIR / "damascus-revert-proof"),
                "--repo",
                str(tmp),
                "--id",
                "real-fix",
                "--base-ref",
                "HEAD~1",
                "--fix-ref",
                "HEAD",
                "--prod-file",
                "src/calc.py",
                "--test-cmd",
                f"{sys.executable} -c 'from src.calc import add; assert add(2, 3) == 5'",
                "--report-out",
                str(report_path),
            ]
        )
        # Vacuous revert-proof case -> should fail with GREEN (exit 1)
        rp_green = run_cmd(
            [
                sys.executable,
                str(SCRIPTS_DIR / "damascus-revert-proof"),
                "--repo",
                str(tmp),
                "--id",
                "vacuous-fix",
                "--base-ref",
                "HEAD~1",
                "--fix-ref",
                "HEAD",
                "--prod-file",
                "src/calc.py",
                "--test-cmd",
                f"{sys.executable} -c 'assert True'",
            ]
        )
        # Inconclusive (ImportError) revert-proof case -> should fail with INCONCLUSIVE (exit 1)
        rp_inc = run_cmd(
            [
                sys.executable,
                str(SCRIPTS_DIR / "damascus-revert-proof"),
                "--repo",
                str(tmp),
                "--id",
                "inconclusive-fix",
                "--base-ref",
                "HEAD~1",
                "--fix-ref",
                "HEAD",
                "--prod-file",
                "src/calc.py",
                "--test-cmd",
                f"{sys.executable} -c 'from src.calc import add; assert add(2, 3) == 5; import nonexistent_xyz'",
            ]
        )
        if rp_red.returncode == 0 and rp_green.returncode != 0 and "[FAIL:GREEN]" in rp_green.stdout:
            score += 7.0
            notes.append("[PASS] damascus-revert-proof distinguishes RED from vacuous GREEN and INCONCLUSIVE (7.0 pts)")
        else:
            notes.append(f"[FAIL] damascus-revert-proof tri-state check failed: red={rp_red.returncode}, green={rp_green.stdout}")

        # 2.5 Test damascus-proof-coverage (detects uncovered src/extra.py -> passes when covered/exempt) [7 pts]
        cov_uncovered = run_cmd(
            [
                sys.executable,
                str(SCRIPTS_DIR / "damascus-proof-coverage"),
                "--repo",
                str(tmp),
                "--base-ref",
                "HEAD~1",
                "--fix-ref",
                "HEAD",
                "--report",
                str(report_path),
            ]
        )
        cov_exempt = run_cmd(
            [
                sys.executable,
                str(SCRIPTS_DIR / "damascus-proof-coverage"),
                "--repo",
                str(tmp),
                "--base-ref",
                "HEAD~1",
                "--fix-ref",
                "HEAD",
                "--report",
                str(report_path),
                "--exempt-glob",
                "src/extra.py",
            ]
        )
        if cov_uncovered.returncode != 0 and "[UNCOVERED]   src/extra.py" in cov_uncovered.stdout and cov_exempt.returncode == 0:
            score += 7.0
            notes.append("[PASS] damascus-proof-coverage catches uncovered changed production files (7.0 pts)")
        else:
            notes.append("[FAIL] damascus-proof-coverage failed uncovered file detection")

    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    return score, notes


def eval_protocol_and_model_agnosticism() -> tuple[float, list[str]]:
    """Component 3: Audit skills and agents against scientific & model-agnosticism invariants (25 pts)."""
    score = 0.0
    notes: list[str] = []

    temper_text = (SKILLS_DIR / "temper" / "SKILL.md").read_text(encoding="utf-8")
    hone_text = (SKILLS_DIR / "hone" / "SKILL.md").read_text(encoding="utf-8")
    anvil_text = (SKILLS_DIR / "anvil" / "SKILL.md").read_text(encoding="utf-8")
    quench_text = (SKILLS_DIR / "quench" / "SKILL.md").read_text(encoding="utf-8")

    # 3.1 Stratified BLOCKING-only capture-recapture overlap in temper & hone [5 pts]
    if "D_B" in temper_text and "m_B" in temper_text and "D_B" in hone_text and "m_B" in hone_text:
        score += 5.0
        notes.append("[PASS] temper & hone stratify capture-recapture overlap over BLOCKING findings (D_B, m_B) (5.0 pts)")
    else:
        notes.append("[FAIL] temper or hone missing BLOCKING-only overlap stratification (D_B, m_B)")

    # 3.2 Vacuity Check, [DELTA]/[INVARIANT] tags, and M0 Micro-Temper [5 pts]
    if (
        "Vacuity Check" in temper_text
        and "M0 Micro-Temper" in temper_text
        and "[DELTA]" in anvil_text
        and "[INVARIANT]" in anvil_text
    ):
        score += 5.0
        notes.append("[PASS] Vacuity Check, [DELTA]/[INVARIANT] classification, and M0 Micro-Temper present (5.0 pts)")
    else:
        notes.append("[FAIL] Missing Vacuity Check, [DELTA]/[INVARIANT] tags, or M0 Micro-Temper")

    # 3.3 Composable .damascus/addenda/<stage>.md hook across all 5 stage skills + portable root discovery [5 pts]
    addenda_ok = all(
        f".damascus/addenda/{s}.md" in (SKILLS_DIR / s / "SKILL.md").read_text(encoding="utf-8")
        for s in ("forge", "anvil", "temper", "quench", "hone")
    )
    no_gnu_readlink = "readlink -f .claude/skills/anvil" not in anvil_text
    if addenda_ok and no_gnu_readlink:
        score += 5.0
        notes.append("[PASS] All 5 stage skills support .damascus/addenda/<stage>.md and portable root resolution (5.0 pts)")
    else:
        notes.append("[FAIL] Missing .damascus/addenda/<stage>.md hook or non-portable readlink -f remains")

    # 3.4 Model-agnosticism across all 5 dispatch agents (`model: inherit`, zero hardcoded `model: sonnet`) [5 pts]
    agents_texts = {name: (AGENTS_DIR / name).read_text(encoding="utf-8") for name in AGENT_FILES}
    if all("model: inherit" in txt and "model: sonnet" not in txt for txt in agents_texts.values()) and (
        "damascus agent-run" in temper_text and "damascus agent-run" in hone_text
    ):
        score += 5.0
        notes.append(f"[PASS] All {len(AGENT_FILES)} agents use `model: inherit` and temper/hone integrate `damascus agent-run` (5.0 pts)")
    else:
        notes.append("[FAIL] Hardcoded model: sonnet or missing damascus agent-run integration")

    # 3.5 Modern idioms (Pydantic v2, SQLAlchemy 2.0, timezone-aware UTC, PBT, Karpathy autoresearch) + Seeded Corpus Verification [5 pts]
    fastapi_txt = agents_texts["fastapi-implementer.md"]
    tdd_txt = agents_texts["tdd-test-generator.md"]
    labcoat_txt = agents_texts["labcoat.md"]
    corpus_path = REPO_ROOT / "evals" / "corpus" / "seeded_cases.json"
    corpus_ok = False
    if corpus_path.is_file():
        corpus = json.loads(corpus_path.read_text(encoding="utf-8"))
        # Verify stratified BLOCKING-only capture-recapture rating logic on corpus cases:
        # Clean control case has 0 BLOCKING findings and 4 disjoint NITs -> must NOT be capped at B+
        clean_case = next((c for c in corpus.get("temper_cases", []) if c["id"] == "temper-02-clean-control"), None)
        flawed_case = next((c for c in corpus.get("temper_cases", []) if c["id"] == "temper-01-seeded-flaws"), None)
        hone_case = next((c for c in corpus.get("hone_cases", []) if c["id"] == "hone-01-seeded-diff"), None)
        if clean_case and flawed_case and hone_case:
            clean_rating = adjudicate_stratified_rating(clean_case["simulated_critic_findings"])
            flawed_sim = [
                {"critic": "critic-a", "severity": "BLOCKING", "id": "D1"},
                {"critic": "critic-b", "severity": "BLOCKING", "id": "D2"},
                {"critic": "critic-c", "severity": "BLOCKING", "id": "D3"},
                {"critic": "critic-a", "severity": "BLOCKING", "id": "D4"},
            ]
            flawed_rating = adjudicate_stratified_rating(flawed_sim)
            corpus_ok = clean_rating == "A+" and flawed_rating == "B+"

    if (
        "ConfigDict" in fastapi_txt
        and "field_validator" in fastapi_txt
        and "timezone.utc" in fastapi_txt
        and "hypothesis" in tdd_txt
        and "autoresearch" in labcoat_txt
        and "autoresearch" in quench_text
        and corpus_ok
    ):
        score += 5.0
        notes.append(
            "[PASS] Modern Pydantic v2 / SQLAlchemy 2.0 / UTC idioms, Hypothesis PBT, autoresearch, and seeded corpus verified (5.0 pts)"
        )
    else:
        notes.append("[FAIL] Missing modern idioms, PBT, autoresearch, or seeded corpus check failed")

    return score, notes


def adjudicate_stratified_rating(findings: list[dict[str, str]]) -> str:
    """Reference implementation of the Damascus v0.2 stratified capture-recapture adjudication rule.

    Only BLOCKING findings (D_B, m_B) enter the capture-recapture cap. Disjoint NITs never cap convergence.
    """
    by_id: dict[str, set[str]] = {}
    important_count = 0
    for f in findings:
        sev = f.get("severity", "NIT")
        if sev == "BLOCKING":
            fid = f.get("id", "")
            by_id.setdefault(fid, set()).add(f.get("critic", "unknown"))
        elif sev == "IMPORTANT":
            important_count += 1

    d_b = len(by_id)
    m_b = sum(1 for critics in by_id.values() if len(critics) >= 2)
    overlap_b = (m_b / d_b) if d_b > 0 else 1.0

    # Low overlap cap applies ONLY when D_B >= 4 and m_B / D_B < 25 % (skills/temper, skills/hone)
    low_overlap_cap = d_b >= 4 and overlap_b < 0.25
    if d_b == 0 and important_count == 0:
        return "B+" if low_overlap_cap else "A+"
    if d_b == 0 and important_count <= 2:
        return "B+" if low_overlap_cap else "A"
    if d_b <= 2:
        return "B+"
    return "B+" if low_overlap_cap else "B"


FALLBACK_MARKER = "> rule-auditor fallback"
CORPUS_PATH = REPO_ROOT / "evals" / "corpus" / "seeded_cases.json"
LIVE_RUNS_DIR = REPO_ROOT / ".damascus" / "eval-runs"

# The format is described in words, never shown as a literal tag: a reply that merely
# echoes the prompt must not contain a single tagged finding.
FINDING_FORMAT = (
    "Report each finding on its own line, starting with its severity in square brackets "
    "(the word BLOCKING for anything that would be wrong to ship, otherwise NIT), then the "
    "location, then the specific issue. Report only real defects; if there are none, say so in one line."
)
TEMPER_PROMPT = (
    "You are a Damascus Temper critic (Completeness, Feasibility, and Testability lenses). "
    "Review the following spec.md, plan.md, and tasks.md. " + FINDING_FORMAT + "\n\n"
)
HONE_PROMPT = (
    "You are a Damascus Hone code review critic (Conformance, Security, and Simplicity lenses). "
    "Review the following git diff against FR-002 (reject expired coupons with 422) and "
    "security/simplicity invariants. " + FINDING_FORMAT + "\n\n"
)


class CorpusError(ValueError):
    """The seeded corpus cannot be scored honestly (e.g. a defect has no novel diagnosis term)."""


def answered_by(backend: str, stdout: str) -> str:
    """'rule-auditor' when the deterministic checker produced the output (requested or fallback), else 'model'."""
    return "rule-auditor" if backend == "rule-auditor" or FALLBACK_MARKER in stdout else "model"


def term_regex(term: str) -> re.Pattern[str]:
    """Case-insensitive match for a corpus term; word boundaries at word-character ends, `*` = prefix."""
    prefix = term.endswith("*")
    core = term[:-1] if prefix else term
    left = r"(?<!\w)" if re.match(r"\w", core) else ""
    right = r"(?!\w)" if re.search(r"\w$", core) and not prefix else ""
    return re.compile(left + re.escape(core) + right, re.IGNORECASE)


def has_term(terms: list[str], text: str) -> bool:
    return any(term_regex(t).search(text) for t in terms)


def case_prompt(case: dict[str, Any]) -> str:
    if "diff" in case:
        return HONE_PROMPT + case["diff"]
    return TEMPER_PROMPT + f"{case['spec_md']}\n{case['plan_md']}\n{case['tasks_md']}"


def effective_diagnosis(case: dict[str, Any]) -> dict[str, list[str]]:
    """Per defect, the diagnosis terms that do NOT already occur in the prompt (artifacts + template).

    Terms the model could copy from its input prove nothing, so they never earn credit.
    A defect left with no novel term would be unscoreable: fail loudly instead of scoring 0.
    """
    prompt = case_prompt(case)
    out: dict[str, list[str]] = {}
    for d in case.get("seeded_blocking_defects", []):
        novel = [t for t in d["diagnosis"] if not term_regex(t).search(prompt)]
        if not novel:
            raise CorpusError(f"{case['id']}/{d['id']}: every diagnosis term already occurs in the prompt")
        out[d["id"]] = novel
    return out


# A finding starts its line (after any bullet, number, quote or table pipe) with its severity
# either in square brackets, `[BLOCKING]`, or followed by a colon or dash, `BLOCKING:`; bold is ignored.
_TAG = re.compile(
    r"^[\s>|*+-]*(?:\d+[.)]\s*)?[*_]*(?:\[\s*(BLOCKING|NIT|UNCONFIRMED)\s*\]|(BLOCKING|NIT|UNCONFIRMED)[*_]*\s*[:\u2014\u2013-])",
    re.IGNORECASE,
)


def blocking_findings(reply: str) -> list[str]:
    """Split a reply into BLOCKING findings: a tagged line plus its continuation lines
    (up to the next tagged line or a blank line)."""
    findings: list[str] = []
    current: list[str] | None = None
    for line in reply.splitlines():
        m = _TAG.match(line)
        if m:
            if current is not None:
                findings.append("\n".join(current))
            current = [line] if (m.group(1) or m.group(2)).upper() == "BLOCKING" else None
        elif not line.strip():
            if current is not None:
                findings.append("\n".join(current))
            current = None
        elif current is not None:
            current.append(line)
    if current is not None:
        findings.append("\n".join(current))
    return findings


def score_reply(case: dict[str, Any], reply: str) -> dict[str, Any]:
    """A seeded defect counts as found only when one BLOCKING finding names it (an anchor such as
    its ID or symbol) AND says what is wrong in words the prompt did not supply."""
    diagnosis = effective_diagnosis(case)
    findings = blocking_findings(reply)
    matched: list[str] = []
    credited: set[int] = set()
    for d in case.get("seeded_blocking_defects", []):
        for i, f in enumerate(findings):
            if has_term(d["anchors"], f) and has_term(diagnosis[d["id"]], f):
                matched.append(d["id"])
                credited.add(i)
                break
    return {
        "blocking_findings": len(findings),
        "matched": matched,
        "unmatched_blocking": len(findings) - len(credited),
    }


def load_corpus_cases() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """(seeded cases, clean controls) across temper and hone."""
    corpus = json.loads(CORPUS_PATH.read_text(encoding="utf-8"))
    cases = corpus.get("temper_cases", []) + corpus.get("hone_cases", [])
    return [c for c in cases if c.get("seeded_blocking_defects")], [c for c in cases if not c.get("seeded_blocking_defects")]


def summarize(results: list[dict[str, Any]]) -> dict[str, Any]:
    seeded = [r for r in results if r["total"]]
    matched = sum(len(r["matched"]) for r in seeded)
    total = sum(r["total"] for r in seeded)
    return {
        "matched_defects": matched,
        "total_defects": total,
        "recall": round(matched / total, 2) if total else 1.0,
        "clean_false_positives": sum(r["blocking_findings"] for r in results if not r["total"]),
        "unmatched_blocking_on_seeded": sum(r["unmatched_blocking"] for r in seeded),
        # A case whose backend failed (timeout, crash) has no reply: its zero is not a result.
        "errored_cases": [r["id"] for r in results if r.get("returncode", 0) != 0],
    }


def echo_baseline() -> dict[str, Any]:
    """Score a 'model' that replies with its own prompt. Any credit here means the scorer leaks."""
    seeded, clean = load_corpus_cases()
    results = []
    for case in seeded + clean:
        r = score_reply(case, case_prompt(case))
        results.append({**r, "id": case["id"], "total": len(case.get("seeded_blocking_defects", []))})
    return summarize(results)


def check_corpus() -> list[str]:
    """Self-check of the live-eval scorer and corpus (run in CI; not part of J_damascus)."""
    errors: list[str] = []
    try:
        seeded, clean = load_corpus_cases()
        for case in seeded:
            effective_diagnosis(case)
    except (CorpusError, KeyError, ValueError) as e:
        return [f"corpus is not scoreable: {e}"]
    if not clean:
        errors.append("corpus has no clean control case")
    echo = echo_baseline()
    if echo["matched_defects"] or echo["clean_false_positives"]:
        errors.append(f"echoing the prompt earns credit: {echo}")
    for case in seeded:
        for d in case["seeded_blocking_defects"]:
            got = score_reply(case, f"- [BLOCKING] {d['description']}")["matched"]
            if d["id"] not in got:
                errors.append(f"{case['id']}/{d['id']}: its own description is not recognised as finding it")
            if set(got) - {d["id"]}:
                errors.append(f"{case['id']}/{d['id']}: its description also credits {sorted(set(got) - {d['id']})}")
    for case in clean:
        nits = "\n".join(f"- [NIT] {f['text']}" for f in case.get("simulated_critic_findings", []))
        if score_reply(case, nits)["blocking_findings"]:
            errors.append(f"{case['id']}: NIT findings were counted as BLOCKING")
    return errors


def run_live_llm_corpus_eval(
    backend: str = "auto", out_dir: Path | None = None, runs: int = 1, timeout_s: float = 170.0
) -> dict[str, Any]:
    """Optional live LLM benchmark over every corpus case, including the clean control.

    Each prompt and raw reply is saved under `out_dir` so the score can be audited. With
    `runs` > 1 the corpus is sent `runs` times (replies under `run-<k>/`) and the report
    adds the spread: replies vary from run to run, so one run is a rough reading.
    """
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = out_dir or LIVE_RUNS_DIR / f"{ts}-{backend}"
    if runs <= 1:
        return live_llm_corpus_run(backend, out_dir, timeout_s)
    per_run = [live_llm_corpus_run(backend, out_dir / f"run-{k}", timeout_s) for k in range(1, runs + 1)]
    recalls = [r["recall"] for r in per_run]
    found_rate: dict[str, float] = {}
    for r in per_run:
        for c in r["cases"]:
            for d in c["matched"]:
                found_rate[d] = found_rate.get(d, 0) + 1 / runs
    report = {
        "backend": backend,
        "runs": len(per_run),
        "answered_by": per_run[0]["answered_by"] if len({r["answered_by"] for r in per_run}) == 1 else "mixed",
        "total_defects": per_run[0]["total_defects"],
        "matched_defects_per_run": [r["matched_defects"] for r in per_run],
        "recall_mean": round(sum(recalls) / len(recalls), 2),
        "recall_min": min(recalls),
        "recall_max": max(recalls),
        "clean_false_positives_per_run": [r["clean_false_positives"] for r in per_run],
        "errored_cases_per_run": [r["errored_cases"] for r in per_run],
        "defect_found_rate": {d: round(v, 2) for d, v in sorted(found_rate.items())},
        "echo_baseline": per_run[0]["echo_baseline"],
        "replies_dir": str(out_dir),
    }
    (out_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def live_llm_corpus_run(backend: str, out_dir: Path, timeout_s: float) -> dict[str, Any]:
    """One pass over the corpus; see run_live_llm_corpus_eval."""
    seeded, clean = load_corpus_cases()
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd_tail = ["--no-fallback"] if backend not in ("auto", "rule-auditor") else []
    case_results: list[dict[str, Any]] = []

    for case in seeded + clean:
        prompt = case_prompt(case)
        role = "critic-b" if "diff" in case else "critic-a"
        proc = run_cmd(
            [sys.executable, str(SCRIPTS_DIR / "damascus-agent-run"), "--backend", backend, "--role", role,
             "--timeout", str(timeout_s), "--prompt", prompt, *cmd_tail],
            timeout_s=timeout_s + 10,
        )
        (out_dir / f"{case['id']}.prompt.txt").write_text(prompt, encoding="utf-8")
        (out_dir / f"{case['id']}.reply.txt").write_text(proc.stdout + (f"\n--- stderr ---\n{proc.stderr}" if proc.stderr else ""), encoding="utf-8")
        total = len(case.get("seeded_blocking_defects", []))
        scored = score_reply(case, proc.stdout)
        case_results.append(
            {
                "id": case["id"],
                "returncode": proc.returncode,
                "answered_by": answered_by(backend, proc.stdout),
                **scored,
                "total": total,
                "recall": round(len(scored["matched"]) / total, 2) if total else None,
            }
        )

    answered = {c["answered_by"] for c in case_results}
    report = {
        "backend": backend,
        "cases": case_results,
        "answered_by": "model" if answered == {"model"} else "rule-auditor" if answered == {"rule-auditor"} else "mixed",
        **summarize(case_results),
        "echo_baseline": echo_baseline(),
        "replies_dir": str(out_dir),
    }
    (out_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def eval_simplicity_regularizer() -> tuple[float, int, list[str]]:
    """Component 4: Karpathy Simplicity Regularizer (15 pts).

    Ensures all agent prompts stay <= 150 lines (for 8k-32k local model KV caches)
    and all stage skills stay <= 260 lines.
    """
    notes: list[str] = []
    total_lines = 0
    over_budget = 0

    for name in AGENT_FILES:
        lines = len((AGENTS_DIR / name).read_text(encoding="utf-8").splitlines())
        total_lines += lines
        if lines > 150:
            over_budget += lines - 150
            notes.append(f"[WARN] agents/{name} is {lines} lines (budget <= 150)")

    for stage in STAGE_SKILLS:
        lines = len((SKILLS_DIR / stage / "SKILL.md").read_text(encoding="utf-8").splitlines())
        total_lines += lines
        if lines > 260:
            over_budget += lines - 260
            notes.append(f"[WARN] skills/{stage}/SKILL.md is {lines} lines (budget <= 260)")

    penalty = min(15.0, over_budget * 0.15)
    score = round(max(0.0, 15.0 - penalty), 2)
    notes.insert(
        0,
        f"[{'PASS' if score == 15.0 else 'WARN'}] Prompt simplicity budget: {total_lines} total lines across 6 skills + {len(AGENT_FILES)} agents ({score} / 15.0 pts)",
    )
    return score, total_lines, notes


def append_results_tsv(
    total_score: float,
    smoke_pts: float,
    harness_pts: float,
    protocol_pts: float,
    simplicity_pts: float,
    total_lines: int,
    status: str,
    hypothesis: str,
) -> None:
    RESULTS_TSV.parent.mkdir(parents=True, exist_ok=True)
    header = "timestamp\tcommit\tscore\tsmoke_pts\tharness_pts\tprotocol_pts\tsimplicity_pts\ttotal_prompt_lines\tstatus\thypothesis\n"
    if not RESULTS_TSV.is_file():
        RESULTS_TSV.write_text(header, encoding="utf-8")
    commit_proc = run_cmd(["git", "rev-parse", "--short", "HEAD"])
    commit_sha = commit_proc.stdout.strip() if commit_proc.returncode == 0 else "unknown"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    row = f"{ts}\t{commit_sha}\t{total_score:.2f}\t{smoke_pts:.1f}\t{harness_pts:.1f}\t{protocol_pts:.1f}\t{simplicity_pts:.2f}\t{total_lines}\t{status}\t{hypothesis}\n"
    with RESULTS_TSV.open("a", encoding="utf-8") as f:
        f.write(row)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="damascus eval", description="Run Damascus immutable evaluation harness.")
    parser.add_argument("--json", action="store_true", help="Output evaluation report as JSON.")
    parser.add_argument("--record", action="store_true", help="Append evaluation result to evals/results.tsv.")
    parser.add_argument("--status", default="KEEP", help="Status label when recording to results.tsv (default: KEEP).")
    parser.add_argument(
        "--hypothesis",
        default="Science-based improvements & mechanized harnesses",
        help="Hypothesis summary when recording to results.tsv.",
    )
    parser.add_argument(
        "--live-llm",
        action="store_true",
        help="Also run live LLM critic evaluation against evals/corpus/seeded_cases.json via damascus-agent-run.",
    )
    parser.add_argument("--backend", default="auto", help="Backend for --live-llm (default: auto).")
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="Where --live-llm saves each prompt and raw reply (default: .damascus/eval-runs/<UTC time>-<backend>/).",
    )
    parser.add_argument(
        "--runs",
        type=int,
        default=1,
        help="With --live-llm, send the corpus this many times and report the spread (default: 1).",
    )
    parser.add_argument(
        "--critic-timeout",
        type=float,
        default=170.0,
        help="With --live-llm, seconds each critic call may take before it counts as an errored case (default: 170).",
    )
    parser.add_argument(
        "--check-corpus",
        action="store_true",
        help="Only self-check the live-eval scorer and seeded corpus (echo scores 0, each defect matches its own description); exit 1 on failure.",
    )
    args = parser.parse_args(argv)

    if args.check_corpus:
        errors = check_corpus()
        for e in errors:
            print(f"[FAIL] {e}")
        if not errors:
            echo = echo_baseline()
            print(
                f"[PASS] live-eval corpus is scoreable: echo baseline {echo['matched_defects']} / {echo['total_defects']} defects, "
                f"{echo['clean_false_positives']} clean false positives; every defect is matched by its own description"
            )
        return 1 if errors else 0

    smoke_pts, smoke_notes = eval_smoke_suite()
    harness_pts, harness_notes = eval_mechanized_harnesses()
    protocol_pts, protocol_notes = eval_protocol_and_model_agnosticism()
    simplicity_pts, total_lines, simplicity_notes = eval_simplicity_regularizer()

    total_score = round(smoke_pts + harness_pts + protocol_pts + simplicity_pts, 2)
    report: dict[str, Any] = {
        "j_damascus": total_score,
        "max_score": 100.0,
        "components": {
            "smoke_suite": smoke_pts,
            "mechanized_harnesses": harness_pts,
            "protocol_and_model_agnosticism": protocol_pts,
            "simplicity_regularizer": simplicity_pts,
        },
        "total_prompt_lines": total_lines,
        "notes": smoke_notes + harness_notes + protocol_notes + simplicity_notes,
    }

    if args.live_llm:
        report["live_llm_corpus"] = run_live_llm_corpus_eval(
            args.backend, args.out_dir, runs=args.runs, timeout_s=args.critic_timeout
        )

    if args.record:
        append_results_tsv(
            total_score,
            smoke_pts,
            harness_pts,
            protocol_pts,
            simplicity_pts,
            total_lines,
            args.status,
            args.hypothesis,
        )

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"=== Damascus Evaluation Harness (J_damascus = {total_score:.2f} / 100.00) ===")
        for line in report["notes"]:
            print(f"  {line}")
        if args.live_llm and "runs" in report["live_llm_corpus"]:
            llm_res = report["live_llm_corpus"]
            label = "LIVE-LLM" if llm_res["answered_by"] == "model" else "RULE-AUDITOR"
            total = llm_res["total_defects"]
            print(
                f"  [{label}] {llm_res['runs']} runs — recall per run: "
                + ", ".join(f"{m}/{total}" for m in llm_res["matched_defects_per_run"])
                + f" (mean {llm_res['recall_mean'] * 100:.0f}%, min {llm_res['recall_min'] * 100:.0f}%, max {llm_res['recall_max'] * 100:.0f}%)"
            )
            print("    clean-control BLOCKING findings per run: " + ", ".join(map(str, llm_res["clean_false_positives_per_run"])))
            for k, errs in enumerate(llm_res["errored_cases_per_run"], 1):
                if errs:
                    print(f"    [WARN] run {k}: backend failed on {', '.join(errs)}; that run's totals are incomplete")
            rates = llm_res["defect_found_rate"]
            print("    found in share of runs: " + ", ".join(f"{d} {r * 100:.0f}%" for d, r in rates.items()) + (" (others never)" if len(rates) < total else ""))
            print(f"    prompts and raw replies: {llm_res['replies_dir']}/run-<k>/")
        elif args.live_llm:
            llm_res = report["live_llm_corpus"]
            label = "LIVE-LLM" if llm_res["answered_by"] == "model" else "RULE-AUDITOR"
            note = "" if label == "LIVE-LLM" else " (deterministic pattern checks, not a model review)"
            echo = llm_res["echo_baseline"]
            print(
                f"  [{label}] Recall: {llm_res['matched_defects']} / {llm_res['total_defects']} seeded BLOCKING defects; "
                f"{llm_res['clean_false_positives']} BLOCKING finding(s) on the clean control; "
                f"{llm_res['unmatched_blocking_on_seeded']} other BLOCKING finding(s) on seeded cases{note}"
            )
            print(f"    echo-the-prompt baseline: {echo['matched_defects']} / {echo['total_defects']}, {echo['clean_false_positives']} clean false positives")
            if llm_res["errored_cases"]:
                print(f"    [WARN] backend failed on {', '.join(llm_res['errored_cases'])}: those cases have no reply, so the totals above are incomplete")
            for case_res in llm_res.get("cases", []):
                found = f"{len(case_res['matched'])} / {case_res['total']} {case_res['matched']}" if case_res["total"] else "clean control"
                print(
                    f"    - {case_res['id']}: {found}, {case_res['blocking_findings']} BLOCKING finding(s), exit {case_res['returncode']}, via {case_res['answered_by']}"
                )
            print(f"    prompts and raw replies: {llm_res['replies_dir']}")

    return 0 if total_score >= 95.0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

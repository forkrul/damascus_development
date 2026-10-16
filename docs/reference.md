# Configuration and CLI reference

Everything a host repo can configure, and every command the stages run. The stage
contracts themselves live in the skill pages; this page covers the plumbing around them.

## Running the commands

The skills call the mechanized gates as `damascus <cmd>`. That means the damascus
checkout's `install.sh <cmd>`, which hands off to `scripts/damascus-<cmd>` (or
`evals/run_eval.py` for `eval`):

```bash
vendor/damascus/install.sh agent-run --probe     # from a consumer repo root
./install.sh eval                                # inside damascus itself
```

No global `damascus` command is installed. Every command is Python 3.9+ standard library
only and takes `--help`; the gates work on the repository in the current directory unless
given `--repo`.

## `agent-run`: routing critics, judge and implementer

`damascus agent-run` sends one prompt to one model and prints the reply. Temper and hone
use it when you want critics or the judge on a different model than the session's own
subagents; it is never required.

```bash
damascus agent-run --probe                                   # JSON: reachable servers, Ollama models, agent CLIs
damascus agent-run --role critic-a --input-file bundle.md   # route by role (see below)
damascus agent-run --backend ollama --model <name> --prompt "..."
```

| Flag | Meaning |
|------|---------|
| `--backend` | `auto` (default), `local-openai`, `ollama`, `claude`, `gemini`, `codex`, `opencode`, `llm`, `rule-auditor`, `custom` |
| `--role` | `critic-a` … `critic-d`, `judge`, `implementer`, `generic`; selects routing keys and labels critic output `### CRITIC A` … |
| `--model` | model name for the chosen backend |
| `--prompt` / `--input-file` | the user prompt, inline or from a file |
| `--system` / `--system-file` | an optional system prompt |
| `--output-file` | also write the reply to a file |
| `--temperature`, `--max-tokens`, `--num-ctx` | sampling, output length for HTTP backends, Ollama context (default 32768) |
| `--timeout` | seconds before the backend call is abandoned (default 300) |
| `--no-strip-identity` | keep model/provider self-identification (stripped by default so the judge rates blind) |
| `--no-fallback` | exit 3 instead of falling back to the rule-auditor (see below) |

**Backends.** `local-openai` talks to any OpenAI-compatible server — llama.cpp's
`llama-server`, vLLM, SGLang, LM Studio, LocalAI. `ollama` uses Ollama's API. `claude`,
`gemini`, `codex`, `opencode` and `llm` run that agent CLI non-interactively. `custom`
pipes the prompt into the command in `DAMASCUS_CUSTOM_CMD`. `rule-auditor` is the
built-in deterministic checker described below.

**`auto`** first applies the routing below. If that names no backend, it uses the first
of: a reachable OpenAI-compatible server (`DAMASCUS_LOCAL_URL` or `OPENAI_BASE_URL`, else
`127.0.0.1` ports 8080, 8000 and 1234), Ollama with at least one model pulled, then an
installed agent CLI — with two or more CLIs installed, `critic-a`, `critic-b` and
`critic-c` each get a different one, for diversity. When nothing
answers — nothing found, a CLI failed, timed out or printed nothing — it falls back to
the **rule-auditor** and says so: a `[WARN]` on stderr and a `> rule-auditor fallback`
line in the output. The rule-auditor runs regex checks for a few known defect patterns;
its output is not a model review. Pass `--no-fallback` when you need a model's answer or
nothing.

### Role routing: `.damascus/models.conf`

Under `--backend auto` with a `--role`, the backend and model come from the first match
in this order (the role is upper-cased with dashes turned into underscores, so
`critic-a` → `CRITIC_A`):

| Backend from | Model from |
|--------------|------------|
| env `DAMASCUS_<ROLE>_BACKEND` | env `DAMASCUS_<ROLE>_MODEL` |
| `models.conf` `<ROLE>_BACKEND` | `models.conf` `<ROLE>_MODEL` |
| env `DAMASCUS_BACKEND` | env `DAMASCUS_MODEL` |
| `models.conf` `DEFAULT_BACKEND` | `models.conf` `DEFAULT_MODEL` |

An explicit `--backend` or `--model` on the command line wins over all of these.
`models.conf` is read from `.damascus/models.conf` under the current directory, as
`KEY=VALUE` lines; `#` starts a comment and surrounding quotes are dropped:

```ini
# .damascus/models.conf — critics on a local server, the judge on another agent CLI
DEFAULT_BACKEND=local-openai
DEFAULT_MODEL=<your-local-model>
JUDGE_BACKEND=<agent-cli>
CRITIC_C_BACKEND=ollama
CRITIC_C_MODEL=<an-ollama-model>
```

`LOCAL_OPENAI_URL` in the file sets the server URL when no environment variable does.
Without a model name, `local-openai` uses the first model the server lists and `ollama`
the first model Ollama has pulled.

### Environment variables

| Variable | Used for |
|----------|----------|
| `DAMASCUS_LOCAL_URL`, `OPENAI_BASE_URL` | the OpenAI-compatible server's base URL (e.g. `http://127.0.0.1:8080/v1`) |
| `DAMASCUS_API_KEY`, `OPENAI_API_KEY` | that server's API key, if it needs one |
| `OLLAMA_HOST` | Ollama's URL (default `http://127.0.0.1:11434`) |
| `DAMASCUS_CUSTOM_CMD` | the command line for `--backend custom`; it receives the prompt on stdin |
| `DAMASCUS_<ROLE>_BACKEND`, `DAMASCUS_<ROLE>_MODEL`, `DAMASCUS_BACKEND`, `DAMASCUS_MODEL` | routing overrides (table above) |

## Mechanized gates

Each gate exits 0 when it passes and 1 when it doesn't, so a stage can't report green over
a failed gate.

### `test-lock`

Freezes tests at amber and checks them at green (quench's test-freeze rule).

```bash
damascus test-lock lock --task T001 [--path tests/unit/test_x.py]   # record SHA-256 of the task's tests
damascus test-lock verify [--allow-new]                             # fail on any edit or deletion since lock
damascus test-lock unlock --reason "AMBER-AMEND: spec FR-003 changed" # spec changed first; relock afterwards
```

Without `--path`, `lock` takes every file under `tests/`, `test/` and `e2e/`. The manifest
is `.damascus/locks/amber-tests.sha256.json` (`--lock-file` to move it). `--allow-new`
lets new test files appear while the locked ones stay frozen.

### `bdd-check`

Fails when a `.feature` file has no `Scenario`, or no test file binds it (pytest-bdd
`scenarios("…")` or `@scenario(…)`) — the case where `pytest` exits 0 having run none of
its scenarios. Features are found under `tests/`, `features/` and `e2e/` unless
`--feature-dir` names a directory or file.

### `revert-proof`

Shows a fix fails without itself. For each case it checks out the fixed commit in a
throwaway worktree, confirms the test passes, reverts only the production files to the
base ref, reruns the test and classifies the result:

| Result | Meaning |
|--------|---------|
| **RED** — pass | the test ran and failed on its assertion (matching `expected_regex` if given) |
| **GREEN** — fail | the test still passes without the fix: it doesn't test the fix |
| **INCONCLUSIVE** — fail | the run broke before the assertion (import, collection or syntax error) |

One case from flags, or many from a file:

```bash
damascus revert-proof --id F1 --base-ref HEAD~1 --prod-file src/app/discounts.py \
  --test-cmd "pytest tests/unit/test_discounts.py -q" --expect-regex "AssertionError"
damascus revert-proof --cases specs/001-x/cases.json --report-out specs/001-x/revert-proof.json
```

```json
{"cases": [
  {"id": "F1", "base_ref": "HEAD~1", "fix_ref": "HEAD",
   "production_files": ["src/app/discounts.py"],
   "test_cmd": "pytest tests/unit/test_discounts.py -q",
   "expected_regex": "AssertionError"}
]}
```

A bare list of cases works too. `--timeout` bounds each test run (default 180 s).

### `proof-coverage`

Fails when any production file changed between `--base-ref` and `--fix-ref` (default
`HEAD`) has no RED revert-proof in `--report` (the `--report-out` file above). Paths under
`tests/`, `test/`, `specs/`, `docs/`, `.prd/` and the harness directories are exempt;
`--exempt-glob` adds patterns, and an `"exemptions"` object in the report
(`{"path": "reason"}`) exempts a file with a stated reason.

```bash
damascus proof-coverage --base-ref HEAD~3 --report specs/001-x/revert-proof.json
```

## `upgrade-consumers`

Reports on, and re-links, other repos that use damascus: for each one it runs
`install.sh --all-harnesses` and then `--verify`. Read-only checkouts are reported and
skipped. It does not move anyone's `vendor/damascus` pin.

```bash
damascus upgrade-consumers --scan-dir ~/src --check     # report only: harnesses, pinned commit, writability
damascus upgrade-consumers --repo ../shop-api           # re-link one repo (repeatable)
```

It runs the `install.sh` of the damascus checkout you invoke it from, and links always
point at that checkout. To keep a repo linked to its own pinned submodule, bump the pin,
then run its own installer (`vendor/damascus/install.sh`) or invoke `upgrade-consumers`
from that submodule with `--repo .`. `--dry-run` passes `--dry-run` to each install,
`--claude-only` links `.claude/` only, and `--json` prints a machine-readable report.

## Stage addenda: `.damascus/addenda/<stage>.md`

A host repo can extend a stage without forking it. Each stage reads its addendum, when
present, before it starts:

| File | Read by | Typical content |
|------|---------|-----------------|
| `forge.md` | forge | extra domain questions folded into the REASONS Canvas |
| `anvil.md` | anvil | decomposition constraints (e.g. every task names its migration) |
| `temper.md` | temper | domain checks for the critics, or a fourth lens `critic-d` |
| `quench.md` | quench | extra test or build gates a task must pass at green |
| `hone.md` | hone | domain checks for the critics, or a fourth lens `critic-d` |

Addenda are plain Markdown instructions that the stage applies alongside its own; the
skill pages say exactly where each one is read.

## Evaluation harness: `eval`

`damascus eval` scores damascus itself; it is for working on this repo, not on a consumer.

```bash
./install.sh eval                                   # J_damascus, 0–100; exits 1 below 95
./install.sh eval --json --record                   # JSON report; append a row to evals/results.tsv
./install.sh eval --live-llm --backend <backend>    # also benchmark a real critic model
./install.sh eval --check-corpus                    # self-check the live benchmark's scorer and corpus
```

**J_damascus** adds up four deterministic components: the smoke test (25), the
mechanized gates against seeded defects (35), protocol and model-agnosticism invariants
(25) and a prompt-size budget (15: agents ≤ 150 lines, stage skills ≤ 260). CI fails
below 95. [`evals/program.md`](https://github.com/forkrul/damascus_development/blob/master/evals/program.md)
is the keep/revert protocol for improving the skills against it.

**The live benchmark** (`--live-llm`) is a separate number. It sends every case in
[`evals/corpus/seeded_cases.json`](https://github.com/forkrul/damascus_development/blob/master/evals/corpus/seeded_cases.json)
— seeded specs and diffs plus a clean control — to the backend as a temper or hone
critic. A seeded defect counts as found only when a `[BLOCKING]` finding names it and
says what is wrong in words that don't occur in the prompt, so a model that echoes its
input scores 0. The report gives recall, blocking findings on the clean control (false
positives), the echo baseline, and any case where the backend failed. Every prompt and
raw reply is saved under `.damascus/eval-runs/<time>-<backend>/` (`--out-dir` to
override) so a score can be checked by hand. Treat one run as a rough reading: replies
vary from run to run, and the scorer's term lists are still being tuned. A
`--backend rule-auditor` run scores the regex checker, whose patterns were written
against this corpus, so its result says nothing about models.

# Production Readiness — Single-Founder Plan

What "production ready" means for damascus: **a stranger can pin a tagged version,
run `install.sh` on their machine, and get a working pipeline — and one person can
sustain that promise with near-zero recurring toil.**

There is no runtime service here. The product surface is exactly three things:

1. `install.sh` — the only executable code
2. the five `SKILL.md` contracts (+ aliases + agents)
3. the two pinned vendor submodules

So readiness is about **licensing, portability, CI, versioned releases, and
automated maintenance** — not uptime. The single-founder constraint drives every
choice below: prefer automation over process, CI gates over human review, and
scheduled bots over remembering things.

Current gaps (as of this writing): no LICENSE, no `.github/` (zero CI), no tags or
releases, install.sh smoke-tested only by hand, submodule bumps are manual and
unprompted, and `install.sh` hard-fails on stock macOS bash 3.2 (`declare -A`).

> **Status:** phases 0–4 are implemented in-repo (checked boxes below). Two items
> remain manual, GitHub-side, after this lands on `master`:
> **(1)** cut `v0.1.0` — tag + Release per the ritual now in CLAUDE.md;
> **(2)** enable branch protection on `master` (require PR + green CI, no
> force-push, no required approver count) in repo Settings → Branches.

---

## Phase 0 — Legal & baseline hygiene *(blocker for any adoption; ~1 hour)*

Nobody serious will consume an unlicensed repo, and no other phase is worth doing
before this one.

- [x] Add a `LICENSE` (MIT suggested). Note in the README that `vendor/superpowers`
      and `vendor/spec-kit` retain their own upstream licenses and are not
      relicensed by this repo.
- [x] README: add a **Requirements** section — git ≥ 2.13 (submodules), bash ≥ 4
      (associative arrays in `install.sh`), GNU coreutils on macOS *until Phase 1
      removes the dependency*.
- [x] README: state the support posture honestly ("maintained by one person;
      issues welcome, response time best-effort") — this manages expectations
      instead of silently missing them.

**Exit criteria:** LICENSE visible on GitHub; requirements documented.

## Phase 1 — Correctness & CI safety net *(the highest-leverage phase; ~½ day)*

A single founder has no reviewer. CI is the second pair of eyes; every guarantee
the README makes should be enforced by a workflow, not by memory.

- [x] **Portability fix in `install.sh`**: replace `declare -A` with parallel
      arrays or a `case` mapping, and replace `readlink -f` / `realpath
      --relative-to` GNU-isms with portable equivalents (or an explicit,
      well-messaged bash-version check that fails fast). Stock macOS is the
      most likely consumer environment after Linux.
- [x] **`.github/workflows/ci.yml`** on every PR + master push:
  - `bash -n install.sh` and `shellcheck install.sh`
  - repo integrity: every `skills/<alias>` symlink resolves, is relative, and
    points inside `skills/`; every SKILL.md and agent file referenced by
    `install.sh` exists (catches rename drift between script arrays and disk)
  - frontmatter lint: each `SKILL.md` / `agents/*.md` has `name` + `description`
  - **install/uninstall smoke test** (the CLAUDE.md throwaway-repo test, encoded):
    init a temp repo, run `install.sh` twice (idempotency), assert every created
    link resolves, run `--uninstall`, assert `.claude/` contains nothing
    damascus-owned; also assert a pre-existing non-damascus file is *never*
    touched (the ownership guarantee)
  - run the smoke test on a matrix: `ubuntu-latest` **and** `macos-latest`
- [x] **Changelog gate**: CI check that PRs touch `CHANGELOG.md` (enforces the
      existing convention mechanically).

**Exit criteria:** green CI on both OSes; a deliberately broken symlink or
skipped changelog entry fails a test PR.

## Phase 2 — Versioned releases *(makes "pin a version" real; ~½ day once, minutes thereafter)*

Consumers add damascus as a submodule — today they can only pin an opaque SHA on
`master`. Production consumers need stable, named versions and an upgrade story.

- [ ] Tag **`v0.1.0`** and cut the first GitHub Release from the `[Unreleased]`
      changelog section; adopt semver (breaking skill-contract or install.sh
      behavior changes = major once past 1.0).
- [x] Document the release ritual in CLAUDE.md (move `[Unreleased]` → version
      heading, tag, `gh release create`) — small enough to stay manual, but a
      release-drafter or tag-triggered workflow can generate the release notes
      from the changelog.
- [x] README install snippet: pin the tag —
      `git -C vendor/damascus checkout v0.1.0` — and add an **Upgrading** section
      (checkout new tag → commit pointer → re-run `install.sh`; the install is
      idempotent and prunes/refreshes its own links).
- [ ] **Branch protection on `master`**: require PR + green CI, no force-push.
      Do **not** require a second approver — that deadlocks a solo maintainer;
      CI is the gate, and the temper-style self-review discipline covers the rest.

**Exit criteria:** `v0.1.0` release exists; README shows a pinned-tag install;
direct pushes to master are impossible (including for the founder).

## Phase 3 — Consumer-experience hardening *(reduces support burden before it exists; ~½–1 day)*

Every support question a solo maintainer never receives is time recovered. Make
`install.sh` self-diagnosing.

- [x] `install.sh --verify` (or `--doctor`): report every expected link, whether
      it exists, resolves, and is damascus-owned — the first thing to ask for in
      any bug report.
- [x] `install.sh --dry-run`: print planned actions without touching anything.
- [x] **Stale-link pruning**: install currently only writes the *current* name
      set, and uninstall only removes *known* names — a skill renamed upstream
      leaves an orphaned damascus-owned link forever. On install, sweep
      `.claude/{skills,agents}` and remove any damascus-owned link not in the
      current set.
- [x] Friendlier failures for the known sharp edges: uninitialized submodules
      (already handled), `.claude/skills` existing as a regular directory with
      real files, running from inside damascus (already handled), old bash.
- [x] Extend the CI smoke test to cover `--verify`, `--dry-run`, and the prune
      behavior (rename a skill in a fixture, re-install, assert the orphan is
      gone).

**Exit criteria:** a consumer with a broken setup can self-diagnose with one
command; the rename-orphan case has a regression test.

## Phase 4 — Automated maintenance *(the "still alive in 12 months" phase; ~2 hours)*

The recurring obligations are exactly two: vendor submodule bumps and upstream
breakage. Automate the noticing so nothing depends on the founder remembering.

- [x] **Dependabot for submodules** (`package-ecosystem: gitsubmodule`, monthly):
      opens PRs when superpowers / spec-kit publish new commits. The Phase 1
      smoke test then *validates the bump automatically* — the KEEP-list link
      step fails CI if upstream renames or removes a skill, which is precisely
      the failure a manual bump would miss.
- [x] Bump policy note in CLAUDE.md: only merge bumps that land on an upstream
      *tag*; re-check the DENY/KEEP/CONDITIONAL table when superpowers adds or
      renames skills (a new upstream skill overlapping a stage should become
      DENY).
- [x] Minimal `.github/ISSUE_TEMPLATE/bug.md` asking for `install.sh --verify`
      output, OS, and bash version — makes drive-by reports actionable without
      a round-trip.

**Exit criteria:** an upstream release produces a PR whose CI proves the bump is
safe (or shows exactly what broke) with zero founder-initiated effort.

## Phase 5 — Adoption polish *(optional; only after 0–4)*

- [ ] An `examples/` walkthrough or short screen capture: one feature taken
      forge → anvil → temper → quench in a toy repo, with the on-disk artifacts
      (`.prd/`, `specs/NNN-*/`) shown at each gate — the README describes the
      pipeline, but seeing the artifact trail is what converts.
- [ ] A "which stage do I start at?" decision note for partially-specified work
      (smithy resumes from artifacts; make that discoverable).
- [ ] Optionally publish to a skills marketplace/registry if one fits; the
      submodule + symlink model already works everywhere Claude Code runs.

---

## Sequencing summary

| Phase | Theme | Effort | Unblocks |
|-------|-------|--------|----------|
| 0 | License + requirements | ~1 h | any external adoption |
| 1 | CI + portability | ~½ day | trusting every future change |
| 2 | Tags + releases + branch protection | ~½ day | consumers pinning safely |
| 3 | `--verify` / `--dry-run` / prune | ~½–1 day | low-touch support |
| 4 | Dependabot + templates | ~2 h | 12-month sustainability |
| 5 | Examples & polish | as desired | conversion, not correctness |

Phases 0–2 are the production-readiness bar; 3–4 are what make it sustainable
for one person; 5 is growth. Total: roughly **2–3 focused days** to the bar,
one more to sustainability.

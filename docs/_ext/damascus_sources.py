"""Publish the repo's own Markdown into the Sphinx build, unchanged in substance.

The skills, agents, README, example trail and changelog stay the single source of
truth (CLAUDE.md: every contract lives in its SKILL.md body). At ``config-inited``
this extension copies each of them into ``docs/_generated/`` and makes three
mechanical edits so the copy builds cleanly:

* YAML frontmatter is stripped; its ``description`` becomes a lead paragraph, and a
  page without a level-1 heading gets one from its ``name``.
* Relative links are re-pointed: to the generated page when the target is published
  here, to the file itself when it sits under ``docs/``, otherwise to GitHub.
* Every page gets a "Source:" line linking the file it was generated from.

``_generated/`` is rebuilt on every run and is never committed.
"""

from __future__ import annotations

import posixpath
import re
import shutil
from pathlib import Path

REPO_URL = "https://github.com/forkrul/damascus_development"
BRANCH = "master"

# repo path -> generated docname (relative to docs/, without .md)
SOURCES = {
    "README.md": "_generated/overview",
    "CLAUDE.md": "_generated/contributing",
    "CHANGELOG.md": "_generated/changelog",
    **{f"skills/{s}/SKILL.md": f"_generated/skills/{s}"
       for s in ("smithy", "forge", "anvil", "temper", "quench", "hone")},
    **{f"agents/{a}.md": f"_generated/agents/{a}"
       for a in ("bdd-scenario-writer", "tdd-test-generator", "playwright-e2e-tester",
                 "fastapi-implementer", "labcoat")},
    "examples/README.md": "_generated/examples/index",
    "examples/cart-discounts/.prd/001_cart-discount-codes.md": "_generated/examples/prd",
    **{f"examples/cart-discounts/specs/001-cart-discount-codes/{f}.md": f"_generated/examples/{f}"
       for f in ("spec", "plan", "tasks", "review", "quench-log", "code-review", "smithy-log")},
}

# Directories that are aliases of a published file (README tables link to them).
DIR_ALIASES = {
    "examples": "examples/README.md",
    **{f"skills/{s}": f"skills/{s}/SKILL.md"
       for s in ("smithy", "forge", "anvil", "temper", "quench", "hone")},
}

LINK = re.compile(r"(!?)\[([^\]]*)\]\(([^)\s]+)\)")
FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.S)
FENCE = re.compile(r"^(`{3,}|~{3,})")


def _frontmatter(text: str) -> tuple[dict[str, str], str]:
    m = FRONTMATTER.match(text)
    if not m:
        return {}, text
    meta = {}
    for line in m.group(1).splitlines():
        key, sep, value = line.partition(":")
        if sep:
            meta[key.strip()] = value.strip()
    return meta, text[m.end():]


def _target(repo_path: str, out_doc: str, repo_root: Path) -> str:
    """Rewrite one relative link target found in ``repo_path``."""
    path, _, anchor = repo_path.partition("#")
    suffix = f"#{anchor}" if anchor else ""
    path = DIR_ALIASES.get(path.rstrip("/"), path.rstrip("/"))
    here = posixpath.dirname(out_doc)
    if path in SOURCES:
        return posixpath.relpath(SOURCES[path] + ".md", here) + suffix
    if path.startswith("docs/") and (repo_root / path).exists():
        return posixpath.relpath(path[len("docs/"):], here) + suffix
    kind = "tree" if (repo_root / path).is_dir() else "blob"
    return f"{REPO_URL}/{kind}/{BRANCH}/{path}{suffix}"


def _rewrite_links(body: str, src: str, out_doc: str, repo_root: Path) -> str:
    out, fence = [], None
    for line in body.splitlines(keepends=True):
        m = FENCE.match(line.lstrip())
        if m:
            marker = m.group(1)
            if fence is None:
                fence = marker
            elif marker[0] == fence[0] and len(marker) >= len(fence) and not line.strip()[len(marker):]:
                fence = None
            out.append(line)
            continue
        if fence is None:
            def repl(m: re.Match) -> str:
                bang, text, target = m.groups()
                if re.match(r"^[a-z][a-z0-9+.-]*:|^#", target):
                    return m.group(0)
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(src), target))
                return f"{bang}[{text}]({_target(resolved, out_doc, repo_root)})"
            line = LINK.sub(repl, line)
        out.append(line)
    return "".join(out)


def generate(app, config) -> None:
    docs_dir = Path(app.confdir)
    repo_root = docs_dir.parent
    gen = docs_dir / "_generated"
    if gen.exists():
        shutil.rmtree(gen)
    for src, doc in SOURCES.items():
        meta, body = _frontmatter((repo_root / src).read_text(encoding="utf-8"))
        body = _rewrite_links(body, src, doc, repo_root)
        source_line = f"*Source: [`{src}`]({REPO_URL}/blob/{BRANCH}/{src})*\n"
        lead = f"\n{meta['description']}\n" if "description" in meta else ""
        lines = body.lstrip("\n").splitlines(keepends=True)
        if lines and lines[0].startswith("# "):
            page = lines[0] + "\n" + source_line + lead + "".join(lines[1:])
        else:
            title = f"# `{meta['name']}`\n" if "name" in meta else f"# `{src}`\n"
            page = title + "\n" + source_line + lead + "\n" + "".join(lines)
        out = docs_dir / (doc + ".md")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(page, encoding="utf-8")


def setup(app):
    app.connect("config-inited", generate)
    return {"parallel_read_safe": True, "parallel_write_safe": True}

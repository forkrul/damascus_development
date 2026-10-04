# damascus docs

This folder is a [Sphinx](https://www.sphinx-doc.org/) site that also reads well on GitHub.

| Page | What it covers |
|------|----------------|
| [Architecture](architecture.md) | The contracts as diagrams: pipeline and artifacts, smithy's state machine, the adversarial review round, red-amber-green, parallel `[P]` tasks, how `install.sh` places a link, the superpowers policy |
| [Production readiness](production-readiness.md) | The phased single-founder plan and what remains manual |
| [Hero image provenance](assets/README.md) | How `hero.png` was made and why it carries no lettering |

The rest of the site is generated at build time from the files that ship, so there is
nothing to keep in sync by hand: the [README](../README.md), the six
[stage skills](../skills/), the five [quench agents](../agents/), the
[worked example](../examples/), [CONTRIBUTING-style guidance](../CLAUDE.md) and the
[changelog](../CHANGELOG.md). Read those directly on GitHub, or build the site:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r docs/requirements.txt
sphinx-build -W --keep-going -n -b html docs docs/_build/html   # any warning fails the build
open docs/_build/html/index.html                               # xdg-open on Linux
```

Diagrams are ` ```mermaid ` blocks: GitHub renders them natively, and Sphinx renders the
same blocks through `sphinxcontrib-mermaid`. Write new diagrams the same way, and link to
repository files outside `docs/` with absolute GitHub URLs so a page builds without
warnings and still works on GitHub.

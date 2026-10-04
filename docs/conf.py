"""Sphinx configuration for the damascus docs.

Build (CI runs exactly this; any warning fails it):

    python3 -m pip install -r docs/requirements.txt
    sphinx-build -W --keep-going -n -b html docs docs/_build/html
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "_ext"))

project = "damascus"
author = "forkrul"
copyright = "forkrul, MIT licensed"

extensions = [
    "myst_parser",
    "sphinxcontrib.mermaid",
    "damascus_sources",  # publishes README, skills, agents, example trail, changelog
]

source_suffix = {".md": "markdown"}
root_doc = "index"
# docs/README.md is the GitHub landing page for this folder; Sphinx starts at index.md.
exclude_patterns = ["_build", "README.md", "assets/hero-subject.txt"]

# ```mermaid fences render natively on GitHub; this makes the same fence a
# sphinxcontrib-mermaid directive, so one source serves both.
myst_fence_as_directive = ["mermaid"]
myst_heading_anchors = 3
myst_enable_extensions = ["colon_fence"]

html_theme = "furo"
html_title = "damascus"
html_static_path = []

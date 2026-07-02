---
name: Bug report
about: Something broke — installer, a stage skill, or a gate behaving wrongly
labels: bug
---

## What happened

<!-- What did you run, what did you expect, what did you get? -->

## Environment

- OS:
- `bash --version` (first line):
- damascus version (`git -C vendor/damascus describe --tags --always`):

## Installer health

<!-- Paste the full output of: -->

```
./vendor/damascus/install.sh --verify
```

## For skill/pipeline bugs

<!-- Which stage (forge / anvil / temper / quench / smithy), and the relevant
     artifact paths (.prd/NNN_*.md, specs/NNN-*/...) if applicable. -->

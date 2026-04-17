# Evaluator Overview

The evaluator is intentionally conservative.

It produces a candidate report with:

- required and optional command results
- path-boundary / architecture checks
- diff stats
- weighted metrics
- OpenEvolve-style `artifacts` fields for next-generation feedback

## Current default commands

Defaults come from `automation/config.toml`:

- backend: `python -m pytest backend/tests`
- website: `npm --prefix website run build`
- ios: `swift test --package-path ios/AmonKit`
- ops: no required command by default

Adjust lane commands in `automation/config.toml` as you learn what works best in this repo.

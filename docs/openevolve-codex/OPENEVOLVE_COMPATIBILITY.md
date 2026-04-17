# OpenEvolve Compatibility Notes

This scaffold is **OpenEvolve-style** rather than tightly coupled to the current OpenEvolve Python package internals.

Why:
- your mutation/implementation engine is Codex CLI
- task specs are repo-local and branch-based
- the evaluator produces `metrics` plus `artifacts`, which is the important OpenEvolve pattern
- next-generation prompts include previous execution feedback derived from those artifacts

## Current compatibility surface

Each candidate evaluation report includes:

- `metrics`
- `artifacts`
- `hard_gate_passed`
- diff stats
- changed files
- failing check names
- stderr excerpts

That is enough to support:

- selection
- diversity search across candidates
- artifact-informed next generations
- later export into another experiment framework if you want

## If you want a deeper direct OpenEvolve integration later

The next step would be to add a bridge that treats:
- the task + strategy prompt as the evolving artifact
- the candidate branch as the evaluated program
- the evaluator report as the fitness / artifact payload

This scaffold keeps that door open without binding your repo workflow to a specific library API today.

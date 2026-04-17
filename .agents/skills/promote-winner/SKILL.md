---
name: promote-winner
description: Use when the best candidate should be moved to an integration branch after passing the required quality gates.
---

Only promote if:
- required checks passed
- path policy passed
- no obvious docs drift remains for the task scope

Promotion should be conservative:
- move or create an integration branch
- do not merge to main unless explicitly instructed
- preserve the winning candidate branch for later inspection

+++
id = "T104"
title = "Extend browse orchestration to workspace reopen and saved-item flows"
status = "failed"
priority = 88
lane = "ios"
base_ref = "main"
allowed_paths = ["ios/"]
eval_profile = ["lane-default", "ux"]
candidate_count = 2
generation_budget = 1
non_goals = [
  "redesigning Workspace UX broadly",
  "adding new save artifact models",
]
done_when = [
  "Saved items reopen through the same decision/orchestration layer as search results",
  "Workspace no longer bypasses recommendation and protected-session eligibility logic",
  "required lane checks pass",
]
+++
## Objective

Make Workspace reopen behavior use the same product logic as Search so Amon feels like one system.

## Context

Relevant files:
- `ios/AmonKit/Sources/AmonKit/Views/WorkspaceDetailView.swift`
- `ios/AmonKit/Sources/AmonKit/Browsing/BrowseOpenOrchestrator.swift`
- `ios/AmonKit/Sources/AmonKit/Views/SearchView.swift`

## Acceptance signals

- Saved items can trigger the same chooser/options model.
- Recommendation and local-open-only constraints are consistent across Search and Workspace.
- Protected Session direct bypasses are reduced where they conflict with the shared flow.

## Notes for Codex

This task should build on T101. Keep it bounded to reopen/open behavior, not full workspace redesign.

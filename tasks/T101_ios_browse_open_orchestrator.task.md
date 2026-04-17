+++
id = "T101"
title = "Add shared browse open orchestrator for Search and Workspace"
status = "running"
priority = 100
lane = "ios"
base_ref = "main"
allowed_paths = ["ios/"]
eval_profile = ["lane-default", "ux"]
candidate_count = 3
generation_budget = 2
non_goals = [
  "redesigning the whole app",
  "changing backend runtime behavior",
  "broad view hierarchy rewrites",
]
done_when = [
  "Search and Workspace use one shared decision/open orchestration path",
  "ServeDecision handling is no longer duplicated in SearchView and WorkspaceDetailView",
  "required lane checks pass",
  "changes stay inside allowed paths",
  "tests or docs are updated when behavior changes",
]
+++
## Objective

Create one thin shared iOS orchestration layer for opening URLs/items across Standard, Clean View, and Protected Session.

## Context

Relevant files:
- `ios/AmonKit/Sources/AmonKit/Views/SearchView.swift`
- `ios/AmonKit/Sources/AmonKit/Views/WorkspaceDetailView.swift`
- `ios/AmonKit/Sources/AmonKit/Views/ReaderPageView.swift`
- `ios/AmonKit/Sources/AmonKit/API/AmonAPIClient.swift`

New files likely:
- `ios/AmonKit/Sources/AmonKit/Browsing/BrowseOpenOrchestrator.swift`
- `ios/AmonKit/Sources/AmonKit/Browsing/BrowseOpenModels.swift`

## Acceptance signals

- One shared orchestrator requests `ServeDecision`, normalizes options, and returns a typed chooser/open result.
- Search results and Workspace saved items both use it.
- Recommendation labeling, local-open-only behavior, and Protected Session availability are handled in one place.
- The renderer layer (`PrivacyAwarePageView`) stays a renderer, not the decision owner.

## Notes for Codex

Keep this thin. Do not redesign the app. The goal is to unify orchestration, not invent a new navigation architecture.

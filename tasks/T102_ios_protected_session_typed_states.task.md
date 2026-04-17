+++
id = "T102"
title = "Replace stringly Protected Session client states with typed states"
status = "failed"
priority = 98
lane = "ios"
base_ref = "main"
allowed_paths = ["ios/"]
eval_profile = ["lane-default", "ux"]
candidate_count = 3
generation_budget = 2
non_goals = [
  "changing the backend stream protocol",
  "rewriting the whole Protected Session screen",
]
done_when = [
  "ProtectedSessionViewModel uses typed session/connection states instead of banner-driven string states",
  "ProtectedSessionPageView renders clearer connecting/reconnecting/degraded/expired/ended/failed states",
  "required lane checks pass",
  "changes stay inside allowed paths",
]
+++
## Objective

Make Protected Session UI state intentional and typed, rather than inferred from strings and banner text.

## Context

Relevant files:
- `ios/AmonKit/Sources/AmonKit/ViewModels/ProtectedSessionViewModel.swift`
- `ios/AmonKit/Sources/AmonKit/Views/ProtectedSessionPageView.swift`
- `ios/AmonKit/Sources/AmonKit/API/ProtectedSessionStreamClient.swift`
- `ios/AmonKit/Sources/AmonKit/API/APIModels.swift`

## Acceptance signals

- Introduce typed states such as:
  - `connecting`
  - `live`
  - `reconnecting`
  - `degradedPolling`
  - `expired`
  - `ended`
  - `failed`
- Separate action state from session state.
- Terminal states are explicit and not collapsed into generic banners.
- UI copy and loading/error surfaces feel deliberate.

## Notes for Codex

Keep the current backend/runtime contract intact. This is a client-state cleanup and UX hardening pass.

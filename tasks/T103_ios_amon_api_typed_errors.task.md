+++
id = "T103"
title = "Decode backend error envelopes once in AmonAPIClient"
status = "failed"
priority = 92
lane = "ios"
base_ref = "main"
allowed_paths = ["ios/"]
eval_profile = ["lane-default"]
candidate_count = 2
generation_budget = 1
non_goals = [
  "changing backend error schema",
  "broad error copy redesign",
]
done_when = [
  "AmonAPIClient exposes typed API errors instead of pushing raw serverError bodies upward",
  "Presentation/error mapping uses structured fields",
  "required lane checks pass",
]
+++
## Objective

Centralize backend error decoding in the client so UI layers stop reparsing raw error strings.

## Context

Relevant files:
- `ios/AmonKit/Sources/AmonKit/API/AmonAPIClient.swift`
- `ios/AmonKit/Sources/AmonKit/API/APIModels.swift`
- `ios/AmonKit/Sources/AmonKit/Models/PresentationModels.swift`

## Acceptance signals

- `AmonAPIClient` decodes structured backend error payloads once.
- A typed `AmonAPIError` or equivalent carries status/code/message.
- UI presentation code maps typed errors rather than raw `serverError(statusCode:body)` strings.
- Existing client call sites still compile and behave safely.

## Notes for Codex

Prefer minimal change to public client APIs where possible. This is about contract discipline, not total API redesign.

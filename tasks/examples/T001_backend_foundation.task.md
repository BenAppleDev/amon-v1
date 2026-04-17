+++
id = "T001"
title = "Example backend task — replace with a real task before using"
status = "example"
priority = 10
lane = "backend"
base_ref = "main"
allowed_paths = ["backend/", "shared/openapi/", "shared/schema/"]
eval_profile = ["lane-default", "architecture"]
candidate_count = 3
generation_budget = 2
non_goals = [
  "changing ios or website code",
]
done_when = [
  "backend tests pass",
  "path policy passes",
]
+++

## Objective

Use this only as a reference structure for a real backend task.

+++
id = "T004"
title = "Example ops task — replace with a real task before using"
status = "example"
priority = 40
lane = "ops"
base_ref = "main"
allowed_paths = ["tools/", "docs/deployment/", "ops-dashboard/"]
eval_profile = ["lane-default", "architecture"]
candidate_count = 3
generation_budget = 2
non_goals = [
  "changing backend or ios or website code unless the task explicitly requires it",
]
done_when = [
  "path policy passes",
]
+++

## Objective

Use this only as a reference structure for a real ops task.

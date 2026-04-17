+++
id = "T003"
title = "Example iOS task — replace with a real task before using"
status = "example"
priority = 30
lane = "ios"
base_ref = "main"
allowed_paths = ["ios/"]
eval_profile = ["lane-default", "architecture"]
candidate_count = 3
generation_budget = 2
non_goals = [
  "changing backend or website code",
]
done_when = [
  "swift package tests pass",
  "path policy passes",
]
+++

## Objective

Use this only as a reference structure for a real iOS task.

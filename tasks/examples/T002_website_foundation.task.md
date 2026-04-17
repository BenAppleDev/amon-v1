+++
id = "T002"
title = "Example website task — replace with a real task before using"
status = "example"
priority = 20
lane = "website"
base_ref = "main"
allowed_paths = ["website/"]
eval_profile = ["lane-default", "architecture"]
candidate_count = 3
generation_budget = 2
non_goals = [
  "changing backend or ios code",
]
done_when = [
  "website build passes",
  "path policy passes",
]
+++

## Objective

Use this only as a reference structure for a real website task.

+++
id = "T000"
title = "Replace me with a real bounded task"
status = "draft"
priority = 100
lane = "backend"
base_ref = "main"
allowed_paths = ["backend/", "shared/openapi/", "shared/schema/"]
eval_profile = ["lane-default", "architecture"]
candidate_count = 3
generation_budget = 2
non_goals = [
  "broad unrelated refactors",
  "changing secrets or external infrastructure",
]
done_when = [
  "required lane checks pass",
  "changes stay inside allowed paths",
  "tests or docs are updated when behavior changes",
]
+++

## Objective

State the specific thing you want improved.

## Context

List the most relevant files, routes, modules, or user flows.

## Acceptance signals

Describe what a successful candidate should demonstrably achieve.

## Notes for Codex

Add task-specific warnings, tradeoffs, or implementation preferences.

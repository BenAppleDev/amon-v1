---
name: task-planner
description: Use when a task file from tasks/ needs to be translated into an implementation plan, path boundary, and verification checklist before editing starts.
---

1. Read the task file completely.
2. Extract:
   - objective
   - lane
   - allowed paths
   - done_when items
   - non_goals
   - required eval profile
3. Produce a short execution plan:
   - files likely to change
   - tests/checks to run
   - biggest risks
4. Do not start editing until the plan is grounded in actual repository files.

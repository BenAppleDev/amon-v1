# Amon Vision

Amon explores what a privacy-first AI assistant could look like when the product is useful enough to support real research and comparison work, but still disciplined about what the server and operators are allowed to see.

## Who it is for

- people doing research, comparison, or synthesis work who want help from AI tools
- teams that need clearer operational boundaries than "send everything to the cloud and inspect it later"
- builders evaluating what a responsible local-first or metadata-limited workflow could look like

## Product direction

- Keep retrieval and research workflows practical and easy to demo.
- Treat user queries and fetched page content as transient whenever possible.
- Keep durable user work local to the client or export bundle rather than turning the backend into a permanent knowledge vault.
- Give operators enough metadata to keep the system healthy without giving them routine access to page contents, form values, or user work product.

## Constraints

- privacy and user trust come before convenience for operators
- prototype surfaces should stay easy to run locally and easy to understand
- handoff matters: the repo should be readable by another engineer without hidden setup knowledge
- public docs should stay honest about what is unfinished

## What success looks like in this repo

- a reviewer can understand the architecture quickly
- the backend demo runs locally without hidden dependencies
- the privacy/operator boundary is visible in both code and docs
- internal or experimental routes are clearly marked as prototype-only
- the project is credible as a public-interest AI systems prototype, even before full product hardening

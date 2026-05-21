---
name: my-new-skill
description: "One-paragraph trigger surface. State what the skill does AND when to use it, including specific phrases users would type. Aim for 800-1000 chars (hard limit 1024). Avoid angle brackets — the validator rejects '<' and '>'. Be pushy: skills tend to under-trigger, so list 5-10 concrete phrases."
license: MIT
compatibility: "Constraints worth knowing: required runtimes, required MCP plugins, surface limitations. Max 500 chars."
metadata:
  author: opensubagents
  version: "0.1.0"
---

# my-new-skill

One paragraph: what this skill is for, why it exists, who it pairs with (if anything).

## When to use

- Trigger phrase 1
- Trigger phrase 2
- Concrete scenario where this beats freeform Claude

## When NOT to use

- Adjacent case that should go to a different skill or to freeform Claude

## Workflow

Steps. Number them. Each step is independently verifiable.

1. Inspect: what does the agent know about the current state?
2. Plan: what's the target state?
3. Act: which tools / files / commands?
4. Verify: how does the agent confirm it worked?

## Bundled references

- `references/<topic>.md` — load when the agent needs deep detail beyond the table above
- `scripts/<helper>.sh` — execute as the deterministic alternative to "ask the LLM to do it"

## Operational rules

Non-negotiable invariants the agent must respect (paths, timeouts, idempotency, error-handling).

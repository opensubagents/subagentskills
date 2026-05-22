---
name: anthropic-subprocessor-lanes
description: "Look up Anthropic's 18 subprocessors from trust.anthropic.com and surface each one's public developer footprint across three lanes — npm packages, GitHub repositories, and skills.sh agent skills. Pairs with the bundled MCP server (org_lanes, anthropic_subprocessors, anthropic_subprocessor_report tools). TRIGGER on phrases like 'who does Anthropic use as a subprocessor', 'list Anthropic's vendors', 'show me Anthropic subprocessor data', 'npm + github + skills.sh for X', 'is vendor X on skills.sh', 'how many repos does Cloudflare have', 'trust.anthropic.com lanes', 'subprocessor compliance report', 'supply chain snapshot Anthropic'. Use the snapshot read (zero network, instant) by default; only call the live report when the user asks for a refresh or asks about a moment after 2026-05-21."
license: MIT
compatibility: "Pairs with the local MCP server at src/server.ts (run via tsx). Requires Node 20+ and outbound HTTPS to www.npmjs.com, api.github.com, and www.skills.sh for live refresh. Snapshot read works offline. trust.anthropic.com itself is Vanta-hosted JS-rendered — the subprocessor list is maintained by hand in data/subprocessors.json."
metadata:
  author: opensubagents
  version: "0.1.0"
  pairs_with_plugin: "in-repo: src/server.ts"
  snapshot_verified_at: "2026-05-21"
---

# anthropic-subprocessor-lanes

Anthropic discloses 18 subprocessors on trust.anthropic.com/subprocessors. Each is a real company with a public developer surface — npm scope, GitHub org, skills.sh page. This skill answers "who, where, how big" by joining the trust-page list against those three lanes.

## Why this skill exists

The trust page is Vanta-rendered (JS-only — a plain fetch returns empty meta tags). Re-typing the 18 names every time someone asks "does Anthropic use Stripe" is wasteful. The skill encodes:

1. The 18 names + per-lane slugs, hand-maintained in data/subprocessors.json and embedded in the MCP server snapshot. Verified 2026-05-21.
2. Three scrape recipes (npm/github/skills.sh) tuned against quirks that bit during authoring — see references/lane-quirks.md.
3. A Code Mode entry point (anthropic_subprocessor_report) that fans out 18×3 lookups in one tool call rather than 54.

## When to use

- "What does Anthropic depend on?" / supply-chain / compliance questions
- "Show me Cloudflare's GitHub repos / skills.sh footprint"
- "Is vendor X on the Anthropic subprocessor list?"
- Refreshing the snapshot after Anthropic updates the trust page

## When NOT to use

- Looking up an arbitrary org not on the Anthropic list — use the generic org_lanes tool with explicit slugs, no need for the snapshot.
- Anything requiring actual TLS cert / DPA / GDPR detail — those live on trust.anthropic.com itself; this skill is the developer-surface joiner.

## Workflow

1. Default path (zero network): call anthropic_subprocessors — returns the 18 entries with embedded snapshot (npm first-page count, github total_count + top repo, skills.sh skills/sources). Instant.
2. Live refresh: call anthropic_subprocessor_report — re-runs the three-lane fan-out against today's data. Slower but current.
3. One-off lookup: call org_lanes with a single slug for any org (not just Anthropic's subprocessors).
4. Snapshot update: when Anthropic publishes a new subprocessor, edit data/subprocessors.json AND the SEED loader in src/server.ts will pick it up on next start. Bump snapshot_verified_at in this SKILL.md frontmatter.

## Bundled resources

- src/server.ts — the MCP server (3 tools, stdio transport, native fetch only)
- src/package.json + src/tsconfig.json — runnable via tsx src/server.ts
- data/subprocessors.json — canonical 18-vendor list with per-lane slugs and verified snapshot
- references/lane-quirks.md — quirks per lane (Cloudflare/Twilio unscoped, Sentry's missing skills.sh page, ElevenLabs WAF 403, npm pagination floor)

## Operational rules

- Snapshot is canonical for the verification date. If a caller needs a live number, they must explicitly ask for the report tool — otherwise return the snapshot.
- Lane skips are intentional, not errors. Nutun and Boldr (user-support BPOs) have no public dev presence — npm/github/skillsSh: null is correct, not missing data.
- Cloudflare and Twilio publish unscoped packages. @cloudflare/* and @twilio/* are mostly empty — the org's flagship npm package is cloudflare, twilio. Document this quirk; don't "fix" the 0.
- Never invent skills.sh slugs. If a vendor has no skills.sh page, leave skillsSh: null. Sentry's 404 is in the snapshot for exactly this reason.

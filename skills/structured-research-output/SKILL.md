---
name: structured-research-output
description: Deliver research findings as a decomposed task-list-style structured output instead of prose, and maintain a session-level URL ledger that accumulates every source touched during research. Use this skill whenever a response involves more than five web sources, whenever the user says "no prose", "task list", "decomposed", "structured", or "atomic", whenever the research-brief-xml skill is active, and whenever the response would otherwise contain multi-sentence prose paragraphs summarizing findings, vendor capabilities, or recommendations. Apply this to every research-style deliverable unless the operator brief explicitly demands prose.
license: MIT
compatibility: "No runtime dependencies. Uses /home/claude/research_urls.json as the session ledger path, so requires a writable container filesystem. Pairs with research-brief-xml. Designed for hosts with web_search / web_fetch and a present_files affordance."
metadata:
  author: opensubagents
  version: "0.1.0"
  pairs_with_skill: "research-brief-xml"
  spec: "https://agentskills.io/specification"
---

# Structured Research Output

Two responsibilities:

1. **URL ledger** — every web_search, web_fetch, drive_search, or extended-research source touched during the session is appended to a single JSON file the user can download at the end.
2. **Decomposed output** — the deliverable arrives as atomic items (numbered claims with one citation each, checklist blocks with status markers, single decision block) instead of multi-sentence prose paragraphs.

The two responsibilities reinforce each other: atomic claims map one-to-one to ledger entries, so every finding is independently verifiable from the index.

## When to use

- A response will cite more than five web sources.
- The user says "no prose", "task list", "decomposed", "structured", or "atomic".
- The `research-brief-xml` skill is active for the current turn.
- The deliverable would otherwise be multi-sentence prose paragraphs summarizing findings, vendor capabilities, or recommendations.
- Any research-style deliverable, unless the operator brief explicitly demands prose.

## When NOT to use

- Quick factual lookups, definitions, or single-document summaries.
- Conversational replies where one or two sentences suffice.
- Operator brief whose `<output_format>` or `<style_guidance>` explicitly demands prose narrative.
- Code-only deliverables with no source-cited findings.

## URL ledger

Maintain `/home/claude/research_urls.json` for the duration of the session. Append on every URL touch. Do not lose entries between turns — read the file, append, write back.

### Schema

```json
{
  "session_started_at": "2026-05-21T14:30:00Z",
  "topic": "claude_code_otel_backend_selection",
  "entries": [
    {
      "url": "https://axiom.co/docs/guides/opentelemetry-claude-code",
      "title": "OpenTelemetry Claude Code - Axiom Docs",
      "domain": "axiom.co",
      "first_seen": "2026-05-21T14:33:12Z",
      "topic_tag": "axiom_claude_code_guide",
      "claim_supported": "Axiom publishes a Claude-Code-specific OTLP routing guide",
      "primary": true
    }
  ]
}
```

- `primary` = vendor docs, official GitHub READMEs, RFCs, government sites, standards bodies.
- non-primary = third-party blogs, aggregators, forums, Stack Overflow.
- `topic_tag` = short snake_case key for grouping (e.g., `axiom_cf_workers`, `honeycomb_metrics_beta`).
- `claim_supported` = the specific claim this URL backs, in one phrase. Update if a later turn finds a more specific use.

### Operations

**Append on every URL touch.** Before writing a citation in the response, ensure the URL is in the ledger. Read → check → append-if-new → write.

**Deduplicate by URL.** If a URL appears twice, keep one entry; refine `claim_supported` to the most specific claim if a later use is narrower.

**Prefer primary sources for citation.** If two URLs in the ledger support the same claim, cite the one with `primary: true`.

**At session end, present the ledger.** When delivering the final report, also call `present_files` on `/home/claude/research_urls.json` and add one summary line: "Source ledger: N URLs across M domains, K primary."

### Bootstrap

If the ledger does not exist at the start of a research turn, create it. If it exists from a prior turn, read and append — do not overwrite.

```python
import json, os
from datetime import datetime, timezone

LEDGER = "/home/claude/research_urls.json"

def load_ledger(topic: str) -> dict:
    if os.path.exists(LEDGER):
        with open(LEDGER) as f:
            return json.load(f)
    return {
        "session_started_at": datetime.now(timezone.utc).isoformat(),
        "topic": topic,
        "entries": [],
    }

def append_url(ledger: dict, url: str, title: str, domain: str,
               topic_tag: str, claim: str, primary: bool) -> None:
    for e in ledger["entries"]:
        if e["url"] == url:
            if claim and len(claim) < len(e.get("claim_supported", "")):
                e["claim_supported"] = claim
            return
    ledger["entries"].append({
        "url": url, "title": title, "domain": domain,
        "first_seen": datetime.now(timezone.utc).isoformat(),
        "topic_tag": topic_tag, "claim_supported": claim, "primary": primary,
    })

def save_ledger(ledger: dict) -> None:
    with open(LEDGER, "w") as f:
        json.dump(ledger, f, indent=2)
```

For extended research (where intermediate URLs are not visible to the calling Claude), populate the ledger from the citation list in the returned report. Each cited URL becomes one entry with `claim_supported` set to the sentence the citation backs.

## Decomposed output: replace prose with atoms

Prose hides structure. Atomic items make structure visible and independently checkable.

### Findings → numbered claims, one citation each

❌ Don't:
> Axiom is documented end-to-end for this workflow. Its first-party guide describes routing claude_code.* metrics into two datasets, and the MCP server itself runs on Cloudflare Workers, which makes the integration story unusually deep…

✅ Do:
```
1. Axiom publishes a Claude-Code-specific OTLP guide. [axiom.co/docs/guides/opentelemetry-claude-code]
2. Axiom routes claude_code.* metrics and events into two datasets via x-axiom-dataset headers. [axiom.co/docs/send-data/opentelemetry]
3. Axiom MCP server is itself hosted on Cloudflare Workers at mcp.axiom.co/mcp. [github.com/axiomhq/mcp]
4. Axiom metrics product went GA on 2026-03-27. [axiom.co/changelog/metrics-mpl]
```

One sentence, one citation, one verifiable fact per row.

### Vendor / candidate sections → checklist blocks

Replace multi-paragraph deep dives with a fixed-shape block per entity:

```
### Axiom
- CF Workers OTel path: ✅ first-party guide [axiom.co/docs/guides/opentelemetry-cloudflare-workers]
- OTLP metrics: ✅ GA 2026-03-27 [axiom.co/changelog/metrics-mpl]
- OTLP logs: ✅ Events dataset [axiom.co/docs/send-data/opentelemetry]
- OTLP traces: ✅ Events dataset [axiom.co/docs/send-data/opentelemetry]
- prompt.id correlation: ✅ APL `where prompt_id == ...` against Events
- Cost-analysis query surface: APL (Kusto-like) + MPL pipeline + visual builder
- Pricing dimension: $/GB ingest, no active-series tax [axiom.co/pricing]
- MCP for observability: ✅ mcp.axiom.co/mcp [github.com/axiomhq/mcp]
- Cloudflare-native composition: parallel to Workers Logs, does not replace
```

**Status markers:**
- ✅ verified from a primary source
- ⚠️ partial, beta, or has documented carve-outs
- ❌ not supported
- ❓ not verified — gated, missing doc, or contradicting sources

Use the exact same row labels across every entity in the comparison so readers can scan vertically.

### Recommendation → single decision block

```
### Decision: Axiom
- Primary reason: only candidate with GA OTLP across metrics + logs + traces, plus CF-hosted MCP, plus per-GB pricing immune to high-cardinality
- Confidence: high
- Hard-constraint check: ✅ Cloudflare Workers OTel path documented
- Switch-to triggers:
  - Switch to Honeycomb if monthly events ≤ 100M and pre-built Claude Code board template matters more than metrics SLOs
  - Switch to Grafana Cloud if team has PromQL/LogQL fluency and accepts Adaptive Metrics cardinality truncation
```

### Risks → severity-tagged bullets

```
- ⚠️ Honeycomb Metrics is Beta as of May 2026; no SLOs on metrics [docs.honeycomb.io/troubleshoot/product-lifecycle/experimental-features/metrics]
- ⚠️ Grafana active-series pricing scales with user.account_id × model cross-product
- ❓ Axiom per-GB cost at OTEL_LOG_USER_PROMPTS=1 volume not modeled — bytes/event not published
```

### Comparison matrices → keep as tables

Tables are already decomposed. Use them. Do not duplicate table content into prose elsewhere in the response.

## Default output skeleton

Unless the operator brief's `<output_format>` overrides this:

```
## Decision
[single block, ≤6 lines]

## Comparison
[matrix table with one row per candidate]

## Per-candidate checklists
[one ✅/⚠️/❌/❓ block per candidate, identical row labels]

## Switch triggers
[bullets — when to prefer runner-up]

## Risks & unknowns
[severity-tagged bullets]

## Source ledger
[present_files: /home/claude/research_urls.json]
[N URLs across M domains, K primary]
```

If the brief specifies different section names, follow the brief — but apply atomic style within each section.

## What "avoid prose" means in practice

**Banned:** multi-sentence paragraphs that string findings together with connective tissue ("Honeycomb is the strongest narrative for X, and on the events side, cardinality is genuinely unlimited and the MCP server adds further leverage…"). These hide which claim is backed by which source.

**Allowed:** short section headers, single-sentence framing before a list ("Three vendors meet the hard constraint:"), table captions, the one-sentence summary line on the source ledger.

**Rule of thumb:** if a sentence contains more than one citation, split it. If a paragraph contains more than three sentences, convert to a list.

## Self-check before delivery

1. Every claim that came from a web source has a citation.
2. Every citation URL is in `/home/claude/research_urls.json`.
3. No paragraph exceeds three sentences.
4. The decision is a single named block, not a paragraph.
5. The ledger file is presented alongside the report via `present_files`.

If any check fails, fix before delivery.

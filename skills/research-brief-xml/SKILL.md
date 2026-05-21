---
name: research-brief-xml
description: Author or follow elaborate XML-tagged research briefs for high-stakes research tasks. Use this skill whenever a user asks to "research", "evaluate", "compare", "recommend", "deep dive", or "do due diligence" on more than one entity or along more than one axis — even if phrased casually. Also use this skill whenever an incoming message already contains XML tags such as role, task, research_questions, output_format, success_criteria, or final_instruction; that is the operator brief format and must be followed verbatim. Pair this with the structured-research-output skill so the final answer arrives as decomposed atomic items rather than prose.
license: MIT
compatibility: "No runtime dependencies. Pairs with structured-research-output — when this skill fires, that skill should also fire so the deliverable arrives as decomposed atoms. Mode A (operator XML brief present) is verbatim-driven; Mode B (drafted from a casual request) is inference-driven."
metadata:
  author: opensubagents
  version: "0.1.0"
  pairs_with_skill: "structured-research-output"
  spec: "https://agentskills.io/specification"
---

# Research Brief XML

High-stakes research produces better answers when the request is structured as an elaborate XML brief: a clear analyst role, scoped questions, an explicit output format, and success criteria the answer can be checked against. Loose prompts produce loose research. Structured prompts produce decisive, sourced reports.

This skill operates in two modes.

## When to use

- User asks to "research", "evaluate", "compare", "recommend", "deep dive", or "do due diligence" — even casually — on more than one entity or more than one axis.
- Incoming message already contains XML tags such as `<role>`, `<task>`, `<research_questions>`, `<output_format>`, `<success_criteria>`, or `<final_instruction>`. That is the operator brief format; follow it verbatim.
- Any final-recommendation deliverable across multiple candidates.

## When NOT to use

- Quick factual lookups, definitions, code snippets, single-document summaries.
- Conversational requests where a one-sentence answer suffices.
- Single-entity status checks ("what is X?") with no comparison axis.

## Mode A — Brief already supplied

The incoming message contains XML tags like `<role>`, `<task>`, `<research_questions>`, `<output_format>`, `<success_criteria>`, `<final_instruction>`. The operator has already written the brief.

- Follow it precisely. The brief is the spec.
- Do not ask clarifying questions if `<final_instruction>` says not to.
- Match the `<output_format>` structure verbatim — same section names, same order, same tables, no extra sections.
- Cite per `<methodology>`. If `<methodology>` is silent on citations, default to inline primary-source URLs.
- Before delivery, re-read `<success_criteria>` and verify each one. Fix the response if any criterion fails.

## Mode B — User asks for research, no brief supplied

Triggers: "research X", "compare A vs B vs C", "evaluate vendors for Y", "recommend the best Z", "deep dive on W", "due diligence on Q".

1. Decide if the task warrants a brief. Comparisons of more than one entity, evaluations along more than one axis, and any request for a final recommendation warrant one. Quick factual lookups do not.
2. Draft an XML brief from the user's intent. Infer reasonable defaults for anything not specified — do not interrogate the user.
3. Either run the brief immediately, or show it and ask in one sentence whether they want to refine. Default to running it.

## Schema

Use only the sections that earn their place. Short briefs are fine. Order matters — role first, final_instruction last.

```xml
<role>
  Who the assistant is for this task. One to three sentences. Name the persona's seniority,
  their evaluation axes, and their bias toward decisiveness.
  Example: "You are a senior observability platform analyst. You evaluate backends on three
  axes: (1) X, (2) Y, (3) Z. You are decisive and make a final recommendation rather than a
  balanced both-sides summary."
</role>

<task>
  What to do, two to four sentences. Hard constraints inline. State explicitly what NOT to
  do — e.g., "Do not ask me to define anything. Decide and justify."
</task>

<context>
  <prior_research>What the user already knows; do not rediscover.</prior_research>
  <known_facts>Verified facts to treat as ground truth (flag if contradicting evidence appears).</known_facts>
  <constraints>Hard requirements. Soft preferences. Deal-breakers.</constraints>
</context>

<research_questions>
  Numbered, specific, answerable. Each question covers one thing. Five to ten for a vendor
  evaluation; three to five for a focused comparison.
</research_questions>

<scope>
  In scope: entities that must be evaluated.
  Out of scope: entities to dismiss briefly or not at all.
  Override clause: under what condition an out-of-scope item earns its way back in.
</scope>

<methodology>
  Parallelize independent lookups. Cite every non-trivial claim with a primary source URL.
  Source preference order (e.g., vendor docs > official GitHub READMEs > third-party blogs).
  How to handle source contradictions. Rules for pricing or gated content.
</methodology>

<output_format>
  The exact section structure. Use XML tags or markdown headers. Specify table columns where
  tables are required. Specify max length per section. This is the contract.
</output_format>

<style_guidance>
  Tone, formatting preferences, hedging tolerance. Use this section to suppress AI-isms:
  excessive headers, balanced both-sides framing, hedging without resolving signal.
</style_guidance>

<success_criteria>
  Five or so concrete tests the output must pass. Used as a self-check before sending.
  Example: "Names a single recommended vendor in the first sentence."
</success_criteria>

<final_instruction>
  One imperative sentence. Almost always: "Begin research now. Do not ask clarifying questions.
  Write the report when you have enough evidence."
</final_instruction>
```

## Drafting heuristics

**Decisiveness is the single highest-leverage line.** In `<role>`: "You are decisive." In `<task>`: "Decide and justify rather than asking me to define anything." A brief that doesn't authorize decisiveness yields a comparison table with no recommendation.

**Hard constraints live in `<task>` and `<scope>`, never `<style_guidance>`.** "Must integrate with Cloudflare" is a deal-breaker — it goes in `<task>` as a hard requirement, and `<scope>` excludes any candidate that fails it. Burying it in `<style_guidance>` makes it negotiable.

**`<output_format>` is a contract, not a suggestion.** If the brief asks for `<executive_recommendation>`, `<comparison_matrix>`, `<vendor_deep_dives>`, `<runner_up_and_when_to_switch>`, `<risks_and_unknowns>` in that order, that is the deliverable. Do not insert other sections.

**`<success_criteria>` are runtime checks.** Before sending, re-read each criterion and verify. If "names a single recommended vendor in the first sentence" fails, fix it.

**Inference over interrogation.** When drafting a brief from a casual request, infer source preferences, scope, depth. Show the brief if useful, but proceed.

## Examples

**Trigger (Mode A):** Operator message contains `<role>You are a senior observability platform analyst...</role>` plus `<output_format>` naming five required sections plus `<final_instruction>Begin research now.</final_instruction>`. Follow it verbatim, deliver to spec.

**Trigger (Mode B):** User says "help me pick a telemetry backend for our Cloudflare Workers — Honeycomb, Axiom, Grafana Cloud, maybe others." Draft a brief: role is "senior observability platform analyst", task includes the Cloudflare hard constraint, scope names the three vendors with an override clause, output format requires exec recommendation + matrix + deep dives + runner-up + risks.

**Not a trigger:** "what is OTLP?" — single-sentence answer, no brief.

## Pair with structured-research-output

When this skill triggers, the `structured-research-output` skill should also trigger. It enforces a URL ledger file plus decomposed atomic output formatting (numbered findings, vendor checklists with ✅/⚠️/❌/❓ markers, single decision block) so the brief's `<output_format>` arrives clean rather than padded with prose.

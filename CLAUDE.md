# CLAUDE.md

Repo-wide guidance for Claude (and other coding agents) working inside `opensubagents/subagentskills`.

## What this repo is

A catalog of [Agent Skills](https://agentskills.io/specification) used across the opensubagents stack. Two things live here:

1. `skills/<name>/` — actual skill directories, each with `SKILL.md` at the root
2. `.claude-plugin/marketplace.json` — the catalog manifest. Lists every skill (released or planned), with source pointers

External consumers point at this repo to discover and install skills. CI guarantees that every entry in the marketplace either has a working `SKILL.md` on disk (`status: "released"`) or is openly marked `"planned"`.

## What to do when asked to "add a new skill"

1. Read `template/SKILL.md` and copy it to `skills/<your-skill>/SKILL.md`.
2. Author the skill. Validate locally via the anthropics/skills `quick_validate.py`. Keep `description` ≤1024 chars, `compatibility` ≤500 chars, no `<` or `>` in either.
3. If the skill bundles helpers, put them in `skills/<your-skill>/scripts/` (executable) or `skills/<your-skill>/references/` (read-on-demand markdown).
4. Add a corresponding entry to `.claude-plugin/marketplace.json`. Start with `status: "planned"` while drafting, flip to `"released"` once the skill is verified.
5. Open a PR. CI (`validate-frontmatter` + `validate-marketplace`) will block merge if anything is broken.

## What to do when asked to "edit an existing skill"

1. Preserve the directory name and the `name:` field in frontmatter. Tools downstream key on these.
2. If the skill bundles scripts and the change affects observable behavior, update the skill's own version in frontmatter (`metadata.version`) AND in `marketplace.json`.
3. If the skill is paired with an MCP plugin (`pairs_with_plugin` field), bump the corresponding minimum version constraint in `compatibility:` when the change requires a newer plugin.

## What this repo does NOT do

- It does **not** host MCP servers themselves. Those live in their own repos (e.g. `opensubagents/ts-bootstrap-mcp`). Skills that drive an MCP server reference it via `pairs_with_plugin`.
- It does **not** vendor the agentskills.io spec. See `spec/agent-skills-spec.md` for a pointer.
- It does **not** ship runtime code that a host application calls. A host loads skills via the marketplace manifest or by extracting a `.skill` zip; this repo is config + content only.

## Source-of-truth files (do not edit casually)

- `template/SKILL.md` — copy-paste source for new skills. If you change this, you're changing every future skill's starting shape.
- `.github/workflows/validate-*.yml` — gates for the whole catalog. Breaking them blocks every PR.
- `LICENSE` — MIT, matches sibling repos.

## Coding agent etiquette

- Don't reformat existing skill markdown unless the change is in scope.
- Don't reorder `.claude-plugin/marketplace.json` entries; insert new ones at the end of the array.
- When in doubt about a skill's intent, read its own `SKILL.md` and `references/` BEFORE proposing changes.

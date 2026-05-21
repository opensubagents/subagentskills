# subagentskills

> Catalog of [Agent Skills](https://agentskills.io/specification) used across the opensubagents stack.

Each skill is a directory containing `SKILL.md` plus optional `references/`, `scripts/`, and `assets/` subdirectories. The catalog manifest lives at [`.claude-plugin/marketplace.json`](./.claude-plugin/marketplace.json).

## Skills

| Skill | Status | Pairs with | Tags |
|---|---|---|---|
| [`ts-bootstrap`](./skills/ts-bootstrap/) | released | [`@opensubagents/ts-bootstrap-mcp`](https://github.com/opensubagents/ts-bootstrap-mcp) | typescript, bootstrap, mcp-server, cloudflare-worker |
| `reveal-and-restore-worker-token` | planned | — | cloudflare, secrets, ops-pattern |
| `html-effectiveness-builder` | planned | — | html, rendering, reports |
| `subagenttasks-validator` | planned | [`@opensubagents/subagenttasks`](https://github.com/opensubagents/subagenttasks) | validation, json-schema, tasks |
| `graphql-erd-from-zod` | planned | — | graphql, zod, erd, html |
| `brief-author-canonical` | planned | [`@opensubagents/subagentbriefs`](https://github.com/opensubagents/subagentbriefs) | docs, briefs, authoring |

## Install

Three ways to consume a skill from this catalog:

**1. Drop a `.skill` zip into your host.** Some skill authors publish prebuilt `.skill` artifacts in their source repo's release assets — e.g. `ts-bootstrap.skill` ships at `opensubagents/ts-bootstrap-mcp/dist-skills/ts-bootstrap.skill`. Download and install per your host's flow (claude.ai: Settings → Capabilities → Skills; Claude Code: extract into `~/.claude/skills/`).

**2. Clone a single skill directory:**

```bash
curl -sSL https://github.com/opensubagents/subagentskills/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C ~/.claude/skills \
    subagentskills-main/skills/ts-bootstrap
```

**3. Reference the marketplace manifest from your host** (preferred for multi-skill installs). Point your host at:

```
https://raw.githubusercontent.com/opensubagents/subagentskills/main/.claude-plugin/marketplace.json
```

The host walks the `skills[]` array and resolves each `source.path` against this repo's HEAD.

## Author a new skill

```bash
cp -r template skills/<your-skill>
$EDITOR skills/<your-skill>/SKILL.md

# validate locally (clones the official validator into /tmp)
git clone --depth 1 https://github.com/anthropics/skills /tmp/anthropics-skills
( cd /tmp/anthropics-skills/skill-creator && python3 -m scripts.quick_validate "$PWD/../../../skills/<your-skill>" )

# add a marketplace entry (status: "planned" while drafting, "released" once verified)
$EDITOR .claude-plugin/marketplace.json

# open a PR — CI re-runs validation
```

See [`CLAUDE.md`](./CLAUDE.md) for coding-agent guidance and [`spec/agent-skills-spec.md`](./spec/agent-skills-spec.md) for the spec pointer.

## Repo layout

```
.
├── .claude-plugin/
│   └── marketplace.json              # canonical catalog manifest
├── .github/workflows/
│   ├── validate-frontmatter.yml      # quick_validate every skill on every PR
│   └── validate-marketplace.yml      # cross-check manifest ↔ skills/ on disk
├── skills/
│   └── ts-bootstrap/                 # the one released skill (so far)
│       ├── SKILL.md
│       ├── references/
│       │   ├── workflows.md
│       │   ├── tool-schemas.md
│       │   └── troubleshooting.md
│       └── scripts/
│           ├── check.sh
│           └── install.sh
├── template/
│   └── SKILL.md                      # copy-paste starter for new skills
├── spec/
│   └── agent-skills-spec.md          # pointer to agentskills.io/specification
├── CLAUDE.md                         # agent guidance
├── README.md
└── LICENSE                           # MIT
```

## Deferred for v0.1 (will be added when there's a real consumer)

- `.cursor-plugin/` — mirror manifest for Cursor's plugin format
- `.mcp.json` — references to MCP servers any skill depends on
- `evals/` — Neon-style per-skill test fixtures
- `.github/workflows/bump-skill-shas.yml` — nightly SHA pin updates via the `gh-pr-mcp` worker

## License

MIT — matches the sibling opensubagents repos.

---
name: ts-bootstrap
description: "Bootstrap TypeScript projects in cloud web sandboxes and Claude Code sessions by driving the @opensubagents/ts-bootstrap-mcp plugin's 7 tools (ts_env_inspect, ts_project_init, ts_install, ts_typecheck, ts_run, ts_build, ts_clean). Use this skill whenever the user wants to scaffold a new TypeScript project (node-cli, Cloudflare Worker, MCP server, or library), install the strict-baseline / cf-worker / mcp-server toolchain preset, run tsc --noEmit, build to dist/, or clean node_modules + dist. Triggers on phrases like 'set up a TS project', 'scaffold an MCP server', 'new cf worker', 'install typescript baseline', 'bootstrap typescript', 'create a new node CLI', 'install the mcp sdk', 'I need a tsconfig', 'typecheck my project', 'build my TS lib', 'reset my node_modules'. Also fires on fresh sandbox prompts needing the standard init → tsconfig → install → typecheck → build flow. Always run scripts/check.sh first; if the plugin is not reachable, run scripts/install.sh before any tool calls."
license: MIT
compatibility: "Pairs with @opensubagents/ts-bootstrap-mcp@^0.1.0. Works in: (a) Claude Code where the MCP server is registered via `claude mcp add`, (b) claude.ai web/mobile chat sandboxes via the install script, (c) any host with code execution that can spawn npx. Requires Node 18 or newer and npm in PATH."
metadata:
  author: opensubagents
  version: "0.1.0"
  pairs_with_plugin: "@opensubagents/ts-bootstrap-mcp"
  spec: "https://agentskills.io/specification"
---

# ts-bootstrap

Pairs 1:1 with the `@opensubagents/ts-bootstrap-mcp` plugin. When this skill fires, an agent already knows the seven tools the plugin exposes and the canonical workflows for using them — no second-guessing about parameter shapes or call order.

## Why this skill exists

Every fresh cloud web sandbox starts identical: Node 22, npm 10, no project files. The same 5-step setup (`npm init`, write a strict tsconfig, install `tsx + typescript + @types/node`, run `tsc --noEmit`, run `tsc`) plays out on every cold-start. The MCP plugin collapses those steps into seven tool calls — this skill tells an agent **which tool, with which args, in which order**.

Without the skill, an agent looking at the plugin sees 7 tool names and 4 templates and has to discover the right composition by trial and error. With the skill, the agent reads one page and emits the right sequence on the first try.

## Prerequisites — check before any tool call

The plugin must be reachable before the `ts_*` tools resolve. Run the check script first:

```bash
bash scripts/check.sh
```

The script prints one of:

```
OK  ts-bootstrap-mcp reachable via <method>
MISSING  not registered, not on PATH, and no local clone — run scripts/install.sh
```

If `MISSING`, run the install:

```bash
bash scripts/install.sh
```

The install script tries, in order:

1. If `claude` CLI is on PATH → `claude mcp add ts-bootstrap -- npx -y github:opensubagents/ts-bootstrap-mcp`
2. Else if `~/.npm-global/bin` writable → `npm install -g github:opensubagents/ts-bootstrap-mcp`
3. Else → clone to `/tmp/ts-bootstrap-mcp` and `npm install && npm run build`

After install, re-run `scripts/check.sh` to confirm. Both scripts are idempotent.

## The seven tools, in one table

| Tool | Use when | Key args | Annotations |
|---|---|---|---|
| `ts_env_inspect` | Starting a session, before anything else | `dir` (default `.`) | readOnly, idempotent |
| `ts_project_init` | New project from scratch | `dir`, `template`, `name`, `force?` | destructive |
| `ts_install` | Add deps to a project | `dir`, `packages?[]`, `preset?`, `dev?`, `save_exact?` | destructive, idempotent |
| `ts_typecheck` | Verify types are sound | `dir`, `project?` (alt tsconfig) | readOnly, idempotent |
| `ts_run` | Execute a `.ts` file via tsx | `dir`, `file`, `args?[]`, `env?{}`, `timeout_ms?` | destructive |
| `ts_build` | Emit JS + d.ts to `dist/` | `dir`, `project?`, `clean_first?` | destructive, idempotent |
| `ts_clean` | Reset `node_modules` and/or `dist` | `dir`, `what: 'node_modules' \| 'dist' \| 'all'` | destructive, idempotent |

Full Zod schemas + parameter constraints live in `references/tool-schemas.md`.

## Templates available to `ts_project_init`

```
node-cli       package.json (bin entry) + strict NodeNext ESM tsconfig + src/index.ts hello-world CLI
cf-worker      package.json (wrangler scripts) + Bundler/WebWorker tsconfig + wrangler.toml + default fetch handler
mcp-server     package.json with @modelcontextprotocol/sdk + zod + src/index.ts with one stub tool
lib            composite tsconfig (declaration + declarationMap) for downstream consumers, no bin
```

Each template is designed to `ts_typecheck` and `ts_build` cleanly out of the box.

## Presets available to `ts_install`

```
strict-baseline   dev:  typescript@^5.7.2, tsx@^4.21.0, @types/node@^22.10.0
cf-worker         strict-baseline + dev: wrangler@^4.103.0, @cloudflare/workers-types@^4.20251001.0
mcp-server        strict-baseline + prod: @modelcontextprotocol/sdk@^1.29.0, zod@^3.25.0
```

Match the preset to the template you scaffolded.

## Standard workflows

Each workflow is a tool call sequence. Pick the one that matches the user's intent, then emit the calls in order. Detailed recipes in `references/flows.md`.

### A — Fresh MCP server (most common in this org)

```
1. ts_env_inspect({ dir: "." })                                            # confirm Node + npm present
2. ts_project_init({ dir: "./my-mcp", template: "mcp-server", name: "my-mcp" })
3. ts_install({ dir: "./my-mcp", preset: "mcp-server" })
4. ts_typecheck({ dir: "./my-mcp" })                                       # MUST be ok=true; if not, stop and debug
5. ts_build({ dir: "./my-mcp" })                                           # produces dist/index.js
6. (optional) register: claude mcp add my-mcp -- node ./my-mcp/dist/index.js
```

### B — Fresh Cloudflare Worker

```
1. ts_env_inspect({ dir: "." })
2. ts_project_init({ dir: "./my-worker", template: "cf-worker", name: "my-worker" })
3. ts_install({ dir: "./my-worker", preset: "cf-worker" })
4. ts_typecheck({ dir: "./my-worker" })
5. (deploy step is OPERATOR-SIDE — needs `wrangler login`, not a tool call)
```

### C — Add deps to an existing project

```
1. ts_env_inspect({ dir: "." })                                            # confirm package.json present
2. ts_install({ dir: ".", packages: ["lodash", "@types/lodash"], dev: false })
3. ts_typecheck({ dir: "." })
```

### D — Reset and rebuild

```
1. ts_clean({ dir: ".", what: "all" })                                     # rm -rf node_modules + dist
2. ts_install({ dir: ".", preset: "strict-baseline" })                     # or whatever preset fits
3. ts_typecheck({ dir: "." })
4. ts_build({ dir: "." })
```

## Operational rules

**Always inspect first.** `ts_env_inspect` is cheap (read-only, ~50ms) and tells you whether you're in an empty dir or an existing project. Skipping it leads to "package.json already exists" errors from `ts_project_init`.

**Treat `ok: false` as a hard stop.** When `ts_typecheck` or `ts_build` returns `ok: false`, the `diagnostics[]` array contains parsed `{ file, line, col, code, severity, message }` entries. Read those, fix the source, re-run. Do not proceed to the next workflow step until clean.

**Path validation is enforced.** `ts_run` rejects absolute paths and `..` traversal. `ts_clean` only accepts `'node_modules' | 'dist' | 'all'`. Don't try to be clever — these are defense-in-depth checks, not negotiable.

**Bounded output.** Each tool truncates stdout/stderr to ~50KB with `truncated: true` set. If you need the full log, re-run the underlying command yourself (`bash -c "cd <dir> && npm install <pkg> 2>&1 | tee install.log"`).

**Timeouts default to 5 min.** `ts_install` in a cold sandbox can take 30–60s; `ts_typecheck` is usually <10s; `ts_build` is usually <5s. `ts_run` defaults to 60s (configurable 1s–15min via `timeout_ms`).

## Error handling

| Symptom | Cause | Fix |
|---|---|---|
| Tool not found / `ts_env_inspect` returns "no such tool" | Plugin not registered | Run `bash scripts/install.sh` |
| `ts_project_init` throws "package.json already exists" | Refusing to clobber | Pass `force: true` OR pick another `dir` |
| `ts_install` exits non-zero with `EACCES` | npm cache permission | Set `npm config set cache /tmp/.npm-cache --global` |
| `ts_typecheck` `error_count > 0` after a clean scaffold | Template drift vs your environment's `@types/node` | Pin `@types/node` to the major that matches your Node runtime |
| `ts_run` `timed_out: true` | Script ran past `timeout_ms` | Pass higher `timeout_ms` (max 900000) |
| Captured output ends `... [N characters elided] ...` | Hit the 50KB cap | Re-run via bash directly if you need the full log |

More in `references/troubleshooting.md`.

## When NOT to use this skill

- The user wants Python, Go, Rust, or another language — wrong skill
- The user wants a deploy step (wrangler deploy, vercel deploy) — that's operator-side, not a tool
- The user wants to publish to npm — also operator-side; needs `NPM_TOKEN` in the shell
- The user wants linting/formatting (ESLint, Prettier) — not in this plugin's scope; add as follow-up if asked

## Bundled references

- `references/flows.md` — the four workflows above, expanded with full JSON of every tool call and the expected `structuredContent` shape
- `references/tool-schemas.md` — Zod inputSchema + outputSchema for each of the 7 tools, copied from the plugin source
- `references/troubleshooting.md` — every known failure mode and its fix

Read these only when you need details beyond the table above. SKILL.md is the index; the references are the manual.

## Bundled scripts

- `scripts/check.sh` — verify the plugin is reachable
- `scripts/install.sh` — install + register the plugin in the current sandbox (idempotent)

Both scripts are shellcheck-clean and have no dependencies beyond `bash`, `curl`, `node`, `npm`.

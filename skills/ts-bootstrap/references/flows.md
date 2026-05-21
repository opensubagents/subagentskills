# Workflows — full JSON

Each workflow lists every tool call (with full JSON args) and the shape of the `structuredContent` you should receive back. Use these as paste-ready templates.

## A — Fresh MCP server

The most common case in this org. Builds from zero to a working `dist/index.js` that speaks MCP over stdio.

### A.1 Inspect

```json
{
  "tool": "ts_env_inspect",
  "arguments": { "dir": "." }
}
```

Expect:

```json
{
  "resolved_dir": "/abs/path",
  "node_version": "v22.x.x",
  "npm_version": "10.x.x",
  "tsx_version": "<string|null>",
  "typescript_version": "<string|null>",
  "wrangler_version": null,
  "has_package_json": false,
  "has_tsconfig": false,
  "has_node_modules": false,
  "has_dist": false,
  "package_json_summary": null,
  "globally_installed": ["..."]
}
```

If `node_version` is `null`, abort — Node is not on PATH and the install script will not help. If `has_package_json` is `true`, decide whether you're starting fresh (pick a new dir) or extending (skip A.2).

### A.2 Scaffold

```json
{
  "tool": "ts_project_init",
  "arguments": {
    "dir": "./my-mcp",
    "template": "mcp-server",
    "name": "my-mcp"
  }
}
```

For a scoped name, use `"name": "@opensubagents/my-mcp"` — the scaffold strips `@scope/` to derive the bin name.

Expect:

```json
{
  "resolved_dir": "/abs/path/my-mcp",
  "template": "mcp-server",
  "files_written": [
    ".gitignore",
    "README.md",
    "package.json",
    "src/index.ts",
    "tsconfig.json"
  ],
  "next_steps": [
    "ts_install({ dir, preset: \"mcp-server\" })",
    "ts_build({ dir })",
    "register: claude mcp add <name> -- node <dir>/dist/index.js"
  ]
}
```

### A.3 Install

```json
{
  "tool": "ts_install",
  "arguments": {
    "dir": "./my-mcp",
    "preset": "mcp-server"
  }
}
```

The preset expands to:

- prod deps: `@modelcontextprotocol/sdk@^1.29.0`, `zod@^3.25.0`
- dev deps: `typescript@^5.7.2`, `tsx@^4.21.0`, `@types/node@^22.10.0`

Two npm install passes happen automatically (prod first, then dev). Both must exit 0.

### A.4 Typecheck

```json
{
  "tool": "ts_typecheck",
  "arguments": { "dir": "./my-mcp" }
}
```

Expect `{ "ok": true, "error_count": 0, "diagnostics": [] }`. If not ok, do NOT proceed — read `diagnostics`, fix the source, re-run.

### A.5 Build

```json
{
  "tool": "ts_build",
  "arguments": { "dir": "./my-mcp" }
}
```

Expect `{ "ok": true, "exit_code": 0 }`. After this, `./my-mcp/dist/index.js` exists and is the entry point for `claude mcp add`.

### A.6 (Optional, operator-side) Register

```bash
claude mcp add my-mcp -- node "$(pwd)/my-mcp/dist/index.js"
```

This is a bash command, not a tool call — registering an MCP server with the Claude CLI requires the `claude` binary.

## B — Fresh Cloudflare Worker

Identical to A through step .4. The differences:

```json
{ "tool": "ts_project_init",
  "arguments": { "dir": "./my-worker", "template": "cf-worker", "name": "my-worker" } }
```

```json
{ "tool": "ts_install",
  "arguments": { "dir": "./my-worker", "preset": "cf-worker" } }
```

`ts_build` is NOT useful here — the cf-worker tsconfig sets `noEmit: true`. Use `ts_typecheck` to verify, and deploy via `wrangler deploy` from the shell (not a tool call — `wrangler login` needs a browser).

## C — Add deps to existing project

Single-pass install. Use this when extending an existing project.

```json
{ "tool": "ts_env_inspect", "arguments": { "dir": "." } }
```

Confirm `has_package_json: true`. Then:

```json
{
  "tool": "ts_install",
  "arguments": {
    "dir": ".",
    "packages": ["lodash", "@types/lodash"],
    "dev": false
  }
}
```

To install JUST as devDeps:

```json
{
  "tool": "ts_install",
  "arguments": {
    "dir": ".",
    "packages": ["vitest@^2.1.0"],
    "dev": true,
    "save_exact": false
  }
}
```

Always follow with:

```json
{ "tool": "ts_typecheck", "arguments": { "dir": "." } }
```

…to catch any type errors introduced by the new deps (missing `@types/*` packages, for example).

## D — Reset and rebuild

The "something is wrong, start over" flow. Use this when typecheck is failing with version-skew errors or `node_modules` is corrupted.

```json
{ "tool": "ts_clean", "arguments": { "dir": ".", "what": "all" } }
```

Returns `{ "removed": ["node_modules", "dist"] }` (or a subset if one was already absent).

Then re-run install / typecheck / build:

```json
{ "tool": "ts_install",  "arguments": { "dir": ".", "preset": "<match-the-template>" } }
{ "tool": "ts_typecheck","arguments": { "dir": "." } }
{ "tool": "ts_build",    "arguments": { "dir": "." } }
```

If `ts_typecheck` is still failing after a full clean+install, the issue is in your source code, not in the toolchain.

## Composing tools with `ts_run`

Useful for executing test scripts, smoke checks, or one-off ts files via `tsx` (transpile + run, no build artifact):

```json
{
  "tool": "ts_run",
  "arguments": {
    "dir": ".",
    "file": "scripts/smoke.ts",
    "args": ["--verbose"],
    "env": { "LOG_LEVEL": "debug" },
    "timeout_ms": 30000
  }
}
```

`file` MUST be relative and MUST NOT contain `..`. Absolute paths are rejected at validation time with a clear error message.

## What to do if a tool call fails

Every tool returns a structured response even on non-zero exit. Read `structuredContent.stderr` for the actual error and `structuredContent.exit_code` for the numeric signal. The plugin does not raise exceptions for "expected" shell failures (non-zero npm exits, tsc errors, etc.) — it raises only for validation errors (bad input shape, path traversal, etc.).

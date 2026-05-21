# Troubleshooting

Every known failure mode in `@opensubagents/ts-bootstrap-mcp` and how to recover. Organized by symptom — find the row that matches what you're seeing, apply the fix.

## Plugin availability

### "Tool not found" / "no such tool: ts_env_inspect"

The MCP server is not registered with the current host.

**Fix:**

```bash
bash scripts/check.sh        # confirms the diagnosis
bash scripts/install.sh      # installs + registers
bash scripts/check.sh        # confirms recovery
```

If `install.sh` reports it fell back to the `/tmp/ts-bootstrap-mcp` clone (method 3), you'll need to register that path manually with whatever MCP host you're using. For Claude Code:

```bash
claude mcp add ts-bootstrap -- node /tmp/ts-bootstrap-mcp/dist/index.js
```

### Tool call returns "spawn npm ENOENT" / "spawn node ENOENT"

Node or npm is missing from PATH. The plugin requires Node ≥18 and npm.

**Fix:** install Node from your system package manager or nvm. In an Ubuntu sandbox without Node, `apt-get install -y nodejs npm` works but ships old versions — prefer `curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && apt-get install -y nodejs`.

## ts_project_init

### "package.json already exists at /path/package.json. Pass force:true to overwrite, or pick a different dir."

You're trying to scaffold into a directory that already has a project.

**Fix:** Either pick a fresh `dir`, OR pass `force: true` to overwrite. **`force: true` overwrites EVERY file the template emits**, not just `package.json` — review `files_written` in the return value to see what got clobbered.

### "invalid project name: <name>. Must be lowercase, start with letter/digit, ≤214 chars, optional @scope/ prefix."

The `name` argument doesn't match npm package name rules.

**Fix:** lowercase only, hyphens/underscores/dots allowed. Examples that work: `my-thing`, `@opensubagents/my-thing`, `tool_v2`. Examples that fail: `MyThing`, `my thing`, `my/thing` (without scope).

## ts_install

### `exit_code: 1` with stderr containing `EACCES: permission denied`

npm can't write to its cache directory.

**Fix:**

```bash
npm config set cache /tmp/.npm-cache --global
mkdir -p /tmp/.npm-cache
```

Re-run `ts_install`.

### `exit_code: 1` with stderr containing `ETARGET No matching version found`

You requested a version that doesn't exist on the registry.

**Fix:** Check the actual published versions with `npm view <pkg> versions --json`. The preset version pins in this plugin are tracked majors (e.g. `typescript@^5.7.2`) — if upstream introduces a breaking major, update the preset in `src/constants.ts` and rebuild the plugin.

### `exit_code: 1` with stderr containing `ERESOLVE could not resolve` or `peer dep conflict`

A dependency conflict that npm refuses to silently resolve.

**Fix:**

1. Read the conflict — npm prints the conflicting graph.
2. Most often: pin the conflicting dep yourself via the `packages` array with a compatible version.
3. Last resort: add `legacy-peer-deps` to a `.npmrc` in the project dir and re-run.

### "package spec contains forbidden character"

You passed a `packages[]` entry containing whitespace or a shell metacharacter.

**Fix:** Strip the offending character. Common cause: pasting a version range like `"lodash >=4.17"` (note the space). The validator rejects this before it can reach npm. Use `"lodash@>=4.17.0"` instead.

### `ts_install` succeeds but `node_modules` is missing the packages

Almost always: you have `dev: true` but the package is a runtime dep, or vice versa. `npm install --save-dev <x>` still installs `<x>` — but it lands in `devDependencies` in `package.json`, which means downstream consumers won't get it.

**Fix:** check `installed_packages` and `dev` in the response. Re-install with the correct `dev` flag if needed.

## ts_typecheck

### `ok: false`, `error_count > 0`, diagnostics mention `@types/node`

Type definitions don't match the Node runtime version.

**Fix:** Pin `@types/node` to the major matching your `node --version`. For Node 22:

```json
{ "tool": "ts_install",
  "arguments": { "dir": ".", "packages": ["@types/node@^22.10.0"], "dev": true } }
```

### `ok: false`, diagnostics mention `Cannot find module '@modelcontextprotocol/sdk/server/mcp.js'`

NodeNext module resolution requires the `.js` extension on imports even for `.ts` files. The MCP SDK's package.json exports map paths ending in `.js`.

**Fix:** Always import as `from "@modelcontextprotocol/sdk/server/mcp.js"`, never `.../server/mcp` or `.../server/mcp.ts`. Same for SDK transports: `.../server/stdio.js`, `.../server/streamableHttp.js`.

### Diagnostics array is empty but `ok: false`

The diagnostic format didn't match the parser regex. Read `stdout` and `stderr` directly.

**Fix:** the regex parses tsc's classic pretty-disabled format. Newer tsc versions or non-English locales may emit slightly different text. The shell output is always available; the structured diagnostics are best-effort.

### `ok: false` with `Cannot find name 'process'` after a fresh `ts_install`

`@types/node` is missing or didn't install.

**Fix:**

```json
{ "tool": "ts_install",
  "arguments": { "dir": ".", "packages": ["@types/node@^22.10.0"], "dev": true } }
```

## ts_run

### `timed_out: true`

Script ran past the `timeout_ms` ceiling.

**Fix:** pass a larger `timeout_ms`. Max is `900000` (15 minutes). If you need longer than 15 minutes, the task is not a fit for this tool — drop to bash directly.

### "file must be relative (got absolute path: /path/to/file.ts)"

Path validator caught an absolute path.

**Fix:** make the path relative to `dir`. If you really need an absolute path (you usually don't), set `dir` to the parent and pass the basename as `file`.

### "file contains '..': src/../../etc/foo. Stay inside the project dir."

Path traversal blocked.

**Fix:** stay inside the project dir. This rule is not negotiable — there's no escape hatch.

### Script exits 0 but stdout is empty

Output exceeded `OUTPUT_CHARACTER_LIMIT` (50 KB) and the truncation block ate the start; you'll see `truncated: true` in the response.

**Fix:** for full output, re-run via bash directly:

```bash
cd <dir> && npx --no-install tsx <file> > /tmp/out.log 2>&1
```

## ts_build

### `ok: true` but no `dist/index.js`

Your `tsconfig.json` doesn't have an `outDir` or has `noEmit: true`. The cf-worker template intentionally sets `noEmit: true` — use `ts_typecheck` instead, and let `wrangler deploy` handle bundling.

**Fix:** if you want emitted JS, ensure `compilerOptions.outDir` is set and `noEmit` is false (or absent).

### `ok: false` with `error TS6053: File '<path>/tsconfig.json' not found`

Either no tsconfig, or the `project` arg points somewhere that doesn't exist.

**Fix:** confirm `tsconfig.json` exists in `dir`. Or, pass `project: "./alt-tsconfig.json"` (relative) explicitly.

## ts_clean

### `removed: []` after asking to remove `node_modules`

The directory wasn't there to begin with. Not an error — the tool is idempotent.

### Permission denied on Linux

Rare in a sandbox, common on CI. `node_modules` sometimes contains files with unusual permissions.

**Fix:** drop to bash:

```bash
rm -rf <dir>/node_modules <dir>/dist
```

## Captured output

### Output ends with `... [N characters elided] ...`

Hit the 50 KB cap. The first 35 KB and last 15 KB are preserved.

**Fix:** for the full log, re-run via bash:

```bash
cd <dir> && npm install <pkg> 2>&1 | tee install.log
```

Read `install.log` separately.

## Asking for help

When a tool call fails in a way not covered here:

1. Always include `structuredContent.command_line` (or the underlying command) in your help request — it tells the next person exactly what was run.
2. Include the exit code and the last ~500 chars of stderr.
3. Include `ts_env_inspect` output — Node/npm versions are the single most common root cause.

This skill version: 0.1.0. Plugin version: 0.1.0. If the plugin version differs from the skill version, expect drift — re-fetch the skill from `github.com/opensubagents/ts-bootstrap-mcp/tree/main/skills/ts-bootstrap`.

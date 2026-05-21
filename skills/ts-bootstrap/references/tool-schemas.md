# Tool schemas — full Zod definitions

The Zod `inputSchema` and `outputSchema` for every tool the plugin registers. This is a self-contained reference — you should not need to read the plugin source to drive the tools correctly.

All input schemas use `.strict()`, which means **unknown keys are rejected**. Pass only the documented fields.

## ts_env_inspect

```ts
const InputSchema = z.object({
  dir: z.string().min(1).default(".")
    .describe("Working directory to inspect. Default: '.'"),
}).strict();

const OutputSchema = z.object({
  resolved_dir: z.string(),                  // absolute
  node_version: z.string().nullable(),       // e.g. "v22.22.2"
  npm_version: z.string().nullable(),
  tsx_version: z.string().nullable(),
  typescript_version: z.string().nullable(),
  wrangler_version: z.string().nullable(),
  has_package_json: z.boolean(),
  has_tsconfig: z.boolean(),
  has_node_modules: z.boolean(),
  has_dist: z.boolean(),
  package_json_summary: z.object({
    name: z.string().optional(),
    version: z.string().optional(),
    type: z.string().optional(),
    main: z.string().optional(),
    bin: z.union([z.string(), z.record(z.string())]).optional(),
    scripts: z.record(z.string()).optional(),
    dependency_count: z.number(),
    dev_dependency_count: z.number(),
  }).nullable(),
  globally_installed: z.array(z.string()),
});
```

**Annotations:** `readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false`

## ts_project_init

```ts
const InputSchema = z.object({
  dir: z.string().min(1)
    .describe("Target directory. Created if it does not exist."),
  template: z.enum(["node-cli", "cf-worker", "mcp-server", "lib"])
    .describe("Project shape"),
  name: z.string().min(1)
    .describe("npm package name. Lowercase, optional @scope/ prefix."),
  force: z.boolean().default(false)
    .describe("Overwrite existing files. Default false."),
}).strict();

const OutputSchema = z.object({
  resolved_dir: z.string(),
  template: z.string(),
  files_written: z.array(z.string()),         // relative paths
  next_steps: z.array(z.string()),            // suggested follow-up calls
});
```

**Annotations:** `readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false`

**Validation:** `name` must match `^(?:@[a-z0-9][a-z0-9._-]{0,213}\/)?[a-z0-9][a-z0-9._-]{0,213}$` (npm package name rules).

## ts_install

```ts
const InputSchema = z.object({
  dir: z.string().min(1)
    .describe("Target directory (must contain package.json)."),
  packages: z.array(z.string().min(1).max(200)).default([])
    .describe("Explicit specs: 'lodash', 'lodash@4.17.21', '@scope/pkg', 'github:owner/repo'."),
  dev: z.boolean().default(false)
    .describe("Install as devDependencies."),
  preset: z.enum(["strict-baseline", "cf-worker", "mcp-server"]).optional()
    .describe("Expand to a curated package list."),
  save_exact: z.boolean().default(false)
    .describe("Pin to exact versions (--save-exact)."),
}).strict();

const OutputSchema = z.object({
  resolved_dir: z.string(),
  installed_packages: z.array(z.string()),
  preset_applied: z.string().nullable(),
  dev: z.boolean(),
  exit_code: z.number().nullable(),
  duration_ms: z.number(),
  truncated: z.boolean(),
  stdout: z.string(),
  stderr: z.string(),
});
```

**Annotations:** `readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: true`

**Preset expansion:**

| Preset | dev | prod |
|---|---|---|
| `strict-baseline` | `typescript@^5.7.2`, `tsx@^4.21.0`, `@types/node@^22.10.0` | — |
| `cf-worker` | strict-baseline + `wrangler@^4.103.0`, `@cloudflare/workers-types@^4.20251001.0` | — |
| `mcp-server` | strict-baseline | `@modelcontextprotocol/sdk@^1.29.0`, `zod@^3.25.0` |

**Two-pass behavior:** when `dev: false` (the default) AND the preset has dev entries, the tool runs npm install twice — once for prod, once with `--save-dev` for the preset's dev list. This is transparent to you; one tool call still does the right thing.

**Validation:** each `packages[]` entry is rejected if it contains whitespace, `;`, `&`, `|`, backticks, `$`, `<`, `>`, `(`, `)`, `{`, `}`, `[`, `]`, `"`, `'`, `\\`, or `!`.

## ts_typecheck

```ts
const InputSchema = z.object({
  dir: z.string().min(1).default("."),
  project: z.string().optional()
    .describe("Alternate tsconfig path (relative to dir). Default: tsconfig.json."),
}).strict();

const OutputSchema = z.object({
  ok: z.boolean(),                           // exit_code === 0
  resolved_dir: z.string(),
  exit_code: z.number().nullable(),
  duration_ms: z.number(),
  error_count: z.number(),
  diagnostics: z.array(z.object({
    file: z.string().nullable(),
    line: z.number().nullable(),
    col: z.number().nullable(),
    code: z.string().nullable(),             // e.g. "TS2345"
    severity: z.string(),                    // "error" | "warning" | "info"
    message: z.string(),
  })),
  stdout: z.string(),
  stderr: z.string(),
});
```

**Annotations:** `readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false`

**Parse format:** diagnostics matched against `^(.+?)\((\d+),(\d+)\):\s+(error|warning|info)\s+(TS\d+):\s+(.+)$` per line. If your build emits diagnostics in a different format, they won't appear in `diagnostics[]` — fall back to reading `stdout`/`stderr`.

## ts_run

```ts
const InputSchema = z.object({
  dir: z.string().min(1).default("."),
  file: z.string().min(1)
    .describe("Relative .ts/.tsx path. Absolute paths and '..' rejected."),
  args: z.array(z.string()).default([]),
  env: z.record(z.string()).default({}),
  timeout_ms: z.number().int().min(1000).max(900000).default(60000),
}).strict();

const OutputSchema = z.object({
  resolved_dir: z.string(),
  file: z.string(),
  exit_code: z.number().nullable(),
  duration_ms: z.number(),
  timed_out: z.boolean(),
  stdout: z.string(),
  stderr: z.string(),
  truncated: z.boolean(),
});
```

**Annotations:** `readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true`

**Validation:** `file` must be relative, must not start with `/`, must not contain `..` as any path segment, must not contain `\0`, `\n`, or `\r`.

## ts_build

```ts
const InputSchema = z.object({
  dir: z.string().min(1).default("."),
  project: z.string().optional(),
  clean_first: z.boolean().default(false)
    .describe("rm -rf dist/ before building."),
}).strict();

const OutputSchema = z.object({
  ok: z.boolean(),
  resolved_dir: z.string(),
  exit_code: z.number().nullable(),
  duration_ms: z.number(),
  cleaned: z.boolean(),
  stdout: z.string(),
  stderr: z.string(),
});
```

**Annotations:** `readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false`

## ts_clean

```ts
const InputSchema = z.object({
  dir: z.string().min(1).default("."),
  what: z.enum(["node_modules", "dist", "all"])
    .describe("Which artifacts to remove."),
}).strict();

const OutputSchema = z.object({
  resolved_dir: z.string(),
  removed: z.array(z.string()),              // subset of ["node_modules", "dist"]
  duration_ms: z.number(),
});
```

**Annotations:** `readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false`

**Safety:** `what` is a closed enum — the tool cannot remove anything other than `node_modules`, `dist`, or both. No arbitrary path deletion.

## Constants worth knowing

```ts
OUTPUT_CHARACTER_LIMIT = 50_000   // stdout/stderr truncation per tool response
DEFAULT_TIMEOUT_MS     = 300_000  // 5 min default for shell-outs (per tool)
SERVER_NAME            = "ts-bootstrap-mcp-server"
SERVER_VERSION         = "0.1.0"
```

## How errors surface

The plugin distinguishes two error modes:

1. **Validation errors** (bad input shape, path traversal, forbidden chars in package spec) → JSON-RPC error response, `errors[]` populated. The tool call did not run.
2. **Shell-out errors** (non-zero npm exit, tsc compile errors, timeout) → JSON-RPC success response, `structuredContent` populated with `exit_code !== 0`, `ok: false`, `stderr` containing the error text. The tool ran; the underlying command failed.

Always check `structuredContent.ok` (or `exit_code === 0`) before treating a tool result as success.

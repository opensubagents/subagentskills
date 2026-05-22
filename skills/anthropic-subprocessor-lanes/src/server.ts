import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { z } from "zod";

const here = dirname(fileURLToPath(import.meta.url));
type Snapshot = {
  npmFirstPagePackages: number | null;
  npmNote?: string;
  githubTotalRepos: number | null;
  githubTopRepo?: { name: string; url: string; stars: number };
  skillsShSkills: number | null;
  skillsShSources: number | null;
  skillsShNote?: string;
};
type Sub = {
  name: string; category: string; region: string; products: string;
  npm: string | null; github: string | null; skillsSh: string | null;
  snapshot: Snapshot;
};
type Seed = { verified_at: string; subprocessors: Sub[] };

const dataPath = resolve(here, "..", "data", "subprocessors.json");
const raw = JSON.parse(readFileSync(dataPath, "utf8")) as { verified_at: string; subprocessors: Sub[] };
const SEED: Seed = { verified_at: raw.verified_at, subprocessors: raw.subprocessors };

const UA = { "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36" };
const text = (v: unknown) => ({ content: [{ type: "text" as const, text: JSON.stringify(v, null, 2) }] });

async function fetchText(url: string): Promise<string> {
  const r = await fetch(url, { headers: UA });
  if (!r.ok) throw new Error(`HTTP${r.status}`);
  return r.text();
}
async function npmLane(slug: string) {
  const html = await fetchText(`https://www.npmjs.com/org/${slug}`);
  const re = new RegExp(`/package/(@${slug}/[A-Za-z0-9_.-]+)`, "g");
  const names = [...new Set([...html.matchAll(re)].map((m) => m[1]))];
  return { url: `https://www.npmjs.com/org/${slug}`, firstPagePackages: names, firstPageCount: names.length, isFloor: true };
}
async function githubLane(slug: string) {
  const r = await fetch(`https://api.github.com/search/repositories?q=user:${encodeURIComponent(slug)}&per_page=1`, { headers: { ...UA, Accept: "application/vnd.github+json" } });
  if (!r.ok) throw new Error(`HTTP${r.status}`);
  const j = (await r.json()) as { total_count?: number; items?: { full_name: string; html_url: string; stargazers_count: number }[] };
  return { url: `https://github.com/orgs/${slug}/repositories`, totalRepos: j.total_count ?? null, topRepo: j.items?.[0] ? { name: j.items[0].full_name, url: j.items[0].html_url, stars: j.items[0].stargazers_count } : null };
}
async function skillsShLane(slug: string) {
  const html = await fetchText(`https://www.skills.sh/${slug}`);
  const m = html.match(/Browse\s+(\d+)\s+agent\s+skills.*?across\s+(\d+)\s+repositor/i);
  if (!m) return { url: `https://www.skills.sh/${slug}`, skills: null, sources: null, note: "no meta-description match" };
  return { url: `https://www.skills.sh/${slug}`, skills: parseInt(m[1], 10), sources: parseInt(m[2], 10) };
}
type LaneResult<T> = { ok: true; data: T } | { ok: false; error: string } | { skipped: true };
async function safe<T>(slug: string | null | undefined, fn: (s: string) => Promise<T>): Promise<LaneResult<T>> {
  if (!slug) return { skipped: true };
  try { return { ok: true, data: await fn(slug) }; }
  catch (e) { return { ok: false, error: e instanceof Error ? e.message : String(e) }; }
}

const server = new McpServer({ name: "subprocessor-lanes", version: "0.1.0" });

server.registerTool("org_lanes", {
  title: "Fetch npm + github + skills.sh lanes for an org slug",
  description: "Single-org, three-lane scan. Per-lane slugs may differ — pass overrides; falsy values skip that lane.",
  inputSchema: {
    slug: z.string(),
    npm: z.string().nullable().optional(),
    github: z.string().nullable().optional(),
    skillsSh: z.string().nullable().optional(),
  },
}, async ({ slug, npm, github, skillsSh }) => {
  const [n, g, s] = await Promise.all([
    safe(npm === undefined ? slug : npm, npmLane),
    safe(github === undefined ? slug : github, githubLane),
    safe(skillsSh === undefined ? slug : skillsSh, skillsShLane),
  ]);
  return text({ slug, lanes: { npm: n, github: g, skillsSh: s } });
});

server.registerTool("anthropic_subprocessors", {
  title: "List Anthropic subprocessors with embedded snapshot (zero network)",
  description: `Read seed at data/subprocessors.json (verified ${SEED.verified_at}). Returns 18 entries with per-lane slugs and verified snapshot.`,
  inputSchema: {},
}, async () => text(SEED));

server.registerTool("anthropic_subprocessor_report", {
  title: "Live three-lane scan across all 18 Anthropic subprocessors",
  description: "Fan out org_lanes for each subprocessor in parallel. Replaces 54 individual fetches.",
  inputSchema: {},
}, async () => {
  const rows = await Promise.all(SEED.subprocessors.map(async (sub) => {
    const [n, g, s] = await Promise.all([safe(sub.npm, npmLane), safe(sub.github, githubLane), safe(sub.skillsSh, skillsShLane)]);
    return { ...sub, lanes: { npm: n, github: g, skillsSh: s } };
  }));
  return text(rows);
});

await server.connect(new StdioServerTransport());

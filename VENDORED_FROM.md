# VENDORED_FROM

This repo is not a vendor fork of any other, but it patterns itself on three sources. When upstream changes meaningfully, revisit our shape here.

## Pattern sources

| Source | What we mirror | Last reviewed |
|---|---|---|
| [agentskills.io specification](https://agentskills.io/specification) | The SKILL.md frontmatter shape and the `.skill` zip format. Our `template/SKILL.md` follows this. | 2026-05-21 |
| [anthropics/skills](https://github.com/anthropics/skills) | Repo layout (`skills/<name>/{SKILL.md,references/,scripts/,assets/}`), the `quick_validate.py` + `package_skill.py` tooling we invoke for validation and packaging. | 2026-05-21 |
| [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | The `.claude-plugin/marketplace.json` shape with SHA-pinned source entries (we use in-repo paths, not external SHAs, while the catalog is small). | 2026-05-21 |

## Files we run but do not vendor

- `quick_validate.py` and `package_skill.py` from `anthropics/skills/skill-creator/scripts/`. CI clones the repo at workflow time and runs them in place. We do not copy them in — the upstream is authoritative.

## When to update this file

- Whenever a skill is added that copies a pattern from elsewhere — add a row noting the upstream.
- Whenever a structural change here is driven by an upstream change — update the "Last reviewed" date.

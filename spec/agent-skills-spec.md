# Agent Skills spec

This repo follows the [agentskills.io specification](https://agentskills.io/specification).

## TL;DR (no substitute for the spec)

- A skill is a directory containing `SKILL.md` at its root.
- `SKILL.md` has YAML frontmatter (`name`, `description` required) followed by markdown body.
- Optional sibling directories: `references/` (loaded on demand), `scripts/` (executable helpers), `assets/` (templates / icons / fonts).
- Allowed top-level frontmatter keys: `name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility`.
- `name` is kebab-case, ≤64 chars.
- `description` is ≤1024 chars and must not contain `<` or `>`.
- `compatibility` is ≤500 chars.

## Validation

The official validator lives at `skill-creator/scripts/quick_validate.py` (anthropics/skills). To run:

```bash
git clone --depth 1 https://github.com/anthropics/skills /tmp/anthropics-skills
cd /tmp/anthropics-skills/skill-creator
python3 -m scripts.quick_validate /path/to/your/skill
```

## Packaging

A `.skill` file is a zip of the skill directory. Produce one with:

```bash
python3 -m scripts.package_skill /path/to/your/skill /path/to/output-dir
```

The packager validates before writing, so a successful `.skill` artifact is guaranteed to pass `quick_validate`.

## Adding a new skill to this repo

1. Copy `template/SKILL.md` into `skills/<your-skill>/SKILL.md`.
2. Add bundled references/scripts as needed.
3. Validate with the tool above.
4. Add an entry to `.claude-plugin/marketplace.json` with `status: "released"` (or `"planned"` while drafting).
5. Open a PR. The CI workflow re-runs `quick_validate` on every skill in `skills/`.

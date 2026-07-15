# CLAUDE.md — CawCut Agent Skills

Guidance for Claude Code (and compatible agents) when working in this repository.

## What this is

This repo ships **Agent Skills** (`skills/`) — Markdown instruction packs that tell agents how to invoke the **`cawcut` CLI** (not MCP).

```
skills/cawcut-generate/   →  /cawcut-generate  →  cawcut generate "<prompt>"
skills/cawcut-app-run/    →  /cawcut-app-run   →  cawcut app list → cawcut app run <id>
```

Two skills, each a catch-all entry point that hands off to the other once (never re-checks after handoff — see "Skill chaining" below):

- **`cawcut-app-run`** — app discovery/browsing ("what can \<app\> do", "有哪些 app") and running published Apps; falls back to `cawcut-generate` when no App matches.
- **`cawcut-generate`** — official image/video generation; checks the App catalog before each generate call and hands off to `cawcut-app-run` when a similar App exists.

Skills are **not** an MCP server. Agents run local `cawcut` processes; skill files are routing and UX instructions only.

**Prerequisite:** `cawcut` CLI installed and authenticated (`cawcut auth login`). Install via `npm install -g @ubnt/cawcut`.

## Repository structure

```
├── CLAUDE.md
├── README.md
├── INSTALL.md
├── CONTRIBUTING.md
├── VERSION                            # repo-wide version (source of truth)
├── setup / teardown                   # idempotent skill install / uninstall
├── package.json                       # validate:skills script
├── scripts/validate-skills.sh
├── skills/
│   ├── cawcut-generate/               # SKILL.md + references/
│   └── cawcut-app-run/
├── .claude-plugin/  .cursor-plugin/  .codex-plugin/
└── .github/workflows/validate-skills.yml
```

## Skill authoring rules

**Do not call CawCut HTTP APIs directly** — skills route everything through `cawcut` commands. See each skill's `SKILL.md` and `references/` for command details.

### The 300-line rule

Each `SKILL.md` should stay **under ~300 lines**. Skill bodies load into agent context on every trigger.

**Stays in `SKILL.md`:** frontmatter, bootstrap (CLI installed + logged in), decision flow, UX rules, short pointers to `references/`.

**Belongs in `references/`:** command flag tables, troubleshooting trees, long examples, App input mapping details.

### Self-contained skills

Each folder under `skills/` is **independent**. No `../` parent-directory references. CI enforces this on every PR.

Canonical install paths: `skills/cawcut-*` (matches `gh skill install` discovery of `skills/*/SKILL.md`).

### Media inputs

When a skill needs `image` / `video` / `audio` input, agents must collect **real user-provided** files or URLs. Examples in SKILL bodies, `references/`, or CLI output (`sample:`, `x-cawcut-sample-url`) are **hints only** — never pass them unless the user supplied that exact asset in the conversation.

### Skill chaining

Skills communicate through **CLI stdout**, not shared state:

- **`cawcut-app-run`** scores the live catalog (`references/intent-matching.md`) before deciding; hands off to `cawcut-generate` only when no App matches or the request is a simple official-capability ask.
- **`cawcut-generate`** checks the App catalog before every `cawcut generate` call; on a similar App match, offers it via `AskQuestion` and hands off to `cawcut-app-run` on confirmation.
- **Decide-once guard (required)** — whichever skill receives a handoff must trust the decision it was given and must **not** re-run its own catalog check that turn.
- If the user needs both flows, finish one before starting the other.

## Version sync

[`VERSION`](VERSION) must match:

- `version:` frontmatter in every `skills/*/SKILL.md`
- `.claude-plugin/marketplace.json` — `plugins[0].version`
- `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`

Bump all locations together. CI fails on drift.

## Development

```bash
npm run validate:skills
```

## Adding a new skill

See [CONTRIBUTING.md](./CONTRIBUTING.md). TL;DR:

1. Add `skills/cawcut-<name>/SKILL.md` with valid frontmatter (`name` = directory, **Use when** + **NOT for** in `description`).
2. Register in `.claude-plugin/marketplace.json`.
3. Add to `setup` / `teardown` `SKILLS` array.
4. Run `npm run validate:skills` before opening a PR.

## Commit messages

Follow **[Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)** — examples in [CONTRIBUTING.md](./CONTRIBUTING.md#commit-messages).

Scopes: `skills`, `setup`. PR titles use the same format (English). Squash merge → one conventional subject.

## PR checklist

- [ ] `npm run validate:skills` green
- [ ] Version sync if `VERSION` or any `SKILL.md` frontmatter changed
- [ ] No `../` in skill bodies or references
- [ ] User-facing doc examples use real `cawcut …` commands
- [ ] Commits and PR title follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)

## Reference

- [Agent Skills spec](https://agentskills.io/specification.md) — frontmatter format

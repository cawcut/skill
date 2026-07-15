# Contributing

## Commit messages

This repo follows **[Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)**.

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types (common)

| Type | When to use |
|------|-------------|
| `feat` | New skill capability or user-facing behavior |
| `fix` | Bug fix |
| `docs` | README, SKILL.md, CLAUDE.md, references only |
| `refactor` | Internal cleanup, no behavior change |
| `ci` | GitHub Actions, validate-skills |
| `chore` | Tooling, deps, non-user-facing maintenance |

### Scopes (recommended)

| Scope | Path |
|-------|------|
| `skills` | `skills/cawcut-*/` |
| `setup` | `setup`, `teardown`, `INSTALL.md` |

Scope is optional but helps changelog readers. Use lowercase type and scope.

### Examples

```
feat(skills): add cawcut-generate troubleshooting references

docs: update gh skill install repo to cawcut/skill

ci: drop CLI job from validate-skills workflow
```

### Breaking changes

For incompatible skill contract changes, use `!` after the type/scope **or** a `BREAKING CHANGE:` footer per the [spec](https://www.conventionalcommits.org/en/v1.0.0/#specification):

```
feat(skills)!: rename cawcut-generate invoke path

BREAKING CHANGE: /cawcut-generate is now /cawcut-gen.
```

Squash-merge PRs should use a single conventional subject line as the merge commit.

## Skill layout

Each skill lives under `skills/<name>/` with a required `SKILL.md` and optional `references/` directory.

- Frontmatter `name` must match the directory name (e.g. `cawcut-generate`).
- `version` must match root [`VERSION`](VERSION).
- `description` must include **Use when** trigger phrases and a **NOT for** boundary (≤1024 chars).
- No `../` parent-directory references — skills must be self-contained when installed.

## CLI dependency

Skills invoke the **`cawcut` CLI** — install via `npm install -g @ubnt/cawcut` ([npm package](https://www.npmjs.com/package/@ubnt/cawcut)). Not shipped in this repo.

## Validation

Before opening a PR:

```bash
npm run validate:skills
```

CI runs the same check on pull requests.

## Version bumps

1. Update [`VERSION`](VERSION).
2. Sync `version` in every `skills/*/SKILL.md` frontmatter.
3. Sync `version` in `.cursor-plugin/plugin.json`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and `.claude-plugin/marketplace.json`.

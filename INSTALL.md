# Installing CawCut Agent Skills

This repository contains **Agent Skills only**. Install the `cawcut` CLI separately:

```bash
npm install -g @ubnt/cawcut
cawcut auth login
```

Published as [`@ubnt/cawcut`](https://www.npmjs.com/package/@ubnt/cawcut) on npm.

## Path A — `./setup` (recommended)

Clones the repo and symlinks skills into your agent config directory. Optionally ensures the `cawcut` CLI is on PATH via npm.

```bash
git clone git@github.com:cawcut/skill.git
cd skill
./setup
```

Flags:

| Flag | Effect |
|------|--------|
| `--host claude\|cursor\|codex` | Force target agent (auto-detected from `~/.claude`, `~/.cursor`, `~/.codex`) |
| `--skip-cli` | Do not install or check the CLI |
| `--skip-auth` | Do not require `cawcut auth status` to succeed |

Update after `git pull`:

```bash
git pull && ./setup --skip-auth
```

## Uninstall — `./teardown`

Removes CawCut skills and optionally the global CLI.

```bash
./teardown
```

| Flag | Effect |
|------|--------|
| `--host claude\|cursor\|codex` | Limit cleanup to specific agents (auto-detected if omitted) |
| `--skip-cli` | Remove skills only; leave `cawcut` on PATH |
| `--remove-cli` | Uninstall global `@ubnt/cawcut` |

Also removes CawCut skill entries under agent dirs via `cawcut uninstall --keep-cli` or `npx skills remove`. Equivalent: `cawcut skill uninstall`.

Re-install: `./setup` or `npm install -g @ubnt/cawcut && cawcut skill setup`.

## Path B — `gh skill install` (skills only)

Requires [GitHub CLI](https://cli.github.com/) ≥ 2.90. Installs **skills only** — does not install the CLI or run auth.

```bash
gh skill install cawcut/skill
gh skill install cawcut/skill --agent cursor --scope user
gh skill install ./path/to/skill --from-local --agent cursor --scope user --force
```

| | `./setup` | `gh skill install` |
|--|-----------|-------------------|
| Skill install | symlink to repo | copy into agent dir |
| CLI | installed via npm if missing | not installed |
| Auth check | optional | none |
| Update | `git pull && ./setup` | `gh skill update cawcut/skill` |

## Complete setup (both paths)

1. Install skills + CLI: `./setup` (recommended)
2. Skills only: `gh skill install cawcut/skill`, then install CLI via npm
3. `cawcut auth login`

## Path C — `npx skills add` (manual)

`cawcut skill setup` wraps this. For manual control:

```bash
npm install -g @ubnt/cawcut
npx skills add cawcut/skill -g -y --skill '*' -a cursor -a claude-code -a codex
cawcut auth login
cawcut intro
```

Update:

```bash
cawcut upgrade
```

`cawcut upgrade` updates the CLI when needed, then refreshes skills via `npx skills` (cursor, claude-code, codex).

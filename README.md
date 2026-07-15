# CawCut Agent Skills

Agent Skills for Claude Code, Cursor, Codex, and compatible AI coding hosts. Each skill tells your agent how to invoke the [`cawcut` CLI](https://www.npmjs.com/package/@ubnt/cawcut) — no MCP server, no API keys to paste.

| Skill | Trigger | CLI entry |
|-------|---------|-----------|
| `cawcut-generate` | `/cawcut-generate` | `cawcut generate` |
| `cawcut-app-run` | `/cawcut-app-run` | `cawcut app run` |

---

## Install

### Option A — npm (recommended)

Installs the CLI and Agent Skills together. On npm 11+, lifecycle flags approve postinstall (which runs skill setup):

```bash
npm install -g @ubnt/cawcut --foreground-scripts --allow-scripts=@ubnt/cawcut
cawcut auth login
```

If skills were skipped (`CAWCUT_SKIP_SETUP=1` or postinstall blocked), install them manually:

```bash
cawcut skill setup
```

Update later:

```bash
cawcut upgrade
```

Uninstall:

```bash
cawcut uninstall
```

### Option B — `gh skill install` (skills only)

Requires the CLI on PATH first:

```bash
npm install -g @ubnt/cawcut
cawcut auth login
gh skill install cawcut/skill
```

### Option C — `./setup` (development)

For contributors working from a local clone — symlinks skills into agent directories:

```bash
git clone git@github.com:cawcut/skill.git
cd skill
./setup
cawcut auth login
```

Update after `git pull`:

```bash
git pull && ./setup --skip-auth
```

Uninstall:

```bash
./teardown                  # skills + optional CLI removal
./teardown --skip-cli       # skills only
```

> Full setup details and flags: [INSTALL.md](INSTALL.md)

---

## Usage (agent mode)

After install and `cawcut auth login`, use directly in your agent:

```
/cawcut-generate    →  generate AI images, video via official capabilities
/cawcut-app-run     →  run published CawCut Apps
```

Agents automatically:
- Capture `Workflow: <id>` from the first generate and reuse it in the same session
- Show estimated credits before generating when asked
- Resume polling if a task times out

---

## Repository layout

```
skills/
  cawcut-generate/   /cawcut-generate skill
  cawcut-app-run/    /cawcut-app-run skill
scripts/
  validate-skills.sh # local + CI validation
```

---

## Development

```bash
npm run validate:skills
```

Version is tracked in [`VERSION`](VERSION) and must stay in sync with skill frontmatter and plugin manifests. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Related

| Package / repo | Role |
|----------------|------|
| [`cawcut/skill`](https://github.com/cawcut/skill) | This repo — Agent Skills |
| [`@ubnt/cawcut` on npm](https://www.npmjs.com/package/@ubnt/cawcut) | `cawcut` CLI |

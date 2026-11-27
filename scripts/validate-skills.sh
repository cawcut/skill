#!/usr/bin/env bash
# Validate skill frontmatter, version sync, marketplace listing, and references.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

skill_dirs() {
  local d
  if [ -f skills/cawcut/SKILL.md ]; then
    printf '%s\n' skills/cawcut/
  fi
  for d in skills/cawcut-*/; do
    [ -f "${d}SKILL.md" ] && printf '%s\n' "$d"
  done
}

echo "→ Validating frontmatter and name…"
while IFS= read -r skill_dir; do
  skill_name="${skill_dir%/}"
  skill_name="${skill_name#skills/}"
  skill_md="${skill_dir}SKILL.md"
  if [ ! -f "$skill_md" ]; then
    echo "::error::$skill_md missing"
    fail=1
    continue
  fi
  python3 - "$skill_md" "$skill_name" <<'PY' || fail=1
import sys, yaml, re, pathlib
path = pathlib.Path(sys.argv[1])
expected_name = sys.argv[2]
text = path.read_text()
m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
if not m:
    print(f"::error file={path}::no YAML frontmatter")
    sys.exit(1)
fm = yaml.safe_load(m.group(1))
errors = []
if fm.get("name") != expected_name:
    errors.append(f"name '{fm.get('name')}' != directory '{expected_name}'")
if not fm.get("version"):
    errors.append("version missing")
if not fm.get("description"):
    errors.append("description missing")
desc = fm.get("description", "")
if len(desc) > 1024:
    errors.append(f"description exceeds 1024 characters ({len(desc)})")
if "Use when" not in desc:
    errors.append("description missing 'Use when' trigger phrases")
if "NOT for" not in desc:
    errors.append("description missing 'NOT for' boundary")
for err in errors:
    print(f"::error file={path}::{err}")
if errors:
    sys.exit(1)
print(f"✓ {path} — frontmatter valid (name={fm['name']}, version={fm['version']})")
PY
done < <(skill_dirs)
[ "$fail" -eq 0 ]

echo "→ Validating version sync…"
ROOT_VERSION="$(tr -d '[:space:]' < VERSION)"
echo "Root VERSION: $ROOT_VERSION"

while IFS= read -r skill_dir; do
  v=$(awk '/^---/{c++; next} c==1 && /^version:/{gsub(/^version:[[:space:]]*/,""); gsub(/[[:space:]]*#.*$/,""); gsub(/[[:space:]]/,""); print; exit}' "${skill_dir}SKILL.md")
  if [ "$v" != "$ROOT_VERSION" ]; then
    echo "::error file=${skill_dir}SKILL.md::version $v != VERSION $ROOT_VERSION"
    fail=1
  fi
done < <(skill_dirs)

for f in .claude-plugin/plugin.json .codex-plugin/plugin.json .cursor-plugin/plugin.json; do
  v=$(python3 -c "import json,sys; print(json.load(open('$f'))['version'])")
  if [ "$v" != "$ROOT_VERSION" ]; then
    echo "::error file=$f::version $v != VERSION $ROOT_VERSION"
    fail=1
  fi
done

v=$(python3 -c "import json; print(json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['version'])")
if [ "$v" != "$ROOT_VERSION" ]; then
  echo "::error file=.claude-plugin/marketplace.json::plugins[0].version $v != VERSION $ROOT_VERSION"
  fail=1
fi
[ "$fail" -eq 0 ] && echo "✓ all version locations match $ROOT_VERSION"

echo "→ Validating marketplace.json lists every skill folder…"
listed=$(python3 -c "import json; print(' '.join(json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['skills']))" | sed -E 's#(^|[[:space:]])\./#\1#g')
while IFS= read -r skill_dir; do
  skill_path="${skill_dir%/}"
  if ! echo " $listed " | grep -q " $skill_path "; then
    echo "::error::skill folder '$skill_path' is not listed in .claude-plugin/marketplace.json"
    fail=1
  fi
done < <(skill_dirs)
[ "$fail" -eq 0 ] && echo "✓ marketplace.json includes every skill folder"

echo "→ Validating references…"
# A skill's on-demand files live in content dirs — references/ (tool and domain
# material) and, where a skill is cut by stage or by contract layer, stages/ and
# contract/. Every one must be linked from SKILL.md, and every link must resolve
# — that link is the only thing keeping four independently-owned files reachable.
while IFS= read -r skill_dir; do
  skill_md="${skill_dir}SKILL.md"
  content_files=$(cd "$skill_dir" && ls references/*.md mcp/references/*.md stages/*.md contract/*.md 2>/dev/null || true)
  [ -n "$content_files" ] || continue
  for ref in $content_files; do
    if ! grep -q "$ref" "$skill_md"; then
      echo "::error file=${skill_dir}${ref}::orphaned reference (not linked from $skill_md)"
      fail=1
    fi
  done
done < <(skill_dirs)
[ "$fail" -eq 0 ] && echo "✓ all references resolve, no orphans"

echo "→ Validating Markdown pointers stay inside the skill bundle…"
python3 - <<'PYLINK' || fail=1
import pathlib, re, sys
root = pathlib.Path('skills').resolve()
errors = []
links = {}
if pathlib.Path('mcp/skills').exists():
    errors.append('::error::move legacy MCP skills into their shared skill directories')
for path in root.rglob('SKILL.md'):
    if path.parent.parent != root:
        errors.append(f'::error file={path}::nested SKILL.md would register a duplicate skill')
for path in root.rglob('*.md'):
    links[path] = set()
    text = re.sub(r'```[^\n]*\n.*?```', '', path.read_text(), flags=re.S)
    text = re.sub(r'`[^`\n]*`', '', text)  # Ignore inline Markdown examples.
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
        if '://' in target or target.startswith('#'):
            continue
        target = target.split('#')[0]
        resolved = (path.parent / target).resolve()
        if root not in resolved.parents or not resolved.exists():
            errors.append(f'::error file={path}::invalid bundle reference: {target}')
        else:
            links[path].add(resolved)

for name in ('cawcut-workflow', 'cawcut-app-run', 'cawcut-ad-video'):
    skill = root / name
    entry = skill / 'SKILL.md'
    reachable = set()
    pending = [entry]
    while pending:
        page = pending.pop()
        if page not in reachable:
            reachable.add(page)
            pending.extend(links.get(page, ()))
    for ref in (skill / 'mcp' / 'references').rglob('*.md'):
        if ref not in reachable:
            errors.append(f'::error file={ref}::unreachable from {entry}')
for message in errors:
    print(message)
if errors:
    sys.exit(1)
print('✓ local and sibling-skill Markdown pointers resolve inside the bundle')
PYLINK

[ "$fail" -eq 0 ] || exit 1
echo "All skill validations passed."

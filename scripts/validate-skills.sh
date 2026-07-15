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
listed=$(python3 -c "import json; print(' '.join(s['path'] for s in json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['skills']))")
while IFS= read -r skill_dir; do
  skill_path="${skill_dir%/}"
  if ! echo " $listed " | grep -q " $skill_path "; then
    echo "::error::skill folder '$skill_path' is not listed in .claude-plugin/marketplace.json"
    fail=1
  fi
done < <(skill_dirs)
[ "$fail" -eq 0 ] && echo "✓ marketplace.json includes every skill folder"

echo "→ Validating references…"
while IFS= read -r skill_dir; do
  skill_md="${skill_dir}SKILL.md"
  if [ ! -d "${skill_dir}references" ]; then
    continue
  fi
  for ref in $(grep -oE 'references/[a-zA-Z0-9_./-]+\.md' "$skill_md" | sort -u); do
    if [ ! -f "${skill_dir}${ref}" ]; then
      echo "::error file=$skill_md::references $ref but ${skill_dir}${ref} missing"
      fail=1
    fi
  done
  for f in "${skill_dir}references"/*.md; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    if ! grep -q "$base" "$skill_md"; then
      echo "::error file=$f::orphaned reference (not linked from $skill_md)"
      fail=1
    fi
  done
done < <(skill_dirs)
[ "$fail" -eq 0 ] && echo "✓ all references resolve, no orphans"

echo "→ Validating no parent-dir references…"
while IFS= read -r skill_dir; do
  if grep -nE '(^|[^./])\.\./' "${skill_dir}SKILL.md" 2>/dev/null; then
    echo "::error file=${skill_dir}SKILL.md::contains parent-dir (../) reference"
    fail=1
  fi
  if [ -d "${skill_dir}references" ]; then
    if grep -rnE '(^|[^./])\.\./\.\./' "${skill_dir}references/" 2>/dev/null; then
      echo "::error::${skill_dir}references/ contains ../../ paths"
      fail=1
    fi
  fi
done < <(skill_dirs)
[ "$fail" -eq 0 ] && echo "✓ no parent-dir references"

[ "$fail" -eq 0 ] || exit 1
echo "All skill validations passed."

#!/usr/bin/env bash
# Shared deterministic raw/display editing pipeline. Node is installed with cawcut.
# Usage: script_plan.sh take <id> [--dest dir] | apply/render/show <plan.json> [edits.json]
set -eu
exec node "$(dirname "$0")/script_plan.mjs" "$@"

#!/usr/bin/env bash
# Stage 4 review in one call (wait -> script table -> entity images). Node is installed with cawcut.
# Usage: storyboard_review.sh <id> [--dest dir] [--timeout seconds] [--until display|ready]
set -eu
exec node "$(dirname "$0")/storyboard_review.mjs" "$@"

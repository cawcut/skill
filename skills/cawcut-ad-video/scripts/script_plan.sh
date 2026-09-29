#!/usr/bin/env bash
# Working copy + review table for an Ad Video storyboard script. Bundled with
# the cawcut-ad-video skill so an editing session has one file of record and a
# table rendered from that file — never a plan retyped from memory.
#
# Usage:
#   script_plan.sh take <video_ad_id> [--dest <dir>]      # write the working copy from `detail`
#   script_plan.sh apply <plan.json> <edits.json>         # merge edits, report the fields changed
#   script_plan.sh render <plan.json>                     # print the review table
#   script_plan.sh show <plan.json> <edits.json>          # apply, then render
#
# `take` writes <dest>/storyboard/script.json (the plan) and script.meta.json
# (the video type, so `render` knows whether the Voiceover column applies).
# Default dest: ~/Downloads/ad-video-<product-name>, the same project folder
# download_media.sh uses — pass --dest to match a folder you already have.
#
# The edits file maps a shot to the fields to change, so no JSON is ever typed
# into a shell argument:
#   { "title": "…", "synopsis": "…",
#     "shot-3": { "shot_description": "…", "shot_prompt": "…", "video_prompt": "…" } }
# Editable per shot: duration, shot_type, shot_description, dialogue, camera,
# light, sfx, shot_prompt, video_prompt. Prompts remain editable in the working
# copy but are deliberately omitted from the review table. Anything else
# (shot_id, shot_no, assets, refs, statuses) is structural and is refused rather
# than silently dropped. The shot count is fixed: a shot id that is not in the
# plan is an error.
#
# Exit codes: 0 ok · 2 usage/edit error · 4 the CLI output was unparseable
# · 5 the plan has no readable shots
set -u

EDITABLE_FIELDS="duration shot_type shot_description dialogue camera light sfx shot_prompt video_prompt"
COLUMNS="shot_no duration shot_type shot_description dialogue camera light sfx"
HEADERS="Shot #|Duration|Shot Type|Shot Description|Voiceover|Camera|Light|SFX"

usage() {
  sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

# fail <message>
fail() { printf '⚠️  %s\n' "$1" >&2; exit 2; }

# cell <text> — one markdown table cell: no newlines or tabs, escaped pipes.
cell() {
  printf '%s' "$1" | tr '\n\t' '  ' | sed 's/|/\\|/g; s/^ *//; s/ *$//'
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift

case "$cmd" in
  take)
    id="${1:?missing video_ad_id}"; shift
    dest=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --dest) dest="${2:?missing value for --dest}"; shift 2 ;;
        *) fail "unexpected argument: $1" ;;
      esac
    done
    detail=$(cawcut ad-video detail "$id" --json) || { printf '⚠️  detail call failed (id=%s)\n' "$id" >&2; exit 4; }
    printf '%s' "$detail" | jq -e '.id' >/dev/null 2>&1 || { printf '⚠️  detail output not parseable (id=%s)\n' "$id" >&2; exit 4; }
    if [ -z "$dest" ]; then
      name=$(printf '%s' "$detail" | jq -r '.product_info.name // .name // ""')
      slug=$(printf '%s' "$name" | tr -cs 'A-Za-z0-9_-' '-' | sed 's/^-*//; s/-*$//' | cut -c1-60)
      [ -n "$slug" ] || slug="$id"
      dest="$HOME/Downloads/ad-video-$slug"
    fi
    mkdir -p "$dest/storyboard"
    printf '%s' "$detail" | jq '.outputs.storyboard_plan.value' > "$dest/storyboard/script.json"
    printf '%s' "$detail" | jq -c '{video_type: (.product_info.video_settings.video_type // ""), revision: (.outputs.storyboard_plan.value.revision // 0), title: (.outputs.storyboard_plan.value.title // "")}' > "$dest/storyboard/script.meta.json"
    jq -e '(.shots | type) == "array"' "$dest/storyboard/script.json" >/dev/null 2>&1 || { printf '⚠️  the plan has no shots array — is the storyboard generated yet?\n' >&2; exit 5; }
    video_type=$(jq -r '.video_type' "$dest/storyboard/script.meta.json")
    printf 'plan: %s\nmeta: %s (video_type=%s)\n' "$dest/storyboard/script.json" "$dest/storyboard/script.meta.json" "$video_type"
    ;;

  apply)
    plan="${1:?missing plan.json}"; edits="${2:?missing edits.json}"
    [ -f "$plan" ] || fail "no such plan file: $plan"
    [ -f "$edits" ] || fail "no such edits file: $edits"
    jq -e . "$edits" >/dev/null 2>&1 || fail "edits file is not valid JSON: $edits"

    # Validate before writing: unknown shot, unknown field, or a structural
    # field must fail loudly instead of being dropped by the merge.
    while IFS= read -r key; do
      case "$key" in
        title|synopsis) continue ;;
        shot-*) ;;
        *) fail "unknown key in edits: $key (expected title, synopsis, or shot-N)" ;;
      esac
      jq -e --arg id "$key" '[.shots[].shot_id] | index($id)' "$plan" >/dev/null 2>&1 &&
        [ "$(jq -r --arg id "$key" '[.shots[].shot_id] | index($id)' "$plan")" != "null" ] ||
        fail "unknown shot in edits: $key"
      while IFS= read -r field; do
        case " $EDITABLE_FIELDS " in
          *" $field "*) ;;
          *) fail "field not editable: $key.$field" ;;
        esac
      done < <(jq -r --arg id "$key" '.[$id] | keys[]' "$edits")
    done < <(jq -r 'keys[]' "$edits")

    tmp="$(mktemp "${TMPDIR:-/tmp}/script-plan.XXXXXX")"
    jq --slurpfile e "$edits" '
      ($e[0]) as $edits
      | reduce ($edits | keys[]) as $key (.;
          if ($key == "title" or $key == "synopsis") then .[$key] = $edits[$key]
          else .shots = [ .shots[] | if .shot_id == $key then . * $edits[$key] else . end ]
          end)
    ' "$plan" > "$tmp" || { rm -f "$tmp"; fail "merge failed"; }
    mv "$tmp" "$plan"

    jq -r 'to_entries[] | if (.key | startswith("shot-")) then "\(.key): \(.value | keys | join(", "))" else .key end' "$edits"
    ;;

  render)
    plan="${1:?missing plan.json}"
    [ -f "$plan" ] || fail "no such plan file: $plan"
    meta="$(dirname "$plan")/script.meta.json"
    video_type=""
    [ -f "$meta" ] && video_type=$(jq -r '.video_type // ""' "$meta" 2>/dev/null)
    voiceover=1
    [ "$video_type" = "product_showcase" ] && voiceover=0

    cols="$COLUMNS"; headers="$HEADERS"
    if [ "$voiceover" = "0" ]; then
      cols="shot_no duration shot_type shot_description camera light sfx"
      headers="Shot #|Duration|Shot Type|Shot Description|Camera|Light|SFX"
    fi

    # jq emits one TSV line per shot (plan level first), awk lays the table out.
    # @tsv escapes tabs/newlines inside a cell. Render escaped line breaks as
    # HTML breaks so descriptions never appear as a literal "\\n" in the review.
    jq -r --arg cols "$cols" '
      def s: tostring;
      . as $plan
      | [ $plan.shots[] | [
          ($cols | split(" ")) as $keys
          | $keys[] as $k
          | if $k == "shot_no" then (.shot_no | s)
            elif $k == "duration" then (.duration | s)
            else (.[$k] // "" | s)
            end
        ] ] as $rows
      | (["\($plan.title // "")", "\($plan.synopsis // "")"], $rows[])
      | @tsv
    ' "$plan" | awk -v headers="$headers" '
      function clean(v) {
        gsub(/\\n/, "<br>", v); gsub(/\\r/, "", v); gsub(/\\t/, " ", v)
        gsub(/\|/, "\\|", v)
        gsub(/^[ ]+|[ ]+$/, "", v)
        return v
      }
      BEGIN { n = split(headers, H, "|"); FS = "\t" }
      NR == 1 { printf "**%s**\n\n", clean($1); if ($2 != "") printf "%s\n\n", clean($2); next }
      {
        if (NR == 2) {
          printf "|"; for (i = 1; i <= n; i++) printf " %s |", H[i]; printf "\n"
          printf "|"; for (i = 1; i <= n; i++) printf " --- |"; printf "\n"
        }
        printf "|"; for (i = 1; i <= n; i++) printf " %s |", clean($i); printf "\n"
      }
    '
    ;;

  show)
    plan="${1:?missing plan.json}"; edits="${2:?missing edits.json}"
    # Through the shell, so the script works whether or not it carries the exec bit.
    bash "$0" apply "$plan" "$edits" >&2 || exit $?
    bash "$0" render "$plan"
    ;;

  *) usage ;;
esac

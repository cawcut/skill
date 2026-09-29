#!/usr/bin/env bash
# Download all media of a CawCut Ad Video project (product images, storyboard
# sketch/grid, final video) into one local project folder. Bundled with the
# cawcut-ad-video skill so agents never hand-roll curl/jq pipelines.
#
# Usage:
#   download_media.sh <video_ad_id> [--kind product|storyboard|video|all] [dest_dir]
#
# Default dest: ~/Downloads/ad-video-<product-name> (falls back to the project
# id when no name is set yet). Layout:
#   <dest>/product/     logo + primary/additional product images
#   <dest>/storyboard/  sketch + panel grid images
#   <dest>/<name>.mp4   final video (folder root)
#
# All URLs returned by the API are pre-signed, so plain curl works. If a URL
# ever 403s, re-run this script — product image URLs are re-signed on every
# detail read.
#
# Exit codes: 0 = downloaded at least one file · 4 = detail output unparseable
# · 5 = nothing available to download yet
set -u

id="${1:?usage: download_media.sh <video_ad_id> [--kind product|storyboard|video|all] [dest_dir]}"
shift
kind="all"
dest=""
while [ $# -gt 0 ]; do
  case "$1" in
    --kind) kind="${2:?missing value for --kind}"; shift 2 ;;
    *) dest="$1"; shift ;;
  esac
done

detail=$(cawcut ad-video detail "$id" --json) || {
  printf '⚠️  detail call failed (id=%s)\n' "$id" >&2
  exit 4
}
if ! printf '%s' "$detail" | jq -e '.id' >/dev/null 2>&1; then
  printf '⚠️  detail output not parseable (id=%s)\n' "$id" >&2
  exit 4
fi
# Empty drafts legitimately have no name yet — fall back to the id.
name=$(printf '%s' "$detail" | jq -r '.product_info.name // .name // ""')

if [ -z "$dest" ]; then
  slug=$(printf '%s' "$name" | tr -cs 'A-Za-z0-9_-' '-' | sed 's/^-*//; s/-*$//' | cut -c1-60)
  [ -n "$slug" ] || slug="$id"
  dest="$HOME/Downloads/ad-video-$slug"
fi
mkdir -p "$dest/product" "$dest/storyboard"

saved=0

# ext_from_url <url> <default_ext> — strip query string, keep the path suffix.
ext_from_url() {
  local path="${1%%\?*}"
  local ext="${path##*.}"
  case "$ext" in
    png|jpg|jpeg|webp|gif|mp4|mov|webm) printf '%s' "$ext" ;;
    *) printf '%s' "$2" ;;
  esac
}

# download_one <url> <file> — skip duplicates/empties, report saved paths.
download_one() {
  local url="$1" file="$2"
  [ -n "$url" ] && [ "$url" != "null" ] || return 0
  if curl -fsSL --retry 2 -o "$file" "$url"; then
    printf '%s\n' "$file"
    saved=$((saved + 1))
  else
    printf '⚠️  download failed: %s\n' "$url" >&2
  fi
}

if [ "$kind" = "all" ] || [ "$kind" = "product" ]; then
  while IFS=$'\t' read -r tag url; do
    download_one "$url" "$dest/product/${tag}.$(ext_from_url "$url" png)"
  done < <(printf '%s' "$detail" | jq -r '
    def imgs(tag; arr): [ arr // [] | to_entries[] | "\(tag)-\(.key + 1)\t\(.value.url // "")" ];
    ([ (if .product_info.logo.url then "logo\t\(.product_info.logo.url)" else empty end) ]
     + imgs("logo"; .product_info.logo_images)
     + imgs("primary"; .product_info.primary_images)
     + imgs("image"; .product_info.images))[]' | awk -F'\t' '!seen[$2]++')
fi

if [ "$kind" = "all" ] || [ "$kind" = "storyboard" ]; then
  while IFS=$'\t' read -r tag url; do
    download_one "$url" "$dest/storyboard/${tag}.$(ext_from_url "$url" png)"
  done < <(printf '%s' "$detail" | jq -r '
    def media_urls: [ .. | objects | .url? | strings | select(startswith("http")) ] | unique;
    ([ (.outputs.storyboard_sketch.value | media_urls | to_entries[] | "sketch-\(.key + 1)\t\(.value)") ]
     + [ (.outputs.storyboard_image.value | media_urls | to_entries[] | "panels-\(.key + 1)\t\(.value)") ])[]')
fi

if [ "$kind" = "all" ] || [ "$kind" = "video" ]; then
  url=$(printf '%s' "$detail" | jq -r '
    [ .outputs.final_video.value, .outputs.voiceover_final_video.value, .outputs.talking_video.value
      | .. | objects | .url? | strings | select(startswith("http")) ] | first // empty')
  download_one "$url" "$dest/$(printf '%s' "$name" | tr -cs 'A-Za-z0-9_-' '-' | sed 's/^-*//; s/-*$//' | cut -c1-60)_ad_video.$(ext_from_url "$url" mp4)"
fi

if [ "$saved" -eq 0 ]; then
  printf 'ℹ️  nothing to download yet (kind=%s, id=%s) — media appears as stages complete\n' "$kind" "$id" >&2
  exit 5
fi
printf '📁 %d file(s) saved under %s\n' "$saved" "$dest" >&2

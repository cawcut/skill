#!/usr/bin/env bash
# Poll a CawCut Ad Video project's detail endpoint until a stage reaches a
# terminal state. Bundled with the cawcut-ad-video skill so agents never
# hand-roll polling loops.
#
# Usage:
#   poll.sh <video_ad_id> <jq_path> <success_value> <timeout_s> [interval_s]
#
# Examples:
#   poll.sh "$ID" '.status' stage_completed 600 15
#   poll.sh "$ID" '.outputs.generated_marketing_messages.status' succeeded 600 15
#   poll.sh "$ID" '.outputs.storyboard_plan.status' succeeded 3600 30
#   poll.sh "$ID" '.outputs.final_video.status // .outputs.voiceover_final_video.status // .outputs.talking_video.status' succeeded 3600 30
#
# Exit codes: 0 = success_value reached · 2 = failed · 3 = timeout · 4 = unparseable output
#
# This script raises NO notifications. The notification channel is the host's
# own tool (in Claude Code, PushNotification) — a toast fired from here via
# osascript / notify-send / BurntToast is a different, unwanted channel that
# lingers in the user's system settings. The exit code is the only signal;
# the agent watches for it and notifies through its own tool.
# NOTE: the CLI is piped straight into jq. Never route JSON through
# `echo "$var" | jq` — zsh's echo interprets backslash escapes and corrupts
# the payload, which makes jq fail on every iteration (the loop then spins
# forever without ever matching a terminal state).
set -u

id="${1:?usage: poll.sh <video_ad_id> <jq_path> <success_value> <timeout_s> [interval_s]}"
jq_path="${2:?missing jq_path}"
success_value="${3:?missing success_value}"
timeout_s="${4:?missing timeout_s}"
interval_s="${5:-30}"

start_time=$(date +%s)
first_tick=1
while true; do
  # Missing key (stage not started yet) = "pending" and keeps polling;
  # empty jq output = the CLI output itself was unparseable = hard stop.
  stage_status=$(cawcut ad-video detail "$id" --json | jq -r "($jq_path) // \"pending\"")
  if [ -z "$stage_status" ]; then
    printf '⚠️  detail output not parseable (id=%s) — stop polling and inspect: cawcut ad-video detail %s --json\n' "$id" "$id" >&2
    exit 4
  fi
  printf '[%s] %s = %s\n' "$(date '+%H:%M:%S')" "$jq_path" "$stage_status"
  if [ "$first_tick" = "1" ]; then
    first_tick=0
    # The server's own estimate for the stage now running — the figure to quote
    # to the user. Read once, so a long poll costs one extra call in total.
    # Only the stage's own estimate is read; nothing is inferred when it is 0.
    est_ms=$(cawcut ad-video detail "$id" --json | jq -r '.estimated_running_ms // 0')
    case "$est_ms" in
      ''|*[!0-9]*) ;;
      0) ;;
      *)
        if [ "$est_ms" -lt 60000 ]; then
          printf '   estimated: about %ss\n' "$(( (est_ms + 999) / 1000 ))"
        elif [ "$est_ms" -lt 3600000 ]; then
          printf '   estimated: about %sm\n' "$(( (est_ms + 59999) / 60000 ))"
        else
          printf '   estimated: about %sh\n' "$(( (est_ms + 3599999) / 3600000 ))"
        fi
        ;;
    esac
  fi
  if [ "$stage_status" = "$success_value" ]; then
    exit 0
  fi
  if [ "$stage_status" = "failed" ]; then
    printf '❌ stage failed — read the error: cawcut ad-video detail %s --json\n' "$id" >&2
    exit 2
  fi
  if [ $(( $(date +%s) - start_time )) -ge "$timeout_s" ]; then
    printf '⏰ timed out after %ss (id=%s)\n' "$timeout_s" "$id" >&2
    exit 3
  fi
  sleep "$interval_s"
done

# Running the CLI helpers

### Bundled-script runner

Use `cawcut` CLI commands directly for project operations and detail inspection. Choose bundled helpers for the host platform. Windows helpers require PowerShell and the installed `cawcut` CLI, not Python, jq, bash, or external curl; do not ask Windows users to install those tools for this skill. macOS/Linux `.sh` helpers require jq; neither platform uses Python.

- macOS/Linux: `bash <base_dir>/scripts/<name>.sh …`
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File "<base_dir>\scripts\<name>.ps1" …`

The four helpers (`poll`, `script_plan`, `storyboard_review`, `download_media`) have equivalent `.sh` and `.ps1` implementations. Use the matching extension and platform-specific flags throughout one run; for example, `--kind video` on bash is `-Kind video` on PowerShell.

## Media preview & downloads

All media URLs the API returns (product images, storyboard sketch/grid, final video) are **pre-signed** — plain `curl` downloads them directly, no extra signing step. If one ever 403s, re-read `detail` and retry with the fresh URL (product image URLs are re-signed on every `detail` call).

**Preview priority** (product logo/primary images, storyboard sketch/grid):
1. If the host has a send-file-to-user tool (e.g. Claude's `SendUserFile`), download the file first, then send it so the user previews inline in the chat.
2. Otherwise `open` the downloaded file (macOS) or just report the local path.

Always use the bundled downloader (character/scene images: `cawcut ad-video entities download <id>`, already done by `storyboard_review`) instead of hand-rolling curl/jq pipelines — and never name a shell variable `status` (read-only in zsh):

```bash
# macOS/Linux
bash <base_dir>/scripts/download_media.sh <id> [--kind product|entities|storyboard|video|all] [dest_dir]

# Windows PowerShell
powershell -ExecutionPolicy Bypass -File "<base_dir>\scripts\download_media.ps1" <id> [-Kind product|entities|storyboard|video|all] [-Destination <dir>]
```

Default dest: `~/Downloads/ad-video-<product-name>` (falls back to `ad-video-<id>` before the project is named). Layout: `product/` (logo + primary + additional images), `entities/` (`character-N` / `location-N`), `storyboard/` (sketch + panel grid), final video at the folder root. It prints every saved path — relay those paths to the user in `reply_language`.

## Polling (bundled script — mandatory)

Trigger without `--wait`, then poll with the platform-specific bundled script. **Never hand-roll polling loops** — an ad-hoc `echo "$var" | jq` loop corrupts the JSON under zsh (echo interprets `\n` escapes) and spins forever without matching a terminal state.

```bash
bash <base_dir>/scripts/poll.sh <id> '<json_path>' <success_value> <timeout_s> [interval_s=30]

# Windows PowerShell
powershell -ExecutionPolicy Bypass -File "<base_dir>\scripts\poll.ps1" <id> '<json_path>' <success_value> <timeout_s> [interval_s=30]
```

| Stage | json_path | success_value | timeout_s |
|---|---|---|---|
| ① analyze | `.status` | `stage_completed` | 600 |
| ③ idea | `.outputs.generated_marketing_messages.status` | `succeeded` | 600 |
| ④ plan | `.outputs.storyboard_plan.status` | `succeeded` | 3600 |
| ④ prompts | `.outputs.storyboard_plan.prompt_status` | `succeeded` | 600 |
| ④ sketch | `.outputs.storyboard_sketch.status` | `succeeded` | 3600 |
| ④ panels | `.outputs.storyboard_image.status` | `succeeded` | 3600 |
| ⑤ video | `.outputs.final_video.status // .outputs.voiceover_final_video.status // .outputs.talking_video.status` | `succeeded` | 3600 |

The Windows helper parses these dotted paths and `//` fallbacks internally; `json_path` does not require jq on Windows.

Exit codes: `0` success · `2` failed (report the output's `error` from `detail --json`; see `references/troubleshooting.md`) · `3` timeout → AskUserQuestion `⏳ Continue waiting` (run the script again) / `❌ Stop` (project persists; resume later with `cawcut ad-video detail <id>`) · `4` output unparseable → stop polling, run `cawcut ad-video detail <id> --json` once and inspect (auth/CLI issue).

**The script does not notify — the host's tool does.** `poll.sh` ends on an exit code and nothing else. Never raise an OS notification from the shell (`osascript`, `notify-send`, BurntToast), never add one back into the script, and never register a notification permission on the user's machine on your own initiative: a toast fired from a shell command is a different channel from the app's own notification, and it is not what the user asked for.

### Telling the user how long it will take

**Never estimate generation time yourself — and never turn a deadline into a duration.** The server computes the runtime, and `detail` carries it as `estimated_running_ms` (milliseconds, present while a stage is running). `poll.sh` reads it on its first tick and prints one `estimated: about Nm` line — relay that figure if there is one, and nothing more. If you need it directly, it is on any `detail --json` read.

**When the API gives no figure** (the field is absent or zero — the lookup is best-effort and can miss), fall back to the **order of magnitude, never to the deadline**: these stages run on the order of **minutes** (the node estimates behind them are seconds to a couple of minutes), so say "about a few minutes" / "大概几分钟" and add that you will say the moment it lands. Do not say the timing is unknown, and do not hedge upward.

**The `timeout_s` column is a give-up deadline, not a runtime.** Saying "at most about an hour" because the row says `3600` is the same error as inventing a range: it is the point at which the script stops waiting, typically an order of magnitude past the real runtime. The deadline never appears in a reply, not even hedged with "最多" / "at most".

### Long-enough stages — tell the user they can step away

`storyboard_plan`, `sketch`, `panels` and `video` take minutes rather than seconds. Before polling one, say so once — the server's `estimated_running_ms` if there is one, otherwise "a few minutes" — and tell them they can step away and will be told the moment it lands. Then poll without narrating each tick.

**The notification comes from the host's own tool.** In Claude Code that is `PushNotification` with a one-line `message` and `status: "proactive"`; if its schema is deferred (not yet loaded), load it first with `ToolSearch` (`select:PushNotification`), because a call without the schema or without `status` fails validation. A "not sent" result because the user is active in the terminal is expected: do not retry or treat it as an error. It lands in the app the user is already running and, with Remote Control connected, on their phone — which is the difference between noticing in the next minute and noticing tomorrow. Send it **once**, when the stage lands, naming the stage and the project id. If the host exposes no such tool, skip it silently and just present the result when you have it: do not fall back to a shell-level toast, and do not add one to `poll.sh`.

Do not notify for the short stages (analyze, idea, prompts) — they finish inside a turn.

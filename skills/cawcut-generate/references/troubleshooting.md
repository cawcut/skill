# CawCut Generate — Troubleshooting

## `cawcut: command not found`

External users install the CLI from npm only (no git clone or repo `./setup`):

```bash
npm install -g @ubnt/cawcut
```

Then run `cawcut auth login` via Bash.

## `Token expired, run cawcut auth login`

Run via Bash yourself — do not ask the user to type the command:

```bash
cawcut auth login
```

Tell the user a browser tab will open for OAuth consent. After login succeeds, retry the command that failed once.

## Structured error output

Newer CLI/API errors may include:

- `Code:` — machine-readable BE or provider code.
- `Category:` — stable recovery category such as `insufficient_credits`, `invalid_param`, `missing_input`, `content_policy`, `model_unavailable`, or `timeout`.
- `Suggested actions:` — numbered options. Prefer presenting these options to the user before retrying.

If structured actions are present, use them first. If not, follow the fallback tree below.

## `Unknown capability`

```bash
cawcut capabilities list
```

Use one of the five official keys: `text-to-image`, `text-to-video`, `image-to-image`, `image-to-video`, `omni-to-video`.

## Parameter or media validation errors

BE validates `--param`, `--model`, and media against the AI Kit model schema.

```bash
cawcut capabilities list --schema
```

Fix flags (enums, ranges, required media) and retry.

## Missing input

For App/template-style errors, switch to the App skill:

```bash
cawcut app describe <app_id>
```

Ask the user for the missing KEY and retry with `--input KEY=value`.

For raw generate errors, inspect the selected model's required media:

```bash
cawcut capabilities list --models --schema --json --capability <cap> --model "<model_id>"
```

## Insufficient credits or quota

```bash
cawcut account credits
```

Offer options:

1. Add credits in CawCut billing and retry.
2. Choose a cheaper available model.
3. Reduce duration, loop count, image count, or other cost-driving params.

## Content policy / moderation

Offer options:

1. Revise the prompt to remove sensitive or disallowed wording.
2. Replace user-provided media with a safer file/URL.
3. Retry only after the user confirms the revised direction.

## Model unavailable

```bash
cawcut capabilities list --models --schema --json --capability <cap> --model "<model_id>"
```

Offer the BE default model first. If the user asked for a specific unavailable model, explain it may be unavailable for their plan or region.

## `Generation in progress, check status: cawcut task status ...`

Re-run with `--wait`, or poll manually:

```bash
cawcut task status <task_id> --wait
```

## Timeout

Do not start a duplicate job automatically. Offer:

```bash
cawcut task status <task_id> --wait
```

If the task later fails, use the task's `Category:` and `Suggested actions:`.

## Local media upload

`--image`, `--video`, and `--audio` accept a **local path** or **HTTPS URL**.

- Local path: CLI fetches limits from `GET /developer/config`, validates file size/format/dimensions **before** upload, then uploads via `POST /developer/assets` and sends `asset_id` to generate.
- URL: passed through as `{type, url}` without upload.
- CLI does **not** resize or compress files. If validation fails, compress/resize on the **local machine** (macOS Preview/sips, ImageMagick, ffmpeg, etc.) and retry.

### Upload validation errors (CLI pre-flight)

When a local file fails pre-flight, do not just print the CLI message and stop — ask the user with a numbered choice (`AskQuestion` or numbered-text fallback):

1. Compress/resize it for you now (locally, via `sips`/`ffmpeg`) and retry the upload automatically
2. You'll compress/resize it yourself and re-upload
3. Cancel

Never offer CawCut Web as an option. If the user picks (1), run the matching fix command via Bash, then retry the upload with the new local file — at most one automatic retry; if it still fails, fall back to option (2)'s guidance instead of looping.

| Problem | Typical CLI message | Fix command if user picks "compress for me" (adapt path/values) |
|---------|---------------------|------------|
| File too large (image) | `… MB (limit … MB)` | `sips -s format jpeg -s formatOptions 70 <src> --out <tmp.jpg>` — re-encodes at lower quality; this is a **byte-size** fix, not a resize |
| Longest edge too large (image) | `longest edge is …px (limit …px)` | `sips -Z <limit_px> <src> --out <tmp.jpg>` — resizes so the longest edge fits; this is a **dimension** fix, not a size issue |
| Width/height too large (image) | `dimensions …×… exceed …` | `sips -Z <max(limit_w, limit_h)> <src> --out <tmp.jpg>` |
| File too large (video) | `… MB (limit … MB)` | `ffmpeg -i <src> -vcodec libx264 -crf 28 <tmp.mp4>` — raise `-crf` for smaller output |
| File too large (audio) | `… MB (limit … MB)` | `ffmpeg -i <src> -b:a 96k <tmp.mp3>` — lower bitrate |
| Unsupported format | `Unsupported file type` | `sips -s format jpeg <src> --out <tmp.jpg>` (image) or re-encode with `ffmpeg` (video/audio) |
| Invalid/corrupt image | `Could not read image dimensions` | No local fix applies — ask the user for a valid JPG/PNG/WebP directly (skip the compress-for-me option) |

Check live limits:

```bash
cawcut config limits
```

### Generate-time model limits (after upload)

If upload succeeds but generate fails with `Category: media_limit`, the asset passed platform limits but violated **model** constraints (min size, aspect ratio, duration, etc.). Inspect the selected model:

```bash
cawcut capabilities list --models --schema --json --capability <cap> --model "<model_id>"
```

Look at `medias[].limit` for per-model hints. Workflow may auto-compress images for some models (`hardLimit: false`); video/audio generally do not.

## Download failed

- Verify the result URL is reachable.
- Try `--download tmp` if `~/Downloads` is not writable.

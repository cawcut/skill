# CawCut App Run — Troubleshooting

## `cawcut: command not found`

External users install the CLI from npm only (no git clone or repo `./setup`):

```bash
npm install -g @ubnt/cawcut
```

Then run `cawcut auth login` via Bash.

## Structured error output

Newer CLI/API errors may include `Code:`, `Category:`, and `Suggested actions:`.
When present, show the numbered suggested actions to the user and let them choose before retrying.

## Token expired

Run via Bash yourself — do not ask the user to type the command:

```bash
cawcut auth login
```

Tell the user a browser tab will open for OAuth consent. Retry the app command after login succeeds.

## App not found or inaccessible

```bash
cawcut app list
```

Offer options:

1. Pick another App from Official Apps, My Apps, or Shared Apps.
2. Open the App in CawCut Web and confirm the user has access.
3. Fall back to `cawcut-generate` if no App template is accessible.

## Upload validation errors (CLI pre-flight)

When a local media input fails pre-flight validation (size/format/dimensions), do not just print the CLI message and stop — ask the user with a numbered choice (`AskQuestion` or numbered-text fallback):

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

## Missing required input

```bash
cawcut app describe <app_id>
```

Use the KEY column exactly. Ask the user for missing text/media values and retry with:

```bash
cawcut app run <app_id> --input KEY=value --wait --download --json
```

## Invalid input value

Re-run describe and compare against KIND, DEFAULT, and requirements:

```bash
cawcut app describe <app_id>
```

For media inputs, accept only an HTTPS URL or local path prefixed with `@`.

## Insufficient credits or quota

```bash
cawcut account credits
```

Offer options:

1. Add credits in CawCut billing and retry.
2. Pick a lower-cost App or raw generation model.
3. Reduce duration or other App inputs if the template exposes them.

## Content policy / moderation

Offer options:

1. Revise text inputs to remove sensitive or disallowed wording.
2. Replace user-provided media with a safer file/URL.
3. Choose another App if the template's fixed prompt is unsuitable.

## Timeout

Do not start a duplicate run automatically. Continue polling the existing task:

```bash
cawcut task status <task_id> --wait
```

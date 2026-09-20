# CawCut App Run — Troubleshooting

## `cawcut: command not found`

External users install the CLI from npm only (no git clone or repo `./setup`):

```bash
npm install -g @ubnt/cawcut
```

Then run `cawcut auth login` via Bash.

## Windows PowerShell: redirecting stderr can abort the script

The CLI writes results to stdout, and progress, warnings and errors to stderr. Windows
PowerShell turns a native program's stderr into an ErrorRecord as soon as that stream is
redirected — `2>&1` and `2>$null` both count — and under `$ErrorActionPreference = 'Stop'` the
record is terminating. Measured: `cawcut app list 2>$null` aborts the script on a progress
line that reported no failure at all, while the same command without a redirect runs fine.

When driving the CLI from PowerShell:

- Leave stderr alone and read the result from stdout: `$out = cawcut app list --json`.
- If stderr has to be captured or silenced, relax the preference around the call and restore it:

  ```powershell
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $out = cawcut app list --json 2>$null
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  ```

- Judge failure by `$LASTEXITCODE`, never by whether anything appeared on stderr.
- `--json` silences progress but not errors: a failing command still writes to stderr, so the
  wrapper above is what makes the failure path safe.
- cmd.exe, Git Bash, macOS and Linux shells are unaffected.
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

1. Compress/resize it for you now (locally, with this platform's own tool) and retry the upload automatically
2. You'll compress/resize it yourself and re-upload
3. Cancel

Never offer CawCut Web as an option. If the user picks (1), run the matching fix command via Bash, then retry the upload with the new local file — at most one automatic retry; if it still fails, fall back to option (2)'s guidance instead of looping.

**Choose the tool for the user's platform before running anything.** `sips` is macOS-only —
on Windows it fails with "command not found", which is not a reason to retry.

| Platform | Images | Video / audio |
|---|---|---|
| macOS | `sips` (built in) | `ffmpeg` when installed |
| Windows | PowerShell + `System.Drawing` (built in) — snippet below | `ffmpeg` when on PATH; otherwise there is no local fix, so go to option (2) |
| Linux | `magick`/`convert` (ImageMagick) or `ffmpeg` | `ffmpeg` |

| Problem | Typical CLI message | Fix (macOS) | Fix (Windows) |
|---------|---------------------|-------------|---------------|
| File too large (image) | `… MB (limit … MB)` | `sips -s format jpeg -s formatOptions 70 <src> --out <tmp.jpg>` — re-encodes at lower quality; a **byte-size** fix, not a resize | PowerShell snippet with `$max = 0` (quality only) |
| Longest edge too large (image) | `longest edge is …px (limit …px)` | `sips -Z <limit_px> <src> --out <tmp.jpg>` — resizes so the longest edge fits; a **dimension** fix, not a size issue | PowerShell snippet with `$max = <limit_px>` |
| Width/height too large (image) | `dimensions …×… exceed …` | `sips -Z <max(limit_w, limit_h)> <src> --out <tmp.jpg>` | PowerShell snippet with `$max = <max(limit_w, limit_h)>` |
| File too large (video) | `… MB (limit … MB)` | `ffmpeg -i <src> -vcodec libx264 -crf 28 <tmp.mp4>` — raise `-crf` for smaller output | same `ffmpeg` command when it is installed |
| File too large (audio) | `… MB (limit … MB)` | `ffmpeg -i <src> -b:a 96k <tmp.mp3>` — lower bitrate | same `ffmpeg` command when it is installed |
| Unsupported format | `Unsupported file type` | `sips -s format jpeg <src> --out <tmp.jpg>` (image) or re-encode with `ffmpeg` | PowerShell snippet (image); `ffmpeg` for video/audio |
| Invalid/corrupt image | `Could not read image dimensions` | No local fix applies — ask the user for a valid JPG/PNG/WebP directly (skip the compress-for-me option) | same |

Windows image fix — resizes and re-encodes in one pass. Set `$max` to the pixel limit, or to `0`
to re-encode at lower quality without resizing; lower `$quality` for a smaller file:

```powershell
Add-Type -AssemblyName System.Drawing
$src = '<src>'; $out = '<tmp.jpg>'; $max = <limit_px>; $quality = 70
$img = [System.Drawing.Image]::FromFile($src)
# 1.0 and not 1: [Math]::Min(1, 0.27) binds the int overload and truncates the ratio to 0.
$r = if ($max -gt 0) { [Math]::Min(1.0, [Math]::Min($max / $img.Width, $max / $img.Height)) } else { 1.0 }
$bmp = New-Object System.Drawing.Bitmap ([int]($img.Width * $r)), ([int]($img.Height * $r))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = 'HighQualityBicubic'
$g.DrawImage($img, 0, 0, $bmp.Width, $bmp.Height)
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$p = New-Object System.Drawing.Imaging.EncoderParameters 1
$p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), $quality
$bmp.Save($out, $enc, $p)
$g.Dispose(); $bmp.Dispose(); $img.Dispose()
```

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

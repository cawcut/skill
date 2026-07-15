# CawCut App Run — Input Reference

**Catalog freshness:** run `cawcut app list` on **every new user message** for the **current subject/goal** before discovery, scoring, ID resolution, or browse — never reuse list JSON or a "no match" conclusion from earlier messages. See `SKILL.md` § Catalog freshness (**Per-user-message rule**).

## Discovering inputs

### List all apps (quick scan)

```bash
cawcut app list                     # grouped, human-readable; name + credits + description (no app_id)
cawcut app list --schema            # adds input summary per app
cawcut app list --category image    # image-output apps only
cawcut app list --category video    # video-output apps only
cawcut app list --json              # lean JSON: name/app_id, categories[], credits, source — no input_schema
cawcut app list --json --schema     # full JSON, adds input_schema per app
```

For a plain listing/overview question, `cawcut app list --schema` (no `--json`) is already grouped by category and source in one call — prefer it over JSON + manual parsing. Reserve `--json --schema` for programmatic selection/scoring (see `skills/cawcut/references/intent-matching.md`), where the input schema is needed to score input fit.

### Describe one app (recommended before run)

```bash
cawcut app describe <app_id>         # formatted table: KEY, KIND, required, default, requirements
cawcut app describe <app_id> --json  # raw input_schema JSON
```

`describe` shows:
- Every exposed input key
- Input kind (text / image / video / audio)
- Required or optional
- Whether a real default value exists (`DEFAULT` column / `default` + `x-cawcut-has-default` in JSON)
- Input requirements from `x-cawcut-requirements`
- Human label and description
- Sample URL or CLI example when provided by the app author (**illustrative only** — for `image` / `video` / `audio` kinds, never pass sample URLs, paths, or doc placeholders as actual `--input` values; show the media menu and wait for the user's own file or URL)

## Input kinds

| Kind | What it accepts | Auto-upload? |
|------|----------------|--------------|
| `text` | String, number, boolean (coerced to string) | No |
| `image` | HTTPS URL or local path (`@/path` or bare path) | Yes (local paths) |
| `video` | HTTPS URL or local path | Yes (local paths) |
| `audio` | HTTPS URL or local path | Yes (local paths) |

## `--input` formats

```bash
# Text
--input prompt="summer campaign, bright colors"

# Image — HTTPS URL
--input product_image="https://cdn.example.com/shoe.jpg"

# Image — local file (auto-uploaded via POST /developer/assets)
--input product_image="@./shoe.jpg"
# or without @ if the file exists on disk:
--input product_image="./shoe.jpg"

# Video — local file
--input reference_clip="@/abs/path/clip.mp4"

# Audio — local file
--input background_music="@./track.mp3"
```

The `@` prefix explicitly marks a local path. Bare paths that look like filesystem paths are also auto-detected and uploaded.

## `--input-json` alternative

For inputs with many keys or special characters:

```json
{
  "prompt": "summer campaign",
  "product_image": "https://cdn.example.com/shoe.jpg"
}
```

```bash
cawcut app run <app_id> --input-json ./inputs.json --wait
```

Do **not** combine `--input` and `--input-json` in one invocation.

## Key resolution

The CLI matches `--input` keys case-insensitively against:
1. The schema `property` name (the canonical KEY shown in `describe`)
2. The port ID (`x-cawcut-port-id`) if the app exposes one
3. The node ID (`x-cawcut-node-id`)

If the key doesn't match any of the above and the app has a defined schema, the CLI aborts with `unknown input key "..." (known keys: ...)`.

## Media upload flow

When a local path is detected, the CLI:
1. `GET /developer/config` — loads platform upload limits (image/video/audio)
2. Validates file size, format, and image dimensions locally (CLI does **not** compress)
3. `POST /developer/assets` — uploads the file and receives `{asset_id, url}`
4. Sends `{asset_id, url, format, mode}` as the input value to the run API

If validation fails, do not just print the error and stop — ask the user with a numbered choice (`AskQuestion`): (1) compress/resize it for you now via `sips`/`ffmpeg` and retry automatically, (2) they'll fix it and re-upload, or (3) cancel. Never suggest CawCut Web as a workaround. If they pick (1), run the matching command (`references/troubleshooting.md` has the exact commands per failure type — file-size vs longest-edge are different fixes), then retry the upload once; if it still fails, fall back to option (2)'s guidance.

```bash
cawcut config limits   # show current platform caps
```

HTTPS URLs are passed through as `{type: "url", url: "..."}` without upload.

## Common patterns

```bash
# App with text + image input
cawcut app describe my-ad-app
cawcut app run my-ad-app \
  --input prompt="neon cityscape, vibrant" \
  --input style_image="@./reference.png" \
  --wait

# App with only text inputs
cawcut app run my-text-app \
  --input topic="coffee culture" \
  --input tone="playful" \
  --wait --download

# App with no inputs (self-contained)
cawcut app run my-selfie-app --wait
```

# cawcut ad-video — API reference

All commands hit the CawCut workflow service at `/developer/video_ad/*` with the OAuth developer Bearer token. Response shell: `{ code, msg, data }` — the CLI unwraps `data` for you. Only `detail` returns the `outputs` map; every `run`/`set` response must be followed by a `detail` read.

## Command surface

### Project

```bash
cawcut ad-video create --url <url> [--name <name>] [--category <code>] [--json]
cawcut ad-video detail <id> [--json]
cawcut ad-video options [--video-ad-id <id>] [--language <code>] [--json]
```

- `create` → `POST /developer/video_ad` with `{ name?, category?, product_info?: { url } }`. All fields are optional (an empty draft is allowed); `product_info` is omitted entirely when no `--url` is given. Omit `--name` — the backend auto-names the project from the product info after analysis. Omitting `--category` lets the backend auto-detect the category after analysis.
- `detail` → `GET /developer/video_ad/{id}`. The single polling point. Output keys: `generated_marketing_messages`, `storyboard_plan`, `storyboard_sketch`, `storyboard_image`, `final_video` / `voiceover_final_video` / `talking_video`; each has `status` (`pending|running|succeeded|failed`), `value`, and possibly `need_regenerate: true`. Top level also carries `estimated_running_ms` while a stage is in flight — the server's own wall-clock estimate, and the only figure to quote to a user as an expected duration.
- `options` aggregates `GET /video-settings/options` (`video_settings`, including `video_models`), `GET /supported-platforms`, `GET /storyboard/options` (`storyboard`), `GET /promotional-info/options` (`promotional_info`). `--video-ad-id` scopes all three project-aware sections — the video-settings section included: its language default is derived from the project's crawled product text, so leaving the id off silently falls back to a global default.


### Product (stage ①)

```bash
cawcut ad-video analyze run <id> --url <url> [--wait] [--wait-timeout <s>] [--wait-interval <s>] [--json]
cawcut ad-video analyze cancel <id> [--json]
cawcut ad-video product set <id> [flags…] [--json]
```

`--url` is required for `analyze run` (the API validates `url` as required in the request body); pass the same product URL used at `create`.

`product set` flags (PATCH `/developer/video_ad/{id}/product`, body `product_info`):

**The API replaces `product_info` wholesale; the CLI does not.** `product set` reads the project first and merges the flags onto what is persisted, so a save that only names a field leaves every other field alone — sending the flags alone would erase the description, the images and the selling points that were already there. Two consequences worth knowing:

- A flag that passes an image list replaces that list wholesale, which is also how an image is removed. The replaced list drops its own selection (`selected_image_ids` / `selected_primary_image_id` / `selected_logo_image_id`), so the backend falls back to its defaults: every candidate for `--asset`, the first candidate for logo and primary. `--primary-image` accepts exactly one ref; when that ref was already an additional asset, the CLI removes it from `images` and `selected_image_ids` in the same PATCH so it is moved rather than duplicated. Carrying a stale selection across a swap would resolve to "nothing selected" — normalization drops refs that are no longer candidates — and starve the later stages.
- Because the merge rebuilds `selected_image_ids` from the per-image `selected` flags `detail` returns, you never re-send images by hand. Sent as refs, `asset_id` preferred: an image with no asset_id falls back to its pre-signed url.

`<ref>` is an `asset_id` (preferred), a pre-signed URL, or a local file path. Passing a *downloaded* file instead of its `asset_id` uploads a duplicate input asset, which the backend treats as a brand-new third-party upload and runs through material compliance detection.

| Flag | product_info field | Notes |
|------|--------------------|-------|
| `--product-name <name>` | `name` | Product name (not the project title) |
| `--description <text>` | `description` | |
| `--selling-point <p>…` | `selling_points[]` | Repeatable; replaces the full list (max 20 × 200 chars) |
| `--clear-selling-points` | `selling_points[]` | Empties the list. An empty list is an explicit user decision (it stops the platform's own fallbacks from reviving the old points), so it is a flag and not the absence of one |
| `--logo <ref>` | `logo_images: [<ref>]` | asset_id or URL for an existing image; a local path uploads a new asset |
| `--primary-image <ref>` | `primary_images[]` | Exactly one hero image; same `<ref>` rules, replaced wholesale and moved out of `images[]` when it already exists there |
| `--asset <ref>…` | `images[]` | Repeatable, additional product assets; same `<ref>` rules, replaced wholesale |
| `--target-audience <text>` | `target_audience` | Max 120 chars |
| `--promo-enabled <true\|false>` | `promotional_info.enabled` | |
| `--promo-original-price <p>` | `promotional_info.original_price` | |
| `--promo-price <p>` | `promotional_info.promo_price` | |
| `--promo-detail <d>…` | `promotional_info.promotion_details[]` | Repeatable; tag values from `options` |

Any `product set` invalidates all downstream generated artifacts and rolls the project back to the config stage — re-run Config → Idea → Storyboard → Video afterwards.

### Config (stage ②)

```bash
cawcut ad-video config set <id> [--publish-to <p>] [--language <l>] [--aspect-ratio <r>] \
  [--resolution <res>] [--duration-seconds <n>] [--video-type <t>] [--video-model <m>] \
  [--storyboard-style <s>] [--auto-captions <true|false>] [--json]
```

PATCH `/developer/video_ad/{id}/stage/config` with `video_settings`. All values come from `ad-video options` → `video_settings`. **Aspect ratio is bound to the platform**: each `publish_to` option carries `default_aspect_ratio` — apply it automatically when the platform is picked (the web portal behaves the same way; it has no ratio selector). Changing creative settings (video_type, storyboard_style, duration, language, publish_to) clears downstream artifacts; changing only render params (resolution, aspect_ratio, auto_captions, video_model) keeps Idea/Storyboard and flags `final_video` with `need_regenerate: true`. A language change therefore removes the prior Idea candidates/selection and storyboard; it must be followed by a fresh `idea run`, never a prompt to reuse the prior Idea.

**`--video-model`** writes `video_settings.video_model` and must be one of `video-settings/options.video_models[].value`. The list is actor-scoped: an external account sees the Seedance family, an internal account sees the full AD Video catalog, so never hardcode a model name. The chosen model's `supported_resolutions` is the legal resolution set — the server rejects a mismatch, so clamp `--resolution` to it rather than letting the save fail.

**`--auto-captions`** only has an effect for `product_with_voiceover` / `talking_video`; a `product_showcase` render has no voice track to caption. The web portal forces the value to `false` for that type — do the same rather than asking the user a question with no consequence.


### Idea (stage ③)

```bash
cawcut ad-video idea run <id> [--wait] [--json]         # POST …/stage/marketing_message/run
cawcut ad-video idea select <id> --message-id <mm-N> [--title <t>] [--content <c>] [--json]
cawcut ad-video idea select <id> --custom "<text>" [--json]
cawcut ad-video idea regenerate <id> [--wait] [--json]  # full re-roll; clears selection
cawcut ad-video idea load-more <id> [--json]            # next page of candidates; no LLM call
```

- Candidates: `detail` → `outputs.generated_marketing_messages.value.marketing_messages[]` with `pagination` (`total`, `visible`, `page_size`, `has_more`). One generation run produces up to 16; only `visible` are revealed so far, so **a single read is not the whole set** — the skill reveals up to eight (two pages) before asking, and stops there even when `has_more` is still true. `has_more: false` means everything the project holds is already visible.
- Selection state: `value.selection` (present only after `idea select`).
- Custom ideas (`--custom`) should stay within 60–10000 chars — the web's contract; the API itself only rejects empty text. It maps directly to the same payload as the portal custom path: `{ custom_content: <text>, is_custom: true }`. Use it for whatever idea text was produced (including a title or content); do not wrap it or submit it as a generated-candidate selection.
- `idea select` also readies the storyboard pipeline (free), which unblocks storyboard quotes.

### Storyboard (stage ④)

```bash
cawcut ad-video storyboard run <id> [--style-id <s>] [--force] [--wait] [--json]
cawcut ad-video storyboard set <id> --base-revision <n> (--plan <json> | --plan-file <path>) \
  [--update-prompts --prompt-target <shot_id>:<shot_prompt|video_prompt>[,...] …] [--skip-precheck] [--json]
cawcut ad-video image quote <id> --generation-type <hand_drawn|photo_realistic> [--json]
cawcut ad-video image run <id> [--confirmation-token <t>] [--generation-type <t>] [--force] [--wait] [--download] [--json]
```

- `storyboard run` → poll `outputs.storyboard_plan`. **Without `--force` the call is a no-op when the stage inputs and style are unchanged** — the server fingerprints the run and reuses the existing result, so re-running an edited script does not regenerate it. `--force` (`force: true` in the body) skips that check and re-runs the Script node, which means the script LLM writes a new script and any saved edit is gone. It also re-runs the character/scene prep (`RunUntilLabel` targets the script node, so upstream Analyzer caches survive), and it is the only way to get a platform-written script back. The saved plan lives at `value` (ScriptResult v1) with a read-only optimistic-lock `value.revision`; editing limits are in `outputs.storyboard_plan.constraints` — a sibling of `value`, not a property of it — (`duration.min_seconds`/`max_seconds` plus `max_seconds_formula`, per-field `required`/`max_characters`) — honor them, and keep the total shot duration ≤ the configured `duration_seconds` (the web enforces the same).
- Display surface (FE parity): the web portal's expanded script shows `shot_no`, `duration`, `shot_type`, `shot_description`, `dialogue` (labeled Voiceover), `camera`, `light`, `sfx`, `shot_prompt`, `video_prompt`; the Voiceover column is hidden for `product_showcase`. Per-shot `shot_prompt_status` / `video_prompt_status` tell you whether the prompt text is current — a non-`succeeded` value means it is still being regenerated or is stale.
- Editable per-shot fields (FE parity): `duration`, `shot_type`, `shot_description`, `dialogue`/`voiceover`, `camera`, `light`, `sfx`, `shot_prompt`, `video_prompt`. Shots can never be added or removed.
- `storyboard set` submits the **full** plan (no diffs) with `base_revision` from the latest detail read. `409` = revision mismatch → re-read detail, re-apply, retry.
- **`storyboard set` checks the plan before sending it.** The server validates the whole script on save and reports a failure as one generic error, so the CLI re-reads `detail` and runs the same contract locally (limits taken from `outputs.storyboard_plan.constraints`, which are the server's own numbers), plus the `base_revision` check. A violation exits 1 naming the shot and field — nothing was sent, so edit the plan and save again; the shot at fault need not be the one you changed. The server keeps the last word: `--skip-precheck` sends the plan unchecked, and a rejection that still gets through prints the server's `error_msg` as the first line.
- `--update-prompts` + `--prompt-target` map to the API's `update_prompts`/`prompt_targets`: after saving, the backend asynchronously re-runs the Script Prompt Generator for the targeted shot fields — poll `outputs.storyboard_plan.prompt_status` to `succeeded`; a succeeded `storyboard_plan.status` is only the plan state and must not be interpreted as ready prompts. Target mapping (same as the web): changed `shot_type`/`shot_description` → `shot_prompt`; changed `duration`/`shot_type`/`shot_description`/`dialogue`/`camera`/`light`/`sfx` → `video_prompt`.
- `image quote`/`image run`: `generation_type` and `confirmation_token` travel as query params. When the quote used an explicit `--generation-type`, the run must repeat it.
- Pass structure: `hand_drawn_then_photo` = `hand_drawn` (→ `storyboard_sketch`) then, after user continue, `photo_realistic` (→ `storyboard_image`). `photo_realistic_only` = one `photo_realistic` run. The backend never auto-starts the second pass.

### Video (stage ⑤)

```bash
cawcut ad-video video quote <id> [--json]
cawcut ad-video video run <id> [--confirmation-token <t>] [--force] [--wait] [--download] [--json]
```

- Quote covers only the final-video node for the configured video type (`final_video` / `voiceover_final_video` / `talking_video`).
- Requires `storyboard_image` succeeded. Poll `detail` for the video label matching the video type (or any of the three) reaching `succeeded`.
- `--force` re-renders even when inputs are unchanged.

## Shared flags

| Flag | Meaning |
|------|---------|
| `--wait` | Poll `detail` until the stage's output reaches a terminal state |
| `--wait-timeout <s>` | Max poll time (default 600) |
| `--wait-interval <s>` | Poll interval (default 3) |
| `--download [dir]` | Download result files (default `~/Downloads`; `tmp` = OS temp) |
| `--json` | Machine-readable output |

Skills poll via the platform-specific bundled `scripts/poll.sh` / `scripts/poll.ps1` (never hand-rolled loops), download media via `scripts/download_media.sh` / `scripts/download_media.ps1`, and write a script edit through `scripts/script_plan.sh` / `scripts/script_plan.ps1` (working copy, edits merge, review table — see [`script-editing.md`](./script-editing.md)); `--wait` / `--download` are for scripts and one-shot manual runs.

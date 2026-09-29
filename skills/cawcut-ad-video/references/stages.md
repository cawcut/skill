# Ad Video — stage semantics & invalidation matrix

> Boundary: the CLI/skill never manages scheduling. Stage progression is entirely server-side behind the `/developer/video_ad/*` API. The skill only calls stage run/save endpoints and polls `detail` — never reason about how the backend decides what runs next.

## Stage machine

Top-level `detail.status`: `draft` → `running` → `stage_completed` (per stage) → `succeeded` (final video done) | `failed`.
`detail.current_stage`: `product` → `config` → `marketing_message` (Idea) → `storyboard` → `video`.

| Stage | Trigger | Poll target (output key) | Done when |
|-------|---------|--------------------------|-----------|
| ① Product | `analyze run` | top-level `status` | `stage_completed` |
| ③ Idea | `idea run` / `idea regenerate` | `generated_marketing_messages` | `succeeded` |
| ④ Script | `storyboard run` | `storyboard_plan` | `succeeded` |
| ④ Sketch | `image run --generation-type hand_drawn` | `storyboard_sketch` | `succeeded` |
| ④ Panels | `image run --generation-type photo_realistic` | `storyboard_image` | `succeeded` |
| ⑤ Video | `video run` | `final_video` / `voiceover_final_video` / `talking_video` | `succeeded` |

Config (`config set`) is synchronous — no polling.

**Idea candidates are paginated within a stage, not per stage.** A run generates up to 16 candidates; `detail` reveals 4 at a time (`pagination.page_size`), and `load_more` grows the revealed count cumulatively. `pagination.visible` is the number revealed so far, `total` the number the project holds. Treat `has_more` as the signal that more are available — the skill caps what it reveals at eight (two pages) before asking the user to pick.

**Long stages notify — through the host, not the shell.** `storyboard_plan`, `storyboard_sketch`, `storyboard_image` and the final video take minutes rather than seconds. The platform-matched `scripts/poll.sh` / `scripts/poll.ps1` raises no notifications of its own; the agent calls the host's notification tool (in Claude Code, `PushNotification`) once when the stage lands, and a shell-level toast is not a substitute for it. Tell the user they can step away before starting one — quoting `estimated_running_ms` when the server gives one, and "a few minutes" when it does not: those stages run on the order of minutes, so an estimate that hedges upward (let alone the polling deadline) is the wrong shape of answer.

## Product analysis result

After stage ① completes, present `detail.product_info` to the user **verbatim** — all populated fields (`name`, `description`, `selling_points[]`, `target_audience`, `brand_style`, `promotional_info`, `source_platform`, `category`), original text, no summarizing or translating. Image fields (`logo`, `logo_images[]`, `primary_images[]`, `images[]`) carry pre-signed `url`/`preview_url` — download them with platform-matched `scripts/download_media.sh` / `scripts/download_media.ps1 --kind product` and present them per the skill's Stage ① step 4 (logo/primary inline; additional images one-by-one capped at 9, overflow pointed at the `product/` folder). Corrections go through `product set` (which invalidates downstream stages) — that is the intended trade-off; confirm with the user before overwriting. Re-send kept images by their `asset_id` from `detail`, never as the downloaded files: the image fields are replaced wholesale, so a local path both duplicates the asset and loses its provenance.

**Material rights on the developer path.** `/developer/assets` uploads skip the material compliance pipeline and land as `approved` — there is no check → attest step to walk through, unlike the web portal. The developer-token holder carries the rights responsibility for what they upload, so state that plainly when the user supplies their own image. Crawler-extracted product images were never subject to the check in the first place.

## Invalidation matrix (what a mutation does to downstream artifacts)

| Mutation | Effect |
|----------|--------|
| `product set` (any field) | Clears all generated data (analysis, ideas, storyboard, video), rolls back to `config` stage |
| `config set` — creative fields (video_type, storyboard_style, language, duration, publish_to) | Clears downstream content. The old Idea is unavailable and must never be offered as reusable; run Stage ③ again, poll its new candidates, select one, then generate a storyboard. |
| `config set` — render-only fields (resolution, aspect_ratio, auto_captions, video_model) | Keeps Idea/Storyboard; `final_video` retained with `need_regenerate: true` |
| `idea select` / `idea regenerate` | Clears storyboard/video artifacts |
| `storyboard set` (edit plan) | Invalidates sketch/panels/final video; edited shots get prompts recomputed when saved with `update_prompts`+`prompt_targets` (poll `storyboard_plan.prompt_status`) |

## `need_regenerate` protocol

- A retained-but-stale output keeps `status: "succeeded"` plus `need_regenerate: true`. It is a preview of an outdated configuration, never a deliverable.
- Running `image run` or `video run` while an upstream output carries `need_regenerate: true` is rejected: `VIDEO_AD_NEEDS_REGENERATION` (`308000414`).
- Skill behavior: after every mutation, re-read `detail` and distinguish cleared outputs from retained-but-stale ones. Only the latter have `need_regenerate: true`: collect those flagged outputs, summarize once, AskUserQuestion once, then re-run the affected stages in pipeline order. For a cleared creative-config downstream pipeline — especially after a language change — do not ask about reuse; start a new Stage ③ Idea generation. Never interleave edits and runs.

## Credit quotes

- `image quote` / `video quote` return `{ estimated_credits, generation_type?, confirmation_token, expires_at, target_label }`, and the CLI adds the caller's balance: `credits_balance`, `credits_shortfall`, `credits_sufficient` (or `credits_balance_error` when that lookup failed — never fatal).
- The token binds user + inputs + target node and **expires 5 minutes** after issue. Any edit to quoted inputs also invalidates it.
- Sequence: quote → user confirms credits → run immediately. Token error on run → re-quote → re-confirm → run again.
- Quotes only cover the target node's own cost, never upstream stages.
- **Balance is the client's problem, by design.** The backend enforces no balance gate on any quote or run path, so an over-budget run is not rejected up front — it fails later, after the user has waited. Compare `estimated_credits` against `credits_balance` *before* the confirmation question and route the user to top up when they are short. The web portal does the same comparison client-side.

## Stage-run estimates

- `detail.estimated_running_ms` (milliseconds) is the server's wall-clock estimate for the stage currently running; the portal renders it verbatim as "This may take about N…".
- It is computed per request from the model and its parameters, with a coarse fallback, so it can be approximate — but it is the **only** sanctioned figure to quote. Absent or zero means "no figure from the server": give the order of magnitude instead ("a few minutes" — these stages are minutes-scale), never the polling timeout as if it were an expected duration, and never an upward hedge.

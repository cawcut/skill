---
version: 0.10.0
name: cawcut-ad-video
description: >-
  Use when making an ad or ad video, given a product-page URL alone, /cawcut-ad-video, a known Ad Video project, or a handoff from cawcut-workflow. NOT for ad scripts, scraping product info only or an ad on a canvas (cawcut-workflow).
argument-hint: "[product URL or product description]"
allowed-tools: Bash AskUserQuestion AskQuestion PushNotification
---

# CawCut Ad Video

Start here for an ad or ad video request, a product-page URL with no other
ask, an explicit invocation, a known Ad Video project, or an accepted Ad Video
wizard handoff from `cawcut-workflow`. Carry its product URL,
sourced claims, media/asset IDs, target duration, style, creative decisions and
budget preferences into setup. Reuse supplied inputs and ask only for unresolved
settings; wizard selection alone does not authorize a paid run.

A URL with a scrape-only ask ("抓一下商品信息") and other non-ad production
goals go to `cawcut-workflow`. An explicit flexible canvas request or ordinary
workflow follow-up stays with workflow, even when its nodes include Product,
Script and Storyboard. Switching from a canvas to this wizard creates a separate
project; preserve the old identity and do not imply automatic graph conversion.

Create a complete product ad video through the 5-stage AD Video wizard: **Product → Config → Idea → Storyboard → Video**. Each stage maps to `cawcut ad-video` commands against the developer API. Full command flag tables live in `references/api.md`; stage semantics and the invalidation matrix live in `references/stages.md`; authoring a script edit lives in `references/script-editing.md`; error recovery lives in `references/troubleshooting.md`. `Read` them at `<base_dir>/references/<file>.md` using the base directory printed at the top of this skill body — do not `find`/`grep` for them.

**Reply language.** All live replies — prose, status updates, `AskUserQuestion` / `AskQuestion` questions and option labels — follow the user's language for that turn. This is judged from the user's actual chat message content for that turn — not from whether the `Skill` tool call itself carried an `args` parameter, which is an unrelated, optional pass-through field. This includes implicit triggers: if the skill was invoked because the user's message matched a trigger phrase (e.g. "广告视频", "商品广告", "make an ad for …") rather than the literal `/cawcut-ad-video` command, that trigger phrase **is** the user's chat message content for the turn — reply in its language from the very first response, including when asking for the missing product URL. Only default to English when the invocation carries no language signal at all (e.g. literally just `/cawcut-ad-video` alone with no other text); once the user adds a real request in another language, follow that language for the rest of the session. Keep CLI commands/flags, JSON keys, URLs, and raw error codes in their original form regardless of reply language, and never paste raw English CLI output as the user-facing answer — summarize it in `reply_language`.

For media inputs run `cawcut asset upload` once and keep the returned `asset_id`s; reuse them instead of uploading again. Retain IDs and returned URLs from App/Product/stage results before later processing.

## Step 0 — Bootstrap

### Choose the login mode by execution environment

Choose by where commands actually run. On the user's own computer, run `cawcut auth login --browser --json`; the CLI opens the browser and waits for approval. In a remote environment, VM, or container without access to the user's browser, run `cawcut auth login --device-auth --json` and send the user `authorization_url` to open and approve on their own computer. Both modes support JSON; needing structured output is not a reason to choose device authorization. Agent names, non-TTY shells, and localhost URLs alone do not establish where commands run. Use the known execution context and explicit mode flags to override CLI auto-detection.

For device login, then run `cawcut auth login --complete --wait --timeout 60 --json`. If your tool has a short execution timeout, use single `--complete --json` calls instead, following `next_poll_after_seconds`. After device login is interrupted or returns `wait_timeout`, resume the saved current request rather than creating a new link. Browser login uses the legacy loopback callback; if interrupted, restart `cawcut auth login --browser --json` instead of using `--complete`. `status=pending` is not authentication success. Only retry the original operation after `status=authenticated`. Denial/expiry ends this request; do not silently create an endless sequence of authorization links. Never ask for a password, token, or a code copied back from the web page.


Run bootstrap as a silent guardrail, not as a user-facing phase.

1. **At most once per AI session.** If any `cawcut` command has already succeeded in this AI session, skip all bootstrap checks and continue.
2. **Use only one explicit check command:** `cawcut upgrade check --json`.
   - If `"update_available": true`, **run `cawcut upgrade` yourself in the host shell** (do not ask the user to type it). After it succeeds, continue this skill from Step 1.
   - If `"ahead_of_registry": true`, continue without upgrading.
   - If `cawcut` is missing, ask the user to install it: `npm install -g @ubnt/cawcut`. Then continue bootstrap.
   - For other check failures, continue and mention the warning only if a later CLI command fails.
3. Do **not** print "bootstrap checks passed" — move directly to Step 1.
4. Let the first real command validate auth. If it fails with token/auth errors (including `Token expired`), follow the login steps above. Use the mode appropriate to the execution environment, and retry the failed command once only after `status=authenticated`. Run the CLI commands yourself; the user only approves in their browser.
5. **Structured user-ask tool (check every session).** In **Claude Code**, use **`AskUserQuestion`** for every enumerable choice; in **Cursor**, use **`AskQuestion`**. If either is available, you **must** use it for all enumerable decisions in this skill — platform, resolution, duration, video type, storyboard style, language, idea candidate, credit confirmation — **including when the candidate list is longer than the popup holds**: a long list still opens the tool, with its leading entries as the options and the full numbered list beside them so any later entry can be typed back (see Interactive selection).

## Wizard overview

```
① Product    create → analyze run → poll → review/confirm analysis
② Config     options → pick settings → config set
③ Idea       idea run → poll → pick candidate (or custom) → idea select
④ Storyboard storyboard run → poll → (optional edit / regenerate) → image quote → confirm → image run (×2 if hand-drawn)
⑤ Video      video quote → confirm → video run → poll → download
```

One project = one `video_ad_id`. Every long stage is triggered without `--wait`, then polled with the bundled script (see Polling). **`cawcut ad-video detail <id> --json` is the single polling point** — only it returns the `outputs` map.

### Bundled-script runner

Use `cawcut` CLI commands directly for project operations and detail inspection. Choose bundled helpers for the host platform. Windows helpers require PowerShell and the installed `cawcut` CLI, not Python, jq, bash, or external curl; do not ask Windows users to install those tools for this skill. macOS/Linux `.sh` helpers require jq; neither platform uses Python.

- macOS/Linux: `bash <base_dir>/scripts/<name>.sh …`
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File "<base_dir>\scripts\<name>.ps1" …`

The four helpers (`poll`, `script_plan`, `storyboard_review`, `download_media`) have equivalent `.sh` and `.ps1` implementations. Use the matching extension and platform-specific flags throughout one run; for example, `--kind video` on bash is `-Kind video` on PowerShell.

## Stage ① — Product

1. Collect the product URL (Amazon/Shopify/official page all work). If the user didn't give one, ask in plain text (open-ended). Do NOT ask for a project name — the backend auto-names the project from the product info after analysis/export.
2. `cawcut ad-video create --url "<url>" --json` → capture `id`. `--url` is optional at create (an empty draft is allowed), but pass it whenever the user gave one — `analyze run` requires it later regardless. `--category` is optional; omit it and the backend auto-detects after analysis. Only pass `--name` if the user explicitly asked for a specific title.
3. `cawcut ad-video analyze run <id> --url "<the product URL from step 1>" --json` (no `--wait`; the API requires `url` in the body), then poll with the platform runner: `poll.sh <id> '.status' stage_completed 600 15` on macOS/Linux, or `poll.ps1 <id> '.status' stage_completed 600 15` on Windows.
4. Read `detail <id> --json` and present the analysis result:
   - **Product info verbatim** — every populated `product_info` field: `name`, `description`, `selling_points[]` (each in full, numbered), `target_audience`, `brand_style`, `promotional_info`, `source_platform`, `category`. Do not summarize, truncate, or translate the product content itself — it is the user's marketing copy and must be shown as returned; only your surrounding labels and prose follow reply_language.
   - **Product images** — first download them with the platform-specific `download_media` helper: `<id> --kind product`. Then present by category (labels in reply_language):
     - **Logo** (`logo_images`) and **Primary images** (`primary_images`): preview each inline via the host's send-file tool (e.g. Claude's `SendUserFile`) with the local path just downloaded (e.g. `~/Downloads/ad-video-<name>/product/logo-1.jpg`, `primary-1.jpg`) — a markdown link only renders as a clickable line, not a visible image.
     - **Additional product images** (`images[]`): if inline previews are supported, list them **one by one**, each labeled `Product Image #n` with the image sent inline; **cap at the first 9** — if there are more, say so (e.g. `…and N–9 more`) and tell the user the rest are in the `<dest>/product/` folder. If inline previews are not supported, list them as a table of local paths (`#` + path) and point to the same folder.
     - No `asset_id` column in either form — the local path is a **preview** reference only. These files exist so the user can see the images; never hand them back to the CLI.
   Then ask the user to confirm or correct via AskUserQuestion:
   - `✅ Looks good` → continue to Stage ②
   - `✏️ Edit product info` → collect the changes and pass **only those fields** to `cawcut ad-video product set <id> …`: the command reads the project first and carries every field you did not pass forward. (The API replaces `product_info` wholesale, so a bare `--product-name` would otherwise erase the description, the images and the selling points.) Re-run `analyze run` afterwards if the URL or the product changed materially.
     - **An image list is replaced by passing it**, so `--logo` / `--primary-image` / `--asset` take the complete kept list — that is also how an image is removed. A replaced list drops its own selection, and the backend falls back to its defaults (every candidate for `--asset`, the first candidate for logo/primary). Never re-send the files you downloaded: the persisted refs already come back as `asset_id`s.
     - Pass a local path only for an image the user supplies from outside the project; the CLI uploads it as a brand-new asset (7-day TTL).
     - `--description ""` clears the description and `--clear-selling-points` empties the selling points — an empty list is a real state, not "unset".
5. If the user wants to abort a running analysis: `cawcut ad-video analyze cancel <id>`.

**Material rights.** When the user supplies their own image, relay the `notice` returned by `asset upload` once. Images already in the project (crawler-extracted product images) need no notice.

## Stage ② — Config (all options are runtime-fetched, never hardcoded)

1. `cawcut ad-video options --video-ad-id <id> --json` → read `video_settings` (publish_to, languages, aspect_ratios, resolutions, duration_ranges, video_types, storyboard_styles, video_models, defaults).
2. Ask the axes in this order — **video type first**, because it decides both whether captions are a question at all and which model/resolution combinations are legal.
   - **video type** — one option per entry in `video_types`.
   - **video model** — **only when `video_models` is non-empty.** Candidates are `video_models[].value` in the CLI's order (default `defaults.video_model` first); keep that order. The table that carries the list has three columns beyond `#`: **the model, its `supported_resolutions`, and a default mark on `defaults.video_model`** — the resolutions belong in view because picking a model is what decides which ones stay legal on the next axis. With exactly one candidate, state it in prose and carry on (one option is not a choice); with none, skip the axis entirely.
   - **resolution** — default `defaults.resolution`, then **clamp to the chosen model's `supported_resolutions`** (the same list the server validates against). Never offer a resolution the model does not support: `config set` rejects it. When no model was chosen, offer the full `resolutions` list.
   - **auto captions** — **only for `product_with_voiceover` and `talking_video`.** Captions are burned in from the voiceover/dialogue track, so `product_showcase` has nothing to caption; do not ask, and pass `--auto-captions false` explicitly (mirrors the web portal, which forces the value off for that type).
   - **platform** — show each option's `default_aspect_ratio` in its description (e.g. `TikTok — 9:16`), **language**, **duration**, **storyboard style** (explain: hand-drawn adds a sketch pass before photo-realistic panels).
   - **Aspect ratio is NOT a question.** It is bound to the platform (mirrors the web portal, which has no ratio selector): take the picked `publish_to` option's `default_aspect_ratio` automatically. Never ask for a ratio separately; only if the user explicitly overrides should you deviate from the platform default.

   Batch the axes into **one** AskUserQuestion call — one question per axis, at most four questions per call. A long axis (**platform**, **language**, **video model**) follows Interactive selection's overflow shape: the full list is a numbered table in the message body — `#` plus what that axis actually carries: a platform's label with its `default_aspect_ratio`, a language's label, a model's label with its `supported_resolutions` and default mark. The question itself is one short sentence, the popup holds the leading entries as options labelled with their number, and the entries past them are answered by number or name in the free-text field. Each axis keeps its own table and its own numbering — the answer goes into that axis's own field, so never ask for two numbers at once (`1 + 10`).
3. `cawcut ad-video config set <id> --publish-to … --language … --aspect-ratio <the platform's default_aspect_ratio> --resolution … --duration-seconds … --video-type … --video-model … --storyboard-style … --auto-captions … --json`

`video_model` is a real cost lever — say so when offering it (a cheaper model may be available), but never present a model the endpoint did not return.

## Stage ③ — Idea

1. `cawcut ad-video idea run <id> --json`, poll until `outputs.generated_marketing_messages.status === "succeeded"`.
2. **Reveal up to eight, then stop.** One run generates up to 16 candidates but `detail` hands back one page (4) at a time, so a fresh read shows only the first four. Read `outputs.generated_marketing_messages`, and call `cawcut ad-video idea load-more <id> --json` (re-reading `detail` each time) until **eight are visible** or `has_more === false` — whichever comes first:
   - `load-more` only reveals already-generated candidates — no LLM call, no credit cost.
   - **Eight is the ceiling, not a target.** A project holding fewer shows fewer; once eight are visible you stop revealing even if `has_more` is still true. This flow has no "one more batch" step.
   - State the number you are showing, and never imply the set is everything the project holds when it is not.
3. Present them **as a table, in full, verbatim** — one row per candidate: `#`, title, content. No summarizing, no paraphrasing, no truncating, no translating: this is the user's marketing copy and they are choosing between the whole set. Lead with the count (e.g. "Showing 8 candidates:"). The `#` column is the popup's index — this table is what any number the popup could not hold is typed against.
4. **One decision, one question.** The choice is a **single** AskUserQuestion — never a candidate question followed by a second one asking what to do with that answer. Four options, in this order:
   - `1. <title>`, `2. <title>`, `3. <title>` — the first three candidates, each labelled with its number
   - `✏️ Write my own` → submit the idea text the user or agent produced with `idea select <id> --custom "<text>"` (60–10000 chars, mirroring the web custom-idea limits). This follows the portal custom path: the CLI sends that text as `custom_content` with `is_custom: true`; do not turn it into a generated-candidate selection or add a title wrapper.
   - a candidate from the fourth to the eighth is selected by typing **its number or its title** into the free-text field; name that in the question's own text, in `reply_language`, so the user answers from a set the question stated rather than guessing
5. On a pick: `cawcut ad-video idea select <id> --message-id <mm-N> --title "<title>" --content "<content>" --json`. Offer light edits to title/content before submitting.
6. **A fresh batch is user-initiated only.** `idea regenerate` is not a menu entry: when the user asks for one in their own words ("换一批" / "regenerate"), run `cawcut ad-video idea regenerate <id> --json` + poll — it clears the current selection, so warn first — then re-reveal (step 2) and re-ask (step 4).

## Stage ④ — Storyboard

Order mirrors the web portal: **entities → fee → character → location → script → images (visual direction sits inside the image step).** Read `<base_dir>/references/storyboard-stage.md` before the first edit; entity commands are in `<base_dir>/references/character-scene.md`, script edits in `<base_dir>/references/script-editing.md`. Legacy projects without character/scene capability skip steps 1–4 and the visual-direction question and keep the original flow.

1. **Which entities exist?** After the Idea is confirmed: `character estimate <id> --wait --json`. Tell the user whether the script needs a character, a scene, both or neither (`character.needed` / `location.needed`). Neither → the queue holds only the script.
2. **Fee prompt (mandatory).** Show `estimated_credits` (0 = free) and ask via AskUserQuestion: `✅ Confirm & generate` / `⏸ Not now`. Only then `storyboard run <id> --confirmation-token <token> --json` — it starts the character/scene images and charges credits. Never run it before the answer.
3. **Review queue — let the CLI pick the item.** Run the `storyboard_review` script (wait → images → script table), then `cawcut ad-video review next <id> --json` and show **only** the item it names, one per turn: `character` → `location` → `script`. `wait` → keep polling; `done` → step 4. After the user approves an item run `review approve <id> --item <item>`, then `review next` again. Approvals are tied to what was shown: a regenerated script or image (new Idea, new prompt, edit) comes back up for review, and `image quote/run` is refused until `review next` says `done`.
   - **character / location:** name, image, **image prompt** (`entities[].names` / `prompts`), status. Ask `✅ This character works` / `📝 Regenerate from a new prompt` (scene: `✅ This scene works`). A new prompt runs the procedure in `references/storyboard-stage.md`, then show the new image and ask again. Own-image upload and voice choice are **not open yet**: never offer them.
   - **script:** show `script_table` (never `shot_prompt` / `video_prompt`) with the literal `portal_url` (`ad-video url <id> --json`). Ask `✅ Looks good` / `✏️ Work on the script` / `🔁 Regenerate the script`. Edit and regenerate follow `references/script-editing.md`; **regenerating discards every edit — warn first.**
4. **Images — let the CLI say what is next.** Run `cawcut ad-video image next <id> --json` and do exactly its `next_step`; run it again after every pass or answer.
   - `sketch` → `image quote --generation-type hand_drawn` → confirm credits → `image run` (Quote timing), poll, preview the sketch. Then ask `✅ Continue` / `✏️ Edit script`.
   - `visual_direction` → ask the custom-prompt question (below). `image quote/run --generation-type photo_realistic` is **refused by the CLI** until it is answered.
   - `photo` → `image quote --generation-type photo_realistic` → confirm → `image run`, poll with the 3600 deadline, preview via `download_media <id> --kind storyboard`.
   - `done` → Stage ⑤.

   **Visual direction question** (one custom prompt styles the photo-realistic storyboard and the final video; asked once, right before the photo-realistic pass — after the sketch when there is one, otherwise straight after the script). Show the saved text (`instruction`) and ask: `✅ No extra direction` → `instruction confirm <id>` / `🎨 Add or change visual direction` → `instruction set` (`references/storyboard-stage.md`). **If images or video already exist, saving marks them stale (`need_regenerate`) — warn and get consent first.**

**Never end a turn without a pending question or a running poll** — after generation finishes, show the next item in the order above and ask. A failed entity (`next_step: fix_failed`) is shown, never skipped; retry only with consent.

## Stage ⑤ — Video

1. `cawcut ad-video video quote <id> --json` → AskUserQuestion confirm credits → immediately `cawcut ad-video video run <id> --confirmation-token <token> --json` (add `--force` only when the user explicitly re-renders an unchanged result).
2. Poll until one of `final_video` / `voiceover_final_video` / `talking_video` is `succeeded` — the 3600 deadline from the polling table.
3. On success: `cawcut ad-video video deliver <id> --json` downloads the video into the project folder and returns `report` (local path + the Portal link as a ready-made markdown link), `local_path` and `portal_url`.
4. **Send the hand-over first — a file sent on its own is not the report.** One text message that starts with `report`, with the markdown link kept on its own line and the label in `reply_language`; never mention the Portal without the URL in the same message. The result URL is not needed. Only after it is sent, **hand off unconditionally to `cawcut-vn`** with `local_path` — no VN menu, no `cawcut vn` commands of your own (decide-once: the receiving skill owns the VN decision and you never re-check).

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

## Invalidation semantics (mandatory — mirrors the web portal)

After **every** mutation (`product set`, `config set`, `idea select`, `storyboard set`):

1. Immediately run `cawcut ad-video detail <id> --json`. First distinguish **cleared** artifacts from **retained-but-stale** artifacts; never infer either from the project history.
   - A mutation to any creative config field — `--duration-seconds`, `--language`, `--video-type`, `--storyboard-style`, or `--publish-to` — clears downstream content. If `outputs.generated_marketing_messages` no longer has a usable succeeded `value` / `selection`, the previous Idea does not exist in the current project state. **Do not ask whether to reuse, keep, or continue using that Idea; do not offer it as an option.** Continue at Stage ③ with `cawcut ad-video idea run <id>`, poll it to success, select a fresh Idea, then generate a new storyboard.
   - Only an output that remains present with `status: "succeeded"` and `need_regenerate === true` is retained-but-stale and eligible for the regeneration/later decision. A cleared output is neither stale nor reusable.
2. Collect every retained-but-stale `outputs.<key>` with `need_regenerate === true`. If any exist: list the affected artifacts to the user in one message, then a **single** AskUserQuestion:
   - `🔄 Regenerate affected` → re-run the affected stages in pipeline order (`storyboard run` → `image quote/run` → `video quote/run`), quoting + confirming credits again per generation stage
   - `⏸ Later` → continue without regenerating; note the stale artifacts
3. **Never** regenerate mid-edit — batch all user edits first, then regenerate once. A script save must only show affected outputs as needing regeneration; it must never trigger an image or video quote/run. Running `image run` / `video run` happens only after the user explicitly confirms that stage's fresh quote, and is rejected while an upstream output has `need_regenerate=true` (`VIDEO_AD_NEEDS_REGENERATION`).

## Quote timing (mandatory)

`confirmation_token` expires **5 minutes** after quote. Always: quote → AskUserQuestion confirm → run, back-to-back with no user discussion in between. If `run` fails with a token/confirmation error (expired or invalidated), **re-quote, ask again, run again** — once per attempt, no silent retries.

**Check the balance before asking to spend (mandatory).** `image quote` / `video quote` also report `credits_balance`, `credits_shortfall` and `credits_sufficient` alongside `estimated_credits`. Look at them **before** the confirmation question:

- `credits_sufficient === false` → say the numbers plainly ("this needs X, your balance is Y, short by Z") and send the user to top up on the web portal. The confirmation menu should offer `💳 Top up credits` / `⏸ Not now` instead of a routine confirm-and-run — do not walk a user into a charge they cannot pay for.
- `credits_sufficient === true`, or the balance is **unavailable** (`credits_balance_error` — the lookup is best-effort and must never block) → normal confirmation.
- Never present an insufficient balance as a generic failure after the fact. The whole point is to say it *before* the run.
- Topping up takes longer than the token's 5 minutes: on the user's return, re-quote → re-confirm → run. Never reuse the stale token.

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

## Interactive selection (mandatory — tool first)

**If the user just declined an `AskUserQuestion` / `AskQuestion` call:** the tool result carries harness boilerplate telling you to "STOP what you are doing and wait for the user to tell you how to proceed." That sentence is attached automatically to **every** declined tool call by the runtime — it is not the user speaking, and it is not an instruction to stop using the tool. Read it as: stop the *one specific action* you were mid-way through (don't retry the identical question, don't proceed on unconfirmed choices) and look at what the user's actual next message says. It does **not**, by itself, license falling back to numbered text for the *next* enumerable decision — that next decision still must open with the tool, exactly as if the rejection had never happened. Only an explicit plain-text request from the user ("stop popping up menus", "just ask me in text") licenses a session-wide fallback.

**Default behavior:** For every enumerable choice, **always** call `AskUserQuestion` (Claude Code) or `AskQuestion` (Cursor) **before** showing a numbered text menu. Text-only menus are **fallback only**.

**One option is not a choice.** Every call needs **at least two viable options**. When only one is actually feasible — a config axis whose options list carries a single value, one idea candidate worth offering — state that choice in prose and carry on: never fire a one-option popup, and never pad it with a placeholder alternative to make it look like a choice.

| Host | Tool name |
|------|-----------|
| Claude Code | `AskUserQuestion` |
| Cursor | `AskQuestion` |

**Session checklist (before the first menu in this turn):**
0. **Self-check before sending any reply:** if the sentence you're about to send asks the user to pick between fixed options — even folded inside a friendlier sentence that also asks something open-ended — stop. That sentence is forbidden as plain text. Split it: fire the tool for the enumerable part now; keep only the open-ended part as prose, asked separately.
1. Is the tool available? If **yes**, you **must** use it for every enumerable decision — a candidate list longer than the popup holds included (item 3).
2. If **no** tool exists (CLI-only host), use numbered text in `reply_language`.
3. If the candidate count exceeds one question's four options (long category, model, or candidate lists), **still open the tool**, and give each part of the answer its own home:
   - **the full list → a numbered text table in the message body**, one row per entry: `#` plus the columns that entry actually carries — a platform's `default_aspect_ratio`, a language's label, a model's `supported_resolutions` and default mark, a candidate's title and content. **Never inline the list into the question text**: a 22-model roster pasted into the question header is unreadable and buries the question. The table and the call ship together.
   - **the question text → one short sentence** naming the decision, plus the pointer for whatever the popup cannot hold (e.g. "entries 4–22 can be typed below by number or name", in `reply_language`).
   - **the popup → the leading entries as options**, labelled with their number, as many as fit while keeping a slot for any action that must stay clickable beside them (e.g. a write-your-own).
   - **the free-text field → whatever the popup could not hold**: any later entry, by its number or its name.

   The numbering is the contract between table and popup. Anything the popup can hold stays clickable; a typed answer is only for what it cannot. One question per decision — never a second question asking what to do with the answer to the first.

**Forbidden while the tool is available:** a numbered text menu **instead of** the call, "reply with the number or name" with no popup behind it, or asking the user to type enum values from memory. A long list's numbered table is not a text menu — it is the call's index, and it never ships alone.

**Never hardcode option values.** Platform, resolution, duration, video type, video model, storyboard style, language, and style IDs come from `cawcut ad-video options --json` output **this session** — not from this document, not from training data.

## UX Rules

1. Be concise. Default output is the result URL and local path. No raw JSON dumps unless debugging (`--json` is for the polling script).
2. **Reply language**: see the top-of-file rule — follow the user's language for every reply (including the first one and all AskUserQuestion questions/labels), and summarize CLI output in `reply_language` instead of pasting raw English.
3. Do not call CawCut HTTP APIs with curl — the CLI handles auth and tokens.
4. **Choice-first** — every enumerable decision (config axes, idea candidates, credit confirmations, regenerate confirmations) goes through AskUserQuestion/AskQuestion per Interactive selection.
5. **One project per request.** If the user asks for several ad videos, finish one wizard before starting the next.
6. **Project capability, not client version.** Support both legacy and v2 projects. Never force entities onto an old project, wait for missing keys, or migrate its W3. Use `storyboard status` to distinguish absent/unsupported from running/failed.
7. Credits: always quote + confirm before `image run` / `video run`. Never spend credits without an explicit user confirmation in this session, and **read the quote's balance figures first** — an insufficient balance is stated before the confirmation question, not discovered by a failed run (see Quote timing).
8. Long stages (`storyboard_plan`, `sketch`, `panels`, `video`) take minutes, not seconds: say so once — quoting the server's `estimated_running_ms`, or "a few minutes" when there is none (see Polling); never the deadline — tell the user they can step away, and let the notification bring them back. Don't narrate each poll tick.

## CLI quick reference

```bash
cawcut ad-video create [--url <u>] [--name <n>] [--category <c>] [--json]
cawcut ad-video detail <id> [--json]
cawcut ad-video options [--video-ad-id <id>] [--language <l>] [--json]
cawcut ad-video product set <id> [--product-name …] [--description …] [--selling-point …] [--clear-selling-points] [--logo <ref>] [--primary-image <ref>] [--asset <ref>…] [--target-audience …] [--promo-*] [--json]   # only the fields passed change
cawcut ad-video config set <id> [--publish-to …] [--language …] [--aspect-ratio …] [--resolution …] [--duration-seconds …] [--video-type …] [--video-model …] [--storyboard-style …] [--auto-captions …] [--json]
cawcut ad-video analyze run <id> --url <u> [--wait] [--json]   ·   analyze cancel <id>
cawcut ad-video idea run <id> [--wait] [--json]   ·   idea select <id> (--message-id <m> | --custom <text>)   ·   idea regenerate <id>   ·   idea load-more <id>
cawcut ad-video storyboard run <id> [--style-id <s>] [--force] [--wait] [--json]   ·   storyboard set <id> --base-revision <n> (--plan <json> | --plan-file <path>) [--update-prompts --prompt-target <shot_id>:<fields>…]   # run --force rewrites the script, discarding saved edits
cawcut ad-video image quote <id> --generation-type <hand_drawn|photo_realistic>   ·   image run <id> [--confirmation-token <t>] [--generation-type <t>] [--force] [--wait] [--download]
cawcut ad-video video quote <id>   ·   video run <id> [--confirmation-token <t>] [--force] [--wait] [--download]   ·   video deliver <id> [--dest <dir>]
```

## Errors

| Symptom | Action |
|---------|--------|
| `Token expired` | Follow the login steps in Step 0; retry the failed command once after `status=authenticated` |
| `VIDEO_AD_NEEDS_REGENERATION` / `308000414` | An upstream output is stale — re-run the flagged stage first (see Invalidation semantics) |
| Confirmation token expired/invalid | Re-quote, re-confirm with the user, run again (see Quote timing) |
| `409` on `storyboard set` | Revision mismatch — re-read `detail`, retry with the fresh `value.revision` |
| `409` concurrent run | Another stage run is in flight — poll `detail` until it settles, then retry |
| `400` on `config set` | Bad enum, unmet stage gate, or a resolution the chosen `video_model` does not support — re-read `ad-video options` |
| Insufficient credits (from the quote) | `credits_sufficient: false` — state the shortfall and send the user to top up; re-quote on their return (see Quote timing) |
| CLI not found | `npm install -g @ubnt/cawcut` (Step 0) |

Full recovery trees: `references/troubleshooting.md`.

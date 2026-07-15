---
version: 0.1.12
name: cawcut-generate
description: |
  Generate images or videos via CawCut official node capabilities using the
  local `cawcut` CLI. Defaults: gpt-image-2 for image/edit; Seedance 2.0 for
  video when live discovery is unavailable.
  Use when: "generate an image", "make a video", "text-to-image",
  "text to image", "text-to-video", "text to video", "image-to-image",
  "image to image", "edit/stylize/remix this image", "image-to-video",
  "image to video", "animate this photo", "omni-to-video", "omni to video",
  "/cawcut-generate", or free-form content descriptions (e.g. "a cute
  little hedgehog"). Supports text-to-image, text-to-video, image-to-image,
  image-to-video, and omni-to-video. Checks the App catalog first; hands
  off to cawcut-app-run on a similar App match.
  Requires `cawcut` installed and `cawcut auth login` completed.
  NOT for: running an App already chosen (use cawcut-app-run), app
  discovery/browsing ("what apps are there", "what can an app generate"),
  OAuth setup alone, or Web UI-only flows without the CLI.
argument-hint: "<prompt> --capability <name> [--model <id>] [--param k=v] [--image|--video|--audio <file|url>] [--download [<dir>]]"
allowed-tools: Bash AskUserQuestion AskQuestion
---

# CawCut Generate

Generate images and videos via CawCut official node capabilities. Wraps `cawcut generate`. Always checks the live App catalog for a similar published App before generating, and hands off to `cawcut-app-run` when one is a good fit.

**Skill files are English-only.** `SKILL.md` and `references/` must not contain Chinese or other non-English prose (including YAML `description` trigger phrases). Match the user's language only in live replies via `reply_language`.

## Step 0 — Bootstrap

Run bootstrap as a silent guardrail, not as a user-facing phase.

1. **At most once per AI session.** If any `cawcut` command has already succeeded in this AI session, skip all bootstrap checks and continue.
2. **Use only one explicit check command:** `cawcut upgrade check --json`.
   - Do not also run `cawcut --version`, `command -v cawcut`, or `cawcut auth status`.
   - If `"update_available": true`, **run `cawcut upgrade` yourself via Bash** (do not ask the user to type it). It refreshes CLI + skills. After it succeeds, continue this skill from Step 1 — do not stop or ask the user to re-invoke.
   - If `"ahead_of_registry": true` (local `current` is newer than npm `latest`), continue without upgrading. This usually means a local/dev build; do not ask the user to downgrade or run `cawcut upgrade`.
   - If the check fails because `cawcut` is missing, ask the user to install the CLI via npm (external users — no git clone or repo `./setup`):
     ```bash
     npm install -g @ubnt/cawcut
     ```
     After install succeeds, continue bootstrap; auth is handled in step 4 below.
   - For other check failures, continue and mention the warning only if a later CLI command fails.
3. Do **not** print "bootstrap checks passed" or ask "what would you like to generate?" after bootstrap. Move directly to capability/model discovery or App discovery.
4. Let the first real command (`cawcut app list --json`, `cawcut capabilities list --models --json --capability <cap>`, or `cawcut generate`) validate auth. If it fails with token/auth errors (including `Token expired`), **run `cawcut auth login` yourself via Bash** — do not ask the user to type it. Briefly tell the user a browser tab will open for OAuth consent; wait for login to finish, then **retry the command that failed** once. Only escalate to the user if login fails (denied, timeout, port conflict).
5. This skill's references (`references/troubleshooting.md`, `references/models.md`) live under the base directory printed at the top of this skill body — `Read` them directly at `<base_dir>/references/<file>.md`. Do not `find`/`grep` to locate them; that base directory can be a symlink that a plain `find <dir>` silently fails to traverse.
6. **Structured user-ask tool (check every session).** In **Claude Code**, use **`AskUserQuestion`** for every enumerable choice. In **Cursor**, use **`AskQuestion`**. If either tool is in your allowed-tools list, you **must** use it for all enumerable decisions in this skill — App vs official generation, capability/mode, model pick, Phase A/B settings, enum `--param` values, media source, upload recovery — **unless** overflow forces a numbered text table for that batch only (see Interactive selection). **Never** default to a numbered text menu while `AskUserQuestion` / `AskQuestion` is available and the option count fits.

## Catalog freshness (mandatory)

**Source of truth:** only the output of a `cawcut app list …` command you run in **this user message's turn** for the **current subject/capability/style**. Never treat app names, IDs, counts, or JSON from earlier messages as authoritative — conversation memory is not a catalog. A **"no App match"** conclusion from a **prior user message** is never reusable.

**Per-user-message rule (highest priority):** On **every new user message**, before writing any reply or calling any other tool, run `cawcut app list --json` first — this is a **mechanical step, not a judgment call**; do not reason about whether the message "could involve" App matching before running it. The catalog may have changed on the server since the last message (e.g. the user published a new App on the web).

**Also re-run Step 1** when **any** of these is true:
- User's tool call (`AskUserQuestion` / `AskQuestion` / menu) was rejected or interrupted and their next message changes subject, capability, or style — treat exactly like a new user message and restart from Step 1, even as a "follow-up" in the same exchange
- User switched account, re-logged in, or `cawcut auth login` just succeeded
- User says they published, shared, or created a new App
- User asks to refresh or re-list Apps

**Skip Step 1 catalog check only when all are true (same user message's turn, same subject/capability/style):**
- You already ran `cawcut app list --json` **for this user message** and completed the smell test (or the user chose official generation after a plausible-match prompt)
- User is only tuning settings on the plan already in flight (ratio, resolution, quality, count, duration, "one more", "make it bigger")
- **Or** this turn started from `cawcut-app-run` handoff where the user already picked "Official generation instead" in **this user message** (see Decide-once guard in Step 1)

**Never skip** the per-user-message `app list` across user messages — even if subject, capability, style, and wording are unchanged.

**Hard gate:** Workflow step 9 runs a pre-flight check immediately before `cawcut generate` — see there.

## Step 1 — Check the App catalog first (before every `cawcut generate` call)

**Decide-once guard (same user message only)** — skip this entire step if this turn started because `cawcut-app-run` already ran the per-user-message `app list` in **this user message** and decided there's no matching App, or the user picked "Official generation instead" there. Go straight to capability/model discovery below; do not re-run `app list` to double-check a decision already made **in this user message**.

Otherwise, apply the **Per-user-message rule** and **Skip Step 1** checklists in **Catalog freshness** above. If you have not yet run `cawcut app list --json` **for this user message**, execute Step 1 below — do not reuse a prior message's list or "no match" conclusion.

1. Run `cawcut app list --json` without `--schema` (lean JSON: name, description, credits, source — no `input_schema`; token-efficient smell test).
2. Check whether any App's `name` / `description` clearly overlaps with the user's ask. This is a quick smell test, not full scoring — `cawcut-app-run` owns the formal scoring rubric and re-checks properly once you hand off.
3. **No plausible match** — continue below with raw generation. Do not mention the catalog check to the user.
4. **Plausible match** — **always** call `AskUserQuestion` / `AskQuestion` first (numbered text **only** if the tool is unavailable):
   ```
   Found a published App that does this: <name> — <description> (N credits).
   1. Use <name>
   2. Continue with official generation
   ```
   - User picks the App → hand off to **`cawcut-app-run`** with that App name already decided. It skips catalog scoring/menus (its Step -1) and goes straight to `describe` + tables + input menu; it still live-fetches `app list --json` in that turn when it needs the internal app ID.
   - User picks official generation → continue this skill's flow below. Do not ask about the catalog again for the rest of **this turn**.

## Interactive selection (mandatory — tool first)

**Default behavior:** For every enumerable choice, **always** call `AskUserQuestion` (Claude Code) or `AskQuestion` (Cursor) **before** showing a numbered text menu or asking the user to type capability names, model IDs, aspect ratios, or enum values. Text-only menus are **fallback only**.

**Tool names by host:**

| Host | Tool name |
|------|-----------|
| Claude Code | `AskUserQuestion` |
| Cursor | `AskQuestion` |

Below, **structured user-ask tool** means whichever of these is available in the current session. Do not guess from capability alone — check your allowed-tools list.

**Session checklist (before the first menu in this turn):**
1. Is `AskUserQuestion` or `AskQuestion` available? If **yes**, you **must** use it for every row in the table below that fits in one call.
2. If **no** tool exists (CLI-only host), use numbered text in `reply_language`.
3. If the tool exists but the candidate count exceeds one call (model-list overflow, long enums), use a numbered text table **for that batch only**; then **resume** `AskUserQuestion` / `AskQuestion` for the next small decision.

**Forbidden while the tool is available:** numbered text menus (`1. … 2. …`), "reply with the number or name", or asking the user to type capability names, model IDs, or enum values from memory.

| Step | Always use structured user-ask tool for |
|------|----------------------------------------|
| Image vs video | Output type |
| Capability / input mode | text-to-image, image-to-image, text-to-video, … |
| Model | Each plan-visible model (mark default in label) — see Model-list overflow (Rule 10, Phase A Choice 2) when the candidate count exceeds what the tool can hold |
| Settings gate | Defaults / **change model** / customize settings (Phase A, single-select) |
| Settings — customize | One structured user-ask tool call, one question per axis from the current model's live schema (Phase B) — never collapse multiple axes into one single-select pick |
| Each enum `--param` | Every `options` value from JSON |
| Media | Same three-way branch as `cawcut-app-run` |

**Fallback only:** Use numbered text menus in `reply_language` **only when** `AskUserQuestion` / `AskQuestion` is unavailable, or when option count/structure exceeds what the tool supports for that batch (model-list overflow, long enum lists). Falling back for one decision does **not** exempt the next small decision — re-check and use the tool again when it fits. UX rule 10 and Workflow step 7 text examples are fallback shape only — **not** the default when the tool is present. Only ask for free-text **prompt content** or a **URL/path** after the user picks a Custom / URL / path branch.

## UX Rules

1. Be concise. Default output is the **result URL(s)**. Do not dump raw JSON unless debugging.
2. Always pass `--wait` — jobs are async, CLI blocks and prints the URL when done.
3. Always pass `--download` for image and video generations. The CLI resolves the platform-appropriate downloads folder automatically (`~/Downloads` on macOS/Linux, `%USERPROFILE%\Downloads` on Windows) — do not hardcode a path or download the result yourself. Only skip `--download` if the user explicitly says they only want the URL.
4. **Reply language**:
   - **Bare skill invoke → English.** If the user only runs the skill command with no substantive text (e.g. `/cawcut-generate`, `cawcut-generate`, or the skill name alone), set `reply_language` to **English** for menus, summaries, and questions.
   - **Follow the conversation after that.** Once the user adds a real request or follow-up in another language, switch `reply_language` to match that language for the rest of the session (unless they explicitly ask for English).
   - All prose, status summaries, option labels, questions, and recovery guidance use `reply_language`.
   - Keep CLI commands/flags, model IDs, app IDs, JSON keys, URLs, and raw error codes in English.
   - Do not paste raw English CLI output as the user-facing answer; summarize it in `reply_language`.
5. Do not call CawCut HTTP APIs with curl — the CLI handles auth, media upload, and token refresh.
6. **Template first** — see Step 1 (Check the App catalog first) above; it runs for **every** request, not just ones that sound template-like. When the user picks the offered App, follow `cawcut-app-run`'s **disclose app on selection** rule — name the App, show metadata + inputs tables, then collect inputs via menus; never say only "this app" without details.
7. **Staged discovery (required)** — never fetch all capabilities with full schema in one shot (`cawcut capabilities list --models --schema --json` without `--capability` dumps ~100KB and may be truncated). Use this sequence instead:
   1. After capability is known → `cawcut capabilities list --simple --capability <cap>` (or `--models --json --capability <cap>`) to pick a model.
   2. After model is chosen → `cawcut capabilities list --models --schema --json --capability <cap> --model "<model_id>"` for that model's parameters only.
   **Forbidden:** writing Python/shell scripts to parse capabilities JSON; use CLI `--capability`, `--model`, or `--simple` filters (or a one-line `jq` if the host already has it).
8. **Choice-first** — if the user did not specify enough information, **always** call `AskUserQuestion` / `AskQuestion` first (numbered text **only** when the tool is unavailable or overflow applies). **Fixed or enumerable parameters must always be clickable menus** — the user picks options; never types parameter names, capability names, model IDs, or enum values from memory:
   - image or video output
   - text-only, image input, video input, audio input, or omni input
   - model options from live discovery, with the BE default first
   - enum/options/ranges from the selected model's parameters
9. **No unbounded preference questions** — never ask only "Any preference on resolution, aspect ratio, quality, or number of images?". **Always** show concrete options from the live schema via `AskUserQuestion` / `AskQuestion` (per **Interactive selection** above), plus "use default" and "custom" when customization is possible.
10. **Settings menu before running** — once prompt/media/capability/model are known, resolve settings in **two phases**. **Image and video use the same shape.** **Precedence:** **always** use `AskUserQuestion` / `AskQuestion` for Phase A (one call: defaults / change model / customize) and Phase B (one batched call, one question per axis) when the tool is present — do not merge into a single numbered text block. Workflow step 7 combined text examples are **fallback rendering only** (tool unavailable, or overflow per model-list / long enum caps).
   - **Phase A — gate (one `AskUserQuestion` / `AskQuestion` call):**
     - Choice 1: run now with schema defaults on the **current model** (show the default values).
     - Choice 2: **change model** — list every model from `cawcut capabilities list --simple --capability <cap>` (or the lean JSON equivalent); mark `"default": true`. **Model-list overflow:** `AskUserQuestion` / `AskQuestion` typically caps at ~2–4 options per question; when the model count for this capability exceeds that, present a **numbered text table** (columns: `#`, name, default marker, key specs) instead of an unnumbered list, and tell the user they can reply with **either the number or the model name** — this mirrors `cawcut-app-run`'s App-picker overflow (Interactive selection rule 7). Apply the same numbered-table treatment to any other live-schema-driven candidate list (models, capabilities, or a long `--param` enum) that exceeds the cap. On pick, re-fetch schema for the new model (`--capability <cap> --model "<id>" --schema --json`), then re-enter Phase A for the new model.
     - Choice 3: customize settings — proceed to Phase B.
   - **Phase B — customize (one batched `AskUserQuestion` / `AskQuestion` call, one question per axis):** build the axis list from the **current model's live schema only** (Step 5) — different models expose different axes (e.g. GPT Image 2 has `ratio`/`resolution`/`quality`/`num_images`; Kling 3.0 Pro has `duration`/`aspect_ratio`/`generate_audio` instead, no `resolution`). For every cost- or visual-impacting axis present (aspect ratio, resolution/size, quality, duration, image count, audio on/off, …), ask **one question with its own options**, first option always "use default (show value)".
   - **Never fold two different axes into one single-select pick.** The point of Phase B is that the user can independently touch any subset of axes while the rest silently default — forcing one exclusive choice among axes (e.g. "customize duration" vs. "customize ratio" as alternatives) drops the unpicked axes without ever showing them.
   - `AskUserQuestion` / `AskQuestion` caps at 4 questions per call. If the current model exposes more than 4 cost/visual-impacting axes, batch the 4 most impactful first; the rest still fall under Rule 12 (advanced/non-impacting params stay defaulted without asking).
   - A custom numeric value (e.g. a duration inside `duration_range`) is an option **within** that axis's own question, not a separate top-level choice.
11. For common settings (each is its own Phase B question/axis):
   - Aspect ratio: list every `aspect_ratios` value or the selected model's ratio/aspect_ratio parameter `options`; mark the default. If the schema has no aspect-ratio field, do not invent a `--param`.
   - Resolution/size/quality/style: list `options` from the matching parameter; mark defaults. For min/max ranges, show default, min, max, and "custom within range".
   - Image count: offer `1`, `2`, `3`, `4` with `1` marked default unless the schema says otherwise. If the model has `num_images`, use `--param num_images=N`; otherwise use `--loop N`.
   - Video duration: list `durations`; for `duration_range`, show default, min, max, and custom seconds within range.
   - Boolean toggle (e.g. `generate_audio`): offer On (default) / Off as the two options for that axis's question whenever the parameter description flags a cost/time effect (Rule 14).
12. Do not ask for advanced params the user did not mention unless they are required or clearly cost/visual-impacting. Use defaults from the live model schema for the rest.
13. **Session reuse** — after the first generation, capture `workflow_id` from the JSON result. For **every** follow-up `generate` in the same session, pass `--workflow-id <id>` — including when capability or model changes (e.g. text-to-image → image-to-image → text-to-video). Each call **appends** new generation nodes to that workflow (history is preserved). Omit `--workflow-id` only when the user explicitly wants a new project or the request is clearly unrelated to this session.
14. **Multi-image / multi-candidate (`--loop`)** — `loop` is how many **parallel generation nodes** to add in **this** request (max **4**). It is **not** how many times the workflow runs overall. If the user wants more than 4 candidates (e.g. "5 candidates"), **do not call CLI**; reply that the model/platform supports at most **4** parallel candidates. For `N≤4`: if the model schema has `num_images` and the user wants multiple images in one API call, prefer `--param num_images=N`; otherwise use `--loop N` (works for image and video). Credits and time scale roughly with `loop` (and with `num_images` per node when set).
15. **Never assume models or params from training data** — available models depend on the user's plan. Always discover via CLI first.
16. **Never use illustrative media examples as actual inputs.** When `--image`, `--video`, or `--audio` is required, any example URL or path in SKILL.md, `references/`, model schema, or docs (including `cdn.example.com`, `@/path/to/file` placeholders) is **hint only** — not a usable resource. Do **not** pass them to the CLI unless the user explicitly provided that exact file or URL in this conversation.
17. **Media input — menu, not invented assets** — **always** present the three-way branch via `AskUserQuestion` / `AskQuestion` per **Interactive selection** (above). The numbered list below is text fallback shape only. Same bar as `cawcut-app-run`. For required media, offer: 1) file already in chat 2) HTTPS URL 3) local path. Map the choice to `--image` / `--video` / `--audio` yourself. If required media is missing, show this menu and wait — do not run with fabricated or placeholder examples.
18. **Don't pre-inspect local media before attempting `generate`** — do not shell out to `ls`/`file`/`sips -g pixelWidth/pixelHeight` (or similar) to check a local file's size or dimensions before running. Attempt `cawcut generate` directly; if upload pre-flight fails, the CLI's error already reports the exact size/dimension and its limit — act on that error (see "Upload limits" above / Errors below), not on a manual inspection you ran first.

## Capabilities

| `--capability` | What it does | Media input |
|----------------|--------------|-------------|
| `text-to-image` | Text → image | — |
| `text-to-video` | Text → video | — |
| `image-to-image` | Edit / stylize image | `--image` **required** |
| `image-to-video` | Animate a still | `--image` **required** |
| `omni-to-video` | Any media → video | at least one of `--image` / `--video` / `--audio` **required**; types may be combined (e.g. avatar image + music audio) |

## Discover models and parameters (required)

Use **staged** CLI discovery — do not pull full schema for all five capabilities at once.

**Step A — pick capability** (if not already obvious from the user request):

```bash
cawcut capabilities list
```

**Step B — list models for that capability only** (after capability is known):

```bash
cawcut capabilities list --simple --capability text-to-video
# or: cawcut capabilities list --models --json --capability text-to-image
```

Each `--simple` line is `model_id: name` with `(default)` when applicable. Split on the **first** colon only.

**Step C — load parameters for the chosen model only**:

```bash
cawcut capabilities list --models --schema --json --capability text-to-video --model "Seedance 2.0"
```

This returns a small JSON payload (one capability, one model) with BE-sourced metadata:

- `model_id`, `name`, `default`
- `parameters` — names, types, defaults, options, min/max, descriptions
- `aspect_ratios`, `durations`, `duration_range` when applicable
- `medias` — input limits for image/video/audio capabilities (count, roles, and optional per-model `limit`)

**Never** run bare `cawcut capabilities list --models --schema --json` (all capabilities) unless the user explicitly asks to browse every capability's full schema at once.

**Upload limits (platform):** Before uploading local files, CLI loads `GET /developer/config` and validates size/format/dimensions. CLI does **not** compress. On failure, do **not** just print the error and stop, and never suggest CawCut Web as a workaround — **always** call `AskUserQuestion` / `AskQuestion` first with: (1) compress/resize it for you now via `sips`/`ffmpeg` and retry automatically, (2) they'll fix it and re-upload, or (3) cancel. Numbered text **only** if the tool is unavailable. If they pick (1), run the fix command yourself, then retry the upload. See `references/troubleshooting.md` for the exact commands per failure type. Run `cawcut config limits` to show current caps.

**Rules:**

1. Only suggest or pass `--model` values that appear in the JSON for the chosen capability.
2. Read `--param` keys and allowed values from that model's `parameters` (and related fields). Do not invent param names.
3. Treat BE's `"default": true` as the source of truth. Each capability should have exactly one default; if none or more than one is present, ask the user to choose from the listed models.
4. For the default model, omit `--model`, or pass its `model_id` explicitly.
5. Only when live discovery is unavailable and the user still asks to proceed, use fallback defaults: image/image edit = `gpt-image-2`; video/animate/omni = `Seedance 2.0`.
6. Quote `model_id` values that contain spaces or parentheses.

Human-readable summary (names only, no parameters):

```bash
cawcut capabilities list --models
```

Human-readable summary with parameters (text, not JSON — for a quick look, not for building the table below):

```bash
cawcut capabilities list --schema
```

See `references/models.md` for a short field guide — not a model catalog.

## Present parameters to users (required)

`cawcut capabilities list --models` alone lists names only — no params. `cawcut capabilities list --schema` (implies `--models`) adds one dense line per parameter in plain text — useful for a quick look, but still render a markdown table for the user from the **scoped** `--json` form; do not paste raw CLI text/JSON or prose-only bullets when explaining models.

`cawcut capabilities list --models --json --capability <cap>` is **lean** — `model_id`/`name`/`capability`/`default` only, for picking a model within one capability. Add `--schema` and `--model "<id>"` when you need `parameters`, `aspect_ratios`, `durations`/`duration_range`, or `medias` for a single model.

`cawcut capabilities list --simple --capability <cap>` is the lightest human output for model menus (one line per model).

When the user asks what a model supports or which settings to pick, build a markdown table from live JSON for the selected capability + model:

| Name | Type | Constraints / options | Default | Required | Notes |
|------|------|----------------------|---------|----------|-------|

**Row mapping from JSON `parameters[]`:**

| JSON field | Table column |
|------------|--------------|
| `name` | Name — the `--param` key |
| `type` | Type (`string`, `number`, `boolean`, `array`, …) |
| `options` or `min`/`max` | Constraints — comma-join `options`; for ranges write `1–4` |
| `default` | Default — `—` when absent |
| `required` | Required — `yes` only when `required` is `required`; else `no` |
| `description` + CLI hint | Notes — e.g. `--param ratio=16:9`; arrays use JSON value |

Also include non-`parameters` fields when present:

| Source field | Present as |
|--------------|------------|
| `aspect_ratios` | Extra row or note for ratio when no `ratio` param |
| `durations` / `duration_range` | Row for video length |
| `medias` | Separate **media inputs** table (below) |
| Top-level `prompt` (implicit) | Row: `prompt` / `string` / — / — / **yes** / CLI positional arg |

**CLI flags table** — show once when explaining `cawcut generate` (not per model):

| Name | Type | Constraints / options | Default | Required | Notes |
|------|------|----------------------|---------|----------|-------|
| `prompt` | string | — | — | yes | positional arg |
| `--capability` | enum | `text-to-image`, `text-to-video`, `image-to-image`, `image-to-video`, `omni-to-video` | — | yes | sets input/output mode |
| `--model` | string | `model_id` values from JSON only | capability default | no | quote if spaces |
| `--param` | key=value | from selected model `parameters` | per-field defaults | no | repeatable; arrays/objects as JSON string |
| `--image` | file \| url | local path or HTTPS | — | yes for image/omni caps | repeatable; local auto-upload |
| `--video` | file \| url | local path or HTTPS | — | omni optional | repeatable |
| `--audio` | file \| url | local path or HTTPS | — | omni optional | repeatable |
| `--loop` | number | 1–4 | 1 | no | parallel candidates; not workflow run count |
| `--workflow-id` | string | existing workflow UUID | — | no | reuse same project for all session follow-ups |
| `--wait` | flag | — | off | recommended | block until task completes |
| `--download` | flag \| path | omit = system Downloads | off | recommended | auto-save image/video |
| `--json` | flag | — | off | recommended | structured output; preserves signed URLs |

**Example — GPT Image 2 / `text-to-image`** (shape reference; values must match live JSON):

| Name | Type | Constraints / options | Default | Required | Notes |
|------|------|----------------------|---------|----------|-------|
| `prompt` | string | — | — | yes | text description |
| `ratio` | string | `16:9`, `9:16`, `1:1`, `21:9`, `3:2`, `4:3`, `5:4`, `2:3`, `3:4`, `4:5` | `16:9` | no | `--param ratio=16:9` |
| `resolution` | string | `1K`, `2K`, `4K` | `1K` | no | `--param resolution=2K` |
| `quality` | string | `low`, `medium`, `high` | `low` | no | `--param quality=high` |
| `num_images` | number | 1–4 | `1` | no | multiple images per API call; or use `--loop` |

**Example — GPT Image 2 / `image-to-image`** — same params plus:

| Name | Type | Constraints / options | Default | Required | Notes |
|------|------|----------------------|---------|----------|-------|
| `--image` | file \| url | up to 16 reference images | — | yes | `--image @/path` or URL |

Always re-fetch JSON before presenting — plans and BE config change.

## Workflow

0. **Check the App catalog** — see Step 1 above (runs for every request, with the decide-once guard). Continue below only after the user chooses official generation or no App matches.
1. **Discover capability** — infer from the user request or offer image vs video + input mode choices.
2. **List models** — `cawcut capabilities list --simple --capability <cap>` (or lean `--models --json --capability <cap>`). Put the default model first in menus.
3. **Pick output and input mode with choices** (when not obvious):
   - Image output: `text-to-image` or `image-to-image`
   - Video output: `text-to-video`, `image-to-video`, or `omni-to-video`
   If the user's prompt/media makes the answer obvious, state the inferred choice and continue. If not, **always** call `AskUserQuestion` / `AskQuestion` first (per **Interactive selection** above); numbered menu in `reply_language` **only** when the tool is unavailable.
4. **Choose model** — from Step 2 output only. Put the `"default": true` / `(default)` model first and mark it recommended; offer **change model** again in the settings menu (UX rule 10) for both image and video.
5. **Load schema** — `cawcut capabilities list --models --schema --json --capability <cap> --model "<model_id>"` before building param tables or the settings menu.
6. **Collect prompt/media** — ask for the generation prompt and any required `--image`, `--video`, or `--audio` input. If required media is missing, show the three-way menu (UX rules 16–17) and wait for the user's real file or URL — never substitute example or placeholder media from docs or schema.
7. **Present the settings menu** before generating, per Rule 10's two phases. **Must include change model in Phase A** (same for image and video). Do not ask an open-ended preference question.

**Fallback example (English)** — when `AskUserQuestion` / `AskQuestion` is unavailable or overflow applies (**shape reference only** — every value shown, including which one is "(default)", must come from that model's live schema, not from this example):

Phase A — single-select gate (text fallback):
```
Run with defaults, change model, or customize settings:
1. Use defaults (recommended) on GPT Image 2: ratio 16:9, resolution 1K, quality low, count 1
2. Change model: GPT Image 2 (default) / GPT Image 1 / …
3. Customize settings
```

If the user picks 3, Phase B (text fallback shape for one axis — repeat per axis, or batch via `AskUserQuestion` / `AskQuestion`):
```
- Aspect ratio: 16:9 (default) / 1:1 / 9:16 / 4:3 / 3:4 / custom
- Resolution: 1K (default) / 2K / 4K
- Quality: low (default) / medium / high
- Count: 1 (default) / 2 / 3 / 4
```

**When `AskUserQuestion` / `AskQuestion` is available (required path)** — same GPT Image 2 / `text-to-image` scenario, decomposed (labels in `reply_language`):

1. **Phase A gate** — one `AskUserQuestion` / `AskQuestion` call:
   - `Use defaults` — Run with schema defaults on current model (show default values)
   - `Change model` — Open model picker (overflow → numbered text table per Rule 10 if model count exceeds cap)
   - `Customize settings` — Proceed to Phase B
2. **Phase B customize** — one batched `AskUserQuestion` / `AskQuestion` call, **one question per axis** (never one pick across axes):
   - Aspect ratio — options from live schema; first option = use default (show value)
   - Resolution — same pattern
   - Quality — same pattern
   - Count — same pattern

Video example — Phase B axes come from that model's own schema, not GPT Image 2's (tool-available: same batched one-question-per-axis pattern; text fallback shape):
```
- Duration: 5s (default) / 10s / 15s / custom (4–15s)
- Aspect ratio: adaptive (default) / 16:9 / 9:16 / 1:1 / 21:9 / 4:3 / 3:4
- Resolution: 720p (default) / 480p / 1080p / 4k
- Audio: On (default) / Off
```

A model like Kling 3.0 Pro exposes no `resolution` axis but does have `generate_audio` — build Phase B strictly from that model's live `parameters`/`aspect_ratios`/`duration_range`; never reuse another model's axis list or default marker.

If the user later writes in another language, present the same menu in `reply_language`.

Only include options that exist in the selected model's schema. If a schema uses different values (for example `square`, `portrait`, `landscape`, `1024x1024`, or numeric seconds), display those exact values instead.
8. **Build `--param` flags** from the chosen model's `parameters` / `durations` / `aspect_ratios`. Use selected values, or schema defaults when the user chooses the default option.
9. **Run with `--wait --json`**:

**Pre-flight check (do this immediately before building the command):** Has `cawcut app list --json` been run **for this user message** before routing for the **current** subject/capability/style? If **no** → stop and go back to **Step 1** now. Do **not** call `cawcut generate` first. A prior user message's catalog check or "no match" does not count.

```bash
cawcut generate "<prompt>" \
  --capability <capability> \
  [--model "<model_id from JSON>"] \
  [--param key=value ...] \
  [--loop <1-4>] \
  [--image|--video|--audio <file|url>] \
  --wait --download --json
```

Array/object params use JSON in the value:

```bash
--param 'colors=[]'
--param 'colors=["#004035","#008C65","#025940","#008C3E","#072621"]'
```

10. **Capture `workflow_id`** for every session follow-up (any capability or model):

```bash
cawcut generate "<revised prompt>" \
  --capability <cap> \
  --workflow-id <id from prior JSON> \
  --wait --download --json
```

When switching to a media capability (e.g. image-to-image after text-to-image), pass `--image` / `--video` / `--audio` with the prior `result_urls` entry or user-provided file — nodes are appended side-by-side; BE does not auto-wire prior outputs.

Omit `--workflow-id` only for a clearly unrelated request or when the user asks for a new project.

11. **Deliver** — parse JSON; share every `result_urls` / `local_paths`. Use exact signed URLs (do not strip query parameters). **Always** also report `credits_used` (or `credits_estimate` if `credits_used` is absent) and `credits_balance` (or `credits_balance_error`) from the same JSON — every single completed generation, even back-to-back ones in the same session. Never omit this because it was already shown for a prior task.

## Async tasks

The CLI prints `Task: <task_id>` before polling. Capture it as a recovery handle.

- With `--wait`: CLI blocks, then prints result URLs on success.
- Without `--wait`: `cawcut task status <task_id> --wait`
- On timeout: resume with `cawcut task status <task_id> --wait`

## Errors

| Symptom | Action |
|---------|--------|
| `Token expired` | Run `cawcut auth login` via Bash, then retry the failed command |
| `Unknown capability` | `cawcut capabilities list` |
| Invalid `--param` / unknown model | Re-run `cawcut capabilities list --models --schema --json --capability <cap> --model "<id>"` for this user |
| CLI not found | `npm install -g @ubnt/cawcut` (Step 0); then `cawcut auth login` via Bash |

See `references/troubleshooting.md` and `references/models.md` (discovery guide only).

---
version: 0.10.0
name: cawcut-app-run
description: >-
  Use when handling published CawCut Apps: browse, inspect, run a named App, /cawcut-app-run, or a selected-App handoff from cawcut-workflow. NOT for new production requests (cawcut-workflow).
argument-hint: "[natural-language request or app name] [--input key=value ...] [--wait] [--download [<dir>]]"
allowed-tools: Bash AskUserQuestion AskQuestion
---

# CawCut App Run

Entry point for anything CawCut-App related: discovery ("what can this app do", "what apps are available"), catalog browsing, and running Apps. Wraps `cawcut app list`, `cawcut app describe`, and `cawcut app run`. New media production is routed by `cawcut-workflow`; this skill owns selected-App inspection, inputs and execution.

**Skill files are English-only.** `SKILL.md` and `references/` must not contain Chinese or other non-English prose (including YAML `description` trigger phrases). Match the user's language only in live replies via `reply_language`.

For media inputs run `cawcut asset upload` once and keep the returned `asset_id`s; reuse them instead of uploading again. Retain IDs and returned URLs from App/Product/stage results before later processing.

## Step -1 — Handoff state (check first)

If `cawcut-workflow` already selected an App for this goal, carry its selection,
catalog evidence, user inputs and asset IDs forward. Proceed to live `describe`
and input collection without repeating the picker. Fetch current catalog data
when resolving an ID or handling access changes, preserving the selected App.
If App inspection proves unsuitable, return the reason and evidence to workflow
planning; the canvas branch resumes without another catalog/picker loop.

Otherwise, continue at Step 0.

## Step 0 — Bootstrap

### Choose the login mode by execution environment

Choose by where commands actually run. On the user's own computer, run `cawcut auth login --browser --json`; the CLI opens the browser and waits for approval. In a remote environment, VM, or container without access to the user's browser, run `cawcut auth login --device-auth --json` and send the user `authorization_url` to open and approve on their own computer. Both modes support JSON; needing structured output is not a reason to choose device authorization. Agent names, non-TTY shells, and localhost URLs alone do not establish where commands run. Use the known execution context and explicit mode flags to override CLI auto-detection.

For device login, then run `cawcut auth login --complete --wait --timeout 60 --json`. If your tool has a short execution timeout, use single `--complete --json` calls instead, following `next_poll_after_seconds`. After device login is interrupted or returns `wait_timeout`, resume the saved current request rather than creating a new link. Browser login uses the legacy loopback callback; if interrupted, restart `cawcut auth login --browser --json` instead of using `--complete`. `status=pending` is not authentication success. Only retry the original operation after `status=authenticated`. Denial/expiry ends this request; do not silently create an endless sequence of authorization links. Never ask for a password, token, or a code copied back from the web page.


Run bootstrap as a silent guardrail, not as a user-facing phase.

1. **At most once per AI session.** If any `cawcut` command has already succeeded in this AI session, skip all bootstrap checks and continue.
2. **Use only one explicit check command:** `cawcut upgrade check --json`.
   - Do not also run `cawcut --version`, `command -v cawcut`, or `cawcut auth status`.
   - If `"update_available": true`, **run `cawcut upgrade` yourself via Bash** (do not ask the user to type it). It refreshes CLI + skills. After it succeeds, continue this skill from Step 1 — do not stop or ask the user to re-invoke.
   - If `"ahead_of_registry": true`, continue without upgrading. Do not ask the user to downgrade or run `cawcut upgrade`.
   - If the check fails because `cawcut` is missing, ask the user to install the CLI via npm (external users — no git clone or repo `./setup`):
     ```bash
     npm install -g @ubnt/cawcut
     ```
     After install succeeds, continue bootstrap; auth is handled in step 4 below.
   - For other check failures, continue and mention the warning only if a later CLI command fails.
3. Do **not** print "bootstrap checks passed" or ask "what would you like to run?" after bootstrap. Move directly to App discovery below.
4. Let the first real command (`cawcut app list --schema`, `cawcut app describe`, or `cawcut app run`) validate auth. If it fails with token/auth errors (including `Token expired`), follow the login steps above. Use the mode appropriate to the execution environment, and retry the failed command once only after `status=authenticated`. Run the CLI commands yourself; the user only approves in their browser.
5. This skill's references (`references/troubleshooting.md`, `references/app-inputs.md`, `references/intent-matching.md`, `references/app-presentation.md`) live under the base directory printed at the top of this skill body — `Read` them directly at `<base_dir>/references/<file>.md`. Do not `find`/`grep` to locate them; that base directory can be a symlink that a plain `find <dir>` silently fails to traverse.
6. **Structured user-ask tool (check every session).** In **Claude Code**, use **`AskUserQuestion`** for every enumerable choice. In **Cursor**, use **`AskQuestion`**. If either tool is in your allowed-tools list, you **must** use it for all enumerable decisions in this skill — app pick, duplicate-name pick, enum/default branches, media source, optional-input skip/provide, upload recovery — **unless** overflow forces a numbered text table for that batch only (see Interactive selection). **Never** default to a numbered text menu while `AskUserQuestion` / `AskQuestion` is available and the option count fits. A user declining one such call is not grounds to stop using it for the next decision — see Interactive selection's opening rule for how to read the decline message.

## Catalog freshness (mandatory)

Use live `cawcut app list --schema --json` output for discovery, scoring and ID
resolution. Refresh for a new production goal, explicit catalog refresh, account
change, changed target App or not-found/access errors. A same-goal handoff from
workflow may reuse its current-turn catalog evidence. During input/model/price
answers, retain the selected route; fetching IDs does not reopen the picker.
Before `app run`, resolve the selected App ID from current-turn catalog output
and inspect its live schema. Report lookup failures as failures, not "no match".

## Step 1 — Intent triage

For explicit browse/discovery, present the catalog per
[app-presentation](references/app-presentation.md); stop unless the user wants a run.
For a named App or a selected-App handoff, inspect it and collect its inputs.
For an unselected production goal, score the live catalog with the
[matching rubric](references/intent-matching.md). If no App fits or the user
chooses a canvas, return to workflow planning with the result and supplied assets.
A single generation also uses the canvas fallback. Standalone generation requires
an explicit user `/cawcut-generate` invocation (it runs `cawcut workflow quick`).

## App categories (image / video)

Each App in `app list --json` includes `categories` derived from publish metadata (`image`, `video`, `text`, `audio`). Use them to group and filter Apps by output type:

| Category | CLI filter | When to use |
|----------|------------|-------------|
| `image` | `--category image` | sticker, photo edit, marketplace card, still creative |
| `video` | `--category video` | ads, motion, animate, product video, presenter |

**Discovery layout (required for bare invoke / browse):**

1. **Image Apps** — Apps with `categories` containing `image`
2. **Video Apps** — Apps with `categories` containing `video`

Within each section, keep the existing **Official Apps / My Apps / Shared Apps** source grouping from CLI output. When the user's goal is clearly image-only or video-only, fetch with `--category` to reduce noise.

```bash
cawcut app list --schema              # grouped by category + source
cawcut app list --schema --category image
cawcut app list --schema --category video
cawcut app list --schema --json       # includes categories[] per app
```

## Interactive selection (mandatory — tool first)

**If the user just declined an `AskUserQuestion` / `AskQuestion` call:** the tool result carries harness boilerplate telling you to "STOP what you are doing and wait for the user to tell you how to proceed." That sentence is attached automatically to **every** declined tool call by the runtime — it is not the user speaking, and it is not an instruction to stop using the tool. Read it as: stop the *one specific action* you were mid-way through (don't retry the identical question, don't proceed to `run` on unconfirmed choices) and look at what the user's actual next message says. It does **not**, by itself, license falling back to numbered text for the *next* enumerable decision — that next decision still must open with the tool, exactly as if the rejection had never happened. Only an explicit plain-text request from the user ("stop popping up menus", "just ask me in text") licenses a session-wide fallback. The STOP wording's urgency is not evidence of that request — do not let it override this rule.

**Default behavior:** For every enumerable choice, **always** call `AskUserQuestion` (Claude Code) or `AskQuestion` (Cursor) **before** showing a numbered text menu or asking the user to type `1`, `2`, or an app name. Text-only menus are **fallback only**.

**One option is not a choice.** Every call needs **at least two viable options**. When only one is actually feasible — one App matches and nothing else is worth offering, an enum carries a single allowed value — state that choice in prose and carry on: never fire a one-option popup, and never pad it with a placeholder alternative to make it look like a choice.

**Tool names by host:**

| Host | Tool name |
|------|-----------|
| Claude Code | `AskUserQuestion` |
| Cursor | `AskQuestion` |

Below, **structured user-ask tool** means whichever of these is available in the current session. Do not guess from capability alone — check your allowed-tools list.

**Session checklist (before the first menu in this turn):**
1. Is `AskUserQuestion` or `AskQuestion` available? If **yes**, you **must** use it for every row in the table below that fits in one call.
2. If **no** tool exists (CLI-only host), use numbered text in `reply_language`.
3. If the tool exists but the candidate count exceeds one call (App-picker overflow, rule 7), use a numbered text table **for that batch only**; then **resume** `AskUserQuestion` / `AskQuestion` for the next small decision.

**Forbidden while the tool is available:** numbered text menus (`1. … 2. …`), "reply with the number or name", or asking the user to type app names, input keys, or enum values from memory.

| Step | Always use structured user-ask tool for |
|------|----------------------------------------|
| App picker | Every app from `app list --schema` (label = name + credits + short description; **no app IDs**) — see App-picker overflow (rule 7) when the candidate count exceeds what the tool can hold |
| Duplicate name | Each matching copy (label = description + source; **no app IDs**) |
| Enum / default text | Each allowed value + "Use default" / "Custom" when applicable |
| Media input | `Photo already in chat` / `Paste HTTPS URL` / `Local file path` |
| Optional input | `Skip` / `Provide` |

**Structured user-ask tool rules:**

1. Call **before** waiting for a free-text reply whenever options are enumerable.
2. One decision per form when possible (e.g. `pick-app`, then `scene-photo-source`).
3. Option `label` is what the user reads; keep `id` short and stable (`photo-sticker`, `3d-model-zh`, `3d-model-en`).
4. Do **not** put app IDs in labels. After the user picks, run a fresh `cawcut app list --json` in this turn, then resolve ID from that output only.
5. If the user picks **Custom** / **Local file path** / **Paste URL**, **then** ask one follow-up for that content (text or path) — still do not ask them to type input KEY names.
6. **Fallback only:** Use numbered text menus in `reply_language` **only when** `AskUserQuestion` / `AskQuestion` is unavailable, or when option count/structure exceeds what the tool supports for that batch. Falling back for one decision does **not** exempt the next small decision — re-check and use the tool again when it fits. UX rule 11's combined text block is fallback shape only — **not** the default when the tool is present.
7. **App-picker overflow:** the tool typically caps at ~2–4 options per question (and ~4 questions per call). When the candidate list from `app list --schema` exceeds that, present the batch as a **numbered text table** for browsing — a leading `#` index column, then name, source, credits, description — and tell the user they can reply with **either the number or the app name**. This text fallback covers only that oversized batch. Once the user narrows to a specific App, every later small-option-count decision (duplicate-copy pick, enum values, media source, optional-input skip/provide) **must** go through `AskUserQuestion` / `AskQuestion` again — same pattern as the model-list menu in `cawcut-generate`.

## UX Rules

1. **Choice-first** — when browsing without an already selected App, start with `cawcut app list --schema`, then **always** call `AskUserQuestion` / `AskQuestion` for app selection when the candidate count fits (numbered text **only** for App-picker overflow, rule 7). **Do not show app IDs** — use name, source, credits, description, and input summary only.
2. **Template first** — apply Step 1 (Intent triage): score the live catalog per `references/intent-matching.md` and recommend a strong match first. Return to workflow planning when no App fits or the user chooses a canvas (Step 1).
3. **Disclose app on selection (required)** — whenever an App is chosen — user pick, auto-match from a natural-language request, or your single recommendation — **before** asking for inputs:
   1. Run `cawcut app describe "<app name>"` (disambiguate first if needed).
   2. Present the **App metadata table** + **inputs table** (see "Present app inputs to users") in `reply_language`.
   3. Lead with the **App name** and **description** in prose — never say only "this app" without naming it.
   4. Then show the input collection menu (UX rules 11–12).
   **Forbidden:** vague lines like "this app can help you…" with no name, source, function, or input summary; jumping straight to "please provide the video path" without explaining which App and what it needs.
4. **Natural-language requests are allowed** — translate the user's goal into an App recommendation using the Step 1 scoring rubric (`references/intent-matching.md`) against app name, description, source, credits, and exposed input requirements. When one App scores ≥ 70, treat it as **selected** — run `describe` and disclose full app details immediately; do not wait for the user to ask "what app?".
5. **Reply language**:
   - **Bare skill invoke → English.** If the user only runs the skill command with no substantive text (e.g. `/cawcut-app-run`, `cawcut-app-run`, or the skill name alone), set `reply_language` to **English** for menus, summaries, and questions.
   - **Follow the conversation after that.** Once the user adds a real request or follow-up in another language, switch `reply_language` to match that language for the rest of the session (unless they explicitly ask for English).
   - All prose, status summaries, option labels, questions, and recovery guidance use `reply_language`.
   - Keep CLI commands/flags, model IDs, input keys, JSON keys, URLs, and raw error codes in English. **App IDs are internal** — resolve them from a fresh `cawcut app list --json` run in this turn when needed; never surface IDs in user-facing App lists.
   - Do not paste raw English CLI output as the user-facing answer; summarize it in `reply_language`.
6. **Proactive discovery** — for an explicit browse request or bare invocation without a selected-App handoff, immediately run `cawcut app list --schema`, summarize Apps grouped by **Image Apps** and **Video Apps** (no IDs), and ask the user to choose an App or describe their goal freely.
7. **Always inspect inputs before running** — call `cawcut app describe "<app name>"` first (or `cawcut app describe <app_id>` when resolving from `--json`).
8. **Disambiguate duplicate names before run** — if the name matches multiple Apps, **always** call `AskUserQuestion` / `AskQuestion` with one option per copy (description + source + input summary in labels) when the copy count fits. Wait for the click/choice before run. Numbered-text CLI fallback only when the tool is unavailable: `cawcut app run "<name>" --pick <n>`.
9. **Choice-first for every fixed or enumerable value** — same bar as `cawcut-generate`'s model and settings questions. Never ask the user to type app names, input **keys**, enum values, or flags from memory. After `describe`, if a field has a default, `options`, or a small known set, **always** call `AskUserQuestion` / `AskQuestion` (plus "use default" when applicable). Only ask for open-ended **content** when the schema is genuinely free text with no default and the user has not already provided it. **Never** default to numbered text for small enumerable decisions while the tool is available.
10. **No unbounded input questions** — forbidden patterns:
   - "What app do you want to run?"
   - "Please provide values for the required inputs."
   - "Paste the value for `Input - Scene Photo`."
   Instead, always show concrete numbered choices derived from `app list --schema` / `app describe`.
11. **Input collection menu before run** — after `describe`, collect input choices before run. **Precedence:** **always** decompose into `AskUserQuestion` / `AskQuestion` calls when the tool is present — one call for the "how to fill inputs" overview (defaults vs. custom) when there is more than one field, then one call per field needing a decision (media source A/B/C, text starter-vs-custom, enum value list). The combined text block below is **fallback rendering only** — use it **only** when `AskUserQuestion` / `AskQuestion` is unavailable, or when sub-choice count exceeds what the tool can hold (App-picker overflow, Interactive selection rule 7). Do not merge decomposed decisions into a single numbered text menu while the tool is available.

**Fallback example (English)** — when `AskUserQuestion` / `AskQuestion` is unavailable or overflow applies:

```
Ready to run Photo to Sticker. Choose how to fill inputs:
1. Use defaults only (if any exist) and run — list which fields use defaults
2. Scene photo — pick one:
   A. Use a photo you already shared in this chat (I'll use that file/URL)
   B. Paste an HTTPS image URL
   C. Give a local file path (e.g. ~/Pictures/photo.jpg, or C:\Users\you\Pictures\photo.jpg)
3. Text fields (only when required and no default) — pick a starter or write custom:
   A. Use suggested prompt: "..."
   B. Custom (you describe; one short message)
4. Run now with choices above
```

**When `AskUserQuestion` / `AskQuestion` is available (required path)** — same Photo to Sticker scenario, decomposed (one decision per call; labels in `reply_language`):

1. **Scene photo source** — `AskUserQuestion` / `AskQuestion` with options:
   - `Photo already in chat` — Use a photo you already shared in this chat
   - `Paste HTTPS URL` — Paste an HTTPS image URL
   - `Local file path` — Give a local file path (e.g. ~/Pictures/photo.jpg, or C:\Users\you\Pictures\photo.jpg)
2. **Text field** (if required and no default) — `AskUserQuestion` / `AskQuestion` with options:
   - `Use default` / `Use suggested prompt` — show the default or suggested value
   - `Custom` — then ask one follow-up for the user's text (rule 5 above)

Adapt items to the live schema — omit decisions for inputs that do not exist. **Never show input KEY names as something the user must type**; keys are for CLI only.
12. **Per input kind — menu, not free-form parameter entry** — **always** present each row's choices via `AskUserQuestion` / `AskQuestion` per **Interactive selection** (above). The numbered menus below are text fallback shape only.
    | Kind | User-facing menu (never ask for KEY names) |
    |------|---------------------------------------------|
    | `text` + default | 1) Use default (show value) 2) Custom text |
    | `text` + no default | 1) Suggest 2–3 starters from app description 2) Custom (user writes content once) |
    | `text` + enum/options in schema | Number every allowed option from `describe --json`; add "other" only if schema allows |
    | `image` / `video` / `audio` | 1) File already in chat 2) HTTPS URL 3) Local path — user picks A/B/C, not a raw `--input` key |
    | optional input | 1) Skip 2) Provide (then show sub-menu for that kind) |
13. Map chosen menu options to `--input key=value` yourself using the KEY column from `describe`. The user selects **options**, not parameter names.
14. For media inputs: pass an HTTPS URL or a local path prefixed with `@` after the user picks a menu branch. Paths in this file are written POSIX-style for brevity; on Windows the same input is `--input "key=@C:\Users\you\Pictures\photo.jpg"`, and `~` is expanded by neither the CLI nor PowerShell inside a quoted argument. Pass the path the user gave you as they gave it, quoted when it contains spaces, and never rewrite one platform's form into the other's.
15. **Never use illustrative media examples as actual inputs.** For `image` / `video` / `audio` inputs, any sample URL, path, or asset from `describe` output (`sample:`, `x-cawcut-sample-url`), SKILL.md, `references/`, or other docs is **hint only** — not a usable resource. Do **not** pass them to `--input` unless the user explicitly provided that exact file or URL in this conversation. If required media is missing, show the media sub-menu (rule 12) and wait — do not run with fabricated or placeholder examples; do not ask for a bare URL/path without choices.
16. Pass `--wait` so long jobs block until completion; relay all result URLs.
17. Always pass `--download` when the result is an image, video, or audio file. The CLI resolves the platform-appropriate downloads folder automatically (`~/Downloads` on macOS/Linux, `%USERPROFILE%\Downloads` on Windows) — do not hardcode a path or download the result yourself. Only skip `--download` if the user explicitly says they only want the URL.
18. Do not guess key names — they vary per app. Always derive from describe output (agent-side only; never expose key spelling work to the user).
19. Understand app sources before selecting an app:
   - `Official Apps`: curated apps owned by the CawCut official account.
   - `My Apps`: apps owned by the authenticated user.
   - `Shared Apps`: apps another user shared with the authenticated user.
   If the user asks for "official" or "shared", pick only from that section of `cawcut app list`.
20. **Don't pre-inspect local media before attempting the run** — do not shell out to `ls`/`file`/`sips -g pixelWidth/pixelHeight` (or similar) to check a local file's size or dimensions before running. Attempt `cawcut app run` directly; if upload pre-flight fails, the CLI's error already reports the exact size/dimension and its limit — act on that error (see Errors below), not on a manual inspection you ran first.

## Workflow

### 1. List available apps

```bash
cawcut app list --schema
# optional: --category image | --category video
```

Output: Apps grouped by **output category** (Image Apps / Video Apps), then by **source** (Official / My / Shared), with **name**, description, credits, and input schema lines when available (`cawcut app list` does **not** print app IDs in human output). Identify likely matches by app name, description, `categories`, source, credits, and required input kinds. Use `cawcut app list --json` internally when you need the app ID for automation.

Example human output shape:

```
Image Apps
  Official Apps
    Photo to Sticker  2 credits  description: Turn a scene photo into a sticker
  My Apps
    My still template  description: Custom image workflow

Video Apps
  Official Apps
    Product video generator  8 credits  description: Generate a product ad video
```

Do not treat Official Apps, My Apps, and Shared Apps as interchangeable. When the same app is visible from multiple sources, prefer the source displayed by the CLI.
Translate app names/descriptions when `reply_language` is not English; keep input keys and source group names exact. **Never show app IDs in user-facing App lists.**

If the user provided a natural-language request, rank likely matches:

1. Best official app/template match, when present.
2. Best owned/shared app match.
3. Workflow canvas fallback when no App fits or the user chooses a canvas.

**Single clear match:** treat as selected — run `describe`, then present metadata + inputs tables + input menu (UX rule 3). Do not reply with only "this app can…".

**Multiple matches:** show a numbered list with name, description, source, credits, and input summary for each; after the user picks, run `describe` and disclose full details before collecting inputs.

If the user did not provide a request, still present useful choices immediately. Do not ask an empty "what would you like to run?" question.

Present choices in `reply_language`. Default example (bare skill invoke / English):

```
Here are runnable CawCut Apps:
1. Product video generator — Generate a product ad video
   Source: Official Apps; est. 8 credits; needs: prompt(text), product_image(image)
2. Generate a product ad video — My marketing template
   Source: My Apps; needs: prompt(text)
3. Apply a shared style template — Shared by another user
   Source: Shared Apps; needs: image(image)

You can:
A. Run 1 / 2 / 3 (I'll list required inputs next)
B. Describe your goal and I'll recommend the best App
C. Build a workflow canvas instead
```

If the user later writes in another language, use the same structure in `reply_language`.

If the user chooses an App (or a single App was auto-matched), immediately inspect it:

```bash
cawcut app describe "Product video generator"
```

Then present the **App metadata table**, **inputs table**, and **input collection menu** (UX rules 3, 11–12). Do not run until required inputs are resolved via menu choices — not free-form parameter typing.

**Example — user asks to capture a video's first frame** (after `describe`):

```
Found a matching App: **First/Last Frame Extractor (qa test)**

| Field | Value |
|-------|-------|
| Name | First/Last Frame Extractor (qa test) |
| Source | Official Apps |
| Cost | … credits |
| Output | First frame + last frame images |

Extracts the first and last frame from a video and outputs them as images.

| Name | Type | Required | Notes |
|------|------|----------|-------|
| … | video | yes | The video to process (MP4, WebM, etc.) |

Provide the video:
A. Use a video already shared in this chat
B. Paste an HTTPS video URL
C. Provide a local file path
```

### 2. Inspect inputs

```bash
cawcut app describe "<app name>"
```

Output: a table of inputs with KEY, KIND, required/optional, DEFAULT, and DESCRIPTION. Example:

```
App: Product video generator
Description: Generate a product ad video

Inputs — use the KEY column with --input KEY=value:

  KEY                   KIND    REQ   DEFAULT           DESCRIPTION
  prompt                text    yes   no                Ad script or product description
    requirements: Required text input.
  product_image         image   yes   no                Product photo
    requirements: Required image input. Provide an HTTPS URL, local file path, or {asset_id,url} object.

Run: cawcut app run "Product video generator" --input 'prompt=...' --input 'product_image=@/path/to/file'
```

For the raw JSON schema (includes internal app id in tool `name`):

```bash
cawcut app describe "<app name>" --json
```

### Disambiguate duplicate app names (required)

When `cawcut app describe` or `cawcut app run` returns `Multiple apps named "..."`, present a confirmation table — **still no app IDs**:

| # | Name | Source | Description | Credits | Inputs |
|---|------|--------|-------------|---------|--------|

Fill rows from the CLI message (source, description, credits, input schema lines). Ask the user to pick by number or describe which copy they want. Then run:

```bash
cawcut app run "3D Model Generator" --pick 2 --input ... --wait --download --json
```

Only use `--pick` after the user confirms. If names are unique, omit `--pick`.

### Present app inputs to users (required)

**CawCut App inputs come from `cawcut app describe`** — a KEY/KIND table plus requirement lines. Some CLIs print a ready param table from a dedicated `model get`-style command; CawCut does not. **Render a user-facing markdown table** when explaining an App; do not paste raw CLI output or vague prose.

**Presentation rule:** tables are for **visibility**; interaction is always **numbered menus** for enumerable/fixed values (same as `cawcut-generate`). Do not turn the table into "fill in each row" free input.

Use this column layout:

| Name | Type | Constraints / format | Default | Required | Notes |
|------|------|---------------------|---------|----------|-------|

**Row mapping from `describe` / `--json`:**

| Source | Table column |
|--------|--------------|
| KEY (`properties` key in JSON) | Name — exact `--input` key; may contain spaces — quote in shell |
| `x-cawcut-input-kind` or KIND | Type: `text` / `image` / `video` / `audio` |
| `oneOf` / requirements text | Constraints — `HTTPS URL`, `@/local/path`, `{asset_id,url}` |
| `x-cawcut-has-default` + default | Default — `none` when false |
| `x-cawcut-required` | Required — `yes` / `no` |
| DESCRIPTION + requirements | Notes — human label; `x-cawcut-sample-url` / `sample:` lines are illustrative only — never pass as `--input` |

**App metadata table** — include above the inputs table:

| Field | Value |
|-------|-------|
| Name | from list/describe |
| Source | Official Apps / My Apps / Shared Apps |
| Category | from `categories` in list JSON |
| Cost | credits from `app list --schema` |
| Output | image / video / audio / text (prefer `categories`) |

Do **not** include App ID in user-facing tables. Resolve ID from a fresh `cawcut app list --json` run in this turn when calling the CLI.

**Example — Photo to Sticker**:

| Field | Value |
|-------|-------|
| Name | Photo to Sticker |
| Source | Official Apps |
| Cost | 6.9 credits |
| Output | Sticker-style image (metallic outline + enamel border) |

| Name | Type | Constraints / format | Default | Required | Notes |
|------|------|---------------------|---------|----------|-------|
| `Input - Scene Photo` | image | HTTPS URL, `@/local/path` (auto-upload), `{asset_id,url}` | none | yes | Scene/person photo → sticker effect |

**User-facing menu (after table):**

```
Scene photo for Photo to Sticker:
A. Use a photo already shared in this chat
B. Paste an HTTPS image URL
C. Provide a local file path
```

```bash
cawcut app run "Photo to Sticker" \
  --input "Input - Scene Photo=@/path/to/photo.jpg" \
  --wait --download --json
```

Always run `describe` for the live app — keys and credits vary per app and environment.

**CLI flags table** for `cawcut app run`:

| Name | Type | Constraints / options | Default | Required | Notes |
|------|------|----------------------|---------|----------|-------|
| `<app_ref>` | string | App **name** from list, or internal ID | — | yes | quote if spaces; add `--pick <n>` when name is ambiguous |
| `--pick` | number | 1-based index from disambiguation list | — | no | only when multiple Apps share the same name |
| `--input` | key=value | KEY from describe | — | per schema | repeatable; quote keys with spaces |
| `--input-json` | file | JSON object | — | no | mutually exclusive with `--input` |
| `--wait` | flag | — | off | recommended | block until done |
| `--download` | flag \| path | omit = system Downloads | off | recommended | auto-save media results |
| `--json` | flag | — | off | recommended | structured output |

### 3. Run with inputs

**Pre-flight check:** use this turn's live catalog to resolve the selected App ID,
then validate inputs against live `describe`. If the selected App is missing,
inaccessible or incompatible, report it and offer workflow canvas planning or an
App refresh. Preserve the current route during input answers; only goal/target
changes or an explicit refresh reopen matching.

Always pass `--json` so the CLI outputs structured JSON instead of plain text — this prevents the agent from truncating the signed result URL.

```bash
cawcut app run "Product video generator" \
  --input prompt="summer sale, bright colors" \
  --input product_image="https://cdn.example.com/shoe.jpg" \
  --wait --download --json
```

Local file (auto-uploaded to CawCut assets):

```bash
cawcut app run "Product video generator" \
  --input prompt="summer sale" \
  --input product_image="@./shoe.jpg" \
  --wait --download --json
```

Multiple inputs:

```bash
cawcut app run "<app name>" \
  --input key1=value1 \
  --input key2=value2 \
  --wait --download --json
```

JSON file (alternative for many keys or values with special characters):

```bash
cawcut app run "<app name>" --input-json ./inputs.json --wait --download --json
```

`inputs.json` shape:
```json
{ "prompt": "...", "product_image": "https://cdn.example.com/img.jpg" }
```

Do not combine `--input` and `--input-json` in one invocation.

**Media upload pre-flight failures (size/dimension)** — local `@` paths trigger upload validation before the run proceeds. If the CLI prints a plain-text limit message (e.g. `Audio file size is 22.9 MB (limit 15 MB). Re-encode or trim…`) with **no** `Code:` / `Category:` / `Suggested actions:` markers, that still requires recovery — do **not** just echo the error. **Always** call `AskUserQuestion` / `AskQuestion` first with: compress/resize for the user now (`sips`/`ffmpeg`) and retry, let them fix it, or cancel. Numbered text **only** if the tool is unavailable. Never suggest CawCut Web. See `references/troubleshooting.md` for exact commands per failure type (MB limit vs longest-edge px are different fixes). Same rule in the **Errors** table below.

### 4. Download result

`--download` is already included in the run commands above. The CLI resolves the correct system downloads folder automatically — no path needed.

### 5. Deliver

The CLI outputs JSON when `--json` is used:

The `local_path` values are that platform's own: `/Users/.../file.png` on macOS,
`C:\Users\...\Downloads\file.png` on Windows. Report them back as the CLI printed them.

```json
{
  "result_url": "https://cdn.cawcut.com/...?Expires=...&Signature=...&Key-Pair-Id=...",
  "result_urls": [
    "https://cdn.cawcut.com/...?Expires=...&Signature=...&Key-Pair-Id=...",
    "https://cdn.cawcut.com/...?Expires=...&Signature=...&Key-Pair-Id=..."
  ],
  "task_id": "...",
  "local_path": "/Users/.../file.png",
  "local_paths": ["/Users/.../file-1.png", "/Users/.../file-2.png"],
  "status": "done",
  "credits_used": 12.0,
  "credits_balance": 88.0
}
```

### 6. Hand off to the VN skill

After delivering the results, hand off unconditionally to **`cawcut-vn`** with every delivered local path (`local_paths`, or `local_path` when only one). It owns the entire VN decision — preview-and-import, editing flow, or no action — including whether VN is installed. Do not ask a VN menu here, do not run `cawcut vn` commands here, and do not re-run the App to satisfy the receiving skill's choice (decide-once).

## Input kinds and formats

| KIND | `--input` format | Notes |
|------|-----------------|-------|
| `text` | `key=some text value` | String; numbers/booleans coerced to string |
| `image` | `key=https://…` or `key=@/local/path.jpg` | Local files are auto-uploaded; URL passed as-is |
| `video` | `key=https://…` or `key=@/local/path.mp4` | Same upload behaviour as image |
| `audio` | `key=https://…` or `key=@/local/path.mp3` | Same upload behaviour as image |

The `@` prefix explicitly marks a local path for upload. Bare paths (e.g. `./file.jpg`) are also auto-detected and uploaded if the file exists.

## Async tasks

The CLI always prints `Task: <task_id>` to stdout **before** polling starts. Capture it — it is your recovery handle.

- With `--wait`: CLI blocks, then prints all result URLs on success.
- Without `--wait`: CLI prints `Check status with: cawcut task status <task_id> --wait`.
- If `--wait` times out: CLI prints `Polling timed out. Resume with: cawcut task status <task_id> --wait` — run that command to resume.

## Errors

If the CLI prints `Code:`, `Category:`, or `Suggested actions:`, present those numbered actions to the user before retrying. Use `references/troubleshooting.md` for fallback handling of token, app access, missing input, invalid input, credits, content policy, and timeout errors.

Many other failures are plain-text CLI messages **without** those markers — use the symptom→action table below (including media upload pre-flight size/dimension limits).

Extract `result_urls` from the JSON when present and present every URL to the user. For backward compatibility, `result_url` is the first URL. Also share every `local_paths` entry if present. Use exact signed URL values — do not truncate or strip query parameters (the `?Expires=...&Signature=...&Key-Pair-Id=...` part is required for access).

**Always** also report `credits_used` (or `credits_estimate` if `credits_used` is absent) and `credits_balance` (or `credits_balance_error`) from the same JSON — every single completed run, even back-to-back ones in the same session. Never omit this because it was already shown for a prior run.

| Symptom | Action |
|---------|--------|
| App not found | Re-run `cawcut app list`; verify App name spelling |
| Multiple apps with same name | Show disambiguation table (source, description, inputs); get user confirmation; re-run with `--pick <n>` |
| App is not under Official Apps | Check My Apps and Shared Apps too; a user-owned or shared App is valid but should not be described as official. |
| `unknown input key "..."` | Check `cawcut app describe "<app name>"`; fix key spelling |
| `Token expired` | Follow the login steps in Step 0; retry the failed command once after `status=authenticated` |
| Media upload pre-flight fails (size/dimension) | Do not just print the error — **always** call `AskUserQuestion` / `AskQuestion` first with: compress/resize for the user now (`sips`/`ffmpeg`) and retry, let them fix it, or cancel. Numbered text **only** if the tool is unavailable. Never suggest CawCut Web. See `references/troubleshooting.md` for exact commands per failure type (MB limit vs longest-edge px are different fixes). |
| Run fails on model media limits | Inspect `cawcut workflow nodes --capability <c> --model <id> --schema --json` → `medias[].limit`. |

See `references/app-inputs.md` for deeper input resolution details.

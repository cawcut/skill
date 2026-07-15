# App presentation (cawcut-app-run)

Use whenever you explain a CawCut App to the user — discovery questions, recommendations, or before collecting inputs. **Do not** summarize Apps as bullet lists from JSON alone; run `cawcut app describe "<app name>"` for the matched App.

## Metadata table (required)

| Field | Value |
|-------|-------|
| Name | from list/describe |
| Source | Official Apps / My Apps / Shared Apps |
| Category | from `categories` in list JSON — `image`, `video`, `text`, `audio` (comma-separate when multiple) |
| Cost | credits from `app list --schema` |
| Output | image / video / audio / text (prefer `categories`; else infer from name/description) |

Lead with **App name** and a one-sentence description in prose (`reply_language`). Never say only "this app" without naming it.

## Inputs table (required)

| Name | Type | Constraints / format | Default | Required | Notes |
|------|------|---------------------|---------|----------|-------|

**Row mapping from `describe` / `--json`:**

| Source | Table column |
|--------|--------------|
| KEY | Name — exact `--input` key; quote in shell if spaces |
| `x-cawcut-input-kind` or KIND | Type: `text` / `image` / `video` / `audio` |
| `oneOf` / requirements text | Constraints — `HTTPS URL`, `@/local/path`, `{asset_id,url}` |
| `x-cawcut-has-default` + default | Default — `none` when false |
| `x-cawcut-required` | Required — `yes` / `no` |
| DESCRIPTION + requirements | Notes — human label; `sample:` / `x-cawcut-sample-url` are hints only |

Do **not** include App ID in user-facing tables.

## Catalog list (multiple Apps)

When listing or shortlisting Apps, group by **output category** first, then numbered entries inside each section. Do not mix image and video Apps in one undifferentiated list when both are present.

### Image Apps

| Name | Description | Source | Credits | Inputs |
|------|-------------|--------|---------|--------|
| Paper Cut Sticker | paper-cut sticker from scene photo | Official Apps | 2 | scene photo (image) |

```
1. Paper Cut Sticker — Turn a scene/person photo into a paper-cut sticker effect
   Source: Official Apps; category: image; est. 2 credits; needs: scene photo(image)
```

### Video Apps

| Name | Description | Source | Credits | Inputs |
|------|-------------|--------|---------|--------|
| Product video generator | product ad video | Official Apps | 8 | prompt(text), product_image(image) |

```
1. Product video generator — Generate a product ad video
   Source: Official Apps; category: video; est. 8 credits; needs: prompt(text), product_image(image)
```

**AskQuestion labels:** include category when helpful — `Paper Cut Sticker — paper-cut sticker (image; 2 credits; image)` or `Product video generator — ad video (video; 8 credits; text+image)`.

## Discovery questions (no run intent yet)

When the user asks what an App does, what it generates, what inputs it needs, or wants to browse the catalog (e.g. "what can Paper Cut Sticker generate", "what apps are available", "what official Apps are there") — set `intent = discovery`. Answer with the tables below and **stop** there; do not start collecting run inputs until the user asks to run it.

- **Single named App** or one App scores ≥ 70 and the question is informational: run `describe`, render metadata table + one-sentence prose + inputs table, end with a short offer to run.
- **Multiple plausible Apps**: catalog list grouped by category, or `AskQuestion` with 2–4 Apps; on pick → `describe` + tables + offer to run.
- **Browse all Apps**: catalog list grouped by `categories` (image / video) from `cawcut app list --schema` run in this turn.

## Example — Paper Cut Sticker

| Field | Value |
|-------|-------|
| Name | Paper Cut Sticker |
| Source | Official Apps |
| Cost | 2 credits |
| Output | Paper-cut style sticker image |

**Paper Cut Sticker** turns a scene or person photo into a paper-cut sticker effect.

| Name | Type | Constraints / format | Default | Required | Notes |
|------|------|---------------------|---------|----------|-------|
| `Input - Scene Photo` | image | HTTPS URL, `@/local/path` (auto-upload), `{asset_id,url}` | none | yes | Scene/person photo for the sticker effect |

After tables, offer next step only — do not jump to input collection unless the user wants to run:

```
Want to run Paper Cut Sticker? Share a photo (chat / HTTPS URL / local path) and I'll generate it.
```

## Forbidden patterns

- Bullet-only summaries (`Function: … Input: … Output: …`) without metadata + inputs tables
- Parsing `app list --schema --json` fields into prose instead of calling `describe`
- Showing input KEY names as something the user must type before they choose to run
- Vague lines like "this app can help you…" with no App name, source, or input summary

# Intent matching (live catalog only)

Score how well a user's request matches each App returned by `cawcut app list --schema --json`. Use **only** fields present in that JSON — never hardcode App names, templates, or examples from training data.

## Catalog fields to use

| Field | Use for |
|-------|---------|
| `name` | Exact, partial, and token overlap with the user's words |
| `description` | Semantic overlap with the user's goal, deliverable, or domain |
| `source` | Filter when the user asks for official, own, or shared Apps |
| `categories` | Filter or boost when the user wants image vs video output (`image`, `video`, `text`, `audio`) |
| `credits` | Tie-breaker only; mention in menus, not in scoring |
| Input schema (types, required flags, summaries) | Whether the user's stated inputs fit what the App expects |

## Scoring dimensions (0–100 per App)

Add points from each dimension. Cap the total at 100.

### 1. Name alignment (0–35)

| Signal | Points |
|--------|--------|
| User quoted or clearly referenced the App `name` (exact) | 35 |
| User used a distinctive substring of `name` (≥4 chars, not a generic word) | 20 |
| Significant token overlap between user request and `name` (≥2 meaningful tokens) | 10 |
| No meaningful name overlap | 0 |

Generic words (`video`, `image`, `generate`, `create`, `app`) alone do **not** count as name alignment.

### 2. Description alignment (0–35)

| Signal | Points |
|--------|--------|
| User goal clearly matches the App `description` (same deliverable or workflow type) | 35 |
| Partial overlap — user mentions a subset of what the description promises | 20 |
| Weak thematic overlap only (same broad domain, different task) | 8 |
| No overlap | 0 |

### 3. Input schema fit (0–20)

| Signal | Points |
|--------|--------|
| User already provided or offered media/text that satisfies required inputs | 20 |
| Required input **kinds** match what the user implied (e.g. they mention a product photo and the App requires an image input) | 12 |
| User intent is compatible but inputs not yet provided (App still plausible) | 5 |
| Required inputs conflict with the request (e.g. App needs audio, user wants still image only) | −15 |

### 4. Workflow vs simple generation (0–10)

| Signal | Points |
|--------|--------|
| Request implies multi-step or branded/template workflow (campaign, ad suite, batch variants, presenter flow, structured inputs) | +10 |
| Request is a single-shot generate/edit/animate with no template cues | 0 |
| Request is explicitly "just generate" / "raw model" / names a capability | −10 (prefer a workflow canvas if no App fits) |

### 5. Source preference (modifier)

Apply **after** summing dimensions 1–4:

| User signal | Modifier |
|-------------|----------|
| Asked for official Apps only | Set score to 0 for non-official `source`; +5 for official matches |
| Asked for "my" Apps only | Set score to 0 for non-owned `source` |
| Asked for shared Apps only | Set score to 0 for non-shared `source` |
| No source preference | 0 |

**Category modifier** — when the user clearly wants image or video output:

| User signal | Modifier |
|-------------|----------|
| Wants image and `categories` includes `image` | +10 |
| Wants video and `categories` includes `video` | +10 |
| Wants image but App is video-only (`categories` = `["video"]`) | −20 |
| Wants video but App is image-only (`categories` = `["image"]`) | −20 |

## Routing thresholds

| Total score | Interpretation |
|-------------|----------------|
| **≥ 70** | Strong match — treat as **selected**: run `describe`, present tables, collect inputs |
| **40–69** | Possible match — include in shortlist; use **`AskQuestion`** if multiple Apps land here |
| **< 40** | Weak match — exclude from shortlist |

Apply these scores in `cawcut-workflow`'s route step. No suitable App, an empty
catalog or a canvas choice returns to workflow planning, including for single-step
requests. Naming a capability does not bypass App matching. An explicit
`/cawcut-generate` invocation runs before this lookup.

## Anti-patterns

- Use live catalog evidence for the current goal; refresh on goal/account/target
  changes, access errors or an explicit refresh. Same-goal input answers preserve
  the route; see `SKILL.md` Catalog freshness.
- Do **not** invent Apps that are not in the JSON.
- Do **not** use example product or campaign names as fixed match keys — only compare user text to live `name` / `description` / schema.
- Do **not** route to app run solely because the user said "create" or "make" — those are generic; require name, description, or schema fit.

## Worked pattern (structure only)

```
User: "<goal in natural language>"
Catalog: [ Apps from JSON ]

For each App:
  name_score + description_score + schema_score + workflow_score + source_modifier
  → total (cap 100)

Sort descending → apply thresholds → decide
```

Replace `<goal>` and catalog entries with live data on every invocation.

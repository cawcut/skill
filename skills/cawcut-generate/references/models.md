# Discovering models and parameters

**Do not use this file as a model or parameter catalog.** Available models depend on the signed-in user's billing plan. Always fetch the live list from the CLI.

## Commands (staged — prefer scoped fetches)

```bash
# Capability names only
cawcut capabilities list

# Lightest model list for one capability (agent-friendly)
cawcut capabilities list --simple --capability text-to-video

# Lean JSON — model_id/name/capability/default only, one capability
cawcut capabilities list --models --json --capability text-to-image

# Full schema for ONE model only (before --param / settings menu)
cawcut capabilities list --models --schema --json --capability text-to-video --model "Seedance 2.0"

# Human-readable model list with parameters (text, quick look)
cawcut capabilities list --schema --capability text-to-image
```

**Avoid** bare `cawcut capabilities list --models --schema --json` without `--capability` — it returns all five capabilities (~100KB) and may be truncated in agent sessions.

`--simple` prints one line per model: `model_id: name (default)`. `--models --json --capability <cap>` is lean JSON for model picking. Add `--schema` and `--model "<id>"` when you need `parameters`, `aspect_ratios`, `durations`/`duration_range`, or `medias`.

## How to read scoped `--schema --json` output

Top-level keys are capability names. Each value is an array of models (usually one entry when `--model` is set).

Per model object:

| Field | Use for |
|-------|---------|
| `model_id` | Value for `--model` (quote if it contains spaces) |
| `name` | Display label |
| `default` | `true` → omit `--model` to use this model |
| `parameters` | `--param` keys: `name`, `type`, `default`, `options`, `min`, `max`, `description` |
| `aspect_ratios` | Allowed ratio / aspect_ratio values when present |
| `durations` / `duration_range` | Video length options or bounds |
| `medias` | Required/optional `--image` / `--video` / `--audio` limits (`max` count, `roles`, optional `limit` with model byte/dimension constraints) |

Recraft V3 `colors` (when that model appears in your plan): read `palette_presets`, `applicable_when`, and `description` from the `colors` entry in `parameters` — do not use hardcoded palettes.

## Default model source

Use BE's `default: true` flag as the source of truth. Each capability should return exactly one default model. If a capability has no default or multiple defaults, ask the user to choose explicitly from that capability's model list.

Fallback only when live discovery cannot run and the user still wants to proceed:

| Capability family | Fallback default |
|-------------------|------------------|
| Image generation/editing | `gpt-image-2` |
| Video generation/animation/omni | `Seedance 2.0` |

## Session `workflow_id`

After the first successful `generate`, capture `workflow_id` from JSON and pass `--workflow-id <id>` on **every** follow-up in the same session — including capability changes (text-to-image → image-to-image → text-to-video). BE appends nodes; history stays in one project. For media capabilities, pass `--image` / `--video` / `--audio` from prior `result_urls` or user files; outputs are not auto-wired between steps.

## Agent workflow

1. Infer or ask for `capability`.
2. Run `cawcut capabilities list --simple --capability <cap>` — **only** offer models listed there.
3. After the user picks a model (or accepts default), run `cawcut capabilities list --models --schema --json --capability <cap> --model "<id>"`.
4. Build `--param key=value` from `default` and `options` in that JSON — never from memory or old docs.
5. Present settings menu with **change model** for both image and video before `cawcut generate`.
6. Arrays/objects: use JSON in the value, e.g. `--param 'colors=[]'` or `--param 'colors=["#RRGGBB",...]'`.

Do **not** write Python or multi-step shell scripts to parse capabilities JSON — use CLI filters above.

## Passing params

```bash
cawcut generate "<prompt>" \
  --capability text-to-image \
  --model "<model_id from JSON>" \
  --param ratio=16:9 \
  --wait --download --json
```

Model IDs with spaces or parentheses must be quoted: `--model "GPT Image 1"`.

If the user does not specify a model, omit `--model` and use the entry with `"default": true` for that capability.

## `loop` vs `num_images`

| User intent | Flag |
|-------------|------|
| Up to 4 images in **one** API call (model has `num_images` in `parameters`) | `--param num_images=N` |
| **N parallel candidates** (any model; also video later) | `--loop N` (max 4) |
| More than 4 candidates | Do **not** run CLI; tell user max is 4 |

`loop` adds N independent generation nodes in the same workflow for this request. It is not the workflow execution count.

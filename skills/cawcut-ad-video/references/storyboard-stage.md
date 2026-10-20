# Stage ④ — Storyboard (procedures)

SKILL.md owns the order of the flow. This file holds the procedures behind each step. Command syntax for characters/locations: `character-scene.md`; script edits: `script-editing.md`.

## The review script

```bash
bash <base_dir>/scripts/storyboard_review.sh <id> [--dest dir] [--until display|ready]      # macOS/Linux
powershell -ExecutionPolicy Bypass -File "<base_dir>\scripts\storyboard_review.ps1" <id>      # Windows
```

One call: waits for display (`storyboard status --wait --until display`), takes the script working copy, renders the table with `script_plan`, saves entity images with `cawcut ad-video entities download`. It prints one JSON: `next_step`, `portal_url`, `script_table`, `plan_path`, `entities[]` (`status`, `names`, `editable`, local `files`), `failed_downloads`.

`next_step`: `wait` keep polling · `review` an entity is still generating — show what is ready and refresh · `review_ready` everything is ready · `fix_failed` explain the failure, retry only with the user's consent. Its `review` field is `review next`: show **one item per turn**, the one `review.next` names (character → location → script), then `review approve --item <item>`. The same JSON serves all three, so re-run it only after a change; an approval is dropped automatically when that item is regenerated.

## Steps 1–2 — which entities, and the fee

- `character estimate <id> --wait --wait-timeout 600 --json`. The estimate is free (decision nodes only). `character.needed` / `location.needed` say which entities the script needs; `estimated_credits` is the fee for generating them. A failed decision is an error, not "no entity" — explain, then `--retry` only with consent.
- The first-estimate `confirmation_token` goes to `storyboard run <id> --confirmation-token <token> --json`. Never swap it with a single-entity token.
- Unstarted legacy script: `storyboard run <id> --json` without estimation. Already-successful scripts keep their current stage with no extra charge.
- Check `credits_sufficient` per Quote timing in SKILL.md before asking to spend.

## Steps 3–4 — reviewing and changing a character or scene

Show name, image (local file from the script JSON), **image prompt** and status — name and prompt come from `entities[].names` / `prompts` (the Portal edit dialog shows the same two fields); show the full prompt text, never a summary. Own-image upload and voice choice (`character set --image` / `--voice-id`, `ad-video voices`) are **not open yet** — do not offer or run them; if the user asks, say so. Available:

- **Regenerate from a new prompt:** first show the current name and prompt, ask for the new prompt (and a new name only if the user wants one — add `--name` to the same `character set`). `character set <id> --entity <character|location> --prompt "<text>"` → `character quote <id> --entity <e>` → show `estimated_credits`, confirm → immediately `character run <id> --entity <e> --confirmation-token <token> --wait`. Save the prompt before quoting; a changed input or an expired token needs a fresh quote. Cancelling leaves the new prompt saved and the old image stale — say so, do not roll back or render downstream from it.
- **Rename:** `character set --entity <e> --name <name>`; no regeneration. Refresh the script mapping (`script_plan take`) before editing the script afterwards.
- After any change re-run `storyboard_review` (or `entities download`), show the new image, ask the same question again. An image change makes the photo/final outputs stale — follow the `need_regenerate` flags before continuing.

## Step 5 — the script

The review table comes from the `script_plan` helper (the review script already ran `take` + `render`); never convert `{{ key }}` / `@name` mentions yourself. Table: plan-level `title`, `synopsis`; per shot **Shot #**, **Duration**, **Shot Type**, **Shot Description**, **Voiceover** (`dialogue`; omit for `product_showcase`), **Camera**, **Light**, **SFX**. Never show `shot_prompt`, `video_prompt` or their statuses. Always include the Portal link.

- `✏️ Work on the script` → `script-editing.md` (edits file → `script_plan show` → one `storyboard set`). Nothing reaches the server until the user confirms.
- `🔁 Regenerate the script` → `storyboard run <id> --force` + poll; discards every edit, so warn first and re-show the table afterwards.
- Before paid continuation check `storyboard status <id> --wait --until ready`; `content_revealed` alone is not readiness.

## Steps 6–7 — images and visual direction

`image next <id> --json` returns `mode`, `next_step` (`sketch` | `visual_direction` | `photo` | `done`) and the saved `instruction`; SKILL.md lists the action per value. The CLI refuses a photo-realistic `image quote`/`image run` until the visual direction was answered, so the question cannot be skipped — and a fresh sketch run re-opens it.

One text (≤ 3000 chars) feeds the photo-realistic storyboard and the final video. It does not change the script. Needs an approved script; legacy projects reject it (the gate never applies to them).

1. Show `instruction` (`content`, `applied_content`, `enabled`) if set.
2. `✅ No extra direction` → `instruction confirm <id>`. `🎨 Add or change` → ask for the text, then `instruction set <id> --prompt "<text>" --enabled true --json` (this also counts as answered). Empty text with `--enabled false` clears it. Confirm what was saved.
3. **Invalidation.** Saving deletes nothing; it flags `outputs.storyboard_sketch` / `outputs.storyboard_image` with `need_regenerate: true`, and the final video follows once images are rebuilt. Toggling `enabled` counts as a change.
   - No photo-realistic image yet: nothing to warn about, continue with `image next`.
   - Images or video exist: **say they are stale and need a paid re-run, ask first** (`✅ Apply and regenerate` / `↩ Keep current`). Do not save before the answer. After saving, `image next` drives the re-run (a re-run sketch asks the question again — offer `✅ No extra direction` as the default).
4. Quote after saving; a changed instruction needs a fresh quote and token. Never show a stale preview as final.

`image quote` → confirm → `image run` immediately (token TTL 5 min). Poll `storyboard_sketch` / `storyboard_image` with the 3600 deadline. Preview with `download_media <id> --kind storyboard`. If the user edits `duration` or the shot set afterwards, the sketch, panels and final video go stale — run the invalidation protocol in SKILL.md.

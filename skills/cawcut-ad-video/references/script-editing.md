# Ad Video — editing the storyboard script

Stage ④ hands the script to the agent to write. The user iterates with you in the conversation; the result reaches the backend **once**, when they confirm. This is the contract for that edit — read it before the first change.

## The shape of the job

The plan is a **file in the project folder**, and the table the user reads is rendered from that file. Use `scripts/script_plan.sh` on macOS/Linux or `scripts/script_plan.ps1` on Windows:

```bash
bash <base_dir>/scripts/script_plan.sh take <id> [--dest <dir>]   # write the working copy
bash <base_dir>/scripts/script_plan.sh show <plan.json> <edits.json>   # apply edits, print the table
bash <base_dir>/scripts/script_plan.sh render <plan.json>         # just reprint the table

# Windows PowerShell
powershell -ExecutionPolicy Bypass -File "<base_dir>\scripts\script_plan.ps1" take <id> [-Destination <dir>]
powershell -ExecutionPolicy Bypass -File "<base_dir>\scripts\script_plan.ps1" show <plan.json> <edits.json>
powershell -ExecutionPolicy Bypass -File "<base_dir>\scripts\script_plan.ps1" render <plan.json>
```

- **`take` once.** It writes `<dest>/storyboard/script.json` (the plan) and `script.meta.json` (the video type, so the table knows whether the Voiceover column applies). Default dest is the project folder the matching `download_media` helper uses (`~/Downloads/...` on macOS/Linux, `%USERPROFILE%\\Downloads\\...` on Windows).
- **Edit the file through an edits file, never by retyping.** The edits file maps a shot to the fields to change — no JSON is ever typed into a shell argument, and the script refuses an unknown shot, an unknown field, or a structural one (`assets`, `character_refs`, `shot_no`, statuses) rather than dropping it silently:

  ```json
  { "title": "…", "synopsis": "…",
    "shot-3": { "shot_description": "…", "shot_prompt": "…", "video_prompt": "…" } }
  ```

- **Show, don't save.** `show` applies the edits and prints the **whole current review table** — every shot and every user-reviewable field — with the fields it changed listed on stderr. `shot_prompt` and `video_prompt` remain in the plan and are submitted, but are intentionally not rendered. **That stdout is a tool result the user does not see**: paste the whole table into your own reply, after a line saying what changed. The user is reading a script, not a diff, and a diff-only reply makes them reconstruct the rest from memory. The server sees nothing until "Save once".
- **Never hand-write the table.** It is rendered from the file so the user reviews exactly what will be saved; a table typed from memory is a different document. The renderer escapes pipes, renders both actual and JSON-escaped newlines as `<br>`, and drops the Voiceover column for `product_showcase`. Prompts and their statuses are deliberately hidden.
- **One save at the end.** That is the point of the flow: one revision bump, one downstream invalidation, one credit decision.

## What you are writing

| field | what it is |
|---|---|
| `shot_description` | what happens on screen, in prose — the shot a human reads |
| `dialogue` | the spoken line (Voiceover); not part of `product_showcase` |
| `shot_type`, `camera`, `light`, `sfx` | the shot's grammar — option values come from `cawcut ad-video options --json` → storyboard section |
| `shot_prompt` | **the still image**: composition and framing, subject and action frozen, product appearance held, background, lighting, look |
| `video_prompt` | **the motion**: subject action, camera move, lighting continuity, sound design, continuity and the negative constraints |

Write both prompts in the language the script's prompts are already in (the generator wrote them in `video_settings.language`), and keep the platform's shape: `video_prompt` opens with the duration and then walks 画面 / 调度 / 镜头 / 光线 / 声音 / 连续性 / 限制.

## The association you own (hidden prompts still update)

Changing a field changes what its prompt has to say. The web portal applies this same contract:

| changed | rewrite in the same turn |
|---|---|
| `shot_type`, `shot_description` | `shot_prompt` |
| `duration`, `shot_type`, `shot_description`, `dialogue`, `camera`, `light`, `sfx` | `video_prompt` |

**A save that leaves a prompt describing the pre-edit shot is a bug, not a shortcut** — the image and video stages render from those prompts, so the old text silently produces the old video. Update the prompts in the same edits file and submit them, but never include their contents in the user-facing review table or reply.

**The other path is the platform's.** If you would rather not write the prompts (or the user asks for the platform's own), save with `--update-prompts --prompt-target <shot_id>:<shot_prompt|video_prompt>[,…]` (repeatable) and let the Prompt Generator redo them against your edited script, then poll `.outputs.storyboard_plan.prompt_status` → `succeeded` (600s). It reads the saved script, so your edits are its input; it merges back only the fields you target. You may mix — hand-write some shots, target others.

## The server's limits — pre-validate before the one save

The whole plan is rejected if any of this fails, so check your copy first:

- `schemaVersion` = 1; `title` and `synopsis` non-empty
- **the shot count is fixed**: never add or remove shots (the portal has no such action). The generated script holds 1–16 of them, `shot_id` must be `shot-N`, and `shot_no` must match its position — so the ids are positional, not stable identifiers
- `duration`: whole seconds, ≥ 1, and ≤ `duration_seconds − shots.length + 1`; the **total** must stay ≤ the Stage ② `duration_seconds`
- no empty required field (`shot_description`, `shot_prompt`, `video_prompt`)
- lengths, in runes: `shot_description` 500 · `shot_prompt` 500 · `video_prompt` 1200 · `light` 160 · `sfx` 160 · `dialogue` 100 — and the voiceover must fit its shot (8 chars/s for CJK, 24 for other languages)
- `outputs.storyboard_plan.constraints` carries the same contract; when it is present, prefer it over this list

## References to assets — carry, never invent

`{{ asset_key }}` inside `shot_description` / `shot_prompt` / `video_prompt`, plus each shot's `character_refs` and `scene_ref`, are validated against `value.assets`:

- **preserve them exactly**, `assets` included. A plan that drops `assets` fails on every shot that uses a ref.
- **never invent one.** The character/scene stage is off on the developer path, so a project created here has `assets: {characters: [], scenes: []}` and no refs at all — a made-up `{{ … }}` is an immediate `400`.
- a project created on the web by an engineer's account can carry both. They are not yours to clean up.

## Starting over

`cawcut ad-video storyboard run <id> --force` writes a new script from the same idea and config — the script LLM runs again and **everything saved here is discarded**. Reach for it when the user wants the platform's version rather than your edits, and warn before running it.

A plain `storyboard run` (no `--force`) will not do it: the server fingerprints the stage inputs, finds them unchanged, and reuses the existing result — edits included.

## Saving

```bash
cawcut ad-video storyboard set <id> --base-revision <value.revision> --plan-file <dest>/storyboard/script.json --json
```

`base_revision` is the `value.revision` from your latest `detail` read. `409` means someone saved in between: re-read detail, re-apply your edits to the fresh plan, save again. Afterwards run the invalidation protocol — the save invalidates the sketch, the panels and the final video.

The CLI runs the checks above itself before sending: it re-reads `detail`, takes the limits from `outputs.storyboard_plan.constraints` (the server's own numbers, so they cannot drift from what the save enforces), and reports the base_revision too. A violation means **nothing was sent** — read the named shot and field, fix the plan, save again. It is never the shot you happened to edit: the whole script is checked, so a pre-existing violation in another shot is what usually surfaces. `--skip-precheck` sends the plan unchecked (only for the case where the server is ahead of the installed CLI); the save's own rejection then prints the server's reason as the first line, so never resend an unchanged plan.

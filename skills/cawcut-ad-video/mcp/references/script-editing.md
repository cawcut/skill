# Editing the storyboard script

Stage ④ hands the script to you to write. The user iterates with you in the conversation; the result reaches the backend **once**, when they confirm. Read this before the first change.

## The job

1. `ad_video_project` `get` with `view:"full"`. `outputs.storyboard_plan.value` is the whole plan: `title`, `synopsis`, `shots`, `assets` (the characters and scenes with their keys) and `revision`. `outputs.storyboard_plan.constraints` carries the limits: prefer it over the list below.
2. Keep that plan as your working copy. Apply each requested change to the field it names and leave every other value exactly as read.
3. After each change, show the **whole current review table** and say in a line what changed. The user reads a script, not a diff. The table is [the one in the storyboard procedures](storyboard-stage.md#step-5--the-script): it never shows `shot_prompt`, `video_prompt` or their statuses.
4. Save **once**, when the user confirms: one revision bump, one downstream invalidation, one credit decision. Nothing reaches the server before that.

## Mentions

Text fields refer to a character or scene as `{{ key }}`; the review shows `@name`. The CLI converts both ways with a script; here the discipline is yours.

- Show a template as `@name` using the matching entry in `assets`. Duplicate names are shown qualified, such as `@Alex [characters:c]`; use that exact label when you talk about it.
- **Never** edit, rename, re-key or invent a `{{ key }}` token. Copy each one byte for byte into the saved text. To mention an asset in new text, use a key that exists in `assets`.
- A template with no matching asset is kept as it is and reported to the user, not "fixed". Email addresses and ordinary `@` text are plain text.
- A rename or a new photo never changes a key. When unsure about a token, leave the text as it was.

## What you write

| Field | What it is |
| --- | --- |
| `shot_description` | what happens on screen, in prose |
| `dialogue` | the spoken line (Voiceover); not part of `product_showcase` |
| `shot_type`, `camera`, `light`, `sfx` | the shot's grammar; option values come from `ad_video_options` (its `storyboard` section) |
| `shot_prompt` | the still image: composition, subject and action frozen, product appearance held, background, lighting, look |
| `video_prompt` | the motion: action, camera move, lighting continuity, sound, continuity and the negative constraints |

Prompts stay in the language they are already in. Shots can never be added or removed.

## Prompts follow their fields

| Changed | The prompt that must follow |
| --- | --- |
| `shot_type`, `shot_description` | `shot_prompt` |
| `duration`, `shot_type`, `shot_description`, `dialogue`, `camera`, `light`, `sfx` | `video_prompt` |

A save that leaves a prompt describing the pre-edit shot is a bug: the image and video stages render from those prompts. **Default to the platform's path:** save with `update_prompts:true` and `prompt_targets` (`{"shot-3":["shot_prompt","video_prompt"]}`, only the fields that follow from what changed), and the Prompt Generator rewrites them against your saved script. Then wait for `storyboard_plan` `prompt_status` `succeeded`; `status` `succeeded` alone does not mean the prompts are ready. Write the prompts yourself only when the user asks, and never show them in the table or the reply.

## The server's limits

The whole plan is rejected if any of this fails, so check your copy before saving:

- `schemaVersion` is 1; `title` and `synopsis` are not empty.
- The shot count is fixed. `shot_id` is `shot-N` and `shot_no` its position, so the ids are positional, not stable.
- `duration`: whole seconds, at least 1, at most `duration_seconds − shots + 1`; the **total** stays within the Stage ② `duration_seconds`.
- No empty required field (`shot_description`, `shot_prompt`, `video_prompt`).
- Lengths in characters: `shot_description` 500, `shot_prompt` 500, `video_prompt` 1200, `light` 160, `sfx` 160, `dialogue` 100; a voiceover must fit its shot (8 characters a second for CJK, 24 for other languages).

## Saving

`ad_video_set` with `stage:"storyboard"` and `storyboard:{plan, base_revision, update_prompts, prompt_targets}`, where `plan` is the whole plan and `base_revision` is its `revision` from the latest read.

- `CONFLICT`: someone saved in between. Read again, apply your edits to the fresh plan, save again.
- `PARAM_INVALID`: the whole plan was rejected; `error` names the shot and field. It is not necessarily the shot you edited: a violation that was already in another shot is what usually surfaces. Resending the same plan cannot help.
- `STAGE_BUSY` or `NOT_READY`: a prompt rewrite or the script is still running. Wait, then save.
- After a save, read `stale_outputs`: the sketch, the panels and the final video are now out of date ([After every edit](../../SKILL.md#after-every-edit)).

## Starting over

`ad_video_generate` `storyboard` with `force:true` writes a new script from the same idea and config; **everything saved here is discarded**. Use it when the user wants the platform's version rather than the edits, and warn first. A run without `force` reuses the existing result.

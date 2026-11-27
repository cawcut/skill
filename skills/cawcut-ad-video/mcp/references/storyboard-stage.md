# Stage ④ — Storyboard (procedures)

SKILL.md owns the order. This file holds the procedures behind each step. Script edits: [script editing](script-editing.md). Showing images and video: [delivery](delivery.md#previews).

## Steps 1–2 — which assets exist, and the fee

`ad_video_quote` with `stage:"storyboard"`. It runs the free decision nodes and starts no image.

- `status:"pending"`: the decision is still running. Wait as [Reading progress](../../SKILL.md#reading-progress) says, then quote again.
- `status:"failed"`: a failed decision is an error, not "nothing to generate". Explain `error`; call again with `retry:true` only with the user's consent.
- `status:"ready"`: read `estimate`. `character.needed` / `location.needed` say which assets the script needs; `estimated_credits` is the fee for generating them. Tell the user whether the script needs a character, a location, both or neither.
- `no_charge:true`: nothing to generate or charge. Run `ad_video_generate` `storyboard` with no token.
- Otherwise [Paying](../../SKILL.md#paying) with this token. Never swap it for a single-asset token.

After the run, wait until `storyboard.next_step` is `review` or `review_ready`, and run the review round from SKILL.md; refresh as the rest lands. `content_revealed` alone is not readiness: before paid continuation wait for `preparation_ready`.

## The review queue

`review.order` is character, then location, then script; `review.items` holds the ones this project has, each with `ready` and a `fingerprint`. The round itself is in SKILL.md Stage ④.

**The server records approvals.** After the user says yes to an item, call `ad_video_review` `action:"approve"` with `item` and that item's `fingerprint` from `review.items`. A regenerated script or image, a new prompt or an edit changes the fingerprint: the approval drops (`approved:false`), so show the item and ask again. The server refuses an approval out of order (`REVIEW_OUT_OF_ORDER`), for a changed item (`REVIEW_STALE`) or for one still generating (`REVIEW_NOT_READY`), and it refuses the paid images (`REVIEW_REQUIRED`) until every item is approved. Never call `approve` without the user's yes in this conversation. When `review.enforced` is false, or the tool is not listed, the server keeps nothing: record the yes in the conversation instead, with the same fingerprint rule.

An item that is not `ready` is still generating: say so and refresh, never skip it. A failed asset (`status:"failed"`, or `storyboard.next_step` `fix_failed`) is shown and explained, never skipped; retry only with consent. Paid images (Steps 6–7) wait until every item is approved.

## Steps 3–4 — a character or a location

Show its name, its image (from `storyboard.entities[].images`), its **image prompt** in full (`names` / `prompts`) and its status. Ask **This character works** · **Regenerate from a new prompt** (a location: **This scene works**).

- **Regenerate:** show the current name and prompt, ask for the new prompt (a new name only if the user wants one). `ad_video_set` `stage:"character"` with `entity` (`character` or `location`) and `image_prompt` (and `name`) → **then** `ad_video_quote` for that `stage`, because a quote is tied to the saved inputs → [Paying](../../SKILL.md#paying) → `ad_video_generate` → wait for the new image → show it and ask the same question again. Cancelling leaves the new prompt saved and the old image stale: say so, do not roll back or build anything downstream from it.
- **Rename:** `ad_video_set` `stage:"character"` with `name` only; no regeneration.
- Own-image upload and voice choice are **not open yet**: never offer them, and if the user asks, say so.
- An image change makes the later images and the video stale: follow `stale_outputs`.

## Step 5 — the script

Show the table from `outputs.storyboard_plan.value` (`view:"full"`): the plan's `title` and `synopsis`; per shot **Shot #**, **Duration**, **Shot Type**, **Shot Description**, **Voiceover** (`dialogue`; leave the column out for `product_showcase`), **Camera**, **Light**, **SFX**. Never show `shot_prompt`, `video_prompt` or their statuses. Always include `portal_url`. Mentions are shown as `@name`: [script editing](script-editing.md#mentions). Then Ask **Looks good** · **Work on the script** · **Regenerate the script**.

- **Work on the script:** [script editing](script-editing.md). Nothing reaches the server until the user confirms.
- **Regenerate the script:** it discards every saved edit, so warn first. `ad_video_quote` `storyboard`, then `ad_video_generate` `storyboard` with `force:true` (and the token, unless `no_charge`). Wait, then show the whole table again. A plain run without `force` reuses the existing result, edits included.

## Steps 6–7 — images

`image_plan.next_step` is where the image stage stands:

| `next_step` | Do |
| --- | --- |
| `sketch` | `ad_video_quote` `images` with `generation_type:"hand_drawn"` → [Paying](../../SKILL.md#paying) → `ad_video_generate` `images` with the same `generation_type` → wait for `storyboard_sketch` → show it, then Ask **Continue** · **Edit script**. |
| `visual_direction` | Clear the direction gate below, then read `image_plan` again: the next step becomes `photo`. |
| `photo` | When `image_plan.visual_direction.ask_before_photo` is true → clear the direction gate below first. Then `ad_video_quote` `images` with `generation_type:"photo_realistic"` → Paying → `ad_video_generate` with the same type → wait for `storyboard_image` → show the grid. |
| `done` | Stage ⑤. |

The run must repeat the `generation_type` that was quoted. Read `image_plan` again after every pass or answer.

**The direction gate.** The server holds photo-realistic images until `image_plan.visual_direction.answered` is true. The wizard has no custom visual direction, so clear the gate silently: `ad_video_review` `action:"confirm_direction"` with `image_plan.visual_direction.fingerprint`, then read `image_plan` again. A fresh sketch or a script change re-opens it: clear it again. A user who asks for a custom direction hears that it is not open yet. `visual_direction.applies:false` (legacy) and `review.enforced:false` have no gate to clear.

A user edit to a shot's `duration` or to the shot set after images exist makes the sketch, the panels and the final video stale: follow [After every edit](../../SKILL.md#after-every-edit).

# Plan rules

Load at step 3 when the request matches a row.

| Request | Plan |
| --- | --- |
| Supplied audio (music, voice, sound reference), or video references for a new video, with or without images | `omni-to-video`, a model whose `--schema` has an `Audio` (or `Video`) port; pass each file with `--audio` / `--video`. Supplied audio is a reference the model follows: keep `generate_audio` at `true` (its default); `false` gives a silent video that ignores it |
| Sound wanted but no audio file ("有背景音乐", "with sound") | the capability the visual inputs pick (text-to-video, image-to-video …) with `generate_audio=true` where the model has it |
| First, opening or start frame and last or end frame | `first-last-frame-to-video` → [Frames](#frames) |
| Change existing video content (recolor, replace an object, restyle) | `video-edit` |
| Change existing image content | `image-to-image` → [Revise an image](edit.md#revise-an-image) |
| `motion-transfer`, `object-swap` | only when the user names that capability; other edits use the rows above |
| Several stages in one request (script → voice-over → images → video) where a stage waits on a user pick (voice, script approval) | [Multi-step chains](#multi-step-chains) |
| `{{Image N}}` in a prompt | N is the port name Image N; token kinds and edits: [prompt-refs](prompt-refs.md) |


## Multi-step chains

A pick is a choice only the user can make: a TTS voice, approval of a script they want to review, one of several candidates. Model settings are not picks; confirm them per step 3.

1. List the stages in order and mark each node that waits on a pick.
2. `create` one canvas with every node that waits on nothing and their edges. A consumer of a waiting node (the video that plays the voice-over) is created now; its open port is filled in step 4. Return the canvas link; run nothing.
3. Ask the picks one at a time: the [voice picker](voice-picker.md) for TTS. A script the user wants to review first runs alone and is approved before its consumers ([edit loop](edit.md#edit-loop) step 3).
4. `edit` the same canvas: `add_node` each waiting node with the picked value and `connect` it in the same batch. Read back: `valid` is true and every edge is there.
5. Check and prepare the whole chain once; one price confirmation covers it (step 4 of the main list).

Example: "写一段咖啡店口播脚本，配音，再配一张图做成视频"
- create: `s` (`text_input`, the script) · `img` (text-to-image) · `v` (`omni-to-video`, `--has-port audio`, `duration_mode` `audio_base`); edges `img:image → v:image`
- voice picker → user picks a voice
- edit: `{"op":"add_node","ref":"t","node_kind":"tts","model_id":"<tts model>","params":{"voice_id":"<picked>"}}`, `{"op":"connect","from":{"node_id":"<s>","port":"text"},"to":{"ref":"t","port":"prompt"}}`, `{"op":"connect","from":{"ref":"t","port":"audio"},"to":{"node_id":"<v>","port":"audio"}}`
- prepare the canvas, confirm once, run

Done: the waiting nodes hold the user's picks and the chain is priced once.

## Frames

1. Ask once: "Any middle frames between first and last?" Skip the question when the user already gave a count.
2. No middle frames: models from `nodes --capability first-last-frame-to-video`. `quick` fills first, then last.
3. Middle frames: models from `nodes --capability first-last-frame-to-video --has-port mid_image_1` (today Kling 4.0, up to 8). If none returns, say so; offer first and last only.
4. Do not use `quick --image` for middle frames: it fills two ports and refuses a third (`PORT_INCOMPATIBLE`). Build with `edit`: one input node per frame (`asset_id`), `connect` each to `<node>:first_image`, `<node>:mid_image_1` … `<node>:last_image`, in story order.
5. Say once: the vendor places middle frames; no second can be set.

Done: the plan row for the request is applied.

## Media duration

If the user already specified the cuts, go straight to [create the clips](split-media.md). For model selection, check the input limits even when the media was generated on this canvas.

List models with `workflow nodes --capability <c> --asset <asset_id>…`, including “More models”. For a generated voice-over or video, take the picked `asset_id` from `result_assets` in `workflow results <id> --node <producer> --json`. If the chosen model fits, or the user has yet to choose and there are compatible models, continue with the returned choices.

When the chosen model is filtered out, read its `rejections` under `filtered_out` and the input limits in its schema’s `medias[].limit`. If no model fits and none was chosen, use the limits of a model with the required input ports to propose a split. Follow the same steps when check or prepare reports a duration error. Quote the measured seconds and the applicable input limit.

- **One file is too long.** Offer to split it on the canvas. Show the proposed ranges in source order, at sentence or scene breaks when known. For example, 19 seconds with a 10-second maximum could use 0–9.5 and 9.5–19 seconds. Cover the full source. Move a cut earlier if the last part falls below the minimum. Ask whether to split at those points, keep a specific excerpt, or switch to a listed compatible model. Offer only choices that fit.
- **The total is too long.** Show the combined duration and per-run limit. If each file fits individually, offer separate runs or fewer inputs. Split an individual file only if needed. Recheck the total with the other inputs for each planned run.
- **A file is too short.** Offer a longer source or a compatible model. An empty model list without a duration rejection needs the reported port or capability issue resolved first.

When the user accepts the ranges, [create the clips](split-media.md) and recheck each planned input set before pricing.

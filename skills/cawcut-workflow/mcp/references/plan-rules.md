# Plan rules

Load at step 2 when the request matches a row.

| Request | Plan |
| --- | --- |
| Supplied audio (music, voice, sound reference), or video references for a new video, with or without images | `omni-to-video`, a model whose schema has an `Audio` (or `Video`) input port; pass each file in `audios` / `videos`. Supplied audio is a reference the model follows: keep `generate_audio` at `true` (its default); `false` gives a silent video that ignores it |
| Sound wanted but no audio file ("with sound", "background music") | the capability the visual inputs pick (text-to-video, image-to-video …) with `generate_audio=true` where the model has it |
| First, opening or start frame and last or end frame | `first-last-frame-to-video` → [Frames](#frames) |
| Change existing video content (recolor, replace an object, restyle) | `video-edit` |
| Change the sound of a finished video (lower or remove the background music, change the volume) | An edit of existing video: add a `video-edit` node and `connect` the video's node to it ([edit](edit.md)); say the sound change in its prompt. Do not install ffmpeg or write a local script. When no `video-edit` model in `models_explore` accepts it, say so and offer **Import into VN** to adjust it there. |
| Change existing image content | `image-to-image` → [Revise an image](edit.md#revise-an-image) |
| `motion-transfer`, `object-swap` | only when the user names that capability; other edits use the rows above |
| `{{Image N}}` in a prompt | N is the input port name `Image N`; token kinds and edits: [prompt-refs](prompt-refs.md) |
| A Seedance Draft result the user wants as the final video | add a `video_upscale` node → [edit](edit.md) |

## Frames
1. Ask once: "Any middle frames between first and last?" Skip the question when the user already gave a count.
2. No middle frames: models from `workflow_nodes` with `capability: first-last-frame-to-video`. `workflow_add_node` fills first, then last.
3. Middle frames: `workflow_nodes` with `capability: first-last-frame-to-video` and `has_port: mid_image_1` (today Kling 4.0, up to 8). If `items` is empty, say so; offer first and last only.
4. Do not pass three images to `workflow_add_node`: it fills two ports and refuses a third (`PORT_INCOMPATIBLE`). Build with `workflow_edit`: one `image_input` node per frame (`asset_id`), then `connect` each to the generation node's `first_image`, `mid_image_1` … `last_image`, in story order, with the ports named.
5. Say once: the vendor places middle frames; no second can be set.

Done: the plan row for the request is applied.

## Media duration

If the user already specified the cuts, go straight to [create the clips](split-media.md). For model selection, check the input limits even when the media was generated on this canvas.
List models using `workflow_nodes` with the capability and `asset_ids`, including “More models”. For a generated voice-over or video, take the picked `asset_id` from `result_assets` in `workflow_get` with the producer’s `node_id`. If the chosen model fits, or the user has yet to choose and there are compatible models, continue with the returned choices.

When the chosen model is filtered out, read its `rejections` under `filtered_out` and the input limits in its schema’s `medias[].limit`. If no model fits and none was chosen, use the limits of a model with the required input ports to propose a split. Follow the same steps when check or prepare reports a duration error. Quote the measured seconds and the applicable input limit.

- **One file is too long.** Offer to split it on the canvas. Show the proposed ranges in source order, at sentence or scene breaks when known. For example, 19 seconds with a 10-second maximum could use 0–9.5 and 9.5–19 seconds. Cover the full source. Move a cut earlier if the last part falls below the minimum. Ask whether to split at those points, keep a specific excerpt, or switch to a listed compatible model. Offer only choices that fit.
- **The total is too long.** Show the combined duration and per-run limit. If each file fits individually, offer separate runs or fewer inputs. Split an individual file only if needed. Recheck the total with the other inputs for each planned run.
- **A file is too short.** Offer a longer source or a compatible model. An empty model list without a duration rejection needs the reported port or capability issue resolved first.

When the user accepts the ranges, [create the clips](split-media.md) and recheck each planned input set before pricing.

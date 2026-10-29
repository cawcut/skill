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
| `{{Image N}}` in a prompt | N is the port name Image N |


## Frames

1. Ask once: "Any middle frames between first and last?" Skip the question when the user already gave a count.
2. No middle frames: models from `nodes --capability first-last-frame-to-video`. `quick` fills first, then last.
3. Middle frames: models from `nodes --capability first-last-frame-to-video --has-port mid_image_1` (today Kling 4.0, up to 8). If none returns, say so; offer first and last only.
4. Do not use `quick --image` for middle frames: it fills two ports and refuses a third (`PORT_INCOMPATIBLE`). Build with `edit`: one input node per frame (`asset_id`), `connect` each to `<node>:first_image`, `<node>:mid_image_1` … `<node>:last_image`, in story order.
5. Say once: the vendor places middle frames; no second can be set.

Done: the plan row for the request is applied.

## Media duration

Only video and audio length (each file, and the total per type) is checked up front; images never filter (the server resizes them). Other limits stay with `check`.

1. Media first: add `--asset <asset_id>…` to every `nodes --capability <c>` call, the default pick and More models included. Rejected models are gone from `items`; say nothing about them.
2. Model first: after the upload, run `nodes --capability <c> --asset <asset_id>…`. The chosen model still in `items` → continue.
3. The chosen model is missing: say once why, from `filtered_out` (asset or assets, the length, the limit). Then the Change model question with the returned models only.
4. `items` is empty: no model fits. Name the longest limit in `filtered_out` and ask the user to shorten the asset (trim it yourself or hand it to `cawcut-vn`). Upload the new file and repeat from 1. Do not price or run.

Done: the chosen model accepts every video and audio input, or the user has a shorter file.

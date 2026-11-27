# Split a model input into clips

## On the canvas

1. Read the current asset ID from the input’s `params.asset_id`, or the chosen generated result’s `result_assets`. For a TTS or generated video result, tell the user the clips will use this particular take even after a rerun. Get their agreement to freeze it before adding fixed inputs.
2. Create one `audio_input` or `video_input` per approved range, each with the same source `asset_id`, a unique `ref` and a name showing its range. On the active canvas use `workflow_edit` with `add_node` and the latest `base_graph_token`. Set `keep_fixed: true` on each add for a frozen result. For an outside asset with no canvas yet, use `workflow_create` with a name and the input `nodes`. Keep the original node and its connections.
3. Take the new node IDs from the create or edit reply’s `node_refs`. Read the current `graph_token` with `workflow_get` and pass it as `base_graph_token` in the **second edit**. Each `trim_media` operation needs an existing node ID and its approved range in integer milliseconds. For the 19-second example, send these operations.

```json
[
  {"op":"trim_media","node_id":"<first clip node id>","start_ms":0,"end_ms":9500},
  {"op":"trim_media","node_id":"<second clip node id>","start_ms":9500,"end_ms":19000}
]
```

4. Verify each saved range in `params.trimStartMs` and `params.trimEndMs`, and collect the new `params.asset_id` from each clip. If a call fails or its outcome is unknown, read the graph before retrying. Reuse the created nodes and finish only outstanding trims.
5. Show the clip names and ranges in order. A split-only request ends here. For generation, call `workflow_nodes` with the capability and `asset_ids` for **each intended run**, using the new asset ID and the other inputs for that run. Encoding can change the measured duration slightly. If it still exceeds a limit, adjust the ranges with the user. Connect each accepted clip node to its own target when the clips require separate runs. Replace the old edge only on the intended consumer, then prepare each target and confirm the cost before running.

## Split before upload

If upload rejects a local file for duration, report the upload limit and use the tighter of that limit and the selected model’s input limit. Agree on ranges as in [Media duration](plan-rules.md#media-duration). With a readable source and FFmpeg available, write each approved range to a fresh file. Set `-ss` to the start in seconds and `-t` to the length. These examples cut the second half of a 19-second file.

```bash
ffmpeg -n -ss 9.5 -i "source.mp3" -t 9.5 -map 0:a:0 -c:a pcm_s16le "voice-02.wav"
ffmpeg -n -ss 9.5 -i "source.mp4" -t 9.5 -map 0:v:0 -map "0:a:0?" -c:v libx264 -c:a aac "video-02.mp4"
```

Use the command for the source type. Verify each output’s actual duration, then [upload](media-sources.md#direct-upload) the clips and check their returned IDs per intended run. If the host cannot read or cut the file, ask for a readable source or the agreed clips.

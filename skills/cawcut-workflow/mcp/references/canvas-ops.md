# Manage canvases, nodes and audio

Load to rename, copy or delete a workflow or node; to trim media; to separate a video's audio; or to add a voice-over (TTS).

## Workflow and node housekeeping
| Intent | Call |
| --- | --- |
| rename the workflow | `workflow_edit` with `name` and `operations: []` |
| copy the workflow (graph and results) | `workflow_create` with `duplicate_from` (the `workflow_id`) and optional `name`; the reply's `workflow_id` is the copy. Continue on the copy only when the user asked for it. Give the user both links, original and copy |
| rename a node | `workflow_edit` `update_node` with `name` |
| copy a node (settings and incoming connections come along; name gets the next number, offset 40,40) | `workflow_edit` `duplicate_node` with `node_id`, optional `name`, `position` and `new_ref` (the reply's `node_refs` maps it to the copy's id) |
| delete a node (its connections go; a Product node takes its companions) | `workflow_edit` `remove_node` |

Product nodes and their companions cannot be duplicated: tell the user and add a new Product node only after they say yes. A companion cannot be deleted alone. The copy's default name is `Copy of <name>`. Later operations in the same batch address the copy through the field `ref` with its `new_ref`. The copy lands 40,40 from the original and covers it: send a `layout` operation after copying and give the user the copy's id.

A node rename works on every node type, and places that show the node display the new name.

Delete only a node the user named or a step the confirmed goal made redundant. A deleted producer leaves its consumers without that input: `workflow_check` names the gaps. A prompt that still holds `{{Image N}}` for the removed input is yours to rewrite ([prompt-refs](prompt-refs.md)).
Done: the reply reports no error and `workflow_get` shows the change.

## Trim video or audio
Trimming is a free in-place edit: no price lookup, paid-run confirmation or `workflow_run`.

Reuse the clip's `video_input` or `audio_input` node. For a new upload, [upload the source](media-sources.md) and use its `asset_id` to add an input of that kind. Use `workflow_create` with a name and the input node on a new canvas, or `workflow_edit` with `add_node` on the active canvas. Take the input's ID from `node_refs`. A generated result becomes a fixed input only with the user's agreement ([edit](edit.md)).

Check the input's `params.durationSec` before the first trim. For a re-trim use `params.originVideo.durationSec` or `params.originAudio.durationSec`, not the trimmed duration. Require `0 ≤ start_ms < end_ms ≤ durationSec × 1000`. The server rejects out-of-bounds ranges with `PARAM_INVALID` rather than clamping, and rejects a trim if it cannot determine the source duration.

Call `workflow_edit` with the latest `graph_token` as `base_graph_token` and a `trim_media` operation on that input's `node_id`. For “keep seconds 3–10”, send `start_ms: 3000` and `end_ms: 10000`. Both bounds count from the untrimmed source. The trim keeps the node's ID, connections and original file.

On success, `trim_results` reports each operation's `start_ms`, `end_ms` and `duration_sec`. Read the input back with `workflow_get`. Once `params.trimStartMs` and `params.trimEndMs` match the requested range, the trim is complete. On `TRIM_FAILED` or `TRIM_TIMEOUT`, retry once. If the retry fails, keep the original input and tell the user the trim failed.

## Separate audio and video
`workflow_edit` batch: `add_node` with a `ref` and `node_kind`, then `connect` the video node's video output to the new node's `video` port.
| Goal | `node_kind` | Output |
| --- | --- | --- |
| the full soundtrack | `audio_separation` | audio |
| the video without sound | `mute_video` | video |
| the voice only | `vocal_extraction` | audio |
| the music and noise | `background_extraction` | audio |

`audio_separation` gives one full track. `vocal_extraction` and `background_extraction` split voice and music. For both soundtrack and silent video, send two add-and-connect pairs in one batch. Check the current source before running. Read the selected processor model’s video input limits from `workflow_nodes`. Check known metadata during edit preview and prepare. For generated media, report pending checks until the upstream output is available.

Read each new node's `estimate_status_by_target`, `estimated_credits_by_target` and `warnings_by_target`. Report pending media checks. For a requested target marked `free` with a zero estimate, run it directly by `node_id` and poll to completion before starting its sibling. For `paid` or `unknown`, prepare that target and confirm any charge. Older servers supply the numeric map alone: zero is free for that target, and null or a missing entry requires prepare. A top-level `per_target` or `not_estimated` gives no price for a whole run. A whole run skips processors configured for manual execution.
Done: each processor node has result assets.

## Voice-over (TTS)
1. Call `workflow_nodes` with `capability: "text-to-speech"` and `schema: true`. When the tool advertises `voice_language`, pass the script's language code (e.g. `zh`), or the conversation language when the script is missing. Use the [voice picker](../../references/voice-picker.md) to show the returned samples. For “More voices”, repeat the query with its `next_voice_offset` as `voice_offset`. Older servers return the full catalog in `data.voices`; apply the same picker to it locally.
2. `workflow_edit` (or `workflow_create`) `add_node` with `node_kind: "tts"`, the script in `prompt` (or a `text_input` connected to its prompt port), `params.voice_id`, optional `params.speed`.
3. `workflow_prepare`, show the speed and price in the [run confirmation](../../SKILL.md#4-build-confirm-run), then `workflow_run` after approval. Credits scale with characters.
The audio feeds a video model's `Audio` port ([plan-rules](plan-rules.md)) or goes to the user. A voice-over that must play in the video needs a model with that port: `workflow_nodes` with `capability: omni-to-video` and `has_port: audio`; image-to-video models have none, so switch capability, connect the TTS `audio` output to the `Audio` port and keep `generate_audio` on. A model's minimum audio length (Seedance 2.5: 2 s) can exceed a short line: lengthen the script or lower `params.speed` before the run. When the clip should last as long as the voice-over and the model schema offers `duration_mode` with `audio_base` (Seedance 2.5: "Based On Audio"), set it instead of guessing `duration`.
Done: the node holds an audio result and its `voice_id` is the one the user chose.

## LLM node

For Web text operations, create the native node (do not substitute an LLM). Check `supported_node_kinds` first.

A `text_input` node carries its content in `text` and feeds the chain from its `text` output port.

| Operation | `node_kind` | Input port | Output port | Params |
| --- | --- | --- | --- | --- |
| Rewrite | `rephrase_text` | `input` (up to 9 sources, joined by newlines in connection order) | `text` | `mode` (default `rewrite_improve`), `instructions` (only used with `mode: "custom"`), optional `model_id` |
| Merge | `combine_text` | `text__1` … `text__10`, in the desired order | `combined_text` (sources joined by newlines) | none |
| Split | `split_text` | `text_1` | `text` (one segment, not an array) | `separator` (required, 1–1000 characters), `index` (1–99, default 1) |

`rephrase_text` `params.mode` accepts exactly these values; anything else fails with `unknown rephrase mode`:

| `mode` | Use |
| --- | --- |
| `rewrite_improve` | Polish wording (default) |
| `rewrite_summarize` | Shorten or summarize (缩写) |
| `rewrite_expand` | Expand (扩写) |
| `rewrite_briefing` | Turn into a briefing doc |
| `custom` | Follow `params.instructions` |
| `t2i_prompt_optimizer` | Optimize an image-generation prompt |

`split_text` matches `separator` literally (no regex, no escape processing) and the run fails with `Separator not found in text` when the text lacks it. Newlines around each segment are trimmed and empty first/last segments are dropped. To split on a line break, the separator must be a real newline: in a JSON file write `"separator": "\n"`. Change a param later the same way; send a JSON string `"\n"` (a real newline), never the two characters `\` and `n`. An `index` past the last segment fails the run as out of range. When an upstream rewrite may drop line breaks, read its result before choosing the separator.

All three take text only through edges: setting `prompt` or `text` on them is rejected with `connect upstream text to this node`, and `combine_text`/`split_text` reject a `model_id`. `workflow_nodes` with `schema=true` does not describe these nodes; this section is the contract. One text output (an LLM, `rephrase_text`, `split_text` or a `text_input`) can feed any number of nodes, e.g. one script into a voice-over, captions and a storyboard; connect each consumer to the same output instead of copying the node.

For example, combine `red` and `blue`, then split the result using a newline and index 2. Read each node’s results: the merge should return both lines and the split should return `blue`. For rephrase and LLM, check the returned text against the instruction, not just the run status.

Discover models with `workflow_nodes` and `capability="text-to-text"`, then read the selected model with `model` and `schema=true`. For one step, pass the user prompt to `workflow_add_node` with that capability and `model_id`. For a chain, create or add an `llm` node and connect user text to `input`, optional system text to `instructions`, and media to the model's advertised ports. Set `params.output_format="json"` only when the schema offers it.

Prepare the target, confirm and run. Read `workflow_results` with the workflow and node IDs to deliver its latest `text_outputs`. Connect its `text` output to a downstream prompt or TTS node to reuse it on the canvas.

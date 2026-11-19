# Manage canvases, nodes and audio

Load to rename, copy or delete a workflow or node, trim media, separate a video's audio, or add or edit a voice-over (TTS).

## Workflow and node housekeeping
| Intent | Call |
| --- | --- |
| rename the workflow | `workflow rename <id> "<name>"` |
| copy the workflow (graph and results) | `workflow duplicate <id> [--name "<name>"]`; the reply's `workflow_id` is the copy. Continue on the copy only when the user asked for it. Give the user both links, original and copy |
| rename a node | `workflow set <id> --node <n> name="<name>"` |
| copy a node (settings and incoming connections come along; name gets the next number, offset 40,40) | `workflow duplicate-node <id> --node <n> [--name "<name>"] [--x <n> --y <n>]` |
| delete a node (its connections go; a Product node takes its companions) | `workflow delete-node <id> --node <n>` |

Product nodes and their companions cannot be duplicated: tell the user and add a new Product node only after they say yes. A companion cannot be deleted alone. The copy's default name is `Copy of <name>`; its id is in the reply's `changes.added_node_ids`. `duplicate-node` accepts a name another node already has: say so in the reply and offer a different one. The copy lands 40,40 from the original and covers it: run `workflow layout <id>` after copying and give the user the copy's id.

A node rename works on every node type, and places that show the node display the new name.

Workflow writes count Unicode code points. Workflow and node names use the title limits from `workflow_limit`, and `text_input` content uses `input_limit.text.maxLength`. The CLI skips each missing or zero limit. A note’s `text` (its canvas label) allows up to 20,000 code points. Exceeding a limit returns `PARAM_INVALID` before submission.

Delete only a node the user named or a step the confirmed goal made redundant. A deleted producer leaves its consumers without that input: `workflow check <id>` names the gaps. A prompt that still holds `{{Image N}}` for the removed input is yours to rewrite ([prompt-refs](prompt-refs.md)).
Done: the reply's graph shows the change and `valid` is true.

## Trim and separate on the canvas

These edits run on the workflow service, including when Claude Code runs on Windows. For a request such as “keep seconds 5–15 and give me the silent video and its soundtrack”:

1. Reuse the active workflow and its video input. For a new workflow, upload the source, create a `video_input` with the returned `asset_id` under the requested workflow name, and use the input's ID from `node_refs`.
2. Run `workflow trim <id> --node <input> --start 5 --end 15 --json`. Check that the same input now has `params.trimStartMs=5000` and `params.trimEndMs=15000`. Continue only after the trim succeeds.
3. For separation, check the [input limits](#separate-audio-and-video) on the clip to be split, using the trimmed clip if the user requested a trim. Run `workflow separate <id> --node <input> --what both --json` on that input. The response's `node_refs.audio` and `node_refs.silent` identify the two targets. Prepare, confirm and run each target with `--wait`, one at a time. Read each target's `workflow results` and deliver both assets. For a trim-only request, stop after the trim.

If the CLI reports an unknown command, check which commands the installed launcher exposes. Different builds labelled 0.10.3 shipped in source checkouts. In PowerShell:

```powershell
Get-Command cawcut -All
cawcut workflow --help
```

For a Windows source install, check `node cli/dist/index.js workflow --help` from the updated checkout. If it lists the missing command, use that entry point on the same workflow. If the checkout needs rebuilding, run its Windows setup (`.\setup.cmd`) and check again. For an npm install, check for an upgrade and verify the commands before retrying. If either command is still missing, report which one and return the workflow link for resuming.

## Trim video or audio
`workflow trim <id> --node <input node> --start <s> --end <s>` keeps that range, in seconds from the untrimmed source. The node keeps its id, connections and original file; a second trim starts again from the original. Trim works on `video_input` and `audio_input` nodes. A generated result becomes one only with the user's word to freeze it ([edit](edit.md)).
Both `workflow trim` and `trim_media` in an edit batch require `0 ≤ start < end ≤ source duration`. A range outside a known source duration returns `PARAM_INVALID` before submission. If the duration is unavailable, the CLI warns and submits the range.
Trim failure: `TRIM_FAILED` or `TRIM_TIMEOUT` leaves the node unchanged. Retry once; if it fails again, tell the user the trim service failed and keep the untrimmed node. Keep the untrimmed node and tell the user.
Done: the node's `trimStartMs` and `trimEndMs` equal the range asked for.

## Separate audio and video
All separation modes require a video with an audio track, a duration of 2–600 seconds inclusive, and a size of at most **100 MiB (104,857,600 bytes)**. Check the current clip's metadata as soon as the user supplies it or the canvas shows it. The CLI returns `PARAM_INVALID` before adding nodes when known metadata violates a limit.

If the clip exceeds the size limit, tell the user its size and the limit before adding nodes or asking about credits. Offer to keep the full duration and audio by re-encoding at a lower video bitrate, or to use a smaller video. Wait for their choice. When the size is unknown, let `workflow separate` check the available metadata. If it returns a size error, offer the same options. Quote credits only after the processor exists and `prepare --target` returns an estimate.

`workflow separate <id> --node <video node> --what audio|silent|both|vocals|background` adds the processor nodes the Portal shortcut adds and wires the video into each:
| `--what` | Nodes | Output |
| --- | --- | --- |
| `audio` | `audio_separation` | the full soundtrack |
| `silent` | `mute_video` | the video without sound |
| `both` | the two above | soundtrack and silent video |
| `vocals` / `background` | `vocal_extraction` / `background_extraction` | the voice or the music and noise |

`audio` gives one full track; `vocals` plus `background` (two nodes) split it into voice and music. Running `separate` again adds another node set. These nodes run only when targeted: `prepare <id> --target <node>`, confirm, then `run <id> --target <node> --wait`. A full run skips them. Nodes that read the same video run one after the other: a second run is refused with `REQUEST_REJECTED` while a sibling is still running.
Done: each processor node has a result asset.

## Voice-over (TTS)
1. `nodes --capability text-to-speech --model <id> --schema --json` lists the models, ports and `voices`. If the catalog is empty, tell the user. Filter by `languages` using the script's language (otherwise the language the user writes in).
   - List each `voice_id` once. Order the matches in two groups: first the voices with a `previews` entry in the selected language, then the rest. Within each group, put voices from `recent_voice_ids` first, in listed order, marked “previously used”, then the others in catalog order. Show about eight at a time and offer “More voices” if more remain.
   - Before asking, send a normal reply with a Voice | Traits | Listen table in the conversation language and say nothing has been charged yet. Use `gender`, `age` and any style in the voice name. The Listen cell is a Markdown link whose text is “▶ Listen” in the conversation language and whose target is the `preview_audio_url`. Never print the URL itself: preview URLs are long signed links and break the table. Link the preview whose `language_code` matches the selected language. Otherwise link the first entry in `previews` and name its language in the link text, e.g. “▶ Listen (English)”. If no URL is available, write “no preview”.
   - Then ask for the pick with the question tool. Its question and options are plain text: put no table, Markdown or URL in them, only the voice name and its traits per option. Recommend the most recent previously used voice that has a preview in the selected language, otherwise the first voice in the table. Use the chosen catalog `voice_id`.
2. `edit` add_node `node_kind: "tts"`, the script in `prompt` (or a `text_input` connected to its prompt port), `params.voice_id`, optional `params.speed`.
3. `prepare <id> --target <n>`, show the speed and price in the [run confirmation](../SKILL.md#4-build-confirm-run), then `run` after approval. Credits scale with characters.
The audio feeds a video model's `Audio` port ([plan-rules](plan-rules.md)) or goes to the user. A voice-over that must play in the video needs a model with that port: `nodes --capability omni-to-video --has-port audio`; image-to-video models have none, so switch capability, connect the TTS `audio` output to the `Audio` port and keep `generate_audio` on. A model's minimum audio length (Seedance 2.5: 2 s) can exceed a short line: lengthen the script or lower `params.speed` before the run.
Done: the node holds an audio result and its `voice_id` is the one the user chose.

### Edit a voice-over
1. Read the active canvas with `workflow get <id> --json`. Locate the existing `textToSpeech` node and read its `node_id`, `model_id` and `params.voice_id`.
2. For a voice change, use the voice catalog and previews above. For “another female voice”, filter by gender and language and exclude the current voice. Use the requested voice if it is identified, or ask the user to pick from the matches.
3. Apply the requested settings together with `cawcut workflow set <id> --node <node_id> speed=1.1 voice_id=<chosen_voice_id> --json`. Include only the assignments the user requested. A speed-only edit goes straight to `set`.
4. Read back with `workflow get <id> --node <node_id> --json`. Confirm the saved `params.speed` or `params.voice_name` and `params.voice_id` for each requested change. An edit-only request ends here. To generate updated audio on request, prepare the target and use its saved settings in the [run confirmation](../SKILL.md#4-build-confirm-run).

## LLM node

For a reusable text-generation step on the canvas, list `workflow nodes --capability text-to-text --json` and read the selected model with `--model <id> --schema`. Use the returned ports for its media inputs. Set `params.output_format` to `json` only when the schema offers it.

For a single step, `workflow quick "<prompt>" --capability text-to-text --model <id> --estimate --json` creates and wires the prompt. For a chain, create or add a node with `node_kind: "llm"` and that `model_id`. Connect user text (`Text` or `TextGroup`) to `input`. Optional system instructions come from a separate text node connected to `instructions`. Edit the upstream text to change the prompt.

After prepare and confirmation, run the target. Read `workflow results <id> --node <node-id> --json` and deliver the text from the latest output. The node's `text` port can feed the next step, including TTS.

---
version: 0.11.0
name: cawcut-workflow
description: >-
  Use when making video, images, audio; trimming an uploaded video or separating its soundtrack on a workflow canvas; writing scripts, storyboards or shot lists; scraping product info from a URL; AI edits of existing media (recolor, replace, restyle, first/last frame); LLM text generation on a workflow canvas; canvas follow-ups. NOT for ads (cawcut-ad-video), VN timeline cuts (cawcut-vn), named Apps (cawcut-app-run).
argument-hint: "<outcome, assets or follow-up>"
allowed-tools: Bash AskUserQuestion AskQuestion SendUserFile PushNotification
---

# CawCut Workflow

**One canvas.** Follow-ups, missing inputs and re-runs go into the active `workflow_id`; an unrelated goal starts a new one.
**Solid edge, fixed asset.** A canvas output reaches its consumer through an edge; an `asset_id` input is outside media or a result the user picked.

```cawcut-card
cawcut asset upload <path|url|asset_id>… --json
cawcut workflow nodes [--capability <c>] [--asset <asset_id>…] [--model <id> --schema | --has-port <selector>] --json
cawcut workflow quick "<prompt>" --capability <c> --model <id> [--workflow <id>] [--param k=v] [--image|--video|--audio <asset_id>] --estimate --json
cawcut workflow create --file - --json
cawcut workflow edit <id> --file - --json
cawcut workflow set <id> --node <n> key=value --json
cawcut workflow connect <id> <from> <to> --json
cawcut workflow upscale <id> --node <draft_node> --json
cawcut workflow rename <id> <name> --json
cawcut workflow duplicate <id> [--name <name>] --json
cawcut workflow duplicate-node <id> --node <n> [--name <name>] --json
cawcut workflow delete-node <id> --node <n> --json
cawcut workflow trim <id> --node <n> --start <seconds> --end <seconds> --json
cawcut workflow separate <id> --node <video_node> --what audio|silent|both|vocals|background --json
cawcut workflow layout <id> --json
cawcut workflow prepare <id> [--target <n>] --json
cawcut workflow run <id> [--target <n>] --wait --json
cawcut workflow results <id> --node <n> --download --json
```

`--json` replies `{v,ok,data}` or `{ok:false,error}`; follow `error.next`. Ask with the host question tool, recommended option first; independent settings may share one call up to its question limit.

## Turn gates
Run all five before the last message of a turn. Each ends on a checkable state.
- **Ask:** a choice for the user is one question-tool call, its options the choices; the message above it carries results. A numbered list serves only when no tool exists or the choice exceeds the tool's limit. Done: the turn ends on the call.
- **Show:** the content a choice rests on (product facts, a script) is the opening of the Ask's `question` text, so the dialog stands alone; thinking stays invisible to the user, and a message sent just before a tool call may not reach them. Done: the `question` holds the shot table or the facts in full.
- **Edit close:** a canvas edit ends with a message that names what changed, what it left open (an emptied input, an unconnected port) with one suggested fix, and, when nothing ran, how to run it (ask you, or run from the Portal). Done: all three are in the message.
- **Refusal:** when the server rejects an operation, or a request has no direct operation (a reversed Trim range, copying a Product node, trimming a generated result), the turn stops on an Ask that offers the workaround as one option; a rejection whose error text names the repair (a duplicate ref, a missing field) is fixed and resent once without asking. Done: the canvas is unchanged until the user picks.
- **Hand off:** delivered media is followed by a `Skill` call to `cawcut-vn` in the same turn; VN asks its own question, whatever the user said about editing. Done: the call is made, or the user declined VN earlier this session.

## 0. Bootstrap
Silent guardrail, once per AI session: a session that already ran a `cawcut` command successfully starts at step 1.
Otherwise run `cawcut upgrade check --json`.
- `"update_available": true` → run `cawcut upgrade` yourself; the user never types it. Then continue.
- `"ahead_of_registry": true` → a local build; continue.
- Command missing, or any other check failure → [failures](references/failures.md#first-run-and-sign-in).
Done: the check ran, any update is installed, and no bootstrap text reaches the user.

## 1. Route
| Request | Owner |
| --- | --- |
| Named App, "what apps exist" | `cawcut-app-run` |
| Running or named Ad Video, Story Video or avatar project | that skill |
| Story: multi-shot narrative or dialogue video | [story](references/story.md) on a canvas; `/cawcut-story-video` on request |
| Script, storyboard or shot list only (ad scripts too) | [script-writing](references/script-writing.md) |
| Video asked from a script already in the chat or on the canvas | [script-writing](references/script-writing.md) step 3 (render path), before `nodes` |
| Ad or ad video, or a product-page URL alone | `cawcut-ad-video`; an ad asked for on a canvas → [product](references/product.md) (its Ask also offers the wizard) |
| Product URL to scrape or extract | ask once: Ad Video wizard or canvas with a Product node → [product](references/product.md) |
| Trim a clip or separate its soundtrack in a new, named or active workflow, including a file being uploaded | [Trim and separate on the canvas](references/canvas-ops.md#trim-and-separate-on-the-canvas) |
| Cut or join delivered or local files on a VN timeline | `cawcut-vn` |
| Split audio or video for a model input, including a generated voice-over | [Media duration](references/plan-rules.md#media-duration) |
| Copy an existing canvas, including one used to make an ad | [Copy the workflow](references/canvas-ops.md) first. For requested edits, inspect the returned workflow and use its node IDs |
| Copy a media node already on the canvas | [canvas-ops](references/canvas-ops.md) |
| Change the speed or voice of an existing TTS node | [Edit a voice-over](references/canvas-ops.md#edit-a-voice-over) on the active canvas |
| Anything else new | `cawcut app list --schema --json`; offer an App scoring ≥70 (the rubric is in `cawcut-app-run`) beside "Build a canvas"; else canvas |

Done: the user agreed to an App, a pipeline or a canvas.

## 2. Prepare media
Outside media (file, URL, asset id): `cawcut asset upload`; relay its `notice` once. A canvas output ("the video above") is a solid edge, never an upload.
If a local file exceeds the upload duration limit, use [Split before upload](references/split-media.md#split-before-upload).
Done: outside inputs have an `asset_id`; canvas outputs have edges.

## 3. Plan nodes
`nodes` → capabilities; `--capability` → models; `--model --schema` → ports and parameters. Offer `motion-transfer` and `object-swap` only when the user names them. Scripts are `text_input` text, never a `script` node.
- Audio or video references, sound, frames, edits of existing media, `{{Image N}}` → [plan-rules](references/plan-rules.md).
- Video or audio input, including an existing TTS result → check the asset IDs when listing models. A duration rejection during discovery, check or prepare → [Media duration](references/plan-rules.md#media-duration).
- Story → [story](references/story.md).
- Change an existing canvas, or "what next" → [edit](references/edit.md).
- Generate or transform text with an LLM node on the canvas → [canvas-ops](references/canvas-ops.md#llm-node).
- Rename, copy or delete a workflow or node; trim media; separate audio from video; a voice-over (TTS) → [canvas-ops](references/canvas-ops.md).
- A prompt that refers to an input in words ("the first image") or by `@` / `{{Image N}}` → [prompt-refs](references/prompt-refs.md): write the token, never the words.
- Several nodes, a note, or tidying positions → [layout](references/layout.md); run `workflow layout` after a batch of more than two nodes and after every `duplicate-node`.

### Model and settings (each paid node, before pricing)
Every video node carries a prompt: one line on the motion or scene, from the user's idea. `check` passes an empty one, but a run without it failed on proto.
1. Model: the first one `nodes` returns (the default sits there), or the one the user named.
2. Read `nodes --capability <c> --model <id> --schema` for that exact model, again after every model change. Settings, defaults and `options` come only from that reply; one model's options never carry to another (Seedance 2.5 Draft allows `480p` only, Seedance 2.5 allows more).
   Settings menu, one question: the model and its key settings by `label` (ratio or aspect, resolution or quality, duration, count, audio; only those in its schema). Options: **Use current settings** (recommended) · **Adjust settings** · **Change model**.
3. Adjust settings: one question per key setting in a single call, options from the parameter's labelled `options`, the default marked recommended. Other parameters keep their defaults. Write the answer under the parameter's key (`quick --param key=value`, or `set` on a canvas).
4. Change model (the schema read in step 2 repeats for the new model; settings the new model lacks or no longer allows reset to its defaults): one question with the first three models `nodes` returns (name, price) and **More models**; More models → every model as a numbered list (name, price), the turn's final reply, answered by number. Both keep the CLI's order. Then back to 2.

Done: each node has an input source, and each paid node a model and settings the user accepted.

## 4. Build, confirm, run
1. Build and price:
   - Active `workflow_id` (this AI session ran `quick` or `create`; a script, an image or a video already sits on it): [edit](references/edit.md) adds the new nodes and edges to it, then `prepare <id> --target <n>`. Stages of one goal share one canvas: image → script → video.
   - No canvas yet, several nodes: give the proposal a nonblank `name`, then `create` → `set` / `connect` → `prepare <id>` (runs `check`, returns credits).
   - No canvas yet, one node: `quick … --estimate` (runs `check`; returns `workflow_id`, `node_id`, credits).
2. A `product_input` run is free and skips this step ([product](references/product.md)). Otherwise ask one question: model, settings by label, scope, credits. For a product ad add the chain type (A direct video, B script + storyboard), each paid node's price, and, for chain A, the prompt in full; "generate the final video directly" does not skip this question. Options: Confirm · Change model · Modify settings · Cancel. Each later paid run gets its own. Change model or Modify settings → the step 3 menus, then `switch-model <id> --node <n> --model <m>` or `set`, and `prepare --target`.
   For each TTS node that will run, include its current speaking speed and adjustable range in the confirmation question, e.g. “Speaking speed 1.25x (adjustable 0.5x–2x)”. Use the node’s `params.speed`, reading it with `workflow get` if needed. An unset speed defaults to 1x.
3. After Confirm: `run <id> --target <n> --wait` on the same workflow. Audio separation, mute video, vocal and background extraction nodes run only with `--target <n>`; a full `run` reports done with 0 credits and runs none of them.

**Video notifies.** Video runs a minute or more. Before `run … --wait`, say once that the user can step away and you will tell them when it lands; the CLI gives no estimate, so say "about a few minutes" (quote `estimated_running_ms` only if the output carries one; never the wait timeout). When the command ends `done`, `failed` or `action_required`, send one notification with the host's notification tool (`PushNotification`, one line, `status:"proactive"`); if its schema is deferred, load it first with `ToolSearch` (`select:PushNotification`). Skip it silently when the host has none; never raise a shell-level toast (`osascript`, `notify-send`, BurntToast). Image tasks finish inside a turn: no notice, no notification.

Done: Confirm for this scope, `check` passed, `task_id` read to its end state. Other cases → [failures](references/failures.md).

## 5. Deliver
[delivery](references/delivery.md).
Done: outputs, actual cost, Portal link reach the user; `cawcut-vn` gets every local path plus each output's `asset_id` and signed URL, images too.

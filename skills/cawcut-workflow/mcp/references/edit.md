# Change an existing canvas

Load for a follow-up on a canvas from this conversation: a changed setting or prompt, a model switch, a new or swapped input, a connection, a removed step, or the next stage of the same goal.

## Edit loop
1. `workflow_get` with the `workflow_id`: keep the `graph_token` and the node ids involved. Add `node_id` to also get the `result_assets` that node made in its latest run.
2. Name the change in outcome words: what is new, what stays.
3. A missing input is an existing output to reuse or a producer node to add. Add the producer and its consumer connection in one batch; a node added in the batch is named by `ref`.
4. `workflow_edit` with every operation in one call and `base_graph_token` set to the `graph_token` you just read. Keep the batch to the nodes the change names; operations touch nothing else.
5. Read the reply: `node_refs` maps your refs to node ids, `changes` lists what moved, `dropped_params` and `dropped_edges` list what a model switch removed, and `graph_token` is the token for the next edit. Repair a wanted connection in the next call.
6. `workflow_prepare` shows what re-runs and what stays cached; each paid run is confirmed (main step 5).

Done: the reply reports no error, every needed connection is there, and the user knows the next run's scope and credits.

## Preview an edit

Read `workflow_get`. Send the proposed operations to `workflow_edit` with `dry_run: true` and the current `base_graph_token`. Use this for a feasibility question or to inspect the effects of a model switch. If the connected tool lacks this field, explain that this server cannot preview the edit. For a preview-only request, stop after reporting the result.

Report dropped parameters and edges, any `run_warning` or `warnings`, and any deferred URL import. A valid preview checks whether the edit can be saved. Missing media metadata can still affect execution. To apply a requested edit, submit the original batch with the same token and omit `dry_run`. Rebuild the preview after a graph conflict. Read the persisted node IDs from the apply reply.

| Intent | Operation |
| --- | --- |
| add a step | `add_node`, connected in the same batch |
| use an output of this canvas ("the video above") | `connect` from its node to the consumer. Adding its `asset_id` as an input node, or in `workflow_add_node` `images` / `videos` / `audios`, cuts the live link; the call is refused with `OWN_OUTPUT_AS_INPUT`. Add the consumer without the media, then `connect` |
| use an outside file, URL or asset id | [media-sources](media-sources.md), then an input node (`add_node` with `node_kind` `image_input` / `video_input` / `audio_input` and its `asset_id`) |
| feed A into B | `connect` with `from` and `to` as objects (`{"node_id": "…"}`, never a bare id string). Leave `port` out when the nodes already exist: the server picks the only compatible free pair. `PORT_AMBIGUOUS` lists the pairs in `details.allowed`; repeat the operation with the ports named |
| stop feeding | `disconnect`, with both ports as `workflow_get` shows them in the edges; keep a node that still serves the goal |
| change a setting | `update_node` with `params`; `unset` drops a key back to the model default |
| redo the node you just prepared with other settings or another model (same content) | `update_node` on that node, never `workflow_add_node`; keep its `node_id` as the target |
| change the prompt | `update_node` with `prompt` (generation node) or `text` (text input) |
| change the model | `update_node` with `model_id`. Read `dropped_params` and `dropped_edges`, tell the user what changed, then prepare |
| change part of an existing image ("make the background white", "remove X") | add an `image-to-image` node and `connect` the image's node to it; the old node and its result stay. [Revise an image](#revise-an-image) |
| change part of an existing video (recolor, replace an object, restyle) | add a `video-edit` node and `connect` the video's node to it; the old node and its result stay |
| redo the whole image (new style or composition) | `update_node` with a new `prompt`, then `workflow_prepare` that node |
| swap the media an existing input node uses | `update_node` on the input node with the new `asset_id`; its connections stay. Then prepare the consumer. `workflow_add_node` adds a second generation node and leaves the old one unchanged |
| turn a Seedance Draft result into the final video | `add_node` with `node_kind` `video_upscale`, then `connect` the draft node's video output to its video input (ports from `workflow_get`) |
| product page on the canvas | `add_node` with `node_kind` `product_input` and `url` → [product](product.md) |
| add or restyle a canvas note | Use `add_node` with `node_kind: "note"` and `text`, or `update_node` with the existing `node_id`. Set `params.color` and `params.fontSize` using the [Note color and font size tokens](layout.md#notes). |
| rename, copy or remove a node; rename or copy the workflow; trim media; separate a video's audio; add a voice-over | [canvas-ops](canvas-ops.md) |
| a prompt refers to an input in words ("the first image", "@Image 1"), or inputs changed under a prompt with `{{Image N}}` | [prompt-refs](prompt-refs.md) |

## Rules
- Pass `base_graph_token`. `GRAPH_CONFLICT` means the canvas changed since your read, for example in the Portal: call `workflow_get` again and rebuild the batch against it. Do not resend the old batch.
- The batch is atomic: if one operation fails, none is saved. `details.operation_index` names the failing one.
- Notes can be created and edited here (`text`, `name`, size and color `params`). Other Portal-only nodes (Character, Script slots, collectors) can be read, moved, renamed, removed and connected here; their parameters are edited in the Portal (`portal_url`). Product companion nodes are the exception: `update_node` sets their output mode ([product](product.md)).
- One upstream result feeds a live connection. To use one picked result out of several, add an input node with that `asset_id` and `keep_fixed: true`, and only when the user asked to freeze exactly that result.
- A model switch drops what the new model cannot take and applies its default instead, and says so in `dropped_params`. Preview the switch to see known input limits before applying. After applying, prepare the target to check its current run scope, inputs and price.
- A step that does not serve the confirmed goal is offered as a choice.
- When the user asked for no run, the reply says the canvas is ready and how to run it (ask you, or run from the Portal).

## Revise an image
The wording picks the route; the user is not asked. A change to one attribute keeps the subject, so it builds on the existing image; a redo replaces the image.
- Unclear wording ("make it nicer", "improve it") asks one question: **Edit this image** (Recommended: the subject stays, the original is kept) · **Regenerate**.
- Name the route in the confirm question (main step 5), for example "keeps the machine, changes the background; the original stays".

## Advise the next move
For "what next" or a request nothing can do: read the canvas with `workflow_get` and `workflow_nodes` for the media in play. Offer up to three moves that reuse an existing output, the cheapest first, the first marked `(Recommended)`, each with its node, model and one tradeoff. Build after the answer.
If no capability reaches the goal, name the unsupported part and the closest achievable adjustment.
Done: the user picked one move or accepted the gap.

A `script` node's result is edited with `update_node` and `script`: the complete script object from the node's `params.script`, edited by `shot_id`; only downstream nodes become dirty. The chain here normally uses `text_input` for scripts instead ([script-writing](script-writing.md)).

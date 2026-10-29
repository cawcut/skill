# Change an existing canvas

Load for a follow-up, a missing reference, a new branch, a model switch, "what next", or the next stage of a goal whose canvas exists (script approved → video).

## Edit loop
1. `workflow get <id> --json`: keep the id and the source nodes involved.
2. Name the change in outcome words: new producers, consumer roles, what stays.
3. A missing input is an existing output to reuse or a producer node to add. Add the producer and its consumer edge in one batch; when the producer needs review first, run it, then add the consumer.
4. `set`, `connect`, `switch-model` for single changes; `edit --file -` for batches (`workflow schema batch` shows the shape). The reply carries the new graph and `valid`.
5. `dropped_params` and `dropped_edges` in a reply name what a model switch removed. Repair wanted connections in the next call.
6. `prepare` shows what re-runs and what stays cached; each paid run is confirmed (step 4 of the main list).

Done: the read-back graph holds every needed edge, `valid` is true, and the user knows the next run's scope and credits.

| Intent | Call |
| --- | --- |
| add a step | `edit` add_node, connected in the same batch (`create` is for a new canvas only) |
| use an output of this canvas ("the video above") | `connect` its node to the consumer. Re-adding its `asset_id` as an input node cuts the edge; the CLI refuses it with `OWN_OUTPUT_AS_INPUT` |
| use an outside file, URL or asset id | `asset upload`, then an input node with `asset_id` |
| feed A into B | `connect` |
| stop feeding | `edit` disconnect; keep a node that still serves the goal |
| change model or settings | `switch-model`, `set` |
| change part of an existing image ("调整为白色背景", "换成红色", "去掉 X") | add an `image-to-image` node, `connect` the image's node to it; the old node and its result stay. [Revise an image](#revise-an-image) |
| redo the whole image ("重新生成", a new style or composition) | `set` the node's `prompt`, then `prepare --target` it |
| swap the image, audio or video an existing node uses ("换个音频") | `set <id> --node <input node> asset_id=<new>`; its edges stay. Then `prepare --target` the consumer. `quick --workflow` adds a second generation node and leaves the old one unchanged |
| remove | `edit` remove_node (product companions go with the parent) |

## Rules
- A canvas edited in the Portal is read fresh before each edit; `GRAPH_CONFLICT` means re-read and rebuild the batch.
- Portal-only nodes (Note, Character, Script slots, collectors) are read, moved, removed and connected here; their parameters are edited in the Portal. `error.portal_url` names where.
- One upstream media result feeds a live edge. For several candidates fix the picked `asset_id` as an input node, or run one single-output stage first. Freezing a single output on purpose needs the user's word and `"keep_fixed": true` on the operation.
- A step that does not serve the confirmed goal is offered as a choice.

## Revise an image
The wording picks the route; the user is not asked. A change to one attribute keeps the subject, so it builds on the existing image; a redo replaces the image.
- Unclear wording ("好看一点", "优化一下") asks one question: **Edit this image** (Recommended: the subject stays, the original is kept) · **Regenerate**.
- Name the route in the confirm question (main step 4), for example "keeps the machine, changes the background; the original stays".

## Advise the next move
For "what next" or an infeasible request: read the project's real outputs and `nodes --capability <c>` for the media in play. Offer up to three moves that reuse an existing output, the cheapest first, marked `(Recommended)`, each with its node, model and one tradeoff. Build after the answer.
If no capability reaches the goal, name the unsupported part and the closest achievable adjustment.
Done: the user picked one move or accepted the gap.

# `@` references in prompts

Load when a prompt names an input ("the first image", "@Image 1") or an edit adds, removes or reorders inputs of a node whose prompt holds references.

## How the Portal writes a reference
Typing `@` in a prompt box lists the node's connected inputs; picking one inserts a chip, saved in `settings.prompt` as plain text:
| Token | Meaning |
| --- | --- |
| `{{Image N}}` `{{Video N}}` `{{Audio N}}` `{{Character N}}` | the input port named `Image N` (and so on) |
| `{{Video N [mm:ss-mm:ss]}}` | that part of the video |

`N` is the number in the port's name (`Image 1`, `Image 2`), as `workflow get` and `nodes --schema` list ports. A token is valid when an edge or group images fill that port. Only generation nodes (`image_generation`, `video_generation`, `storyboard_generation`) and Script nodes read tokens.

## Write them from the CLI
1. `workflow get <id>` and read the node's input `name`s with their edges.
2. Connect each input first, then write the token in `prompt` exactly as the port name: `set <id> --node <n> prompt="Keep the face of {{Image 1}}, use the clothes of {{Image 2}}"`.
3. `workflow check <id> --target <n>`. `REF_OUT_OF_RANGE` names the token that matches no port or no edge: connect the input or fix the token.

## When inputs change
The Portal drops an orphaned token (it becomes a space) and renumbers nothing; the CLI leaves the prompt as written. After a `disconnect`, a `remove_node` or a model switch, re-read the prompt, then `set` it without the tokens whose ports lost their input, and `check`.
Reordering means moving the media to other ports: connect it to the right port, then rewrite the token to that port's name.
Done: `check` reports no `REF_OUT_OF_RANGE` for the node.

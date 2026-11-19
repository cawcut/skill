# Canvas layout and notes

Load when creating or editing a canvas with more than two nodes, adding a note, or tidying positions ("整理", "排版", "间距").

## Footprints (approximate)

Canvas units, node top-left at `position {x, y}`. Source: FE-portal `src/editor/constants/index.ts` (`NodeConfig`, `NoteNodeConfig`); BE mirror: `workflow_layout.go` in flow.cawcut-workflow. Values are estimates for spacing, not exact. When FE changes them, update this table and the BE mirror together.

| Node | Width | Height |
| --- | --- | --- |
| Generation, text input, and most nodes | 280 | 350 (FE `defaultHeight` is 200, but these nodes render about 350 tall in FE-portal; measured); more with many ports (48 + 35 per port beyond the first + 16) |
| Node with media input or preview (image, video, audio input) | 280 | 350 |
| Script (after it ran) | 640 | about 500 |
| Note | 280 default, min 100, max 5000 | 100 default |

Gap between a node and the node it feeds: 125 horizontally (`NodeConfig.satelliteGapX`). Gap between nodes stacked in one column: 40. Use the 350 height, not 200: a smaller estimate makes notes and stacked nodes overlap on the canvas.

## Place nodes

The server places new nodes by rank and the `layout` operation arranges the whole canvas. After a batch that adds more than two nodes, or when the canvas looks tangled, run `cawcut workflow layout <id>` once; its reply carries `graph` with the new positions and `valid`, so no `workflow get` is needed. A horizontal layout also returns `layout {crossings, overlaps, backward_edges}`; `overlaps` and `backward_edges` should be 0.
Done: `overlaps` and `backward_edges` are 0 (vertical layouts return no stats: read positions with the footprint table).

`layout` result, for a read-back check:
- Every edge runs left to right; a column holds one rank, with at least a 125 gap between columns and 40 between stacked nodes. Every position is a multiple of 20, and sizes and gaps are rounded up to it, so real gaps can be up to 15 wider.
- Parallel branches of equal shape become lanes: one row per branch, same-rank nodes aligned in one column, the merge node centred at the right.
- An input shared by at least 3 nodes across 2 or more lanes (Style text, a character sheet, reference images) sits in a band below the lanes, in the columns of its consumers. A shared input with fewer consumers is placed between the lanes by rank; one crossing can be unavoidable.
- Unconnected nodes go to a corner below; notes move below everything, including notes you placed.
- `direction: "vertical"` stacks ranks top to bottom without lane alignment and returns no `layout` stats.
- Running it twice moves nothing; it moves nodes you placed by hand, so ask first when the user arranged the canvas ("tidy up" is the ask).

Placing by hand with `move_node` or `position`:
1. Column x = previous column x + widest node in it + 125 (405 with 280-wide nodes).
2. Stack by node height + 40 and centre a consumer on its producers.
3. No overlap: width and height from the table.
4. Existing nodes keep their positions unless moved.

## Notes

A note uses `node_kind: "note"` and holds its content in `text`. It has no ports and costs nothing. Set the following values in `params` when creating or editing a note.

| Parameter | Canvas options |
| --- | --- |
| `color` | `color-1` neutral (white in light mode, charcoal in dark mode), `color-2` blue, `color-3` purple, `color-4` pink, `color-5` yellow, `color-6` green |
| `fontSize` | `size-1` Small (16 px), `size-2` Medium (24 px), `size-3` Large (40 px), `size-4` Extra Large (64 px) |
| `width`, `height` | Integer canvas units, 100–5000 wide and 40–5000 high |

For a blue note with Medium text, send `"params": {"color": "color-2", "fontSize": "size-2"}`. To verify, read the note with `cawcut workflow get <id>` and compare its `params.color` and `params.fontSize` to those tokens.

- Give a custom size only when the text needs it, and reserve that exact box: width x height from `params` (default 280 x 100).
- Put a note above or below the nodes it describes, or in its own free column; never on top of a node.
- Without `position` the server parks a new note below all other nodes.

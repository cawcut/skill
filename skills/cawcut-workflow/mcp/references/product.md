# Product page to canvas

Load for a product URL on a canvas, or an ad asked for on a canvas. An ad or ad video made through the wizard (a product URL with no canvas asked for) belongs to the `cawcut-ad-video` skill: hand off to it and tell the user a wizard project is separate from this canvas. An ad the user asked for on a canvas, and a product-page URL to extract only, stay here.

Before scraping a URL given only to extract, ask one question: hand the URL to the Ad Video wizard (`cawcut-ad-video`) or create on a free canvas. Extraction starts after the answer. An ad asked for on a canvas skips that question, not the post-extraction Ask below: it keeps a **Ad video wizard** option.

## Source
A product page becomes a `product_input` node. `url` sits on the node next to `ref` and `node_kind`, never in `params`:

```json
{"op":"add_node","ref":"p","node_kind":"product_input","url":"<product page URL>"}
```

It brings four companion groups: brief, main image, logo, images (each has `parent_node_id` = the Product node in `workflow_get`). The parent owns them; `remove_node` on the parent removes them.

A canvas with no generation node starts with `workflow_create`. For extraction alone:

```json
{"name":"<product> extract","nodes":[{"ref":"p","node_kind":"product_input","url":"<product page URL>"}]}
```

Then `workflow_check` (target the product node) and `workflow_run` with `node_id` = the Product node, poll, and read everything with `workflow_get` (each companion holds its content in `params.items`, the brief text included; keep the image `asset_id`s). A Product run is free: it takes no `workflow_prepare` and no Ask, and the paid-run gate of main step 5 starts at the first paid node. `workflow_results` lists only assets. A direct image, video or audio URL is a media input ([media-sources](media-sources.md)), not a product page. A page whose purpose is unclear gets one question: product extraction or something else.

## After extraction
1. Download the main image and the first nine product images in one shell loop ([delivery](delivery.md) holds the file-name and URL rules).
2. Send them in one call of the host's file-send tool (`files` takes several paths), main image first.
3. One Ask whose `question` opens with the facts (title, price, brief, what the main image shows, how many more product images exist). A user who asked for images only gets **Ad images** and goes to the image chain. Otherwise the options are the four below, each with its cost in the option text:
   - **Direct video**: Product → `image-to-video` (chain A). One paid run, one confirm; the confirm shows your prompt, model, length and price. Cheapest, fits one scene.
   - **Script + storyboard**: Product → script `text_input` → `storyboard` → `image-to-video` (chain B). The user confirms the script once, then one price confirm for the whole chain. Costs more; fixes composition and subject across shots.
   - **Ad video wizard**: hands off to the `cawcut-ad-video` skill with the product URL and the facts already extracted; tell the user the wizard makes a separate project, has its own gates and leaves this canvas as it is.
   - **Stop here**.
4. Rules for the Ask:
   - "Generate the final video directly" (any wording) only means the user picked **Direct video**. It does not waive this Ask or the paid-run confirm. When the prompt says it, list **Direct video** first, marked Recommended.
   - A prompt with several selling points or scenes (look, waterproofing, a kids scene) adds one line to the `question`: a single clip may not fit them all, so a script first is advised; list **Script + storyboard** first, marked Recommended.
   - Never build a chain, and never run one, before this Ask is answered.

Done: the main image and the product images are in the chat, a companion with no items (a missing logo) is named as empty, and the Ask is made.

## Pick one output
A companion starts `grouped`. `update_node` on the companion with `params` `{"outputMode":"select","selectedIndex":<i>}` picks one output; `selectedKeys` filters an image group by asset id. Switching mode drops consumer edges the new output type cannot feed: read `dropped_edges`, reconnect the consumers the user still wants and name the dropped ones.

## Ad chain (after extraction)
Build the chain the user picked in the Ask, on the same canvas, in one `workflow_edit` batch wired from the Product companions. Ask once before building: aspect ratio and length (video) or aspect ratio and count (images).

**Ad images**: Product → `image-to-image`; brief → `prompt`, main image → `image`.

### A. Direct video
Product → `image-to-video`. Write the prompt yourself from the brief and the main image: one scene, one camera move, the product named, no unsupported claim.

```json
{"op":"add_node","ref":"v","node_kind":"video_generation","capability":"image-to-video","model_id":"<model_id>","prompt":"<your prompt>","params":{"duration":15,"aspect_ratio":"9:16"}}
{"op":"connect","from":{"node_id":"<main image companion id>","port":"imagegroup"},"to":{"ref":"v","port":"image"}}
```

The same chain as one `workflow_create` (Product node included):

```json
{"name":"<product> ad","nodes":[
 {"ref":"p","node_kind":"product_input","url":"<product page URL>"},
 {"ref":"v","node_kind":"video_generation","capability":"image-to-video","model_id":"<model_id>","prompt":"<your prompt>","params":{"duration":15,"aspect_ratio":"9:16"}}],
 "edges":[{"from":{"ref":"p","port":"main_image"},"to":{"ref":"v","port":"image"}}]}
```

`<model_id>` and the `params` keys come from the model's schema (`workflow_nodes` with `schema:true`). In `workflow_create`, the Product node's output ports are `textgroup` (brief), `main_image`, `logo` and `imagegroup` (product images); on a companion node already on the canvas the output port is `imagegroup` (`textgroup` for the brief). Then `workflow_check`, `workflow_prepare`, and one paid Ask that shows the prompt text in full, the model, length and `credits_required`.

Not satisfied with the result: offer to add a script and storyboard on this canvas (chain B) with `workflow_edit`; never open a new canvas.

### B. Script + storyboard
Product → script `text_input` → `storyboard` → `image-to-video`.

```json
{"name":"<product> ad","nodes":[
 {"ref":"p","node_kind":"product_input","url":"<product page URL>"},
 {"ref":"s","node_kind":"text_input","text":"<script, confirmed by the user>"},
 {"ref":"sb","node_kind":"storyboard_generation","capability":"storyboard","model_id":"<model_id>"},
 {"ref":"v","node_kind":"video_generation","capability":"image-to-video","model_id":"<model_id>","params":{"duration":15,"aspect_ratio":"9:16"}}],
 "edges":[
  {"from":{"ref":"s","port":"text"},"to":{"ref":"sb","port":"prompt"}},
  {"from":{"ref":"p","port":"main_image"},"to":{"ref":"sb","port":"image"}},
  {"from":{"ref":"p","port":"imagegroup"},"to":{"ref":"sb","port":"image_2"}},
  {"from":{"ref":"sb","port":"image"},"to":{"ref":"v","port":"image"}},
  {"from":{"ref":"p","port":"main_image"},"to":{"ref":"v","port":"image_2"}},
  {"from":{"ref":"s","port":"text"},"to":{"ref":"v","port":"prompt"}}]}
```

On a canvas that already holds the Product node use `workflow_edit` with `add_node` and `connect` instead, and the Product's real node ids. The default models take one connection per image port (`image`, `image_2`, …), so each extra source goes to the next port; the ports above fit them, another model's come from its schema.

Order: write the script from the brief ([script-writing](script-writing.md)) and show it in an Ask (confirm or edit); build the chain from the confirmed text; `workflow_check`; `workflow_prepare` for the whole chain; one price Ask with the type (B), each paid node and its price, and the total. Then run in chain order and show each result: the storyboard sheet, then the video.

### Both chains
- Wire every Product reference: the storyboard takes the main image plus the product images, never the main image alone; the video takes the storyboard sheet plus the main image. One `connect` per source; a port whose `maxConnections` is 1 takes one source, so the next source goes to the next numbered port (`image_2`, `image_3`, …). Before wiring, read the model's schema (`workflow_nodes` with `schema:true`) and check the `image` input's `constraints.maxConnections` (in `workflow_get` the same value is the port's own `max_connections`) against the number of sources. `has_port` only tells whether a port exists, not how many images it takes. If the model has fewer image ports than sources, pick another model whose schema allows enough, and name any image left out.
- Port names above are the default models'; another model's come from its schema.
- Keep sourced facts apart from marketing claims; a claim the user cannot support stays out.

Done: the chain's last node delivered its result (main step 7).

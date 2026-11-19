# Product page to canvas

Load for a product URL to scrape or extract, or an ad asked for on a canvas. Before scraping, ask one question: hand the URL to the Ad Video wizard (`cawcut-ad-video`) or create on a free canvas. Extraction starts after the answer. An ad asked for on a canvas skips that question, not the post-extraction Ask below, which keeps an **Ad Video wizard** option.

## Source
A product page becomes a `product_input` node; `url` sits on the node next to `ref` and `node_kind`, never in `params`:
`echo '{"name":"<product> extract","nodes":[{"ref":"p","node_kind":"product_input","url":"<URL>"}]}' | cawcut workflow create --file - --json`
It brings four companion groups: brief, main image, logo, images. The parent owns them; remove the parent to remove them.
A direct image, video or audio URL is a media input; upload it with `cawcut asset upload`. A page whose purpose is unclear gets one question: product extraction or something else.
Run the Product node (`run <id> --target <product node> --wait`); it is free, so it takes no `prepare` and no confirm. Its reply lists only image assets; read everything with `workflow get <id> --json`: each companion (`parent_node_id` = the Product node) holds its content in `params.items`, the brief text included. Keep the image `asset_id`s.
Next move: `workflow results <id> --node <n> --download --json` for the main image and the images companion, then one call of the file-send tool with the main image and the first nine product images (`files` takes several paths), main image first. Then Ask, its `question` opening with the facts (gate **Show**), including how many more product images exist. A user who asked for images only gets **Ad images** and goes to the image chain. Otherwise the options are the four below, each with its cost in the option text:
- **Direct video**: Product → `image-to-video` (chain A). One paid run, one confirm; the confirm shows your prompt, model, length and price. Cheapest, fits one scene.
- **Script + storyboard**: Product → script `text_input` → `storyboard` → `image-to-video` (chain B). The user confirms the script once, then one price confirm for the whole chain. Costs more; fixes composition and subject across shots.
- **Ad Video wizard**: hands off to `cawcut-ad-video` with the product URL and the facts already extracted; it makes a separate project with its own gates and leaves this canvas as it is.
- **Stop here**.

Rules for the Ask:
- "Generate the final video directly" (any wording) only means the user picked **Direct video**. It does not waive this Ask or the paid-run confirm. When the prompt says it, list **Direct video** first, marked Recommended.
- A prompt with several selling points or scenes (look, waterproofing, a kids scene) adds one line to the `question`: a single clip may not fit them all, so a script first is advised; list **Script + storyboard** first, marked Recommended.
- Never build a chain, and never run one, before this Ask is answered.

Done: the main image and the product images are in the chat, a companion with no items (a missing logo) is named as empty, the facts are shown (or the gap is stated and the user chose a manual brief plus real photos), and the Ask is made.

## Pick one output
A companion starts `grouped`. `set <id> --node <companion> outputMode=select selectedIndex=<i>` picks one output; `selectedKeys` filters an image group by asset id. Switching mode drops consumer edges the new output type cannot feed. Re-connect the consumers the user still wants and name the dropped ones.

## Ad chain (after extraction)
Build the chain the user picked in the Ask, on the same canvas, wired from the Product companions. Ask once before building, one call: aspect ratio and length (video) or aspect ratio and count (images). Then price and run per step 4 of the main list.

**Ad images**: Product → `image-to-image`; brief → `prompt`, main image → `image`.

### A. Direct video
Product → `image-to-video`. Write the prompt yourself from the brief and the main image: one scene, one camera move, the product named, no unsupported claim.

`echo '{"name":"<product> ad","nodes":[{"ref":"p","node_kind":"product_input","url":"<product page URL>"},{"ref":"v","node_kind":"video_generation","capability":"image-to-video","model_id":"<model_id>","prompt":"<your prompt>","params":{"duration":15,"aspect_ratio":"9:16"}}],"edges":[{"from":{"ref":"p","port":"main_image"},"to":{"ref":"v","port":"image"}}]}' | cawcut workflow create --file - --json`

On a canvas that already holds the Product node, use `edit` with `add_node` and `connect` (`from` the main image companion's `node_id`, port `imagegroup`). `<model_id>` and the `params` keys come from `nodes --capability image-to-video --model <id> --schema`. Product output ports in `create`: `textgroup` (brief), `main_image`, `logo`, `imagegroup` (product images). Then `prepare`, and one paid Ask that shows the prompt text in full, the model, length and credits.

Not satisfied with the result: offer to add a script and storyboard on this canvas (chain B) with `edit`; never open a new canvas.

### B. Script + storyboard
Product → script `text_input` → `storyboard` → `image-to-video`. Write the script from the brief ([script-writing](script-writing.md)) and show it in an Ask (confirm or edit). Build from the confirmed text:

`echo '{"name":"<product> ad","nodes":[{"ref":"p","node_kind":"product_input","url":"<product page URL>"},{"ref":"s","node_kind":"text_input","text":"<confirmed script>"},{"ref":"sb","node_kind":"storyboard_generation","capability":"storyboard","model_id":"<model_id>"},{"ref":"v","node_kind":"video_generation","capability":"image-to-video","model_id":"<model_id>","params":{"duration":15,"aspect_ratio":"9:16"}}],"edges":[{"from":{"ref":"s","port":"text"},"to":{"ref":"sb","port":"prompt"}},{"from":{"ref":"p","port":"main_image"},"to":{"ref":"sb","port":"image"}},{"from":{"ref":"p","port":"imagegroup"},"to":{"ref":"sb","port":"image_2"}},{"from":{"ref":"sb","port":"image"},"to":{"ref":"v","port":"image"}},{"from":{"ref":"p","port":"main_image"},"to":{"ref":"v","port":"image_2"}},{"from":{"ref":"s","port":"text"},"to":{"ref":"v","port":"prompt"}}]}' | cawcut workflow create --file - --json`

The default models take one connection per image port (`image`, `image_2`, …), so each extra source goes to the next port; another model's ports come from its `--schema`. Then `prepare <id>` for the whole chain and one price Ask with the type (B), each paid node and its price, and the total. Run in chain order and show each result: the storyboard sheet, then the video.

### Both chains
- Wire every Product reference: the storyboard takes the main image plus the product images, never the main image alone; the video takes the storyboard sheet plus the main image. One `connect` per source; a port whose max is 1 takes one source, so the next goes to the next numbered port. If the model has fewer image ports than sources, pick a model with more (`nodes --capability <cap> --has-port <port>`) and name any image left out.
- Models: the step 3 menu per paid node; the default model unless the user changes it.
- Keep sourced facts apart from marketing claims; a claim the user cannot support stays out.

Done: the chain's last node delivered its result (main step 5).

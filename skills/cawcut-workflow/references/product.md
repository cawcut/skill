# Product page to canvas

Load for a product URL to scrape or extract, or an ad asked for on a canvas. Before scraping, ask one question: hand the URL to the Ad Video wizard (`cawcut-ad-video`) or create on a free canvas. Extraction starts after the answer. An ad asked for on a canvas skips the question.

## Source
A product page becomes a `product_input` node; `url` sits on the node next to `ref` and `node_kind`, never in `params`:
`echo '{"name":"<product> extract","nodes":[{"ref":"p","node_kind":"product_input","url":"<URL>"}]}' | cawcut workflow create --file - --json`
It brings four companion groups: brief, main image, logo, images. The parent owns them; remove the parent to remove them.
A direct image, video or audio URL is a media input; upload it with `cawcut asset upload`. A page whose purpose is unclear gets one question: product extraction or something else.
Run the Product node (`run <id> --target <product node> --wait`). Its reply lists only image assets; read everything with `workflow get <id> --json`: each companion (`parent_node_id` = the Product node) holds its content in `params.items`, the brief text included. Keep the image `asset_id`s.
Next move: show the facts and images, then call the host question tool: ad images · ad video · hand the product to the Ad Video wizard · stop here.
Done: facts and images are returned (or the gap is stated and the user chose a manual brief plus real photos), and the question tool call is made.

## Pick one output
A companion starts `grouped`. `set <id> --node <companion> outputMode=select selectedIndex=<i>` picks one output; `selectedKeys` filters an image group by asset id. Switching mode drops consumer edges the new output type cannot feed. Re-connect the consumers the user still wants and name the dropped ones.

## Ad chain (after extraction)
Add the chain to the same canvas in one `edit` batch, wired from the Product companions. Ask once before building, one call: aspect ratio and length (video) or aspect ratio and count (images). Then price and run per step 4 of the main list.

| Goal | Chain | Wiring |
| --- | --- | --- |
| Ad images | Product → `image-to-image` | brief → `prompt`; main image → `image` |
| Ad video | Product → script `text_input` → `storyboard` → `image-to-video` | script from the brief ([script-writing](script-writing.md)); script → storyboard `prompt`; main image **and** the images companion (product images) → storyboard `image`; storyboard output **and** main image → video `image`; script → video `prompt` |

- Wire every Product reference: the storyboard takes the main image plus the product images, never the main image alone; the video takes the storyboard sheet plus the main image. One `connect` per source, to the same `image` port; if the model's `--schema` shows a single-image port or a cap, pick a model with a multi-image port (`nodes --capability <cap> --has-port <port>`) and name any image left out.
- Models: the step 3 menu per paid node; the default model unless the user changes it. Port names above are the default models'; another model's come from its `--schema`.
- Show the script for approval before building, then run in chain order and show each result: the storyboard sheet, then the video.
- Keep sourced facts apart from marketing claims; a claim the user cannot support stays out.
- A longer or multi-scene ad: offer the Ad Video wizard (`cawcut-ad-video`) instead of growing this chain.

Done: the chain's last node delivered its result (main step 5).

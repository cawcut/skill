# Script writing

Load for every script, storyboard text or shot list, and for the script step of a story or ad. The agent writes the screenplay; on a canvas it lives in a `text_input` node. The `script` node stays unused.

1. Write the screenplay as readable shot text. Per shot: number, duration, shot type, camera movement, picture description, dialogue. Fit durations to the video model's limit. Describe characters, products and places in words.
2. The user confirms or edits it. A text-only request ends here, with an offer to produce it.
3. Render path. Two or more shots, or a subject image (supplied, or already on the canvas), asks one question: **Storyboard first** (Recommended: one sheet fixes composition and subject across shots) · **Straight to video** (cheaper, subjects may drift). A single shot, or a user who named the path, skips it.
4. Add a `text_input` with the text and connect it to the prompt port of the storyboard node (script → `prompt`; subject images → `image`; its sheet and the subject image → the video's `image`, wired as the Ad video row in [product](product.md)) or of the video node. A canvas that exists takes `edit` add_node; `create` serves only a first canvas.
5. Connect character and scene images to image ports: canvas outputs by edge, outside media as `asset_id` inputs.
6. A script change is an `update_node` of that text; its consumers become dirty and re-run on the next confirmed run.

Done: the user approved the text, and for production a runnable `text_input` chain exists.

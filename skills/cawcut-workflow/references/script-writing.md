# Script writing

Load for every script, storyboard text or shot list, and for the script step of a story or ad. The agent writes the screenplay; on a canvas it lives in a `text_input` node. The `script` node stays unused.

1. Write the screenplay as readable shot text. Per shot: number, duration, shot type, camera movement, picture description, dialogue. Fit durations to the video model's limit. Describe characters, products and places in words.
2. Show the script in the Ask's `question` (gate **Show**). The canvas receives it after the user confirms or edits it. A text-only request ends here, with an offer to produce it.
3. Render path. Two or more shots, or a subject image (supplied, or already on the canvas), earns that one Ask, the script as its `question` opening: **Storyboard first** (Recommended: one sheet fixes composition and subject across shots) · **Straight to video** (cheaper, subjects may drift) · **Edit the script**. A single shot, or a user who named the path, skips it. A reply that picks neither path names none: Ask again.
4. Add a `text_input` with the text and connect it to the prompt port of the storyboard node (script → `prompt`; subject images → `image`; its sheet and the subject image → the video's `image`, wired as the Ad video row in [product](product.md)) or of the video node. A canvas that exists takes `edit` add_node; `create` serves only a first canvas.
5. Straight to video with a subject image on the canvas uses an `image-to-video` model with the image on its `image` port. A text-only model leaves the image unused: say so and why.
6. Connect character and scene images to image ports: canvas outputs by edge, outside media as `asset_id` inputs.
7. A script change is an `update_node` of that text; its consumers become dirty and re-run on the next confirmed run.

Done: the user approved the text, and for production a runnable `text_input` chain exists.

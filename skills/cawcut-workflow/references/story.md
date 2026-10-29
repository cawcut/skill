# Story or script video on a canvas

Load for a story, screenplay or multi-shot video. The script is text from [script-writing](script-writing.md).
A user who asks for the dedicated pipeline, or has a Story Video project, goes to `cawcut-story-video`.

## Arc
Skip a rung the user already settled. Ask only the next real question.
1. Idea → short script and shot plan.
2. The approved screenplay in a `text_input` node on the canvas.
3. Anchors for recurring subjects and locations: one image each, reuse supplied `asset_id`s.
4. Shot plan: order, duration (within the video model's limit), continuity, sound.
5. Render path: [script-writing](script-writing.md) step 3.
6. Execute each shot, audit, then `cawcut-vn`.

Done: every shot has an anchor, a duration and a model.

## Storyboard
The script `text_input` → the storyboard model's text port; anchors → its image ports. A storyboard sheet is one image. A video model that takes a sheet may use it directly; per-shot first/last frames need single-frame assets from an available crop capability or separate images. Name the gap when neither exists.

## Several clips
Ask only when more than one clip exists.
- Hybrid: chain inside a scene, render scenes in parallel.
- Parallel: time jumps, wardrobe or location changes.
- Sequential: one continuous action.
Chain video references inside one unbroken scene only. A continuity edge needs a media role the consumer's schema offers.

Next move after each result: script → shot plan, then first anchor; anchor → remaining anchors, then render path; storyboard → review or animate its shot; shot → next shot; all shots → `cawcut-vn`.
No stitching node exists; a set of clips becomes a film in `cawcut-vn`.

# Deliver

Load at step 5. An intermediate stage shows its output and returns to the plan.

1. `workflow results <id> --node <n> --download --json`. Keep per output: `workflow_id`, `task_id`, `node_id`, `asset_id`, signed URL, local path. Failed downloads are retried alone.
2. Audit each image against the request's checkable parts: subject, supplied reference, setting, aspect, text, using the image viewer. Report `passed` or `needs_revision` with evidence; execution success and content fit are separate findings.3. Send every image and video to the chat with the host's file-send tool. Fall back to an inline render, then to a link, and say what the preview lacked.
4. Tell the user what was made, actual credits (a BE estimate is labelled so), the balance, the image audit result and the Portal link.
   Draft model (reply has `upscale_hint`, e.g. Seedance 2.5 Draft): the video is a preview. Add one line in the user's language, after the summary: "If you are satisfied with the result, try Upscale for a higher-quality video", with `upscale_hint.estimate_credits` as the cost and `expires_at` as the deadline when present. Omit the price when absent; never invent one. Ask one question: **Upscale** · **Not now**. Never upscale unasked.
   Upscale: `workflow upscale <id> --node <draft_node> --json` (adds and connects the node; reply has `upscale_node_id`), then `prepare <id> --target <upscale_node_id>` for the price, the step 4 confirm, and `run <id> --target <upscale_node_id> --wait`. A full `run` skips draft and upscale nodes, so always name the target. Past `expires_at` the draft cannot be upscaled.
5. Call the `Skill` tool, `skill: cawcut-vn`, in the same turn as step 4, with every local path, title, aspect, order and audit notes in `args`. Images count the same as video: VN imports and previews still images. VN owns the choice (preview, editing or no action) and asks it; ask no VN question and run no VN command here. Skip only when the user already declined VN this session.

Reuse: a later step takes the returned `asset_id` as a fixed input; a live dependency connects the producer's output instead. Re-uploading an edited local file makes it new media.
Done: each output reached the user as an attachment or a stated fallback, with cost (and audit for images), then the `cawcut-vn` Skill call was made.

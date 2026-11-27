# CawCut capabilities

<!-- Generated from references/capabilities.json by scripts/capabilities.py -->

## Choose a route

Reuse the route already chosen in this session, including on a handoff. On first use honor an explicit CLI or MCP request. For an explicit MCP choice, go directly to the connected tools. In automatic mode prefer CLI with a shell. On CLI, if any CawCut CLI call already succeeded, skip the probe. Otherwise run `cawcut upgrade check --json` once. Install an available update with `cawcut upgrade`; an ahead-of-registry build can continue. Choose MCP automatically only without a shell or when the executable is missing. Other check errors leave the CLI selected; let the first real operation report its error.

CLI: read the JSON result and follow its error guidance. For an expired login use `cawcut auth login --browser --json` on the user's computer, or `cawcut auth login --device-auth --json` in a remote environment. For device auth show the authorization URL and resume the same request with `cawcut auth login --complete --wait --timeout 60 --json`. Retry the operation once after authentication; check the status of any ambiguous submission first.

MCP: use the connected CawCut tool with the listed name (hosts may prefix it). Parse JSON text content and treat `isError=true` as failure. The host handles OAuth consent and refresh. On persistent auth failure ask the user to reconnect. Check the actual host's offered tools, since some are deployment-specific. When the selected route cannot perform an operation, use its documented alternative or explain the limitation. Never submit again through the other route to recover an uncertain write.

If no usable route is available, ask the user to install `@ubnt/cawcut` for CLI or connect the hosted CawCut MCP endpoint.

## Operations

Substitute the actual values and JSON types from the current request. Examples with a category, individual node, stage or media type illustrate one scope. Follow the usage notes when that scope changes.

### `ad.analyze`

- CLI: `cawcut ad-video analyze run <video_ad_id> --url <https_url> --json`
- MCP: `ad_video_stage_run {"id": "<video_ad_id>", "stage": "analyze", "url": "<https_url>"}`

Analyze the same URL used to create the project.

### `ad.approve`

- CLI: `cawcut ad-video review approve <video_ad_id> --item <item> --json`
- MCP: `ad_video_review {"id": "<video_ad_id>", "action": "approve", "item": "<item>", "fingerprint": "<fingerprint>"}`

Only after the user's approval of the displayed character, location or script. Use its current fingerprint on MCP. Refresh if it changed.

### `ad.cancel`

- CLI: `cawcut ad-video analyze cancel <video_ad_id> --json`
- MCP: `ad_video_stage_run {"id": "<video_ad_id>", "stage": "analyze_cancel"}`

Cancel an in-progress product analysis on request.

### `ad.config`

- CLI: `cawcut ad-video config set <video_ad_id> --language <language> --json`
- MCP: `ad_video_set {"id": "<video_ad_id>", "stage": "config", "config": {"language": "<language>"}}`

Send the confirmed fields; CLI uses flags, MCP nests the corresponding snake_case fields under config. Saving does not start ideas.

### `ad.create`

- CLI: `cawcut ad-video create --url <https_url> --json`
- MCP: `ad_video_project {"action": "create", "url": "<https_url>"}`

Keep the new project ID and portal URL. Optional name only when requested.

### `ad.deliver`

- CLI: `cawcut ad-video video deliver <video_ad_id> --json`
- MCP: `ad_video_project {"id": "<video_ad_id>", "action": "get", "view": "full"}`

CLI downloads into the project folder and returns report and local_path. MCP returns final_video assets; follow the MCP delivery reference to save, send and import.

### `ad.direction`

- CLI: `cawcut ad-video instruction confirm <video_ad_id> --json`
- MCP: `ad_video_review {"id": "<video_ad_id>", "action": "confirm_direction", "fingerprint": "<direction_fingerprint>"}`

Clear the current visual-direction gate before the photo pass. Read the direction fingerprint from image_plan.

### `ad.duplicate`

- CLI: `cawcut ad-video duplicate <video_ad_id> --name <name> --json`
- MCP: `ad_video_project {"action": "duplicate", "id": "<video_ad_id>", "name": "<name>"}`

Return the copy's URL. Perform requested follow-up edits on its ID.

### `ad.entity.quote`

- CLI: `cawcut ad-video character quote <video_ad_id> --entity character --json`
- MCP: `ad_video_quote {"id": "<video_ad_id>", "stage": "character"}`

For location, use --entity location / stage:location. Keep this entity's quote token.

### `ad.entity.run`

- CLI: `cawcut ad-video character run <video_ad_id> --entity character --confirmation-token <confirmation_token> --json`
- MCP: `ad_video_generate {"id": "<video_ad_id>", "stage": "character", "confirmation_token": "<confirmation_token>"}`

Only after confirmation of that entity's quote. Match character or location.

### `ad.entity.set`

- CLI: `cawcut ad-video character set <video_ad_id> --entity character --prompt <prompt> --json`
- MCP: `ad_video_set {"id": "<video_ad_id>", "stage": "character", "character": {"entity": "character", "image_prompt": "<prompt>"}}`

Select character or location. Name-only edits do not generate; save a changed prompt before quoting.

### `ad.get`

- CLI: `cawcut ad-video detail <video_ad_id> --json`
- MCP: `ad_video_project {"action": "get", "id": "<video_ad_id>", "view": "full"}`

Read current project fields and outputs. On MCP use summary for polling and full to present content.

### `ad.ideas`

- CLI: `cawcut ad-video idea run <video_ad_id> --json`
- MCP: `ad_video_stage_run {"id": "<video_ad_id>", "stage": "ideas"}`

Start idea generation. For an explicitly requested fresh batch use CLI idea regenerate or MCP regenerate:true after explaining that the selection clears.

### `ad.images.quote`

- CLI: `cawcut ad-video image quote <video_ad_id> --generation-type <generation_type> --json`
- MCP: `ad_video_quote {"id": "<video_ad_id>", "stage": "images", "generation_type": "hand_drawn"}`

Quote exactly the next pass: hand_drawn or photo_realistic.

### `ad.images.run`

- CLI: `cawcut ad-video image run <video_ad_id> --generation-type <generation_type> --confirmation-token <confirmation_token> --json`
- MCP: `ad_video_generate {"id": "<video_ad_id>", "stage": "images", "generation_type": "hand_drawn", "confirmation_token": "<confirmation_token>"}`

Repeat the quoted generation type and token immediately after approval.

### `ad.more`

- CLI: `cawcut ad-video idea load-more <video_ad_id> --json`
- MCP: `ad_video_select {"id": "<video_ad_id>", "action": "load_more"}`

Reveal the next page of generated candidates.

### `ad.options`

- CLI: `cawcut ad-video options --video-ad-id <video_ad_id> --json`
- MCP: `ad_video_options {"video_ad_id": "<video_ad_id>"}`

Read actor- and project-scoped settings and defaults.

### `ad.product`

- CLI: `cawcut ad-video product set <video_ad_id> --description <description> --json`
- MCP: `ad_video_set {"id": "<video_ad_id>", "stage": "product", "product": {"description": "<description>"}}`

Send only the edited product fields. MCP nests them under product; preserve existing asset IDs.

### `ad.rename`

- CLI: `cawcut ad-video rename <video_ad_id> <name> --json`
- MCP: `ad_video_project {"action": "rename", "id": "<video_ad_id>", "name": "<name>"}`

Changes only the project title, not the product name, and regenerates nothing. Refused while a stage is generating; wait, then retry.

### `ad.review.next`

- CLI: `cawcut ad-video review next <video_ad_id> --json`
- MCP: `ad_video_project {"action": "get", "id": "<video_ad_id>", "view": "full"}`

For CLI display use the bundled storyboard_review helper; it also downloads previews and renders the script table. On MCP read storyboard.next_step, review and image_plan from the project. Request the full view to present prompts, images and the script table; use summary for polling.

### `ad.script.set`

- CLI: `cawcut ad-video storyboard set <video_ad_id> --base-revision <revision> --plan-file <plan_file> --json`
- MCP: `ad_video_set {"id": "<video_ad_id>", "stage": "storyboard", "storyboard": {"base_revision": 1, "plan": {"title": "<edited title>", "synopsis": "<synopsis>", "assets": {"characters": [], "scenes": []}, "shots": [{"shot_id": "<existing shot id>"}]}}}`

CLI reads the complete edited plan from disk. MCP takes the complete JSON plan object at storyboard.plan. The abbreviated shape only locates the fields: copy the full fetched plan with its assets, shots and unknown fields, apply the confirmed edits, and use its real revision. On conflict re-read and reapply.

### `ad.select`

- CLI: `cawcut ad-video idea select <video_ad_id> --message-id <message_id> --title <title> --content <content> --json`
- MCP: `ad_video_select {"id": "<video_ad_id>", "action": "select", "message_id": "<message_id>", "title": "<title>", "content": "<content>"}`

Use the candidate as returned. For a custom idea send --custom / custom instead of generated message fields.

### `ad.storyboard.quote`

- CLI: `cawcut ad-video character estimate <video_ad_id> --wait --json`
- MCP: `ad_video_quote {"id": "<video_ad_id>", "stage": "storyboard", "wait_seconds": 25}`

Free decision about required entities and their initial fee. Pending means wait; a failed decision needs user consent before retry.

### `ad.storyboard.run`

- CLI: `cawcut ad-video storyboard run <video_ad_id> --confirmation-token <confirmation_token> --json`
- MCP: `ad_video_generate {"id": "<video_ad_id>", "stage": "storyboard", "confirmation_token": "<confirmation_token>"}`

Use the first-estimate token only. Omit token for an explicitly no-charge or supported uncharged legacy step. Explicit regeneration discards script edits; use --force / force:true only after warning and any required fresh quote.

### `ad.video.quote`

- CLI: `cawcut ad-video video quote <video_ad_id> --json`
- MCP: `ad_video_quote {"id": "<video_ad_id>", "stage": "video"}`

Quote only the final video. Check balance before asking.

### `ad.video.run`

- CLI: `cawcut ad-video video run <video_ad_id> --confirmation-token <confirmation_token> --json`
- MCP: `ad_video_generate {"id": "<video_ad_id>", "stage": "video", "confirmation_token": "<confirmation_token>"}`

Submit only after the user accepts the fresh video quote.

### `ad.wait`

- CLI: Run the bundled poll.sh or poll.ps1 with the project ID and stage-specific field, success value and timeout from references/cli-media.md.
- MCP: `ad_video_project {"action": "get", "id": "<video_ad_id>", "wait_seconds": 25}`

On CLI use the bundled stage polling helper and its stage-specific terminal condition. On MCP repeat this long poll while busy; use view:full when presenting content.

### `media.confirm`

- CLI: Handled by the CLI upload; there is no separate command.
- MCP: `media_confirm {"upload_token": "<upload_token>"}`

MCP only. Confirm the successful PUT with its matching upload token.

### `media.import`

- CLI: `cawcut asset upload <https_url> --json`
- MCP: `media_import_url {"url": "<https_url>", "type": "image"}`

Use the actual media type. Keep the returned asset_id. Say the rights notice once per conversation, before the first upload or import of the user's own media.

### `media.pick`

- CLI: Ask for a readable path or HTTPS URL and use media.upload or media.import.
- MCP: `media_upload_widget {"type": "image", "multiple": false}`

Say the rights notice once per conversation before opening it. MCP Apps hosts can collect a file without a readable local path. Keep the reported asset IDs. If unavailable, request a readable file or HTTPS URL.

### `media.upload`

- CLI: `cawcut asset upload <path> --json`
- MCP: `media_upload {"filename": "<filename>", "type": "image"}`

Say the rights notice once per conversation, before the first upload of the user's own media. CLI completes the upload. MCP returns a signed upload URL: PUT the file bytes using the exact headers, then call media.confirm.

### `vn.import`

- CLI: Hand off the delivered paths and cloud refs to the cawcut-vn skill.
- MCP: `vn_import {"assets": [{"asset_id": "<asset_id>"}]}`

MCP imports eligible delivered images/videos by ID. On CLI hand off paths and cloud refs to the cawcut-vn skill, which owns the user's choice.

# CawCut capabilities

<!-- Generated from references/capabilities.json by scripts/capabilities.py -->

## Choose a route

Reuse the route already chosen in this session, including on a handoff. On first use honor an explicit CLI or MCP request. For an explicit MCP choice, go directly to the connected tools. In automatic mode prefer CLI with a shell. On CLI, if any CawCut CLI call already succeeded, skip the probe. Otherwise run `cawcut upgrade check --json` once. Install an available update with `cawcut upgrade`; an ahead-of-registry build can continue. Choose MCP automatically only without a shell or when the executable is missing. Other check errors leave the CLI selected; let the first real operation report its error.

CLI: read the JSON result and follow its error guidance. For an expired login use `cawcut auth login --browser --json` on the user's computer, or `cawcut auth login --device-auth --json` in a remote environment. For device auth show the authorization URL and resume the same request with `cawcut auth login --complete --wait --timeout 60 --json`. Retry the operation once after authentication; check the status of any ambiguous submission first.

MCP: use the connected CawCut tool with the listed name (hosts may prefix it). Parse JSON text content and treat `isError=true` as failure. The host handles OAuth consent and refresh. On persistent auth failure ask the user to reconnect. Check the actual host's offered tools, since some are deployment-specific. When the selected route cannot perform an operation, use its documented alternative or explain the limitation. Never submit again through the other route to recover an uncertain write.

If no usable route is available, ask the user to install `@ubnt/cawcut` for CLI or connect the hosted CawCut MCP endpoint.

## Operations

Substitute the actual values and JSON types from the current request. Examples with a category, individual node, stage or media type illustrate one scope. Follow the usage notes when that scope changes.

### `apps.describe`

- CLI: `cawcut app describe <app_id> --json`
- MCP: `describe_app {"app_id": "<app_id>"}`

Read the selected App's live input_schema before collecting inputs.

### `apps.list`

- CLI: `cawcut app list --schema --category image --json`
- MCP: `list_apps {"include_schema": true, "category": "image"}`

Omit the category to browse all Apps. Use the current catalog and preserve Official, My and Shared groups.

### `apps.run`

- CLI: `cawcut app run <app_id> --input-json <inputs_file> --wait --download --json`
- MCP: `run_app {"app_id": "<app_id>", "inputs": {"prompt": "<user_text>", "product_image": {"asset_id": "<asset_id>"}}}`

Submit once after price and input confirmation. Replace the example keys with the live schema. The CLI file contains only the inputs object. MCP returns a task immediately.

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

### `tasks.status`

- CLI: `cawcut task status <task_id> --wait --json`
- MCP: `get_task_status {"task_id": "<task_id>"}`

Poll the existing task. On MCP wait poll_after_seconds between calls. A timeout resumes the same task.

### `vn.import`

- CLI: Hand off the delivered paths and cloud refs to the cawcut-vn skill.
- MCP: `vn_import {"assets": [{"asset_id": "<asset_id>"}]}`

MCP imports eligible delivered images/videos by ID. On CLI hand off paths and cloud refs to the cawcut-vn skill, which owns the user's choice.

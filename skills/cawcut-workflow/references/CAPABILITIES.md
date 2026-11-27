# CawCut capabilities

<!-- Generated from references/capabilities.json by scripts/capabilities.py -->

## Choose a route

Reuse the route already chosen in this session, including on a handoff. On first use honor an explicit CLI or MCP request. For an explicit MCP choice, go directly to the connected tools. In automatic mode prefer CLI with a shell. On CLI, if any CawCut CLI call already succeeded, skip the probe. Otherwise run `cawcut upgrade check --json` once. Install an available update with `cawcut upgrade`; an ahead-of-registry build can continue. Choose MCP automatically only without a shell or when the executable is missing. Other check errors leave the CLI selected; let the first real operation report its error.

CLI: read the JSON result and follow its error guidance. For an expired login use `cawcut auth login --browser --json` on the user's computer, or `cawcut auth login --device-auth --json` in a remote environment. For device auth show the authorization URL and resume the same request with `cawcut auth login --complete --wait --timeout 60 --json`. Retry the operation once after authentication; check the status of any ambiguous submission first.

MCP: use the connected CawCut tool with the listed name (hosts may prefix it). Parse JSON text content and treat `isError=true` as failure. The host handles OAuth consent and refresh. On persistent auth failure ask the user to reconnect. Check the actual host's offered tools, since some are deployment-specific. When the selected route cannot perform an operation, use its documented alternative or explain the limitation. Never submit again through the other route to recover an uncertain write.

If no usable route is available, ask the user to install `@ubnt/cawcut` for CLI or connect the hosted CawCut MCP endpoint.

## Operations

Substitute the actual values and JSON types from the current request. Examples with a category, individual node, stage or media type illustrate one scope. Follow the usage notes when that scope changes.

### `account.balance`

- CLI: `cawcut account credits`
- MCP: `get_account {}`

Read the signed-in account's credits balance when the user asks for it. MCP also returns plan_name and plan_code. When MCP returns credits_balance_error the balance is unknown: say so and never report 0.

### `apps.list`

- CLI: `cawcut app list --schema --category image --json`
- MCP: `list_apps {"include_schema": true, "category": "image"}`

Omit the category to browse all Apps. Use the current catalog and preserve Official, My and Shared groups.

### `media.confirm`

- CLI: Handled by the CLI upload; there is no separate command.
- MCP: `media_confirm {"upload_token": "<upload_token>"}`

MCP only. Confirm the successful PUT with its matching upload token.

### `media.import`

- CLI: `cawcut asset upload <https_url> --json`
- MCP: `media_import_url {"url": "<https_url>", "type": "image"}`

Use the actual media type. Keep the returned asset_id and rights notice.

### `media.pick`

- CLI: Ask for a readable path or HTTPS URL and use media.upload or media.import.
- MCP: `media_upload_widget {"type": "image", "multiple": false}`

MCP Apps hosts can collect a file without a readable local path. Keep the reported asset IDs. If unavailable, request a readable file or HTTPS URL.

### `media.upload`

- CLI: `cawcut asset upload <path> --json`
- MCP: `media_upload {"filename": "<filename>", "type": "image"}`

CLI completes the upload. MCP returns a signed upload URL: PUT the file bytes using the exact headers, then call media.confirm.

### `tasks.status`

- CLI: `cawcut task status <task_id> --wait --json`
- MCP: `get_task_status {"task_id": "<task_id>"}`

Poll the existing task. On MCP wait poll_after_seconds between calls. A timeout resumes the same task.

### `vn.import`

- CLI: Hand off the delivered paths and cloud refs to the cawcut-vn skill.
- MCP: `vn_import {"assets": [{"asset_id": "<asset_id>"}]}`

MCP imports eligible delivered images/videos by ID. On CLI hand off paths and cloud refs to the cawcut-vn skill, which owns the user's choice.

### `workflow.add`

- CLI: `cawcut workflow quick "<prompt>" --capability <capability> --model <model_id> --estimate --json`
- MCP: `workflow_add_node {"capability": "<capability>", "model_id": "<model_id>", "prompt": "<prompt>"}`

Create one generation node after settings are accepted. CLI --estimate builds and prices without a paid run. MCP returns an advisory estimated_credits for the target, or null if unavailable; prepare and confirm before paid generation. To reuse the canvas pass --workflow / workflow_id. Outside media use --image, --video or --audio / images, videos or audios.

### `workflow.check`

- CLI: `cawcut workflow check <workflow_id> --target <node_id> --json`
- MCP: `workflow_check {"workflow_id": "<workflow_id>", "node_id": "<node_id>"}`

Check the planned execution scope. Resolve reported problems in the graph and check again.

### `workflow.connect`

- CLI: `cawcut workflow connect <workflow_id> <producer> <consumer> --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "connect", "from": {"node_id": "<producer>"}, "to": {"node_id": "<consumer>"}}]}`

Use graph node IDs for canvas outputs. For ambiguous ports specify NODE:port on CLI or the port property on MCP endpoints.

### `workflow.create`

- CLI: `cawcut workflow create --file <proposal_file> --json`
- MCP: `workflow_create {"name": "<name>", "nodes": [{"ref": "source", "node_kind": "text_input", "text": "<text>"}], "edges": []}`

Build a graph without execution. Supply the CLI proposal file or MCP nodes and edges; name both ports on MCP create edges. Keep returned node IDs.

### `workflow.duplicate`

- CLI: `cawcut workflow duplicate <workflow_id> --name <name> --json`
- MCP: `workflow_create {"duplicate_from": "<workflow_id>", "name": "<name>"}`

Copy graph and results; omit name for the default. Continue edits on the returned copy only.

### `workflow.edit`

- CLI: `cawcut workflow edit <workflow_id> --file <batch_file> --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "update_node", "node_id": "<node_id>", "name": "<name>"}]}`

Apply one atomic batch. On MCP, dry_run=true previews the same operations without saving. Report warnings and dropped settings before applying a requested edit. After a conflict re-read the graph and rebuild the batch.

### `workflow.get`

- CLI: `cawcut workflow get <workflow_id> --node <node_id> --json`
- MCP: `workflow_get {"workflow_id": "<workflow_id>", "node_id": "<node_id>"}`

Omit node to read the entire graph. Retain the current graph token for an edit.

### `workflow.layout`

- CLI: `cawcut workflow layout <workflow_id> --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "layout", "direction": "horizontal"}]}`

Arrange graph dependency levels after a batch of more than two nodes or after copying a node.

### `workflow.model.change`

- CLI: `cawcut workflow switch-model <workflow_id> --node <node_id> --model <model_id> --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "update_node", "node_id": "<node_id>", "model_id": "<model_id>"}]}`

Keep the prepared node ID; show dropped parameters or edges. Read the new schema and reprice.

### `workflow.models`

- CLI: `cawcut workflow nodes --capability <capability> --asset <asset_id> --json`
- MCP: `workflow_nodes {"capability": "<capability>", "asset_ids": ["<asset_id>"]}`

Omit all arguments for capabilities. Omit the asset filter when no media was supplied. Repeat --asset on CLI. Preserve model order.

### `workflow.node.copy`

- CLI: `cawcut workflow duplicate-node <workflow_id> --node <node_id> --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "duplicate_node", "node_id": "<node_id>"}]}`

Copies settings and incoming connections. Follow with layout; Product nodes and companions cannot be copied.

### `workflow.node.remove`

- CLI: `cawcut workflow delete-node <workflow_id> --node <node_id> --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "remove_node", "node_id": "<node_id>"}]}`

Remove only the named or agreed node. Report newly empty ports.

### `workflow.node.rename`

- CLI: `cawcut workflow set <workflow_id> --node <node_id> name="<name>" --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "update_node", "node_id": "<node_id>", "name": "<name>"}]}`

Rename the specified node. Keep its connections and workflow name.

### `workflow.prepare`

- CLI: `cawcut workflow prepare <workflow_id> --target <node_id> --expect <node_id> --json`
- MCP: `workflow_prepare {"workflow_id": "<workflow_id>", "node_id": "<node_id>"}`

Read the current scope and estimated credits before requesting approval. For the whole graph omit --target / node_id in check, prepare and run. Every node the user asked to run must be in scope_node_ids (CLI: pass each with --expect); otherwise fix its connections before quoting. The reply also carries credits_balance and, for a known estimate, credits_sufficient and credits_shortfall. When credits_sufficient is false, show credits_required, credits_balance and credits_shortfall and send the user to top up on the web portal instead of asking to confirm; credits_balance_error means the balance is unknown, so quote the estimate as usual.

### `workflow.rename`

- CLI: `cawcut workflow rename <workflow_id> <name> --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [], "name": "<name>"}`

Rename only the existing canvas.

### `workflow.resources`

- CLI: Use the note tokens in the layout guide, the model's palette_presets and applicable_when in its raw schema (--schema --raw --json), or `cawcut vn fonts --recommend caption --json` to find annotated fonts available on the editing device.
- MCP: `workflow_resources {"kind": "note_color", "query": "review", "limit": 3}`

Choose note_color, note_font_size, recraft_palette or font. Search with English keywords from the brief and pass next_offset as offset for more matches. Check the returned when_not_to_use before proposing a resource. If the host lacks this tool, use the documented note tokens or model schema. Verify a suggested VN font on the editing device.

### `workflow.results`

- CLI: `cawcut workflow results <workflow_id> --execution <task_id> --download --json`
- MCP: `workflow_results {"workflow_id": "<workflow_id>", "task_id": "<task_id>"}`

Read text_outputs and result_assets. To recover earlier or intermediate outputs, omit the task filter, optionally narrow by --node / node_id.

### `workflow.run`

- CLI: `cawcut workflow run <workflow_id> --target <node_id> [--confirm-quote <quote_id>] --wait --json`
- MCP: `workflow_run {"workflow_id": "<workflow_id>", "node_id": "<node_id>"}`

After the user approves the quoted run in chat, CLI accepts the quote_id from prepare or quick --estimate. MCP returns task_id after host approval where required. Force only for a separately confirmed repeat.

### `workflow.schema`

- CLI: `cawcut workflow nodes --capability <capability> --model <model_id> --schema --json`
- MCP: `workflow_nodes {"capability": "<capability>", "model": "<model_id>", "schema": true}`

Read ports, settings, defaults, duration limits and supported values for the exact model.

### `workflow.separate`

- CLI: `cawcut workflow separate <workflow_id> --node <node_id> --what audio --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "add_node", "ref": "track", "node_kind": "audio_separation"}, {"op": "connect", "from": {"node_id": "<node_id>", "port": "video"}, "to": {"ref": "track", "port": "video"}}]}`

Full soundtrack shown. For silent video, vocals or background use the processor kinds in the canvas operations guide. For both outputs add and connect both processors. On MCP, run each target whose estimated_credits_by_target is zero directly by node_id, without prepare or confirmation. Wait for each run before submitting the next. Prepare paid or unpriced targets and confirm any charge.

### `workflow.set`

- CLI: `cawcut workflow set <workflow_id> --node <node_id> speed=1.25 --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "update_node", "node_id": "<node_id>", "params": {"speed": 1.25}}]}`

Update only settings the user asked for, using values allowed by this node. TTS speed is one example; preserve the node ID. Read the node back before reporting the edit.

### `workflow.trim`

- CLI: `cawcut workflow trim <workflow_id> --node <node_id> --start 1 --end 3 --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "trim_media", "node_id": "<node_id>", "start_ms": 1000, "end_ms": 3000}]}`

These examples both keep seconds 1 through 3 of the original input. Convert requested seconds to milliseconds on MCP. Preserve the existing input node and edges.

### `workflow.upscale`

- CLI: `cawcut workflow upscale <workflow_id> --node <draft_node> --json`
- MCP: `workflow_edit {"workflow_id": "<workflow_id>", "base_graph_token": "<graph_token>", "operations": [{"op": "add_node", "ref": "upscale", "node_kind": "video_upscale"}, {"op": "connect", "from": {"node_id": "<draft_node>", "port": "<draft video output selector>"}, "to": {"ref": "upscale", "port": "video"}}]}`

After the user chooses Upscale for an unexpired draft, add and connect the processor. Read the output selector from the draft node. Use the returned upscale node ID as the target for a fresh prepare, price confirmation and run.

### `workflow.voices`

- CLI: `cawcut workflow nodes --capability text-to-speech --schema --json`
- MCP: `workflow_nodes {"capability": "text-to-speech", "schema": true, "voice_language": "zh"}`

Use the script's language, or the conversation language when there is no script yet. On MCP, add voice_query when the brief specifies a tone or use and the host advertises it. Keep the language and query when paging with next_voice_offset. If the host lacks voice_language, use the full catalog as on CLI.

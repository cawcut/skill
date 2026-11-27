# Recovery

Every recovery that offers options is an Ask. A paid rerun passes through prepare and confirm again.

| Situation | Action |
| --- | --- |
| `workflow_add_node` fails after graph creation may have started | A partial workflow may exist. Call `workflow_get` with the `workflow_id` if one was returned, otherwise there is nothing to read. Ask: **Retry add** · **Open Portal to inspect** · **Cancel**, with `portal_url` when available. Retry only on that answer. |
| `failed` / `cancelled` task | Report the failed node, the outputs that did finish (`workflow_results` with the `task_id`) and the actual cost, then the error details. Ask: **Adjust and rerun** (back to model/settings) · **Stop**. A new run needs a new prepare and confirm. |
| `action_required` | Stop polling. Give `portal_url` and any `pending_asset_ids`. |
| `isError=true` | Use `error`, `kind`, `retryable`, `next`, `details`. Follow validation guidance before retrying an unpaid prepare or add. |
| Ambiguous `workflow_run` result with a `task_id` | Poll that task. |
| Ambiguous `workflow_run` result without a `task_id` | `workflow_get`: `active_executions` names a run still going, `workflow_results` without `task_id` reads each node's latest result. Only when both are empty, ask the user to inspect the Portal before another paid attempt. |
| `workflow_run` `RUN_IN_PROGRESS` | The same target is already running (the `task_id` is in the message). Poll it with `get_task_status`. `force: true` only when the user asked for a second paid run; it needs its own confirm. |
| `workflow_run` `QUOTE_UNAVAILABLE` or `HOST_APPROVAL_UNSUPPORTED` | No reply in chat can approve this run. Do not ask for confirmation or retry; give the user `details.portal_url` to review and run it there. |
| `workflow_check` problems | `valid:false`: each problem names `node_id`, `port` and what was expected. Fix with `workflow_edit`, check again, then prepare. |
| `workflow_create` fails | Nothing was created. Read `kind` and `details`, fix the proposal, call again. |
| `workflow_edit` `GRAPH_CONFLICT` | The canvas changed since the read. Call `workflow_get`, rebuild the batch against it, then edit again with the new `graph_token`. |
| `workflow_edit` fails with no reply (timeout, dropped connection) | The edit is saved whole or not at all. Call `workflow_get` and compare its `graph_token` with the `base_graph_token` you sent. Same token: nothing landed; send only the missing changes against the new token, node adds first, then one `connect` per edit call, reading each reply. Different token: it landed; check the nodes and edges and continue from that token. Never resend the old batch. |
| `workflow_edit` `PORT_AMBIGUOUS` | Several ports fit. Pick one of `details.allowed` (Ask when the choice is the user's, otherwise the one that serves the goal), then repeat the connect with `port` named on both ends. |
| `workflow_edit` or `workflow_add_node` `OWN_OUTPUT_AS_INPUT` | The asset was made on this canvas. `connect` its producing node to the consumer instead. Retry with `keep_fixed: true` only when the user asked to freeze that exact result. |
| `workflow_edit` `PARAM_INVALID` | For `details.field: arguments`, use the validation message to correct the tool payload. For a model parameter, use its field and expected range or values. Retry a preview with `dry_run: true`. Never try candidate values one by one: when the error, the `workflow_nodes` schema and `workflow_get` name no valid value, ask the user or give `portal_url`. |
| `MEDIA_LIMIT` or a preflight warning | Report the target, port and measured limit when present. Offer a compatible input, trim, or model. If the service reports missing metadata, tell the user which check is pending. |
| `PORT_INCOMPATIBLE` on an LLM output | Read its allowed connection count. Rewire the existing edge or ask which consumer should receive the output. |
| Authorization keeps failing | Ask the user to reconnect the MCP server. |

# Recovery

Every recovery that offers options is an Ask. A paid rerun goes back through the confirm step.

| Situation | Action |
| --- | --- |
| `failed` / `cancelled` task | Report `error`, `error_category`, `error_key`, `error_code` when present. Ask: **Adjust inputs and rerun** · **Choose another App** · **Stop**. |
| `action_required` | Stop polling. Give `portal_url` and any `pending_asset_ids`. |
| `isError=true` | Follow the returned error and recovery fields. |
| Unknown or invalid input key | Re-run `describe_app`; rebuild inputs from the new schema. |
| App not found or access error | Refresh `list_apps`; Ask the user to pick again. |
| Ambiguous submission failure (no `task_id`) | Ask: **Check the task first** · **Start a new paid run**. Start a new run only on the second answer. |
| Authorization keeps failing | Ask the user to reconnect the MCP server. |

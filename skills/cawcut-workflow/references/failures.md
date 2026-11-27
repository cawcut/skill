# Failures beyond `error.next`

`error.next` is the first answer. These cases need judgement.

| Case | Move |
| --- | --- |
| `SUBMISSION_UNKNOWN` | The request may or may not have landed. Read the project and its tasks (`workflow get`, `task list`) before any write. A known `task_id` is queried. After `edit`, `connect` or another canvas change, follow [Unknown edit outcome](#unknown-edit-outcome). |
| `POLL_TIMEOUT` | `cawcut task status <task_id> --wait --json` on the same task. |
| `RUN_IN_PROGRESS` | Wait on the named execution. `--force` only when the user wants a second run. |
| `CHECK_FAILED` | Fix the located node and port; the problem list names each one. |
| `SCOPE_INCOMPLETE` | A requested node is not in the quoted scope; `missing` gives each reason. Do not quote the estimate. Connect the input or prepare that node with `--target`, then prepare again. |
| `ATTESTATION_REQUIRED`, `ACTION_REQUIRED` | Give the user `portal_url`; they sign or act there; run again. |
| `QUOTE_UNAVAILABLE` | The service returned no run quote. Do not ask for a quote confirmation or retry; give the user `portal_url` to review and run there. |
| `TASK_FAILED` | Report the failed node, finished outputs and actual cost. A new run needs a new confirmation. |
| `NODE_UNAVAILABLE` | Use the node in `next`. |
| `PARAM_INVALID`, or an unknown parameter name or value | Do not try another value. Read it from `workflow nodes --capability <c> --model <id> --schema --json`, the node table in the guide, or `workflow get <id> --node <n> --json`. If none lists it, ask the user or give the Portal link. |
| Capability absent from `nodes` | Name the gap and the closest supported adjustment, or the Portal. |

A write is submitted once. Keep the existing workflow and task ids; repeat a create, edit or run only after the state is read.

## Unknown edit outcome
An edit batch is saved whole or not at all, and only while its `base_graph_token` still matches. So one read settles what landed:

1. `cawcut workflow get <id> --json` (or `workflow check <id> --json`). Compare its `graph_token` with the `base_graph_token` you sent; the error repeats it.
2. Same token: nothing landed. Do not resend the whole batch. Send only the missing changes against the new read: node adds (with their `ref`) in one small `edit`, then each edge with its own `cawcut workflow connect <id> <from> <to> --json`, each one read back before the next.
3. Different token: the batch landed. Check the expected nodes and edges are in the graph and continue from that `graph_token`. If an edge is missing, add it with `workflow connect`.
4. A second `SUBMISSION_UNKNOWN` on the same change: stop writing, give the user `portal_url` and say what is not confirmed.

Resending the old batch file with its old token is never the fix: it returns `GRAPH_CONFLICT` when the first attempt landed, and a batch without a token would add the nodes twice.

## First run and sign-in
- Command missing: `npm install -g @ubnt/cawcut`, then resume at step 0. Any other upgrade-check failure matters only when the real command fails too.
- Auth error: `cawcut auth login --browser --json` on the user's own computer. Without their browser (remote or container): `--device-auth --json`, show `authorization_url`, then `cawcut auth login --complete --wait --timeout 60 --json`. Retry the failed call once after `status=authenticated`.
- PowerShell treats redirected stderr as an error record; read results from stdout and judge by `$LASTEXITCODE`.


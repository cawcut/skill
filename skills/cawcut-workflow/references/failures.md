# Failures beyond `error.next`

`error.next` is the first answer. These cases need judgement.

| Case | Move |
| --- | --- |
| `SUBMISSION_UNKNOWN` | Read the project and its tasks (`workflow get`, `task list`) before any write. A known `task_id` is queried. |
| `POLL_TIMEOUT` | `cawcut task status <task_id> --wait --json` on the same task. |
| `RUN_IN_PROGRESS` | Wait on the named execution. `--force` only when the user wants a second run. |
| `CHECK_FAILED` | Fix the located node and port; the problem list names each one. |
| `ATTESTATION_REQUIRED`, `ACTION_REQUIRED` | Give the user `portal_url`; they sign or act there; run again. |
| `TASK_FAILED` | Report the failed node, finished outputs and actual cost. A new run needs a new confirmation. |
| `NODE_UNAVAILABLE` | Use the node in `next`. |
| Capability absent from `nodes` | Name the gap and the closest supported adjustment, or the Portal. |

A write is submitted once. Keep the existing workflow and task ids; repeat a create, edit or run only after the state is read.

## First run and sign-in
- Command missing: `npm install -g @ubnt/cawcut`, then resume at step 0. Any other upgrade-check failure matters only when the real command fails too.
- Auth error: `cawcut auth login --browser --json` on the user's own computer. Without their browser (remote or container): `--device-auth --json`, show `authorization_url`, then `cawcut auth login --complete --wait --timeout 60 --json`. Retry the failed call once after `status=authenticated`.
- PowerShell treats redirected stderr as an error record; read results from stdout and judge by `$LASTEXITCODE`.


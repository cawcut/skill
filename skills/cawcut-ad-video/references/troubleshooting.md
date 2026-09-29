# Ad Video — troubleshooting

| Symptom | Meaning | Recovery |
|---------|---------|----------|
| `Token expired, run cawcut auth login` | OAuth token stale | Run `cawcut auth login` in the host shell, wait for the browser flow, retry the failed command once |
| CLI not found | `cawcut` not installed | `npm install -g @ubnt/cawcut` |
| `404` on any `<id>` command | Wrong ID or project belongs to another account | Re-check the ID from `create` output; ask the user |
| `VIDEO_AD_NEEDS_REGENERATION` / `308000414` | An upstream output is stale (`need_regenerate: true`) | `detail <id> --json`, find flagged outputs, re-run those stages in order (storyboard → image → video) with fresh quotes |
| Confirmation token expired / invalid | 5-minute TTL passed or inputs changed after quoting | Re-quote, AskUserQuestion to confirm again, run immediately |
| `409` on `storyboard set` | `base_revision` mismatch | Re-read `detail`, take `outputs.storyboard_plan.value.revision`, re-apply edits, retry |
| `storyboard set` refused locally ("would be rejected") | The plan breaks the server's script contract — the CLI checked the whole plan against `outputs.storyboard_plan.constraints` before sending | Fix the named shot/field and save again. The message names it (`Shot 3 voiceover is too long (max 48 chars for 2s).`), and the shot at fault is not necessarily the one being edited. Resending the same plan cannot help |
| `Invalid parameters.` / `code -2` on `storyboard set` | The server rejected the whole plan; the reason is in the response's `error_msg`, which the CLI prints as the first line | Fix the named field. This still appears when the server is ahead of the installed CLI and the local check passes — same fix, and `--skip-precheck` never makes it pass |
| `409` concurrent run | Another stage run is in flight on this project | Poll `detail` until `status` leaves `running`, then retry |
| `400` on `config set` | Stage gate not met or bad enum | Product analysis must be `stage_completed` first; use only values from `ad-video options`. A resolution outside the chosen model's `supported_resolutions` also lands here |
| `400` on `idea load-more` | No more candidates | `pagination.has_more` is false — everything the project holds is already revealed; offer `idea regenerate` instead |
| Output `failed` during polling | Stage workflow failed | Read the output's `error` from `detail --json`; retry the stage once; if it persists, adjust inputs (shorter duration, different images) |
| Poll timeout | Stage still running past the deadline | Project state persists server-side. Ask the user: continue waiting (restart the loop) or stop and resume later with `cawcut ad-video detail <id>` |
| Insufficient credits (caught before running) | `credits_sufficient: false` on the quote — `credits_shortfall` is how much is missing | Say the numbers plainly, send the user to top up on the web portal, and don't offer a routine confirm-and-run. On their return: re-quote (the token has long expired) → confirm → run |
| Credits balance unavailable on the quote | `credits_balance_error` — the balance lookup failed, not the quote | Non-fatal by design: confirm and run as normal, but don't claim the balance is sufficient |
| `308000202` / Rights & Permissions notice required | A material reached the generation gate without an attestation | Should not happen on this path — CLI uploads land approved. If it appears, the asset came from elsewhere (web upload, share copy); the attestation can only be signed in the web portal |
| Poll loop never exits / status prints empty | Ad-hoc loop routed JSON through `echo "$var" \| jq`; under **zsh**, echo turns `\n` escapes into raw newlines and corrupts the JSON, so jq never matches a terminal state | Use the bundled platform-specific `scripts/poll.sh` / `scripts/poll.ps1`. Inspect raw output with `cawcut ad-video detail <id> --json`; on Windows, use the PowerShell example below to inspect a field |
| `poll.sh` / `poll.ps1` exits 4 | `detail --json` output was unparseable (auth expired, CLI missing/old) | Run `cawcut ad-video detail <id> --json` once, read the raw error; `cawcut auth login` if it is a token error |
| Nothing to save (`product set` / `config set`) | No flags passed | Pass at least one field flag |

## Inspect detail on Windows without extra tools

Use the CLI directly to inspect the complete response:

```powershell
cawcut ad-video detail <id> --json
```

For a single field, use PowerShell's built-in JSON parser (replace `<id>` with the project ID):

```powershell
$raw = cawcut ad-video detail <id> --json
if ($LASTEXITCODE -ne 0) { throw 'Unable to read AD Video detail' }
$detail = ($raw -join "`n") | ConvertFrom-Json
$detail.outputs.final_video.status
```

This status-only example needs neither jq nor Python. For polling, script editing, and downloads, use `poll.ps1`, `script_plan.ps1`, and `download_media.ps1`; these helpers also handle CLI UTF-8 decoding. Do not replace them with ad-hoc shell pipelines.

## Windows PowerShell: redirecting native stderr

PowerShell turns native-program stderr redirection into an `ErrorRecord`. With
`$ErrorActionPreference = 'Stop'`, `2>$null` can terminate a helper even when
the CLI printed valid JSON. The bundled `.ps1` scripts temporarily use
`'Continue'` around the redirected `cawcut` call and restore the prior value.
Keep that pattern if adding another PowerShell helper; do not broadly change the
user's preference or replace it with a Bash dependency.

## Rules

- Never retry a credit-spending `run` without re-confirming with the user when the failure changed the quote (new token = new confirmation).
- Never work around a stage gate by skipping stages — the pipeline is strictly ordered.
- A failed or cancelled project is resumable: `cawcut ad-video detail <id> --json` always reflects the latest server state; pick up from the first non-succeeded stage.

# Recovery

Every recovery that offers options is an Ask. A paid rerun passes through quote and confirm again.

A failed call is `isError=true` with `error`, `kind`, `retryable`, `next` and `details`. Follow `next` when it is present.

| `kind` or situation | Meaning | Action |
| --- | --- | --- |
| `authorization_required` | The MCP token is missing or expired | Ask the user to reconnect the MCP server. |
| `NOT_FOUND` | Wrong `video_ad_id`, or the project belongs to another account | Re-check the ID from the `create` reply; ask the user. |
| `PARAM_INVALID` | Bad or missing value; `error` and `details.field` name it | Correct it from `ad_video_options` or the reply and call again. Nothing was saved. |
| `PRODUCT_LOCKED` | The product cannot change once the storyboard has started | Say so; a different product means a new project. |
| `PRODUCT_EXTRACTION_FAILED` | The page could not be read | Ask for another product URL, or fill the details by hand with `ad_video_set` `product`. |
| `NEEDS_REGENERATION` | An upstream output is stale | Read `stale_outputs`; run those stages in order (script → images → video) with a fresh quote for each paid one. |
| `QUOTE_REQUIRED` | A paid run was asked for without a quote's token | Quote, show the price and balance, ask, then generate. |
| `REVIEW_REQUIRED`, `REVIEW_OUT_OF_ORDER` | Paid images were asked for before the user approved every item, or an item was approved out of order (`details.item` is the next one) | Show that item, ask, then `ad_video_review` `approve`. Order: character, location, script. |
| `REVIEW_STALE` | The item changed after you showed it | Read the project (`view:"full"`), show it again, ask again, approve with the new fingerprint. |
| `REVIEW_NOT_READY`, `REVIEW_UNAVAILABLE` | The item is still generating, or the server could not read or save the review (`retryable:true`) | Wait or retry shortly; never work around it. |
| `VISUAL_DIRECTION_REQUIRED` | Photo-realistic images were asked for before the direction gate was cleared | Call `confirm_direction` ([storyboard](storyboard-stage.md)), then quote again. |
| `QUOTE_EXPIRED` | The token passed five minutes, or the inputs or target changed after the quote | Quote again, ask again, generate again. Once per attempt. |
| `CONFLICT` | The script changed since it was read | Read it again, re-apply the edits, save again ([script editing](script-editing.md#saving)). |
| `STAGE_BUSY` | Another run is in flight on this project | `get` with `wait_seconds` until `busy` is false, then retry. |
| `NOT_READY` | A prerequisite has not finished | Wait for it, then retry. |
| `SYSTEM_ERROR`, `REQUEST_FAILED` | A server fault, usually transient | Retry the same call once. Persisting: give `portal_url`. |
| An output `failed` while waiting | The stage's workflow failed | Read the output's `error` from `get`; retry the stage once; if it persists, change the inputs (a shorter duration, other images). Do not hide it as "nothing to do". |
| `storyboard.next_step` `fix_failed` | A character, location or the script failed | Show which one and why. Retry only with the user's consent (`retry:true` on the storyboard quote for a failed decision). |
| `credits_sufficient:false` on a quote | The balance does not cover the price | Say the numbers, send the user to top up on the web portal, offer **Top up credits** · **Not now** instead of a confirm. After they return, quote again: the old token has expired. |
| `credits_balance_error` on a quote | The balance lookup failed, not the quote | Ask as usual; do not claim the balance covers it. |
| A stage far past `estimated_running_ms` | It may be slow, not stuck | Say so once and Ask **Keep waiting** · **Stop**. The project persists; resume later with `get`. |
| `ad_video_select` `load_more` finds no more | `pagination.has_more` is false | Everything the project holds is already shown: offer a fresh batch instead. |
| Rights and permissions notice required | A material reached the generation gate unattested | Only the web portal can sign it: give `portal_url` and stop. |

## Rules

- Never retry a credit-spending call without re-confirming when the failure changed the quote: a new token is a new confirmation.
- Never work around a stage gate by skipping stages; the pipeline is ordered.
- A failed or stopped project is resumable: `get` shows the latest server state; continue from the first stage that is not succeeded.
- A legacy project (`workflow_generation` not `v2`) keeps its original flow. Never run a quote or a run to force the character or location features onto it, and never treat their missing outputs as a failure.
- A profile that succeeded with no entities is a normal absence. A profile or image that failed is surfaced and refreshed, never masked as "legacy".

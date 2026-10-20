# Character / location and Portal parity

All operations use the existing developer identity and project ownership. New features depend on the project's cloned graph (`workflow_generation: v2`), not the CLI version or an internal account tag. Existing v1 projects stay on their graph, retain their outputs and original five-stage flow.

## State and progressive review

`cawcut ad-video storyboard status <id> --json` returns `content_revealed`, `preparation_ready`, entity states, instruction and `portal_url`. Raw `detail` remains unchanged inside the plan.

- `content_revealed`: script succeeded with shots and at least one entity side decided, mirroring Portal. It does not mean both images are ready.
- Entity profile and image keys both absent: no entity chain to wait for. Before the script exists, missing keys do not prove the project is legacy. Resume the legal current stage and refresh.
- A successful profile with an empty entity list means absent, not failed. Character and location are independent.
- Existing legacy digital-human labels are read for display without granting new editing capability.
- Running/pending versus failed versus stale-success must stay distinct. A failure is visible, never silently skipped as legacy.
- Show the available script and entity cards/statuses together. The common script helper renders @ names independently of image availability.
- `--wait --until display` stops at display readiness. `--wait --until ready` waits for usable entities before continuation; it does not itself authorize spending.

## Commands

```bash
cawcut ad-video character estimate <id> [--retry] [--wait] [--json]
cawcut ad-video storyboard run <id> --confirmation-token <first-estimate-token> --json
cawcut ad-video storyboard status <id> --wait --until display --json
cawcut ad-video character set <id> --entity character --prompt "New appearance" --json
cawcut ad-video character quote <id> --entity character --json
cawcut ad-video character run <id> --entity character --confirmation-token <entity-quote-token> [--wait] --json
cawcut ad-video character set <id> --entity location --name "Living room" --json
cawcut ad-video instruction set <id> --prompt "Soft warm visual direction" --enabled true --json
cawcut ad-video url <id> --json
```

Each command also supports `--json` where shown; ordinary API command output stays JSON-shaped. First estimates can be pending/failed; credits/needed flags are meaningful only when ready. The estimate is free (decision nodes only). Confirm fees before starting storyboard preparation. Never swap a first-estimate token with a single-entity token. Each entity quote is tied to its current saved inputs, so save the prompt before quoting. A changed input or expired token requires a fresh quote and confirmation. The backend retains transitional empty-token compatibility for older clients; the new Skill always supplies it.

> Not open yet: `character set --image` / `--voice-id` and `ad-video voices`. Do not guide users to them.

`character set` changes only supplied fields. Do not combine image and prompt in one save. A supplied image must resolve to an owned, approved image asset: the local developer upload follows its existing policy, while an asset ID is verified by BE. URLs alone are not accepted as uploaded image references. Upload then PATCH, never delete the prior server image first. Upload/validation failure leaves the old reference intact. Photo replacement does not run image generation. New prompt generation switches away from the uploaded reference using the existing backend logic.

Voice IDs and previews come from integration's TTS `/public/voices/cawcut`, matching Portal; no character-library voice IDs. Omitted voice preserves, empty clears. Only characters accept voice. A voice update does not regenerate a picture. Name-only update does not invalidate outputs. An entity image change invalidates affected photo/final outputs; retain previews but follow regeneration flags before continuing.

Instruction text and enabled state are independent. Saving does not run a model or rewrite the script. Compare `storyboard_additional_instruction.content` with `applied_content` plus output invalidation flags, respecting sketch then photo. Do not offer it on legacy graphs as if they necessarily have its input node.

## Failure and resume

All explicit `--wait` timeouts/intervals must be positive. Timeouts do not cancel server execution: read detail before retrying, never blindly re-run a paid request. Failed terminal states exit nonzero. For recoverable errors, show the current Portal link and preserve the project ID. No migration, abstract-all, character library, permanent deletion or public sharing is part of this flow.

## Review menu and downloads

- Fee prompt: the first estimate is free, but `storyboard run` with its token starts paid entity images. Always show `estimated_credits` (0 = free) and wait for the user's answer first.
- Review order is character, then scene, then script (see SKILL.md Stage ④). Always show the current name and image prompt first (Portal parity). A character/scene that is not suitable offers `character set --prompt` + `quote` + `run`; each regenerate re-quotes and re-confirms fees. Own-image upload and voice are not open yet and are not offered. Full procedure: `storyboard-stage.md`.
- Save entity images with `cawcut ad-video entities download <id>` (writes `entities/<entity>-<n>-<name>.<ext>`); `scripts/storyboard_review` does this together with the script table. Do not hand-roll `curl` with `storyboard status`; in zsh `status` is a read-only variable, so `status=$(...)` fails.

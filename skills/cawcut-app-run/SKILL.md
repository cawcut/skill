---
version: 0.12.0
name: cawcut-app-run
description: >-
  Use when handling published CawCut Apps: browse, inspect, run a named App, /cawcut-app-run, or a selected-App handoff from cawcut-workflow. NOT for new production requests (cawcut-workflow).
argument-hint: "[natural-language request or app name] [--input key=value ...] [--wait] [--download [<dir>]]"
allowed-tools: Bash AskUserQuestion AskQuestion SendUserFile PushNotification
---

# CawCut App Run

## Route

Read the installed [capability map](references/CAPABILITIES.md) before the first operation. Choose a route there once per session and carry it, the selected project or App, and its inputs through handoffs. Each capability below uses the example for that route. Where a step links two guides, open only the guide for the active route.

## Catalog freshness

Use `apps.list` to browse or match a new goal. Reuse a same-goal handoff's selection, current catalog, inputs and asset IDs. Refresh after an explicit refresh, changed goal, account or App, or an access error. Resolve the selected ID from live catalog evidence before submission. A lookup error requires recovery.

## Discover and inspect

1. For browsing, group Apps by output category and then by Official, My and Shared. Show names, descriptions, input summaries and available credit estimates in the user's language. Default to English for a bare invocation. Keep IDs internal. Offer every candidate; when the picker overflows show the numbered table. A single feasible choice can be stated directly. Use the host question tool for choices that fit, and accept the user's explicit preference for text. See [catalog presentation](references/app-presentation.md).
2. For a goal without a selected App, use [CLI matching](references/intent-matching.md) or [MCP matching](mcp/references/intent-matching.md). If exactly one match scores at least 70, inspect and present it immediately. For several plausible matches offer a picker. For duplicate names show the source, description and inputs so the user can choose the exact copy. If none fit, offer a canvas and hand off the goal, assets and no-match decision without reopening the picker.
3. Use `apps.describe` even when the catalog returned a schema. Lead with the chosen App's name and description. Show its metadata and inputs tables (name, type, required, default, constraints and notes) before the first input question. Use the schema's exact keys internally. An explicit browse request can stop after catalog presentation.

## Collect inputs

Use only the supplied values and the live schema. Offer enums, defaults, optional **Skip / Provide**, and a follow-up for **Custom**. When several fields need choices, first offer to use applicable defaults or customize, then ask for unresolved fields. Group independent questions within the host limit. Ask for the user's content, never for an internal field name. Example media and defaults that are only illustrations cannot serve as real inputs. Reuse media already handed over, and request a source only for an unresolved input.

- HTTPS source: `media.import`. Readable local path: `media.upload`. Preserve the returned ID. On MCP finish a signed PUT with `media.confirm`, or use `media.pick` for a pathless attachment. Relay the rights notice once.
- Follow [CLI input formats](references/app-inputs.md) or [MCP media sources](mcp/references/media-sources.md). Validate constraints against the live schema. For an upload size/dimension rejection offer to compress or resize, let the user supply a replacement, or cancel.

## Confirm, run and deliver

1. Show the selected App, resolved inputs (media by name/type) and estimated credits; state when unknown. Ask **Confirm and run**, **Change inputs**, or **Cancel**. Every paid run gets its own approval.
2. Call `apps.run` once with the confirmed App and inputs. Preserve its task ID. A long video gets one advance notice and one available host notification at its terminal status. Quote runtime only when estimated_running_ms is available, otherwise say a few minutes. CLI may wait and download inline. On MCP, or after a CLI wait timeout, use `tasks.status` with the same ID. Continue while pending, running or cancelling. For action required, stop and give the Portal link. For an ambiguous submit, check the existing task before proposing another paid run.
3. On success save and show every output, give each complete signed URL, available local paths, task ID, Portal link, credits used (or estimate) and balance or balance error. Report the result before any VN decision. CLI hands paths and cloud refs to `cawcut-vn` immediately; MCP follows [delivery](mcp/references/delivery.md) and `vn.import` for eligible media. Keep existing asset IDs.
4. For failures use [CLI troubleshooting](references/troubleshooting.md) or [MCP recovery](mcp/references/recovery.md). A changed input or a failed task returns to confirmation before another run.

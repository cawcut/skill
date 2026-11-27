---
version: 0.12.0
name: cawcut-workflow
description: >-
  Use when trimming a single video or audio clip to a time range (裁剪、截取、剪辑单个视频), extracting a video's soundtrack (音视频分离), or creating a voice-over (配音、TTS). Also use for making video, images or audio, writing scripts, storyboards or shot lists, scraping product info from a URL, AI edits of existing media (recolor, replace, restyle, first/last frame), LLM text generation and canvas follow-ups. NOT for ads (cawcut-ad-video), VN timeline editing (cawcut-vn), or named Apps (cawcut-app-run).
argument-hint: "<outcome, assets or follow-up>"
allowed-tools: Bash AskUserQuestion AskQuestion SendUserFile PushNotification
---

# CawCut Workflow

## Route

Read the installed [capability map](references/CAPABILITIES.md) before the first operation. Choose a route there once per session and carry it, the selected project or App, and its inputs through handoffs. Each capability below uses the example for that route. Where a step links two guides, open only the guide for the active route.

When asked whether CawCut supports an operation, check the capability map and the matching guide below before answering. On MCP, check the tool named by the guide and its input schema. A capability can be an operation or node kind inside a tool. Answer a capability question without changing the canvas.

For “would this edit work on my canvas?”, read the graph and follow the [MCP edit preview](mcp/references/edit.md#preview-an-edit) when the connected tool exposes `dry_run`. Stop after reporting the preview unless the user also asked to apply the change.

## 1. Route the request

Keep follow-ups, new stages of the same goal and reruns on their active canvas. A new goal starts a new canvas. A result on this canvas feeds its consumer through a live edge. Freeze it as a fixed asset only when the user selects that result.

- A named App or catalog request goes to `cawcut-app-run`. An ad, a product URL alone or an existing Ad Video wizard goes to `cawcut-ad-video`. A product scrape or an ad explicitly requested on a canvas uses the Product guide below. Story Video or avatar wizard requests need their supported CLI skill; tell an MCP-only user when a wizard requires CLI. A timeline edit belongs to VN.
- To keep a time range from a single source clip, extract its soundtrack, or add a voice-over, go directly to [CLI canvas operations](references/canvas-ops.md) or [MCP canvas operations](mcp/references/canvas-ops.md). These requests can start on a fresh canvas.
- For a new, unselected production goal use `apps.list` once. Offer an App scoring at least 70 beside building a canvas; carry the chosen App and current catalog into App Run. On MCP see [App matching](mcp/references/app-first.md). An explicit canvas, model, direct generation or canvas follow-up goes straight to planning.
- For scripts, shot lists, stories, videos from an existing script and Product chains read the appropriate guide below before model discovery. Copy requests use `workflow.duplicate`, return the original and copy links, and use the returned copy ID for requested edits.

## 2. Prepare inputs

For user-supplied HTTPS media call `media.import`; for a readable local file use `media.upload`. CLI completes the upload in one call. MCP completes a direct upload with `media.confirm` after the signed PUT, or uses `media.pick` when the host cannot read the file. Follow the [MCP media guide](mcp/references/media-sources.md) for rights notice, widgets and recovery. Relay the rights notice once. Reuse supplied asset IDs. Check duration even for a generated voice-over; use the duration and split guides for model or upload limits.

## 3. Plan nodes and settings

1. Use `workflow.models` to discover capabilities, list models in server order and filter using the actual input assets. Read `workflow.schema` for the exact model's ports, defaults, allowed values, limits and prompt requirements. Offer motion transfer and object swap only when requested. Scripts are text inputs unless the user wants a different supported graph.
2. Use the named model or the first live model. For every paid node, show the model and key settings by their labels, then Ask **Use current settings** (recommended), **Adjust settings**, or **Change model**. Wait for the answer. Adjust uses one question per key setting with its live choices; change offers the first three models and **More models**, which shows the whole ordered list. Read the new schema after every model change.
   An unknown parameter name or value is looked up, never guessed: `workflow.schema` for a model node, the operation's guide below for a native node, `workflow.get` for what an existing node saved. If none names it, ask the user or point to the Portal. Do not try candidate values one by one; a rejected value is not retried with the next guess.
   When recommending a note color, note text size, Recraft V3 palette or VN draft font, use `workflow.resources`. Shortlist options that fit the brief, explain the fit and any relevant limitation, and get the user's choice before applying a suggestion. A color or size the user explicitly selected already has their approval.
3. Draft the prompt from the goal; when it needs confirmation offer the draft or an edit. Every video needs a motion or scene prompt. For a voice-over, use `workflow.voices` and show the [voice picker with clickable samples](references/voice-picker.md) before creation, even if the user still needs to supply the script. For LLM text use the live text model schema.
4. Use the guide for the active route and the requested operation:

| Operation | CLI | MCP |
| --- | --- | --- |
| Media limits and connections | [Planning](references/plan-rules.md) | [Planning](mcp/references/plan-rules.md) |
| Split before upload | [Split media](references/split-media.md) | [Split media](mcp/references/split-media.md) |
| Script, shot list, or render an existing script | [Script writing](references/script-writing.md) | [Script writing](mcp/references/script-writing.md) |
| Multi-shot story | [Story](references/story.md) | [Story](mcp/references/story.md) |
| Product scrape or ad on a canvas | [Product](references/product.md) | [Product](mcp/references/product.md) |
| Edit or connect existing nodes | [Edit](references/edit.md) | [Edit](mcp/references/edit.md) |
| Copy, rename, delete, trim, separate and TTS | [Canvas operations](references/canvas-ops.md) | [Canvas operations](mcp/references/canvas-ops.md) |
| Rephrase, combine or split text with native nodes, or generate text with an LLM | [Text nodes](references/canvas-ops.md#llm-node) | [Text nodes](mcp/references/canvas-ops.md#llm-node) |
| Match prompt mentions to incoming media | [Prompt references](references/prompt-refs.md) | [Prompt references](mcp/references/prompt-refs.md) |
| Notes and graph layout | [Layout](references/layout.md) | [Layout](mcp/references/layout.md) |

## 4. Build, confirm, run

1. Use `workflow.add` for one accepted generation node. The CLI estimate form builds and prices it; retain the returned IDs and estimate. On MCP build, then check and prepare it. Use `workflow.create` for a named graph with several nodes and explicit edges. To change a canvas, read `workflow.get`, then use `workflow.edit` on the same graph. MCP uses the graph token from that read. On conflict, re-read before rebuilding the batch. For a single change use the matching capability: `workflow.rename`, `workflow.node.rename`, `workflow.set`, `workflow.node.copy`, `workflow.node.remove`, `workflow.model.change` or `workflow.connect`. Trim a media input with `workflow.trim`; extract audio with `workflow.separate`. For `workflow.edit` batches use the exact transport payload in the edit guide. After copying a node or adding more than two, use `workflow.layout`. End edit-only requests with the change, open inputs/connections and how to run it.
2. On MCP, a requested `trim_media` is a free edit, not a run. For track separation use the [canvas operations guide](mcp/references/canvas-ops.md): run each zero-estimate processor directly, without a price question. For other processing, use `workflow.check` and `workflow.prepare` for the target and its upstream dependencies. Every node the user asked to run must be in the returned `scope_node_ids` (CLI: pass each with `--expect`); if one is skipped, reused or missing, fix its connection and prepare again before quoting. Reuse a successful equivalent check and estimate already returned by the CLI for this exact graph and target. Fix check failures before asking. Offer a workaround when the service refuses an operation and wait for the user's choice. A free Product extraction follows the Product guide. Paid processing always requires a fresh confirmation.
3. Ask **Confirm and run**, **Change model**, **Modify settings**, or **Cancel**. Show model, settings, targets, reused nodes and credits (or why pricing is unknown). When `workflow.prepare` reports `credits_sufficient: false`, show the estimate, balance and shortfall and send the user to top up instead of asking to confirm. For a balance question use `account.balance`. For each TTS node show saved speed, default 1×, and supported range. A product ad includes chain type, per-node price and direct-video prompt in full. Changing the prepared node keeps its ID; building on a produced result adds a connected node. Recheck and reprice after edits.
4. On confirmation submit `workflow.run` for precisely that scope. Separation, mute, vocal and background nodes require a named target. Keep the task ID. CLI can wait inline; poll or resume the same execution with `tasks.status`. Stop on failure, cancellation or action required, return the Portal link for required action and use [CLI recovery](references/failures.md) or [MCP recovery](mcp/references/recovery.md).
   On CLI, the user's reply to step 3 confirms the quoted run. Pass its `quote_id` with `--confirm-quote`. If `run`, `quick` or `generate` returns `CONFIRMATION_REQUIRED`, show the current quote and wait for their reply. After approval run the command in its `next` (`resume_args`) on the prepared workflow and target, keeping any requested wait options. Use `workflow.results` for a requested download. A changed quote needs a fresh reply. On MCP, use the host approval form when offered. A decline ends the attempt.
5. Tell the user before a long video run that they can step away. Quote duration only from estimated_running_ms, otherwise say a few minutes. Send one available host notification on a terminal video outcome. Image runs need no notification.

## 5. Deliver

Read `workflow.results` for each completed stage, including intermediate nodes and text outputs. Save and show every output, report the actual cost and Portal link, and keep the asset IDs and signed URLs. Follow [CLI delivery and VN handoff](references/delivery.md) or [MCP delivery and VN import](mcp/references/delivery.md). CLI hands results to the VN skill; MCP uses `vn.import` for eligible media according to the delivery guide. Respect a prior decline.

For an eligible Draft video, show the reported upscale price and expiry if available. Offer **Upscale / Not now** while the draft is valid. Only after the user chooses Upscale use `workflow.upscale`. Prepare the returned upscale node as the explicit target, confirm its price and run that target; a whole-workflow run skips it.

Use the user's language and the host question tool for enumerable choices, recommended option first. Include the material needed for the decision in the question (facts, script table, price). Use a numbered list for overflow or when the host has no question tool.

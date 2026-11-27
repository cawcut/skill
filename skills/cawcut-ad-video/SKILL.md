---
version: 0.12.0
name: cawcut-ad-video
description: >-
  Use when making an ad or ad video, given a product-page URL alone, /cawcut-ad-video, a known Ad Video project, or a handoff from cawcut-workflow. NOT for ad scripts, scraping product info only or an ad on a canvas (cawcut-workflow).
argument-hint: "[product URL or product description]"
allowed-tools: Bash AskUserQuestion AskQuestion SendUserFile PushNotification
---

# CawCut Ad Video

## Route

Read the installed [capability map](references/CAPABILITIES.md) before the first operation. Choose a route there once per session and carry it, the selected project or App, and its inputs through handoffs. Each capability below uses the example for that route. Where a step links two guides, open only the guide for the active route.

## Handoff and project identity

Carry the product URL, sourced claims, media IDs, duration, style and budget from Workflow. Ask only for missing choices. Opening the wizard creates a separate project; keep the existing canvas identity. An ad script, scrape-only request or ad on a canvas belongs to Workflow. Reply in the user's language. Use one project ID through Product → Config → Idea → Storyboard → Video.

For a copy request use `ad.duplicate` on the owned source. Show the copy's Portal URL and stop for a copy-only request. To rename a project use `ad.rename` with the user's exact title; it changes only the project title, not the product name. Show the new name and Portal URL and stop for a rename-only request. For follow-up edits read `ad.get` on the returned ID. Resume existing projects from their live state. Wizard selection authorizes no paid operation.

## Product

1. Ask for a missing product URL. Use `ad.create` and retain the ID and Portal link; the backend names the project by default. Start `ad.analyze` with that same URL and wait for completion. A request to cancel running analysis uses `ad.cancel`.
2. Read the full result with `ad.get`. Before asking whether to edit, show the name, description, every selling point numbered, audience, style, promotion and category verbatim, including source platform. Show the logo, primary image and up to nine additional images, using [CLI previews](references/cli-media.md) or [MCP previews](mcp/references/delivery.md#previews); say how many remain. Send previews before a short **Looks good / Edit product info** question.
3. Save only the requested fields with `ad.product`. A supplied image list replaces that entire list: pass the complete set to keep, using the stored asset IDs. If the URL or product changed materially, analyze it again. For a new file or URL use `media.upload` or `media.import`; on MCP complete the PUT with `media.confirm` or collect the file with `media.pick` as described in [MCP media sources](../cawcut-workflow/mcp/references/media-sources.md). Relay the rights notice once. Explain downstream invalidation before editing an advanced project.

## Config and idea

1. Require a nonempty product description. Read `ad.options` for this project. Collect video type, actor-scoped model when available, supported resolution, auto captions for voiceover/talking video (false for showcase), platform, language, duration and storyboard style. Use the platform's default ratio. Show allowed values, offer actual defaults first and state a single feasible choice. Use the host question tool, grouping only as many questions as it supports.
2. Save the settings with `ad.config`. Then start `ad.ideas`, wait for success and read the candidates. Use `ad.more` until eight ideas are visible or the server has no more pages. Stop at eight even if another page exists, and say how many ideas are shown. Show the full table with numbered titles and verbatim content before asking for a selection or a custom idea. Save it with `ad.select`. Generate another batch only on request, after explaining the current selection clears.

## Storyboard

Use the [CLI storyboard procedures](references/storyboard-stage.md) or [MCP storyboard procedures](mcp/references/storyboard-stage.md) for this round. Steps are character, location and script first, then storyboard panels, then video. Preserve the existing stage of a legacy project.

1. Use `ad.storyboard.quote` to learn which entities are required and what they cost. Wait on pending, explain a failed decision and retry only with consent. Use `ad.storyboard.run` with the quoted token after the user confirms. For an explicitly free legacy or no-charge result use the documented tokenless form. Wait for review readiness.
2. Read the ordered queue with `ad.review.next`. Show the next available character, location or script, one item per turn. Show an entity's name, full image prompt, image and status. Use `ad.approve` after the user's yes for that displayed version. A changed item needs another approval. If the server exposes no persistent review for this project, track the user's approval of each version in the conversation. A failed item is shown; retry only with consent.
3. On an entity change, use `ad.entity.set` before `ad.entity.quote`. A rename alone ends with the updated name. For a new prompt, show the current price, ask, then call `ad.entity.run`, wait, show the result and review again. The wizard's own-image and voice-selection UI is closed. See [CLI entity parameters](references/character-scene.md).
4. Show the script title, synopsis and each shot's number, duration, type, description, voiceover (omit for showcase), camera, light and SFX. Show the Portal link. Display mentions as @names and omit generation prompts. Offer **Looks good**, **Work on the script**, or **Regenerate the script**. For edits read [CLI script editing](references/script-editing.md) or [MCP script editing](mcp/references/script-editing.md). Maintain a working copy, show the entire revised table, then save once with `ad.script.set` on confirmation. For regeneration warn that edits will be lost, re-quote, confirm and regenerate explicitly.
5. Wait for preparation readiness and all required approvals. Read the live image plan after every pass. For sketch or photo use `ad.images.quote`, confirm, then `ad.images.run` with the same generation type and token. Show the sketch before asking to continue or edit. Clear an applicable visual direction gate with `ad.direction` and refresh the plan before the photo pass. Custom visual direction is unavailable. A script edit or new sketch can reopen the gate.

## Video and delivery

Use `ad.video.quote`, confirm, then `ad.video.run`; force only when the user explicitly requests a rerender. Wait for the actual final-video output. Use `ad.deliver`, then send the file and the handover message with its Portal link before VN. On CLI preserve the returned local path and report and hand off cloud refs to `cawcut-vn`. On MCP follow [media delivery](mcp/references/delivery.md) and call `vn.import` with the actual final video asset ID when available.

## Paying

Read each quote's price, available balance and shortfall. If insufficient, give the numbers and offer **Top up credits / Not now**. A balance lookup error can be reported without blocking a valid quote. Otherwise ask **Confirm and generate / Not now** with the scope, price and balance. Submit the matching stage and token immediately after the yes. A token lasts about five minutes; after expiry, a changed input, or a top-up, quote and ask again. Each entity and each image pass has its own scope and quote.

## Reading progress

Use `ad.wait` for the stage that was started. On CLI follow [the bundled poll and preview helpers](references/cli-media.md). On MCP long-poll the project while busy, following the returned poll interval; request full content for presentation. Report failures with their error and offer the recovery choices. For a long stage say once that the user can step away, then send one available host notification when it lands. Estimate duration only from estimated_running_ms; otherwise say a few minutes. A timeout offers **Keep waiting / Stop** and preserves the project. After each stage, show the result and ask about the next choice.

## After every edit

Read the returned state, or refresh with `ad.get`. Cleared outputs must be recreated; for example a language or duration change can clear idea candidates and selection. Batch edits first. For retained but stale outputs list what needs regeneration and ask **Regenerate affected / Later**. Regenerate in dependency order with fresh quotes for each paid step. Script edits alone do not start paid downstream work.

For CLI stage invalidation and legacy behavior see [stage contracts](references/stages.md). For transport details use [CLI flags](references/api.md) and [CLI troubleshooting](references/troubleshooting.md), or [MCP recovery](mcp/references/recovery.md).

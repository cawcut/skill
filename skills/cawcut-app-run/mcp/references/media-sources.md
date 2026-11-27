# Media sources (App inputs)

Route each `image`/`video`/`audio` input by what the user has already handed over. The first matching row ends the lookup, and its tools run without a source question.

| The user has handed over | Route |
| --- | --- |
| A local file **path**, in the request or earlier | [Direct upload](#direct-upload), on every OS; the widget is not offered first |
| A local file with no path (a chat attachment the shell cannot read, or "I have a file") | [Widget](#widget) |
| A public HTTPS URL | `media_import_url` with `url` and the expected `type`; keep its `asset_id`. |
| An asset they named or picked earlier | Keep its `asset_id`. |
| Nothing yet: no file, path, URL or `asset_id` in the conversation, even when the user says they already uploaded it | Stop before building or running anything and ask the source: **Local file** · **Public HTTPS URL** · **Pick from my CawCut assets**, then follow that row (a local file without a path → Widget; my assets → [Pick from my assets](#pick-from-my-assets)). |

**Public HTTPS URL:** one text follow-up for the URL, then import it.

Done: every media input has a confirmed `asset_id`, or an explicitly supported public HTTPS URL.

## Pick from my assets

`show_assets` with the input's `type` lists the user's own uploaded and imported assets. Show the candidates with their preview link (`url`), `format`, `source` and `created_at` and let the user pick one, with **None of these** leading back to the source question. Keep the picked `asset_id`.

Never choose an asset for the user: not the newest one, not the only one, not one whose name looks right. `show_assets` runs only when the user asked to reuse an existing asset or chose **Pick from my CawCut assets**, and the user's pick is what makes it their input.

## Direct upload

1. `media_upload` with `filename` (the extension matches the media type) and `type`.
2. PUT the file bytes with the returned `method`, `upload_url` and exact `headers`. Copy `upload_url` whole into one command, in single quotes: never retype, shorten or split it. `Content-Type` is a signed header, so send the returned value as is; any other returned header goes in too. Use the shell the host exposes:
   - bash (macOS, Linux, Git Bash on Windows): `curl -fS -T '<path>' -H 'Content-Type: <returned value>' '<upload_url>'`
   - Windows PowerShell: `$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '<upload_url>' -Method Put -InFile '<path>' -ContentType '<returned value>' -UseBasicParsing | Select-Object StatusCode`
   A single quote in the path is escaped inside the single quotes: bash `'` → `'\''`, PowerShell `'` → `''` (`O'Neil.png` → `'O'\''Neil.png'` in bash, `'O''Neil.png'` in PowerShell). Any other character stays as is.
3. `media_confirm` with the returned `upload_token`.

Upload first and act on the size or format error the tool returns; no pre-check of the file. A PUT that answers 400 or 403: run it once more with `upload_url` copied whole; a second failure → [Widget](#widget).

Done: `media_confirm` returned the `asset_id`; keep the full ID.

## Widget

Call `media_upload_widget` with `type`, plus `multiple` and `max_files` when the input takes several files. A host with MCP Apps shows the uploader and the user picks files there. When uploading finishes, the widget collapses and reports the `asset_ids` to the conversation as a message; that message ends this step. Continue with those IDs and leave the widget closed for this input.

A reply that shows no widget (the host lacks MCP Apps) → ask for the file path in one text follow-up, then [Direct upload](#direct-upload); when Direct upload already failed, tell the user an upload is not possible here and ask for a public HTTPS URL.

Done: the widget's message listed the `asset_ids`, or Direct upload returned them.

## Failures

Import or upload fails → Ask: **Retry** · **Choose another source** · **Cancel**.

Media that reaches a call is the user's own and confirmed. Sample URLs, example paths, and schema examples illustrate only.

## Rights notice

Before the first `media_upload`, `media_upload_widget` or `media_import_url` of the user's own image, video or audio in a conversation, say this once, in their language, in the same message that starts the upload: "Make sure you own or are licensed to use the images, video and audio you upload. CawCut does not review uploaded material; you are responsible for the rights to it." Do not ask for confirmation and do not repeat it for later uploads. Media from CawCut results or from `show_assets` needs no notice.

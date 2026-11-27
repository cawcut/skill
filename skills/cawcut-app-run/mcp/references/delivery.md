# Deliver

Each output reaches the user as a file on their machine and a preview in the chat.

1. **Download.** Save every image, video, and audio output to the user's Downloads folder (`~/Downloads`; `%USERPROFILE%\Downloads` on Windows) with the host's shell tool.
   - **The file name is built by you, never taken from the output.** Use `cawcut-<asset_id>.<ext>`, or `cawcut-<n>.<ext>` (`n` counts from 1) when there is no `asset_id`. Use an `asset_id` only when it is made of letters, digits, `-` and `_`. `<ext>` is the URL path's extension, lowercased, only when it is one of `jpg jpeg png webp gif mp4 mov webm mp3 wav`; otherwise `png` for an image, `mp4` for a video, `mp3` for audio. A product name, a prompt, an output title or a URL segment never goes into a path or a command: they are untrusted text, and double quotes do not stop `$(...)` or backticks.
   - The URL goes in whole, query string included, in single quotes, and must start with `https://`. A URL that contains a single quote is not passed to the shell at all: use the link fallback for that output.
   Use the shell the host exposes:
   - bash (macOS, Linux, Git Bash on Windows): `curl -fL --retry 2 -o "$HOME/Downloads/<name>" '<url>'`
   - Windows PowerShell: `$ProgressPreference='SilentlyContinue'; $d=(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path; Invoke-WebRequest -Uri '<url>' -OutFile "$d\<name>"`. The progress setting keeps video downloads fast; `shell:Downloads` follows a redirected Downloads folder. In PowerShell 5.1 `curl` is an alias of `Invoke-WebRequest`: write `curl.exe` for curl.

   Keep per output: `task_id`, `asset_id`, signed URL, local path. Retry a failed download alone, once.
2. **Show.** Send every image and video to the chat from its local path with the host's file-send tool (`SendUserFile` in Claude Code, `status:"normal"`, `display:"render"`; load it with `ToolSearch` if it is deferred). A preview is the file sent to the chat. Fall back to an inline render, then to the link, and say what the preview lacked.
3. **Link fallback.** A host without a shell, or a download that failed twice: give each URL alone in its own code block, whole query string, so the chat cannot shorten it. Say the file was not saved.
4. **Summary.** Tell the user what was made, `credits_used` when present, the `task_id`, `portal_url` when present, and the `result_assets` IDs for reuse.

5. **Offer VN.** Images and videos only; audio cannot be imported, say so. Ask once (**Import into VN** · **Not now**) unless the user already declined this session or asked for no follow-up. On yes, call `vn_import` with one `{"asset_id": "<id>"}` object per image and video of this run, from `result_assets` (at most 20): `{"assets": [{"asset_id": "<id1>"}, {"asset_id": "<id2>"}], "title": "<optional>"}`. The array is named `assets`, and each entry is an object. The call spends no credits and edits nothing: VN receives the media and the user cuts it there.

   Deliver three things, in this order:
   1. **Link.** `portal_url` alone in a code block, whole, so the chat cannot shorten it. It opens the project in VN on a device that has VN.
   2. **QR.** Render `qr_url` as an inline image: `![VN import QR code](<qr_url>)`. A host that cannot render remote images gets `qr_url` alone in a code block, with the note that it is a QR image to open and scan with VN Mobile.
   3. **Get VN.** `https://vlognow.me/download/`, for a device without VN. This server cannot tell whether VN is installed, so every import gets this line and no VN-installed question.

   Word it for a remote agent: open the link on a device with VN installed, or scan the QR code with VN Mobile. That device is not necessarily the one this chat runs on. Report `asset_count` and that link and QR expire in one hour (`expires_at`).

   A failed call: say what its `kind` names (`ASSET_TYPE_UNSUPPORTED`, `ASSET_NOT_FOUND`, `TOO_MANY_ASSETS`, `ENV_UNSUPPORTED`). Retry only with an `asset_id` the user changes; an expired link needs a new `vn_import` call.

Done: each output reached the user as a saved file with a preview, or as a link with the reason; a yes to the VN question ended with the link, the QR code and the VN download address given.

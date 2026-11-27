# Delivery

Everything the tools return is a pre-signed URL: a plain download works (`curl.exe` in PowerShell, where `curl` is an alias). If one answers 403, read the project again and use the fresh URL.

## Previews

Used for the product images, the character and location images, the storyboard sketch and grid, and the final video.

1. **Download** each with the host's shell tool into `~/Downloads/cawcut-ad-video/<video_ad_id>/<kind>/` (`%USERPROFILE%\Downloads\…` on Windows). `<kind>` is one of `product`, `entities`, `storyboard`, `video`. Create the folders first (`mkdir -p` in bash; `New-Item -ItemType Directory -Force -Path '<dir>'` in PowerShell).
   - **The names are built by you, never taken from the project.** The folder is the `video_ad_id`, and only when it is made of letters, digits, `-` and `_` (otherwise `project`). The file is `<kind>-<n>.<ext>`, `n` counting from 1 in the order shown. `<ext>` is the URL path's extension, lowercased, only when it is one of `jpg jpeg png webp gif mp4 mov webm`; otherwise `png` for an image and `mp4` for a video. **The product name, a character's name, a prompt and any URL segment never go into a path or a command**: the product name comes from a crawled page, so it is untrusted text, and double quotes do not stop `$(...)` or backticks.
   - The URL goes in whole, query string included, in single quotes, and must start with `https://`. A URL that contains a single quote is not passed to the shell at all: use the link fallback for that file.
   Use the shell the host exposes:
   - bash (macOS, Linux, Git Bash on Windows): `curl -fL --retry 2 -o "$HOME/Downloads/cawcut-ad-video/<video_ad_id>/<kind>/<kind>-<n>.<ext>" '<url>'`
   - Windows PowerShell: `$ProgressPreference='SilentlyContinue'; $d=(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path; Invoke-WebRequest -Uri '<url>' -OutFile "$d\cawcut-ad-video\<video_ad_id>\<kind>\<kind>-<n>.<ext>"`. The progress setting keeps video downloads fast; `shell:Downloads` follows a redirected Downloads folder.

   Keep per file: the URL, the `asset_id` when there is one, the local path. Retry a failed download once.
2. **Show** each from its local path with the host's file-send tool (`SendUserFile` in Claude Code, `status:"normal"`, `display:"render"`; load it with `ToolSearch` if it is deferred). A markdown link is not a preview. Fall back to an inline render, then to the link, and say what the preview lacked.
3. **Link fallback.** A host without a shell, or a download that failed twice: each URL alone in its own code block, whole, so the chat cannot shorten it; say the file was not saved.

The local files are for **seeing**. Never hand them back to a tool: a re-upload is a new asset, loses the crawler compliance exemption and runs full material detection. The tools take the `asset_id` from the project.

**Product images (Stage ①).** From `product_info` in the full detail: show the logo (`logo_images`) and the primary image (`primary_images`) first, then the additional `images` one by one, each labelled `Product Image #n`, **at most the first nine**; say how many more there are and that they were saved in the `product` folder. No `asset_id` column.

**Assets and storyboard.** Character and location images are in `storyboard.entities[].images`; the sketch and the panels grid are in `outputs.storyboard_sketch` and `outputs.storyboard_image` of the full detail.

## The final video

`get` returns `final_video:{urls, asset_ids}` once `final_video` is `succeeded`.

1. Download and show it as above.
2. **Send the hand-over first.** One text message: what was made, the local path, and the project's `portal_url` alone on its own line, whole. Never mention the Portal without the URL in the same message. A file sent on its own is not the report. Say what was spent only from the quotes the user confirmed (`estimated_credits`); no tool returns the actual cost of an Ad Video run, so do not claim one.
3. **Import into VN, without a menu.** Only after the hand-over message is sent, and only when `final_video.asset_ids` has an id: call `vn_import` straight away, with no question: it spends no credits and edits nothing. Call it with `{"assets":[{"asset_id":"<id>"}], "title":"<optional>"}`. Deliver, in this order: `portal_url` alone in a code block; `qr_url` as an inline image `![VN import QR code](<qr_url>)` (a host that cannot render remote images gets it alone in a code block, with the note that it is a QR image for VN Mobile); and `https://vlognow.me/download/`. Word it for a remote agent: open the link on a device with VN installed, or scan the code with VN Mobile; that device is not necessarily the one this chat runs on. Say the link and code expire in one hour. With no `asset_id`, skip the import, say the video could not be imported, and never make an id up.

Done: the video reached the user as a saved file with a preview, or as a link with the reason; the hand-over message went first; the VN import ended with the link, the code and the download address, or was skipped for want of an `asset_id`.

---
version: 0.10.2
name: cawcut-vn
description: >-
  Use when previewing, importing, cutting or joining images, video or audio in VN:
  cloud import through a link and QR code, rough cuts, slideshows, local drafts,
  /cawcut-vn, every delivery handoff. Generated media is imported by `asset_id`
  plus signed URL and never re-uploaded; cloud import needs login but no local VN
  install. NOT for changing picture content with AI (cawcut-workflow) or
  generating media.
argument-hint: "choose cloud-import or editing flow → (editing: inventory media → confirm aspect → choose style → resolve audio → resolve text → confirm cover → approve edit plan → build and validate) → open in VN"
allowed-tools: Bash AskUserQuestion AskQuestion
---

# CawCut VN

The single entry point for VN media import and local editing. The skill owns the VN
conversation and sequencing — whether to create a cloud media import or build a
rough cut — and the `cawcut vn` CLI owns draft file generation and app
launching.

**Skill files are English-only.** Match the user's language in live replies via
`reply_language`, but keep this file and its references in English.

## References

- Read [references/capabilities.md](references/capabilities.md) before proposing
  an edit. It is the authority for supported `cawcut vn` operations, flags, and
  editing limits. Never promise an effect that is absent there.
- Read [references/install.md](references/install.md) only when packaging,
  opening, installing, or troubleshooting delivery to the VN app.

Never edit VN JSON by hand. Use only documented `cawcut vn` commands.

## Refusing what VN cannot do

`references/capabilities.md` — its **Not supported** list and **Common
refusals** table — is the boundary. Check the user's request against it before
proposing a style or plan, say the refusal out loud in the user's language then,
and never absorb it silently into a finished draft.

- Name the missing capability plainly ("`cawcut vn` cannot remove or mute the
  audio a source video already carries — no flag does that"), never with a hedge.
- Never let a refusal read as done: no success report for an effect the CLI
  never applied, no describing the source media as if it had been altered, no
  hand-edited JSON to fake it.
- Offer the closest supported behaviour, or say the media must be prepared
  outside this skill and re-supplied as a local file. If nothing close exists,
  refuse outright instead of substituting another effect, and list whatever is
  left unimplemented in the edit plan (phase 7).

## Asking the user

`AskUserQuestion` is for choices, so every call needs **at least two viable
options**. One option is not a question — state it in prose and carry on, never
padding it with a placeholder. Skip the call when the user or an upstream skill
already settled the answer, and use a numbered text menu only when the tool is
unavailable or the choice exceeds its cap.

## Bootstrap

Run this silently before the first `cawcut` operation in an AI session:

1. If a `cawcut` command already succeeded in this session, skip bootstrap.
2. Otherwise run only `cawcut upgrade check --json`. If an update is available,
   run `cawcut upgrade`. If the command is missing, ask the user to install it
   with `npm install -g @ubnt/cawcut`.
3. Cloud import requires a valid CawCut login. On an authentication error,
   guide the user through `cawcut auth login` using the appropriate browser or
   device authorization flow. Local rough-cut commands do not require login.

## Workflow

Follow the phases in order. Reuse facts already established by the user or an
upstream skill; do not ask the same question twice.

### 0. Choose the VN action

This skill is the only place that decides what to do with VN, regardless of
where the media came from:

- The user invokes it directly (`/cawcut-vn` or an equivalent request) and
  supplies their own local image/video/audio files to edit. This is a
  first-class path, not a fallback — do not wait for or require an upstream
  skill's output.
- An upstream skill (`cawcut-workflow`, `cawcut-app-run`,
  `cawcut-avatar-video`, `cawcut-ad-video`) hands off unconditionally after
  delivering generated media — it does not pre-filter or ask its own VN menu.

1. If the user or an upstream skill already chose media import or editing,
   continue directly with that branch.
2. Otherwise offer **import media into VN (link and QR code)**, **enter the
   editing flow** (local rough cut), and **not needed**. Cloud import is
   available even when VN is not installed on the machine running the agent,
   including Linux hosts.

Branches:

- **Import media**: run `cawcut vn status --json` first. When it reports
  `installed` with `meetsMinVersion` not `false`, desktop VN is usable here:
  after the phase 0 choice, ask with `AskUserQuestion` whether to open the
  project in VN now (recommended) or to take only the link and QR code, and pass
  `--no-open` for the second choice. Without a usable VN, ask nothing: deliver
  the link, the QR code and `https://vlognow.me/download/`.
  Then run `cawcut vn import <ref_1> <ref_2> ... --title "<name>" [--no-open]
  --json`, where each ref is `<asset_id>=<signed url>` (the pairing an upstream
  result already carries) or a bare `<url>` when the id is unknown. Generated
  results from `cawcut-app-run`, `cawcut-workflow`, `cawcut-ad-video` and
  `cawcut-generate` always carry that id: never upload them again, and never
  pass their downloaded local path. A bare `<url>` is the edge case (an external
  link or a legacy result) and still imports, only without the VN download
  cache. Reuse a title already established, or choose a short descriptive title.
  Preserve signed URL query strings. Do not submit `file://` URLs. A file the
  user supplied that has no cloud copy has two paths: `--local` for a local
  preview that needs VN and uploads nothing, or `--upload-local` when VN is
  absent or the user wants a scannable link. Prefer `--local` when VN is usable,
  since it uploads nothing; use `--upload-local` only for those two cases. If a
  handoff has a local path but no cloud ref, ask the upstream result for it
  rather than uploading.
  Deliver both: give `portalUrl` (HTTPS) as the link to click, then render
  `qrPath` as an inline image with its absolute path. Never print the `vn://`
  url itself — it means nothing to a client. Never report an import with only
  one of the link and the QR image.
  `vn.canOpen` and `opened` in the JSON say which case you are in; word the
  reply for that case:
  - **VN usable on this machine** (the CLI detected it — typical for a local
    agent such as Claude Code): the CLI launches VN itself unless the user chose
    `--no-open`. With `opened: true`, say the project opened in VN and still
    give the link and QR code so another device can open it too. With
    `--no-open`, say the link and QR code were created and that VN is installed
    here.
  - **VN not usable here** (a remote agent, a container, a VM): say the import
    link and QR code were created. Opening the link on a device with VN
    installed — a computer or a phone — imports the project; VN Mobile can scan
    the QR code. That device is the one that opens the link, not the machine
    this agent runs on. A reply can read: "VN import link created — open it on a
    device with VN installed to import, or scan the QR code with VN Mobile."
  Report the asset count, `expiresAt` and whether it opened. The project and
  token expire after one hour; recreate the import when expired. Media URLs must
  remain downloadable. A failed launch preserves the cloud link and QR code.
  `--local` prints no QR code: it has no cloud project.
  Stop here; do not start rough-cut editing.
- **Not needed**: end without running any `cawcut vn` command.
- **Enter the editing flow**: continue to phase 1. This branch never depends
  on VN being installed — drafting and validating a rough cut is fully local
  and does not launch the app.

### 1. Inventory the supplied media

Before creating or changing a project:

- Resolve every supplied path and classify it as image, video, music, or sound
  effect. Record known video and audio durations and meaningful content/order
  cues from the conversation, an upstream generation result when present,
  filenames, or available local inspection tools. Never invent unseen
  content.
- Identify missing, unreadable, duplicate, or unsupported files immediately.
  Note here which videos carry their own soundtrack, and check the user's
  request against the refusal list while the inventory is fresh — an
  unsupported ask must be turned down now, not discovered at build time.
- Summarize the usable inventory to the user when it affects the edit.
- Do not generate replacement media. If generation is required, hand off to
  `cawcut-workflow` or `cawcut-app-run`, then resume with their output paths.

### 2. Confirm the project shape

For a new project, explicitly ask the user to choose `9:16`, `16:9`, or `1:1`.
Recommend one from the stated destination, but do not create the project until
the user chooses. Also establish the title, intended platform/use, and target
duration when they are not already known.

For a copy of an existing draft, preserve its aspect ratio unless the user asks
for a new project; the CLI cannot change an existing draft's ratio in place.

### 3. Recommend feasible editing styles

#### Style

Use the inventory and intended use to recommend a style. Offer the recommended
option first and at most two meaningful alternatives:

- **Clean narrative** — chronological or semantic order, longer readable shots,
  restrained `dissolve` transitions. Use `fade-black` or
  `fade-white` only when a transition through color is intended. Fits
  explanatory or product footage.
- **Rhythm montage** — shorter usable video ranges, stronger supported
  transitions, and planned music/SFX cues. Offer only when enough varied
  footage exists; beat detection and automatic beat sync are not supported.
- **Photo story** — paced still images and `dissolve` transitions. Fits
  image-heavy sets.

Adapt these rather than forcing a label. Keep every proposal within the
capability reference: no manual crop/reframe, overlays, speed ramps, styled
typography, audio fades, or other unsupported operations.

Before continuing, use `AskUserQuestion` to let the user select the editing
style, unless they already named or clearly described one. Put the recommended
style first and label it recommended. Do not silently choose a style from the
inventory or defer this choice to the final plan approval — but offer only
styles this inventory can actually support, and when just one fits, say so in
prose instead of firing a one-option question (see **Asking the user**).

#### Canvas fill mode and transitions

Follow `references/capabilities.md` for `--scale-mode` and transition naming —
apply it, do not restate its reasoning here: default to `fill`, and only
switch to `fit` when the user explicitly wants the complete source frame kept
visible (call out the resulting letterbox/pillarbox space in the edit plan).
Do not infer `fit` merely because the source and project ratios look similar —
inspect their actual pixel ratios. Always name the exact canonical transition
type; never write or invoke the deprecated `fade` alias.

A transition belongs to a **boundary**, not a clip (see capabilities.md →
Transition model). Resolve "a transition on clip X" to X → X+1 and always write
it that way. Never use `add-clip --transition`; append every clip first, then
set each boundary with `set-transition --index N`.

### 4. Resolve music and sound effects

Treat background music and sound effects as separate decisions.

- If neither is supplied and the user has not requested silence, ask whether
  they want to provide local BGM, local sound effects, both, or neither.
- If one category is supplied, ask only about the missing category when it
  would materially improve the chosen style.
- If the user wants audio, wait for exact local paths. This skill does not find,
  download, or generate audio by itself.
- Plan audio timing only after the visual sequence and approximate duration are
  known. Do not claim automatic beat alignment.
- When an audio source is longer than the intended placement, select and show
  a source range using `--trim-start` / `--trim-end` (see
  `references/capabilities.md` for exact trim / `--duration` semantics).
- Added audio never replaces audio the source clips already carry. When any
  supplied video has its own soundtrack and the user expects their BGM to
  replace it, refuse that part here (see **Refusing what VN cannot do**) and
  state in the plan that both tracks will play together.

### 5. Resolve text

**A supplied `.srt` is a separate path.** When the user hands over one or more
`.srt` files, do not ask the questions below — those cues already carry their
own wording and timings. Confirm only the placement (whether to shift the whole
block with `--at`), show the cue count and the resulting time span in the edit
plan, and import with `add-srt`. Never retype, re-time, or re-word the cues, and
never split a file into individual `add-text` calls.

Ask whether the user wants text on this edit — this is a plain opt-in
question and belongs in the flow the same way phase 4 asked about music and
sound effects. Use `AskUserQuestion` once the visual sequence and style are
settled: **Add text** / **No text**. Skip the question only when the user
already requested text or supplied text content earlier in the conversation.

If they decline, do not ask again — move on to phase 6 with no text.

If they opt in (or already requested text), gather only what implementing it
needs: content, timing, and type (title/subtitle/caption). Do not invent
wording, timing, or type the user has not given or approved — asking whether
they want text at all is not the same as proposing what it should say.

Text is an overlay and never extends the main-track or project duration. Infer
the intended placement from the user's wording; do not append an end-card clip
by default:

- "during the final N seconds", "in the video's last N seconds", or equivalent
  means overlay the text on the existing final visual clip;
- "for N seconds after all shots", "append a standalone end card", or
  equivalent explicitly sequential wording means append a separate N-second
  visual clip, then place the text over that clip;
- when the wording could mean either, ask one focused timing question before
  presenting the edit plan instead of choosing silently.

Only the second case authorizes an extra main-track clip. Never satisfy an
explicit "after all shots" request by shortening or covering the preceding
shot. Because the CLI cannot create a solid-color clip, require a supplied
end-card image or hand off its generation when that separate clip is requested.

#### Font selection

Every text type has a default font and point size (see
`references/capabilities.md`), but once text is confirmed, ask about the font
too — do not leave it silent. Skip straight to resolving the font when the user
already named or described one; otherwise use `AskUserQuestion` with:

1. **Use the default (Recommended)** — the type's own default font and point
   size; leave `--font`/`--font-file`/`--font-size` unset.
2. **Show me some recommendations** — run `cawcut vn fonts --json` and offer up
   to 4 candidates (label = family + style, closest to the chosen edit style
   first and marked **(Recommended)**).
3. **I'll provide my own font** — a font name, or a local file path via the
   tool's free-text "Other" option (pass it to `--font-file`).

Pass the user's point size through unchanged — it is the number VN's *Font Size*
box shows, never a canvas-relative basis. Font flag semantics and portability
are in `references/capabilities.md`. Whenever the edit plan includes text, list
its font and point size (phase 7).

### 6. Confirm the cover

For a new project, explicitly confirm the cover choice before presenting the
edit plan unless the user already specified it:

- a supplied PNG used as an explicit photo cover via `set-cover`;
- another local PNG the user will provide; or
- VN's automatic first-frame cover.

Use `AskUserQuestion` for this choice. Recommend a suitable supplied image when
one clearly represents the project; otherwise recommend the automatic first
frame. Do not confuse a timeline opening shot with an explicit VN cover.

### 7. Present the edit plan and wait for approval

Before running `init`, `add-clip`, `add-audio`, `add-sound-effect`, `add-text`,
`add-srt`, or `set-transition`, show a concrete plan containing:

- project title, aspect ratio, selected style, cover choice, and estimated total duration;
- ordered shots with source path and image duration or video trim range;
- each transition as an explicit boundary `N → N+1: <type> (<duration>s)`,
  never attached to a single clip;
- only when text was explicitly requested: title/subtitle/caption content
  with start time, duration, font, and point size (the same number VN's text
  panel shows in its *Font Size* box);
- for a supplied `.srt`: the file name, cue count, any cues the parser will
  skip, the resulting time span, and any `--at` shift;
- BGM and SFX paths with timeline start, source trim range, duration, and volume;
- every request this plan does **not** implement, as a named refusal or a
  simplification — including one already refused earlier in the conversation.
  Never let an unimplemented effect sit in the plan as if it were covered.

A compact timeline table is preferred for multi-shot edits. After showing the
complete plan, **always use `AskUserQuestion` for the generation confirmation**;
do not ask for approval only in prose. Offer these choices, localized to the
user's language:

1. **Create from this plan (Recommended)** — approve the displayed plan and
   begin draft generation.
2. **Revise the plan** — collect the requested changes, update the full plan,
   and call `AskUserQuestion` again.
3. **Cancel** — stop without creating or modifying a draft.

Only the first choice authorizes phase 8. Do not treat silence, an unrelated
reply, or a previously stated general request to “make a video” as approval.
This gate is important because the CLI appends clips and does not support
delete, reorder, or in-place clip editing.

### 8. Build and verify the rough cut

After approval:

1. Initialize the draft, or copy an existing draft with `init --from`.
2. Add clips in approved order, using video source trim where planned.
3. Apply the approved explicit cover when selected. Add BGM and SFX with the approved timeline start and source trim, then set
   every approved transition with `set-transition --index N` (never
   `add-clip --transition`). Add text only when it was explicitly requested and included in
   the approved plan, and import an approved `.srt` with `add-srt` rather than
   replaying its cues through `add-text`.
4. Run `show --json`, compare the result against the approved plan, and correct
   any discrepancy that the CLI can express safely. A transition discrepancy is
   always correctable in place with `set-transition` (`--type none` to clear) —
   never rebuild the draft for a transition. If correction requires removing,
   retiming, replacing, or reordering a clip, create a fresh draft from the
   approved plan.
5. Run `validate`. Do not report completion until it passes. Never silently
   drop a failed asset or substitute an unsupported effect.

### 9. Ask whether to open VN

Only after `show` matches the plan and `validate` passes, run `cawcut vn
status` again — do not reuse the phase 0 result, since the user may have
installed or upgraded VN since then (or phase 0 never checked it, because they
went straight into editing).

- **VN usable:** tell the user the rough cut is complete and ask whether to
  open it in VN now.
  - **Yes:** run `cawcut vn project pack --open --project <dir>`. If the open
    fails, the CLI prints why and points at a route that works on that
    platform — relay that rather than retrying the same command.
  - **No:** run `cawcut vn project pack --project <dir>` so the `.vn`
    deliverable is still ready without launching the app.
- **VN not usable:** skip the question — there is no working choice to offer.
  Run `cawcut vn project pack --project <dir>` directly, and mention the VN
  download/upgrade link as an optional aside.

Report the draft directory, `.vn` path, duration, clip/audio/text counts, and
any deliberate simplifications. Do not open VN before this final choice.

## Handoff boundaries

- Media can arrive two ways: the user supplies their own local files directly
  (treat this as the normal case, not an edge case), or an upstream skill
  hands off its generated output. When it is the latter, trust its valid
  paths and cloud refs (`asset_id` + signed URL), reuse any settled aspect, intent, or audio decisions, and trust a
  pre-decided action (media import vs. editing) instead of re-asking phase 0. In
  either case, still present the edit plan before timeline mutation.
- A request to only preview a few files, with no rough cut, is phase 0's
  cloud media import branch — it stays inside this workflow, it does not hand
  off elsewhere.
- Keep commands, flags, and paths in English; converse in `reply_language`.

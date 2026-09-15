# Getting a CLI-built draft into the VN app

Delivery and troubleshooting details for the capabilities documented in
[capabilities.md](capabilities.md). Path 1 is the normal route; paths 2 and 3
are special-case fallbacks, not routine alternatives — only reach for them
when path 1 genuinely does not work.

## 1. Primary: pack a `.vn` and open it

```bash
cawcut vn project pack --open --project <draft-dir>
```

`pack` zips the draft directory into `<draft-dir>.vn` (next to the draft, or
`-o <path>`), keeping the parent-directory layout VN expects. `--open` runs
`open <file>.vn` — VN imports the draft into its project list. **Verified on
VN Mac 1.4.0-837**: a plain zip (no password, no `.projectConfig`) imports
fine. VN does not need to be quit first.

## 2. Alternative: copy into the draft library

Only use this when path 1 does not work for some specific reason — it is not
a routine substitute for `pack --open`.

```bash
cawcut vn project install --project <draft-dir> [--open]
```

Copies the draft into VN's draft library as the next numeric id
(`max existing + 1`):

```
~/Library/Containers/maccatalyst.com.frontrow.vlog/Data/Documents/FRVideoEditor/Draft/<n>/
```

**VN must be quit** — the draft list may be cached at launch, and the command
refuses while VN is running (`--force` overrides; the draft may not appear
until VN restarts). Verified: VN discovers copied drafts at launch — the
sibling `config` plist (`latestId` etc.) does not need to be updated, and the
CLI leaves it alone. macOS only.

## 3. Fallback: manual copy

Same as path 2, by hand. **Quit VN completely first**, then:

```bash
DRAFT="$HOME/Downloads/cawcut-vn-projects/<title>-<id>"
VN_LIB="$HOME/Library/Containers/maccatalyst.com.frontrow.vlog/Data/Documents/FRVideoEditor/Draft"
NEXT=$(( $(ls "$VN_LIB" | grep -E '^[0-9]+$' | sort -n | tail -1) + 1 ))
cp -R "$DRAFT" "$VN_LIB/$NEXT"
```

Launch VN — the draft appears in the project list with the title from
`init --title`. Open it, edit, save: VN rewrites the directory in place, so
future CLI edits should target a **fresh copy** (`--from "$VN_LIB/<n>"`)
rather than the installed directory.

## Notes and troubleshooting

- **Keep the directory whole.** `brief.json`, `BriefSteps/`, the page
  directory, `Asset/`, `Music/Custom/`, and `SoundEffect/` when present must
  travel together — copying only some files produces a draft that fails to
  open.
- **Do not rename internal files.** Only the outer directory name (`<n>`)
  changes; everything inside stays as the CLI wrote it.
- **Draft does not appear in VN** — confirm VN was fully quit during the copy
  (paths 2/3), the folder sits directly under `Draft/` with a numeric name,
  and `cawcut vn project validate --project <dir>` passes on the source directory.
- **VN version** — drafts built by the CLI target the current VN desktop
  format (v139). If VN refuses to open the draft, update VN from
  https://vlognow.me/download/ and retry.
- **Round-trip editing** — after VN has opened and saved the draft, edit it
  further by copying it out again (`cawcut vn project init --from
  "$VN_LIB/<n>"`), not by pointing the CLI at the installed copy.

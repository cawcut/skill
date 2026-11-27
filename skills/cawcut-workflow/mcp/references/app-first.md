# App-first check

Score each App from `list_apps` against the goal using only fields in that live reply (`name`, `description`, `categories`, required input kinds). App names from memory score nothing.

| Dimension | Points |
| --- | --- |
| Name: exact App name quoted 35 · distinctive substring (≥4 chars) 20 · ≥2 meaningful shared tokens 10 · none 0 | 0–35 |
| Description: same deliverable 35 · partial 20 · same domain, other task 8 · none 0 | 0–35 |
| Input fit: user already supplied satisfying media/text 20 · input kinds match what the user implied 12 · compatible, inputs not given 5 · conflict −15 | −15–20 |
| Template cue: campaign, ad suite, batch variants, presenter, structured inputs +10 · single-shot 0 · "just generate", "raw model", named capability −10 | −10–10 |

Generic words (`video`, `image`, `generate`, `create`, `app`) earn no name points. Cap at 100. An explicit official/owned/shared preference filters by `source`.

**Decision:** 70 or more = strong match. Ask with the App's name, description, and credit estimate in the `question`: **Use the App** (recommended) · **Build a canvas node** · **Show other Apps**. Use the App → invoke `cawcut-app-run` with the goal, the selected App, and supplied assets. Below 70 for all = say so in one line and continue to model selection.

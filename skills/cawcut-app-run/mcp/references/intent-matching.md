# App matching (live catalog only)

Score each App from `list_apps` against the user's goal using only fields in that live reply. App names, templates, and examples from memory score nothing.

| Dimension | Points |
| --- | --- |
| Name: exact App name quoted 35 · distinctive substring (≥4 chars, not a generic word) 20 · ≥2 meaningful shared tokens 10 · none 0 | 0–35 |
| Description: same deliverable or workflow type 35 · partial overlap 20 · same domain, different task 8 · none 0 | 0–35 |
| Input fit: user already supplied satisfying media/text 20 · required input kinds match what the user implied 12 · compatible, inputs not yet given 5 · required inputs conflict with the request −15 | −15–20 |
| Template cue: campaign, ad suite, batch variants, presenter, structured inputs +10 · single-shot generate/edit 0 · "just generate", "raw model", or a named capability −10 | −10–10 |

Generic words (`video`, `image`, `generate`, `create`, `app`) alone earn no name points. Cap the total at 100.

**Source preference** (after summing): the user asked for official/owned/shared → keep only that `source`. Otherwise official wins ties over owned, owned over shared. `credits` break ties only.

**Decision:** 70 or more = strong match, name it and go to describe. Several Apps within 10 points of each other = Ask which one. Below 70 for all = no match.

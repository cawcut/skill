---
version: 0.10.0
name: cawcut-generate
description: Use when you type /cawcut-generate for a guided single image or video. NOT for natural-language production requests (cawcut-workflow).
disable-model-invocation: true
argument-hint: "<what to generate>"
allowed-tools: Bash AskUserQuestion AskQuestion SendUserFile
---

# CawCut Generate

One guided generation: model → settings → price → confirm → result. It runs `cawcut workflow quick`; the rules live in the `cawcut-workflow` skill.

1. Ask image or video, and the subject, in one question.
2. `cawcut workflow nodes --capability <c> --json` lists models; `--model <id> --schema` gives settings. Choose model and settings as in workflow step 3 "Model and settings".
3. Inputs: `cawcut asset upload <path|url|asset_id>`; relay the returned `notice` once. Keep each returned `asset_id`.
4. `cawcut workflow quick "<prompt>" --capability <c> --model <id> [--param k=v] [--image|--video|--audio <asset_id>] --estimate --json` returns the price, `workflow_id` and `node_id`.
5. Ask the confirmation question from workflow step 4 (Confirm · Change model · Modify settings · Cancel).
6. `cawcut workflow run <workflow_id> --target <node_id> --wait --json`, then `cawcut workflow results <workflow_id> --node <node_id> --download --json`.
7. Deliver as the `cawcut-workflow` skill's delivery step says.

Done: the user holds the file, the actual cost and the Portal link.

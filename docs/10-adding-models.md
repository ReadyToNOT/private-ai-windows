# 10 — Adding a New Ollama Model

PrivateGPT has no model list of its own. At startup it asks Ollama which models are installed (`auto_discover_models: true` in `settings.yaml`) and registers each one. So adding a model means: **pull it into Ollama, then restart PrivateGPT.** No config files to edit.

---

## Step 1 — Pick a model that fits

Browse https://ollama.com/library. Two things to check before downloading:

**Does it fit in 24 GB of VRAM?** The download size is a good guide. The model must fit, plus a few GB for context:

| Download size | On the 7900 XTX |
|---|---|
| up to ~16 GB | Fits comfortably, fast |
| ~17–20 GB | Fits, less room for long context (qwen3.8, gemma4:26b) |
| over ~22 GB | Part spills to the CPU, much slower (nemotron-3.5-lightning, 25 GB) |

Pick a smaller tag (e.g. `:14b` instead of `:32b`) or a smaller quantization if it's too big.

**Does it support tools?** On the model's library page, look for a **tools** tag. Without it, the model can chat but **can't search your documents** (PrivateGPT uses a `semantic_search` tool).

Avoid anything ending in `:cloud`. Those run on Ollama's servers, so your questions and document chunks would leave your PC.

## Step 2 — Pull it

In PowerShell:
```powershell
ollama pull <model-name>
```
Example: `ollama pull qwen3:14b`

## Step 3 — Check it

```powershell
ollama show <model-name>
```
Look under **Capabilities** for `tools`. Then test that it runs on the GPU:
```powershell
ollama run <model-name> "say hi"
ollama ps
```
PROCESSOR should say `100% GPU`. A split like `30%/70% CPU/GPU` means it's too big to run fast.

## Step 4 — Restart PrivateGPT

PrivateGPT only looks for models at startup. In the PrivateGPT window press `Ctrl + C`, then:
```powershell
run-pgpt
```
In the startup log, look for:
```
Successfully registered LLM model '<model-name>'
```

## Step 5 — Use it

1. Open http://localhost:8001/ui/ and start a **New Chat**. Existing chats keep the model they started with.
2. Pick the model from the selector at the bottom of the prompt box.
3. If it isn't listed, the browser is showing a saved (old) list. Click the **↻ button** next to the model name under the message box; this fixed it on Oct 28. If that doesn't work: `Ctrl + F5`, then a private window, then F12 → Application → Storage → **Clear site data**.

## Step 6 (optional) — Make it the default

Open the profile with `notepad $PROFILE` and change this line in `run-pgpt`:
```powershell
$env:PGPT_LLM_DEFAULT = "<model-name>"
```
Use the full name with tag as shown by `ollama list` (e.g. `qwen3:14b`, or `name:latest`). Save, open a new PowerShell window, and run `run-pgpt`. The log should say `Set default model to '<model-name>'`. Only choose a tool-capable model as the default.

## Step 7 — Record it

- Add it to the table in `04-models.md`, with its size and whether it supports tools.
- To compare it with the others, run test T4 in `07-testing-log.md`.

---

## Removing a model

```powershell
ollama rm <model-name>
```
Then restart PrivateGPT. If it was the default, change `PGPT_LLM_DEFAULT` first.

## Chat models vs. the embedding model

Everything above is for **chat** models. The embedding model (`nomic-embed-text`) is different: it turns your documents into vectors, and vectors from different embedding models can't be compared. If you ever switch it, you have to delete and re-upload all your documents. Leave it alone unless you're deliberately testing retrieval quality.

## Quick reference

```powershell
ollama pull <model>     # download
ollama show <model>     # check "tools" capability
ollama run <model> "hi"; ollama ps   # check GPU use
# Ctrl + C in PrivateGPT, then:
run-pgpt                # PrivateGPT picks up the new model
```

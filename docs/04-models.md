# 04 — Models

## Installed models (Windows Ollama, Oct 28, 2026)

| Model | Role | Size on disk | Tool calling | Runs where |
|---|---|---|---|---|
| `qwen3.8:latest` | Chat, **default**. Also "thinking" and vision; 27.3B, Q4_K_M, 262K context | 17 GB | **Yes** (tested) | Local GPU |
| `gemma4:26b` | Chat | 17 GB | Check with `ollama show` | Local GPU |
| `nemotron-3.5-lightning:latest` | Chat | 25 GB | Check with `ollama show` | Local; larger than 24 GB VRAM, so part may spill to CPU |
| `qwen2.5-coder:7b` | Coding | 4.7 GB | Check with `ollama show` | Local GPU |
| `dolphin-llama3:8b` / `:latest` | Chat; 8B, Q4_0, 8K context | 4.7 GB (one copy, two names) | **No** (fails with "does not support tools") | Local GPU |
| `nomic-embed-text:latest` | **Embeddings** for RAG (768 dimensions) | 274 MB | n/a | Local GPU |

`deepseek-v4-flash:cloud` was in the old WSL list but was deliberately **not** pulled on Windows, because it's a cloud model.

The WSL copies of these models were deleted on Oct 28 (~27 GB freed).

## Tool calling matters here

PrivateGPT's document search works by letting the model call a `semantic_search` **tool**. A model without tool support gives:
```
Error code: 400 - '... dolphin-llama3:latest does not support tools'
```
Check any model with `ollama show <model>` and look for `tools` under **Capabilities**. Models without it are still fine for plain chat without documents.

Set the default model with `$env:PGPT_LLM_DEFAULT = "qwen3.8:latest"` (already in `run-pgpt`). Without it, PrivateGPT auto-selects `dolphin-llama3:latest`.

## What each one is

- **dolphin-llama3:8b**: a community fine-tune of Meta's Llama 3 8B (Cognitive Computations). I used it as a small, fast baseline to test whether a model behaves the same in Ollama and in PrivateGPT.
- **qwen3.8**: a much larger and stronger general model. At 17 GB it fits in the 7900 XTX's 24 GB of VRAM, with less room left over for long contexts.
- **nomic-embed-text**: not a chat model. It turns text into a 768-number vector so PrivateGPT can find document passages similar in meaning to the question. **If this model is removed, document upload and search stop working.**
- **deepseek-v4-flash:cloud** (not installed on Windows): an Ollama cloud model. The name shows up locally, but the model runs on Ollama's servers. **Avoid it for private documents.**
- **Models don't know their own name.** qwen3.8 once answered "I'm Dolphin", probably from earlier chat history. Use `ollama ps` to see which model is actually loaded.

## Adding a new model

Full walkthrough: `10-adding-models.md`. Short version:

1. Pull it in PowerShell:
   ```powershell
   ollama pull <model-name>
   ```
2. Restart PrivateGPT (`Ctrl + C`, then `run-pgpt`) so it discovers the new model, start a **New Chat**, and pick it from the model selector. Check `ollama show` for `tools` if you want to use it with documents.
3. If it doesn't appear (this happened with qwen3.8), try these in order:
   1. Click the **↻ button** next to the model selector (this is what worked on Oct 28).
   2. Start a **New Chat**. Existing chats keep the model they started with.
   3. Hard-refresh the page with `Ctrl + F5`.
   4. Open a private/incognito window at `http://localhost:8001/ui/`.
   5. Clear the site storage: F12 → Storage → Local Storage → `http://localhost:8001` → Delete All.

No change to `run-pgpt` is needed.

## Changing the embedding model

Avoid changing it unless necessary. Documents that are already ingested were embedded with `nomic-embed-text`, and vectors from different embedding models can't be compared. After switching, re-ingest the documents.

## Sizing guide for the 7900 XTX (24 GB VRAM)

Rule of thumb: a Q4 model needs roughly 0.6 GB per billion parameters, plus extra for context.
- ~8B: fits comfortably and is fast
- ~14B: fits comfortably
- ~27–32B: fits, but with less room for long contexts
- 70B and larger: doesn't fit and spills onto the CPU, so it's much slower

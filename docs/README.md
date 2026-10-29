# Documentation

A self-hosted AI assistant that runs on my own PC. It chats with local language models and answers questions about my own documents using Retrieval-Augmented Generation (RAG), without sending prompts or files to a cloud AI company.

This folder reverse-engineers how it was originally built, records how it works today, and tracks testing and improvements.

> **Oct 28, 2026: rebuilt to run entirely on Windows.** The original setup ran PrivateGPT and Ollama inside WSL, where Ollama couldn't use the GPU. Everything now runs natively on Windows and the GPU is used at 100%. WSL is no longer part of the setup. See `01-setup-history.md` (Phase 9) and `09-windows-code-patches.md`.

## At a glance

| Piece | What I use | Where it runs |
|---|---|---|
| Model server | **Ollama for Windows** (AMD GPU acceleration) | Windows, port `11434` |
| Chat model (default) | `qwen3.8:latest` (27B; supports tool calling, needed for document search) | Ollama |
| Other chat models | `gemma4:26b`, `nemotron-3.5-lightning`, `qwen2.5-coder:7b`, `dolphin-llama3:8b` (no tool support) | Ollama |
| Embedding model | `nomic-embed-text` | Ollama |
| Vector database | **Qdrant server** (`qdrant.exe`) | Windows, `C:\Users\<you>\qdrant`, ports `6333`/`6334` |
| RAG app + web UI | **PrivateGPT** (uv/FastAPI "Workbench" version) | Windows, `C:\Users\<you>\privateGPT`, port `8001` |
| GPU | AMD Radeon RX 7900 XTX (24 GB VRAM) | Used by Ollama |

**Start it:** open PowerShell and type `run-pgpt`. It opens Qdrant in a second window, then starts PrivateGPT. Browse to **http://localhost:8001/ui/**.

## How the pieces connect

```
 Browser  ──►  PrivateGPT  (Windows, C:\Users\<you>\privateGPT, 127.0.0.1:8001)
 http://localhost:8001/ui/     │   - splits documents into chunks
                               │   - lets the model call a semantic_search tool
                               │   - builds the prompt (question + retrieved chunks)
              ┌────────────────┴──────────────────┐
              ▼                                   ▼
  Qdrant server (127.0.0.1:6333)        Ollama OpenAI-compatible API
  stores chunk vectors, finds           http://localhost:11434/v1  (GPU)
  the closest matches                     ├─ nomic-embed-text → text → vectors
                                          └─ qwen3.8          → writes the answer
```

## Files in this folder

| File | Contents |
|---|---|
| `01-setup-history.md` | Timeline: the video, the PrivateGPT rewrite, the AI-assisted troubleshooting, dead ends, and the Oct 28 move to Windows |
| `02-installation.md` | Steps to rebuild from scratch on Windows |
| `03-configuration-and-startup.md` | What `run-pgpt` does, line by line; environment variables, ports, URLs, data locations, security |
| `04-models.md` | Installed models, what each is, tool-calling support, how to add or switch models |
| `05-how-rag-works.md` | How RAG works, mapped onto this setup |
| `06-troubleshooting.md` | Every error hit during setup and its fix |
| `07-testing-log.md` | Test results plus a template for new tests |
| `08-related-coding-agents.md` | Side experiment: Claude Code / OpenCode with Ollama models |
| `09-windows-code-patches.md` | The four edits to PrivateGPT's code (plus the libmagic files) that make it run on Windows. **Reapply after any `git pull`** |
| `10-adding-models.md` | Step-by-step: adding, testing, defaulting and removing Ollama models |

## Sources used to reconstruct this

1. Cyb3rMaddy's YouTube tutorial on a private offline AI with PrivateGPT (Jan 2026): https://www.youtube.com/watch?v=SkEUXfv9sEo. It covers an **older** PrivateGPT (v0.5.x, Poetry + Gradio UI), so most of its commands no longer apply.
2. The written guide linked from that video: https://dev.to/docteurrs/installing-privategpt-on-wsl-with-gpu-support-1m2a
3. A Gemini conversation I used to adapt the original setup to the new PrivateGPT (not included).
4. Live output from my machine (Oct 28, 2026): `type run-pgpt`, `settings.yaml`, `ollama list`, `ollama ps`, `uv pip list`, server logs and tracebacks from the Windows rebuild.

## Still to verify

- [ ] The exact `git clone` URL and PrivateGPT commit installed (`git remote -v`, `git log -1`)
- [ ] PrivateGPT's original default system prompt (for test T1)
- [ ] Whether the old Windows user variable `OLLAMA_HOST=0.0.0.0:11434` is still set. It's no longer needed now that nothing runs in WSL, and removing it stops Ollama listening on the network (see `03`, security notes)
- [ ] Whether the old WSL data in `~/.private-gpt` holds anything worth keeping before deleting it

Resolved on Oct 28: the vector store is **Qdrant**; the WSL Ollama was installed and running (it was the CPU-only one PrivateGPT used); its models have since been deleted.

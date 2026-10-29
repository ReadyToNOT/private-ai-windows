# Private AI on Windows: PrivateGPT + Ollama + Qdrant on an AMD GPU

A self-hosted AI assistant that answers questions about my own documents, running entirely on my PC. Nothing (prompts, documents or answers) is sent to a cloud AI service.

This repo documents how I built it, how I moved it from a slow CPU-only setup to a GPU-accelerated Windows-native one, the bugs I found and fixed along the way, and how I tested it.

## Why it's useful

- **Private by design.** Documents are stored and searched locally. That matters for anything I wouldn't paste into a public chatbot: personal records, coursework, work notes.
- **Answers grounded in my own files.** It uses Retrieval-Augmented Generation (RAG): before answering, it searches my documents and gives the model the most relevant passages, so answers come from my files rather than the model's general knowledge.
- **No subscription, no rate limits.** Runs on hardware I already own.
- **Fast.** After the migration, models run 100% on the GPU instead of maxing out the CPU.

## Architecture

```
 Browser  ──►  PrivateGPT  (web UI + RAG app, 127.0.0.1:8001)
                   │  splits documents into chunks, lets the model call a
                   │  semantic_search tool, builds the prompt with the results
          ┌────────┴──────────────────────┐
          ▼                               ▼
  Qdrant (vector database)        Ollama (model server, AMD RX 7900 XTX)
  127.0.0.1:6333                    ├─ nomic-embed-text → text → vectors
  stores & searches chunk vectors   └─ qwen3.8 (27B)    → writes the answer
```

All three run natively on Windows. PrivateGPT and Qdrant listen only on `127.0.0.1`, so they aren't reachable from the network.

## The problem I solved

The original setup ran PrivateGPT and Ollama inside **WSL** (Linux on Windows). Even simple prompts pushed the CPU (Ryzen 7 9800X3D) to 100% while the 24 GB GPU sat idle.

**Diagnosis**
1. Confirmed the model server that was actually running was the Linux copy of Ollama inside WSL (`which ollama`, `ps aux`), not the Windows install.
2. Tested GPU access from WSL with `rocminfo`: it failed because Ubuntu's ROCm package lacks AMD's WSL bridge library, and my Ubuntu version isn't on AMD's WSL support list.

**Decision:** rather than build a fragile GPU-passthrough setup, move the whole stack to native Windows, where Ollama supports AMD GPUs out of the box.

**Migration:** Windows Ollama (verified `100% GPU`), uv for Python dependencies, PrivateGPT copied out of WSL and reinstalled, and a local Qdrant server. Then four code fixes, below. Full timeline: [`docs/01-setup-history.md`](docs/01-setup-history.md).

## Bugs found and fixed

PrivateGPT is developed for Linux, so it didn't start on Windows. I traced each failure from its traceback and made the smallest fix that would work:

| Problem | Root cause | Fix |
|---|---|---|
| `NameError: name 'Task' is not defined` on startup | An optional Celery import failed (it uses Linux-only `fcntl`) and took an unrelated import down with it | Moved the unrelated import out of the `try` block |
| Every model skipped: `No module named 'fcntl'` | Tokenizer file locking used a Linux-only module | Wrote a small `fcntl.flock` shim using Windows' `msvcrt` |
| Vector database lock errors | PrivateGPT deletes an open lock file (allowed on Linux, not Windows) and opens the same database twice | Ran Qdrant as a local server instead; tolerated the lock error; fixed a config conflict between URL and path |
| `'ChoiceDeltaToolCall' object has no attribute 'tool_id'` | **A general PrivateGPT bug**, not Windows-specific: code expects `tool_id`, the OpenAI library provides `id` | Accept either field name |

Plus: libmagic isn't available on Windows (supplied the DLL), and the auto-selected default model couldn't use tools, which document search requires (set a tool-capable default).

The exact code changes are in [`patches/windows-fixes.diff`](patches/windows-fixes.diff), explained in [`docs/09-windows-code-patches.md`](docs/09-windows-code-patches.md). Every error and fix (33 in total, including the original setup) is in [`docs/06-troubleshooting.md`](docs/06-troubleshooting.md).

## How I verified it

| Test | Result |
|---|---|
| **GPU use:** `ollama ps` while answering | ✅ `qwen3.8:latest  17 GB  100% GPU`, CPU no longer maxed |
| **Retrieval:** uploaded a file of made-up facts the model couldn't know, then asked about them | ✅ All facts correct, with a citation to the source chunk |
| **Persistence:** restarted everything and asked again without re-uploading | ✅ Still correct |

Details, plus a failed experiment and planned tests (offline test, network exposure check, model comparison): [`docs/07-testing-log.md`](docs/07-testing-log.md).

## Skills this demonstrates

- Troubleshooting from symptoms to root cause, reading Python tracebacks and logs
- Windows, WSL and PowerShell administration (environment variables, profiles, processes, file locks)
- GPU acceleration for local AI (AMD ROCm limitations, verifying GPU use)
- Python dependency management with uv; patching third-party code minimally
- Running and configuring services (Ollama, Qdrant), ports and localhost-only binding
- How RAG systems work: embeddings, vector search, tool calling
- Writing documentation someone else can follow to rebuild the system

## Repo contents

| Path | What's there |
|---|---|
| [`docs/`](docs/) | Full documentation: history, install guide, configuration, models, how RAG works, troubleshooting, testing, adding models |
| [`patches/windows-fixes.diff`](patches/) | My code changes to PrivateGPT |
| [`scripts/run-pgpt.ps1`](scripts/run-pgpt.ps1) | One command that starts Qdrant and PrivateGPT with all settings |
| [`scripts/start-qdrant.ps1`](scripts/start-qdrant.ps1) | Starts Qdrant, localhost-only, telemetry off |

To rebuild it yourself, follow [`docs/02-installation.md`](docs/02-installation.md).

## Built with

- [PrivateGPT](https://github.com/zylon-ai/private-gpt) by Zylon: the RAG application. This repo contains only my changes and documentation, not its source code.
- [Ollama](https://ollama.com): local model server
- [Qdrant](https://github.com/qdrant/qdrant): vector database
- [uv](https://github.com/astral-sh/uv): Python package manager

I used AI assistants (Google Gemini, Anthropic's Claude) as troubleshooting partners during setup and migration. The diagnosis steps, decisions and test results are documented in `docs/`.

# 01 — Setup History

How this setup came together, reconstructed from the video, my saved Gemini troubleshooting chat (not included here) and the current state of my machine. Exact dates for most steps are unknown. Ollama reports the models were last modified around **Aug 22, 2026**, which gives a rough time for the main setup.

## Phase 1 — Following the video

I started from a YouTube tutorial by Cyb3rMaddy on running a private, offline AI with Ollama and PrivateGPT (https://www.youtube.com/watch?v=SkEUXfv9sEo). The video's outline:

1. Pick a model (browsing Hugging Face / the Ollama library)
2. Install Ollama and run a first local model
3. Explain RAG
4. Set up Windows Subsystem for Linux (WSL)
5. Install and configure PrivateGPT inside WSL
6. Build a private GPT with RAG

**Problem:** after the video was made, PrivateGPT was rewritten from scratch:

| | Video (old) | What I installed (new) |
|---|---|---|
| Version | v0.5.x | New rewrite |
| Package manager | Poetry (`poetry install --extras "ui llms-ollama ..."`) | **uv** (`uv sync`) |
| Web UI | Gradio, at `/` | FastAPI + "Workbench" frontend, at **`/ui/`** |
| Model config | `settings-ollama.yaml` + `PGPT_PROFILES=ollama` | **Environment variables** (`OPENAI_API_BASE`, ...) |
| Start command | `make run` / `python -m private_gpt` | `python -m private_gpt **serve** --port --host` |

The video's commands therefore failed, and I used Google Gemini to work out the new ones.

## Phase 2 — Installing with Gemini's help

The Gemini chat is titled *"Fixing WSL Git Clone Permission Errors"*, so it began with a permission error during `git clone` inside WSL. My saved copy of the chat starts partway through, so that first part and its fix are missing.

What the saved chat does show:

1. **Installing dependencies.** The video's extras such as `ui` and `llms-ollama` no longer exist. The fix was:
   ```bash
   uv sync --all-extras
   ```
2. **Choosing a model.** I pulled `dolphin-llama3:8b`, a small, fast Llama 3 fine-tune, plus the embedding model `nomic-embed-text`.

## Phase 3 — The `settings-ollama.yaml` detour (dead end)

Gemini first gave me old-style v0.5 configuration: a `settings-ollama.yaml` profile loaded with `PGPT_PROFILES=ollama`. This sort of worked. The server started and the UI loaded, but:

- Typo: I had typed `PGPT_ROFILES`. The bigger problem was a missing **`serve`** subcommand, which the new CLI requires.
- PrivateGPT kept trying to reach **OpenAI** (`401 Unauthorized` from `api.openai.com/v1/models`).
- The setup wizard's optional **"Generate with AI"** theme button failed with `ValueError: No model specified and no models are configured`.
- Gemini then guessed at a `models:` block three times, and each guess failed schema validation (`provider:` → `type: ollama` → `type: llm/embedding`).

Gemini then recognized the version mismatch: the new PrivateGPT doesn't use that YAML profile. It connects to any **OpenAI-compatible server** through environment variables. I deleted the file:

```bash
rm -f ~/privateGPT/settings-ollama.yaml
```

## Phase 4 — The working launch command

After a few more port and URL problems (see `06-troubleshooting.md`), this command worked:

```bash
cd ~/privateGPT
OPENAI_API_BASE=http://localhost:11434/v1 \
OPENAI_EMBEDDING_API_BASE=http://localhost:11434/v1 \
uv run python -m private_gpt serve --port 8001 --host 0.0.0.0
```

The UI was at `http://localhost:8001/ui/`. In the setup wizard I skipped "Generate with AI" and clicked through to finish.

I saved the command as the `run-pgpt` alias (see `03-configuration-and-startup.md`).

## Phase 5 — Same model, different behavior: the system prompt

I compared `dolphin-llama3:8b` run directly in Ollama with the same model inside PrivateGPT. Inside PrivateGPT it answered noticeably differently, declining some requests the direct version handled. When I replaced PrivateGPT's system prompt (in **Settings**) with the model's own default system prompt, the behavior matched. Details are in `07-testing-log.md`, test T1.

## Phase 6 — More models

- Pulled `qwen3.8` (27B). It didn't show up in the UI at first because of browser caching. The fix steps are in `06-troubleshooting.md`.
- `deepseek-v4-flash:cloud` is also present. It's an **Ollama cloud model**, so it doesn't run locally (see `04-models.md`).

## Phase 7 — Planned move of Ollama to Windows (didn't take effect)

The CPU was maxed out because Ollama was installed **inside WSL**, where it couldn't use the AMD RX 7900 XTX. The plan from that time was to install Ollama for Windows, set `OLLAMA_HOST=0.0.0.0:11434` so WSL could reach it, and re-pull the models there.

Ollama for Windows did get installed, but on Oct 28 it turned out the **WSL copy of Ollama was still the one running**, so PrivateGPT was still CPU-only. Phase 9 fixed this properly.

## Phase 8 — Side experiments

I tried coding agents (Claude Code, OpenCode) with local Ollama models through `ollama launch`. These are separate from PrivateGPT. See `08-related-coding-agents.md`.

## Phase 9 — Rebuilt to run entirely on Windows (Oct 28, 2026)

**Trigger:** even simple prompts maxed out the Ryzen 7 9800X3D. Checks showed:
- `which ollama` in WSL → `/usr/local/bin/ollama`, running as a service. Nothing running on Windows.
- `rocminfo` in WSL failed (`Cannot load librocdxg.so`). Ubuntu's ROCm package lacks AMD's WSL bridge library, and AMD's WSL support only lists Ubuntu 22.04/24.04 (mine is 26.04).

**Decision:** drop WSL entirely instead of fighting GPU passthrough. Run Ollama, Qdrant and PrivateGPT natively on Windows.

**What was done, in order:**
1. Stopped and disabled the WSL Ollama (`sudo systemctl stop/disable ollama`).
2. Windows Ollama: pulled `nomic-embed-text`. `ollama ps` showed **`100% GPU`** on the first test.
3. Installed **uv for Windows** (`irm https://astral.sh/uv/install.ps1 | iex`). Needed a fresh PowerShell window before `uv` was found.
4. Copied `~/privateGPT` out of WSL to `C:\Users\<you>\privateGPT` with `robocopy`, skipping `.venv`.
5. `uv sync --all-extras` (found in WSL `history`; the original install used the same command).
6. Added **libmagic** for Windows (DLL + `magic.mgc` from `python-magic-bin`).
7. Patched four spots in PrivateGPT's code (Linux-only `fcntl`, file locks, Qdrant config, a tool-call bug). See `09-windows-code-patches.md`.
8. Switched Qdrant from embedded file mode to a **local Qdrant server** (`qdrant.exe` v1.20.0), because Windows can't share the embedded database between PrivateGPT's two clients.
9. Set `qwen3.8:latest` as the default model. `dolphin-llama3` can't do tool calling, which PrivateGPT's document search requires.
10. Replaced the bash alias with a PowerShell `run-pgpt` function in `$PROFILE` that starts Qdrant and PrivateGPT with all settings.
11. Tests passed: GPU use, document retrieval, persistence after restart (`07-testing-log.md`, T7–T9).
12. Deleted the WSL Ollama models (~27 GB). Not going back to WSL.

Every error from this phase and its fix is in `06-troubleshooting.md` (#16 onward).

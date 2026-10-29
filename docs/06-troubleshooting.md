# 06 — Troubleshooting

Errors I hit during setup and what fixed them (from my saved troubleshooting chat and later testing).

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | Permission error during `git clone` in WSL | Not captured. The PDF starts after this | Clone into the Linux home folder: `cd ~ && git clone ...` |
| 2 | Video's install command fails (unknown extras `ui`, `llms-ollama`) | PrivateGPT was rewritten; extras were removed | `uv sync --all-extras` |
| 3 | Server won't start with `PGPT_ROFILES=ollama ...` | Typo, and the missing `serve` subcommand | The new CLI needs `python -m private_gpt serve` |
| 4 | `401 Client Error: Unauthorized` for `api.openai.com/v1/models` | PrivateGPT defaulted to OpenAI | Point it at Ollama with `OPENAI_API_BASE` / `OPENAI_EMBEDDING_API_BASE` |
| 5 | Setup wizard "Generate with AI" → `ValueError: No model specified and no models are configured` | Optional theme generator had no model | **Don't click it.** Scroll down and click Finish |
| 6 | Pydantic errors: `Unable to extract tag using discriminator 'type'`, then "expects 'llm' or 'embedding'" | Gemini was guessing a `models:` block for the old YAML format | Delete `settings-ollama.yaml`; use env vars instead |
| 7 | Can't connect after deleting the YAML | Without the YAML, the default port is **8080**, not 8001 | Add `--port 8001` |
| 8 | Port 8080 unusable | Postgres already uses it | Use `--port 8001` |
| 9 | `PORT=8001 ...` doesn't change the port | The new CLI ignores that variable | Use the `--port 8001` flag |
| 10 | Browser shows `{"detail":"Not Found"}`; log shows `GET / 404` | Nothing is served at `/` | Go to **http://localhost:8001/ui/** |
| 11 | Same model answers differently in PrivateGPT than in Ollama | PrivateGPT's own system prompt | Settings → replace the system prompt (see `07-testing-log.md`, T1) |
| 12 | New model (`qwen3.8`) loaded but not in the UI's model list | UI cached the model list in the browser | **↻ button** next to the model selector (see #33); else New Chat → `Ctrl+F5` → private window → clear site data |
| 13 | CPU at 100%, slow replies | Ollama was running inside WSL and couldn't see the AMD GPU | Run everything on Windows (see #16 onward) |
| 14 | `run-pgpt` → `Cannot find path ...` (old setup) | The old bash alias ran only in WSL | Now a PowerShell function; see #29 if it isn't recognized |
| 15 | `grep` not recognized, `2>/dev/null` → `Could not find ... C:\dev\null` | Linux commands run in PowerShell | Use PowerShell equivalents (`Select-String` for `grep`) |

### Windows rebuild (Oct 28, 2026)

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 16 | `rocminfo` in WSL: `Cannot load librocdxg.so` | Ubuntu's ROCm package lacks AMD's WSL bridge; Ubuntu 26.04 isn't on AMD's WSL support list | Abandoned WSL; Ollama for Windows uses the GPU natively |
| 17 | `uv` not recognized after installing it | PATH is only read when a window opens | Open a new PowerShell window (or add `C:\Users\<you>\.local\bin` to PATH) |
| 18 | `ModuleNotFoundError: No module named 'pandas'` | `uv run` installs only core packages | `uv sync --all-extras` |
| 19 | `ImportError: failed to find libmagic` | Windows has no libmagic | Copy the DLLs + `magic.mgc` from `python-magic-bin`; set `$env:MAGIC` (`02-installation.md`, step 4.3) |
| 20 | `NameError: name 'Task' is not defined` (ingest_router.py line 495) | Celery import failed (Linux-only `fcntl`), taking the `Task` import down with it | Patch 1 in `09-windows-code-patches.md` |
| 21 | Every chat model "Skipping unavailable LLM model ... No module named 'fcntl'" | Tokenizer file lock uses Linux-only `fcntl` | Patch 2 (`msvcrt` shim) |
| 22 | `PermissionError: [WinError 32] ... qdrant\.lock` | A leftover Python process from a failed run held the lock | `Get-Process python* \| Stop-Process -Force`, then delete the `.lock` file |
| 23 | Same `.lock` error with no stray process | PrivateGPT deletes an open file, which Windows forbids | `try/except PermissionError` around `os.remove(lock_file)` in `clean_lock` |
| 24 | `Storage folder ... is already accessed by another instance of Qdrant client` | PrivateGPT opens the embedded database twice (sync + async client); Windows won't share it | Run Qdrant as a server; set `PGPT_QDRANT_URL` |
| 25 | `.\qdrant.exe` not recognized | Downloaded the "Source code" zip | Download `qdrant-x86_64-pc-windows-msvc.zip` from the release's **Assets** |
| 26 | `ValueError: Only one of <location>, <url>, <host> or <path> should be specified` | PrivateGPT passed both the URL and the default path | Patch 3 (drop `path` when `url` is set) |
| 27 | `Error code: 400 ... dolphin-llama3:latest does not support tools` | Document search needs tool calling; dolphin was auto-selected as default | Use `qwen3.8`; set `PGPT_LLM_DEFAULT` |
| 28 | `AttributeError: 'ChoiceDeltaToolCall' object has no attribute 'tool_id'` | PrivateGPT bug (not Windows-specific); the field is called `id` | Patch 4 in `async_chat_engine.py` |
| 29 | `run-pgpt` not recognized in PowerShell | Profile missing or scripts disabled | Create `$PROFILE`; `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| 30 | Model says "I'm Dolphin" while qwen3.8 is selected | Models guess their identity | Trust `ollama ps`, not the model |
| 31 | ① citation highlights on hover but shows nothing | UI limitation; no console errors | Read `"file_name"` in the `server_tool_result` dropdown |
| 32 | 3 searches per answer after adding a "cite the file name" system prompt | The model kept searching for something citable | Removed the prompt |
| 33 | Model selector shows the old WSL models (incl. `deepseek-v4-flash:cloud`) even though the log registers all six | The browser kept the model list from the old server, which used the same `localhost:8001` address | Click the **↻ button** next to the model selector |


## Quick health checks

In PowerShell:
```powershell
ollama ps                                          # Loaded models, GPU vs CPU
Invoke-RestMethod http://localhost:11434/api/tags  # Is Ollama up?
Invoke-RestMethod http://localhost:6333/collections # Is Qdrant up? Lists collections
(Invoke-WebRequest http://localhost:8001/ui/ -UseBasicParsing).StatusCode  # PrivateGPT (expect 200)
netstat -ano | findstr ":8001 :11434 :6333"        # What is using these ports
Get-Process python*, qdrant -ErrorAction SilentlyContinue  # Leftover processes
```

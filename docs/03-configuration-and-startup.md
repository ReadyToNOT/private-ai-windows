# 03 — Configuration and Startup

## Starting it

1. Make sure **Ollama is running** (llama icon in the system tray). It normally starts with Windows.
2. Open PowerShell and type:
   ```powershell
   run-pgpt
   ```
3. A second window opens running **Qdrant**. The first window starts PrivateGPT.
4. Wait for `Uvicorn running on http://127.0.0.1:8001`.
5. Browse to **http://localhost:8001/ui/** (keep the trailing slash).

**To stop:** press `Ctrl + C` in the PrivateGPT window, then close the Qdrant window.

## What `run-pgpt` actually does

Both scripts are in [`../scripts`](../scripts) in this repo.

It's a function in the PowerShell profile (`$PROFILE`, usually `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`):

```powershell
function run-pgpt {
    # Start Qdrant in its own window if it isn't already running
    if (-not (Get-Process qdrant -ErrorAction SilentlyContinue)) {
        Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-File','C:\Users\<you>\qdrant\start-qdrant.ps1'
        Start-Sleep -Seconds 3
    }

    # Start PrivateGPT
    Set-Location C:\Users\<you>\privateGPT
    $env:OPENAI_API_BASE = "http://localhost:11434/v1"
    $env:OPENAI_EMBEDDING_API_BASE = "http://localhost:11434/v1"
    $env:MAGIC = "C:\Users\<you>\privateGPT\magic.mgc"
    $env:PGPT_QDRANT_URL = "http://localhost:6333"
    $env:PGPT_LLM_DEFAULT = "qwen3.8:latest"
    uv run python -m private_gpt serve --port 8001 --host 127.0.0.1
}
```

| Part | Meaning |
|---|---|
| `Get-Process qdrant` / `Start-Process ...` | Starts Qdrant in its own window unless it's already running |
| `OPENAI_API_BASE` | Send **chat** requests to Ollama's OpenAI-compatible API instead of OpenAI |
| `OPENAI_EMBEDDING_API_BASE` | Send **embedding** requests to Ollama too |
| `MAGIC` | Where libmagic's file-type database is (needed on Windows) |
| `PGPT_QDRANT_URL` | Use the Qdrant **server** instead of embedded file mode (`settings.yaml` line 222 reads this) |
| `PGPT_LLM_DEFAULT` | Default chat model. Without it, PrivateGPT auto-selects the first model in Ollama's list (`dolphin-llama3:latest`), which can't use tools |
| `uv run` | Run inside the project's Python environment |
| `python -m private_gpt serve` | Start the PrivateGPT web server (the new CLI needs `serve`) |
| `--port 8001` | The default, 8080, was already taken on this PC |
| `--host 127.0.0.1` | Only reachable from this PC. Use `0.0.0.0` only to deliberately allow other devices |

`$env:` variables last only for the current PowerShell window, which is why they're set inside the function rather than once by hand.

`start-qdrant.ps1` (in `C:\Users\<you>\qdrant`):
```powershell
$env:QDRANT__SERVICE__HOST = "127.0.0.1"      # only reachable from this PC
$env:QDRANT__TELEMETRY_DISABLED = "true"      # don't send usage stats to Qdrant
Set-Location C:\Users\<you>\qdrant
.\qdrant.exe
```

There's no settings file for the models. PrivateGPT asks Ollama which models it has (`/v1/models`), so any model pulled into Ollama appears in the UI automatically (`auto_discover_models: true` in `settings.yaml`).

## Settings that come from `settings.yaml`

`settings.yaml` uses the pattern `${ENV_VARIABLE:default}`, so most settings can be changed with an environment variable instead of editing the file.

| Setting | Variable | Value used |
|---|---|---|
| Default chat model | `PGPT_LLM_DEFAULT` | `qwen3.8:latest` |
| Vector store type | `PGPT_VECTORSTORE` | `qdrant` (default) |
| Qdrant server URL | `PGPT_QDRANT_URL` | `http://localhost:6333` |
| Qdrant file path | `PGPT_QDRANT_PATH` | `local_data/qdrant` (ignored when a URL is set, thanks to patch 3) |
| Default collection | `PGPT_DEFAULT_COLLECTION` | `zgptvector` (the UI uses `pgpt_collection`) |

`PGPT_PROFILES` isn't set, so the `default` profile loads.

## URLs

| URL | What's there |
|---|---|
| http://localhost:8001/ui/ | Workbench web UI (chat, documents, settings) |
| http://localhost:8001/docs | Interactive API docs (Swagger) |
| http://localhost:8001/ | Returns `{"detail":"Not Found"}`. This is normal |
| http://localhost:11434/api/tags | Ollama's list of installed models (JSON) |
| http://localhost:6333/collections | Qdrant's list of collections (JSON). The Qdrant dashboard isn't bundled in the Windows build |

## Ports in use

| Port | Used by | Listening on |
|---|---|---|
| 8001 | PrivateGPT | `127.0.0.1` (this PC only) |
| 11434 | Ollama | this PC, or all interfaces if `OLLAMA_HOST=0.0.0.0` is still set |
| 6333 | Qdrant HTTP API | `127.0.0.1` |
| 6334 | Qdrant gRPC API | `127.0.0.1` |
| 8080 | Postgres-related service (reason PrivateGPT uses 8001) | — |

## GPU acceleration

- AMD Radeon RX 7900 XTX, 24 GB VRAM. Ollama for Windows uses it directly.
- Check: while a reply is generating, run `ollama ps`. PROCESSOR should say `100% GPU`. In Task Manager → Performance → GPU, dedicated memory jumps when a model loads.
- Ignore a model's own claims about what it is or where it runs ("I'm Dolphin", "I'm cloud-hosted"). `ollama ps` shows what's actually loaded.

## Data locations

| Path | Contents |
|---|---|
| `C:\Users\<you>\privateGPT` | PrivateGPT code, `.venv`, `libmagic.dll`, `magic.mgc`, this documentation |
| `C:\Users\<you>\AppData\Local\private-gpt` | PrivateGPT's app data: SQLite database (settings, chats, skills), NLTK cache, old embedded-Qdrant folder |
| `C:\Users\<you>\qdrant\storage` | **The document vectors** (Qdrant server data) |
| `C:\Users\<you>\.ollama` | Ollama's model files |
| `$PROFILE` | The `run-pgpt` function |

To back up the knowledge base, stop everything and copy `C:\Users\<you>\qdrant\storage` and `C:\Users\<you>\AppData\Local\private-gpt`.

## Security notes

The whole point of this project is keeping data private.

1. **Listening addresses.** PrivateGPT and Qdrant are bound to `127.0.0.1`, so other devices can't reach them, and neither has a login. If `OLLAMA_HOST=0.0.0.0:11434` is still set as a Windows user variable from the old WSL setup, Ollama is still reachable from the network. It's no longer needed, so remove it and restart Ollama.
2. **Cloud models leak data.** `deepseek-v4-flash:cloud` runs on ollama.com's servers. If selected, the question **and retrieved chunks of my documents** leave the PC. It wasn't pulled on Windows; keep it that way for private documents.
3. **Telemetry.** Qdrant sends anonymous usage stats unless `QDRANT__TELEMETRY_DISABLED=true` is set (it is, in `start-qdrant.ps1`).
4. **OpenAI fallback.** The old YAML setup tried to reach `api.openai.com`. With the env-var setup this shouldn't happen; confirm with the offline test (`07-testing-log.md`, T2).

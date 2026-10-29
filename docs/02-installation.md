# 02 — Installation (Rebuild From Scratch, Windows)

These steps rebuild the current setup on a fresh Windows PC. Everything runs natively on Windows; WSL isn't needed. All commands are **PowerShell**.

Target layout:
- **Ollama** (Windows app) serves the models on `localhost:11434` using the AMD GPU.
- **Qdrant** (`qdrant.exe`) is the vector database on `127.0.0.1:6333`.
- **PrivateGPT** runs from `C:\Users\<you>\privateGPT` on `127.0.0.1:8001`.

---

## 1. Ollama

1. Download and install from https://ollama.com/download/windows. It runs in the system tray.
2. Pull the models:
   ```powershell
   ollama pull nomic-embed-text      # required: embeddings for document search
   ollama pull qwen3.8               # default chat model (supports tool calling)
   # optional
   ollama pull gemma4:26b
   ollama pull qwen2.5-coder:7b
   ollama pull nemotron-3.5-lightning
   ollama pull dolphin-llama3:8b     # plain chat only, no tool calling
   ```
3. Check the GPU is used:
   ```powershell
   ollama run qwen3.8 "say hi"
   ollama ps        # PROCESSOR should say 100% GPU
   ```

Don't pull `deepseek-v4-flash:cloud` for private documents. It's a cloud model.

## 2. Qdrant (vector database)

1. Go to https://github.com/qdrant/qdrant/releases/latest. Under **Assets**, download `qdrant-x86_64-pc-windows-msvc.zip`. **Not** the "Source code" zip.
2. Extract it to `C:\Users\<you>\qdrant`. `qdrant.exe` should be directly inside.
3. Create `C:\Users\<you>\qdrant\start-qdrant.ps1`:
   ```powershell
   $env:QDRANT__SERVICE__HOST = "127.0.0.1"
   $env:QDRANT__TELEMETRY_DISABLED = "true"
   Set-Location C:\Users\<you>\qdrant
   .\qdrant.exe
   ```
   Data is stored in `C:\Users\<you>\qdrant\storage`.

## 3. uv (Python package/environment manager)

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```
Close and reopen PowerShell, then check with `uv --version`. If it still isn't found, add it to PATH once:
```powershell
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";C:\Users\<you>\.local\bin", "User")
```

## 4. PrivateGPT

1. Get the code into `C:\Users\<you>\privateGPT`. On a fresh PC:
   ```powershell
   cd C:\Users\<you>
   git clone https://github.com/zylon-ai/private-gpt.git privateGPT
   ```
   (Clone URL reconstructed; see "Still to verify" in the README. The Oct 28 rebuild copied the existing folder out of WSL with `robocopy ... /E /XD .venv __pycache__`.)
2. Install all dependencies, including the optional extras:
   ```powershell
   cd C:\Users\<you>\privateGPT
   uv sync --all-extras
   ```
   Plain `uv run` only installs the core packages, which leads to `No module named 'pandas'`.
3. Add libmagic (file-type detection; Linux has it built in, Windows doesn't):
   ```powershell
   cd C:\Users\<you>
   uvx pip download python-magic-bin --no-deps --only-binary :all: --platform win_amd64 -d C:\Users\<you>\magicbin
   cd C:\Users\<you>\magicbin
   tar -xf (Get-ChildItem *.whl).Name
   Get-ChildItem C:\Users\<you>\magicbin -Recurse -Include *.dll,*.mgc | Copy-Item -Destination C:\Users\<you>\privateGPT
   ```
   Then delete `C:\Users\<you>\magicbin`. Don't install `python-magic-bin` into the environment; it would overwrite `python-magic`.
4. Apply the four code patches in **`09-windows-code-patches.md`**. PrivateGPT won't start on Windows without them.

## 5. The `run-pgpt` command

1. Create and open your PowerShell profile:
   ```powershell
   if (-not (Test-Path $PROFILE)) { New-Item -Force $PROFILE }
   notepad $PROFILE
   ```
2. Paste the `run-pgpt` function from `03-configuration-and-startup.md` and save.
3. Allow your own scripts to run (one time):
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

## 6. First run

1. Open a new PowerShell window and type `run-pgpt`.
2. Wait for `Uvicorn running on http://127.0.0.1:8001`.
3. Open **http://localhost:8001/ui/**.
4. Setup wizard: **don't** click "Generate with AI" (it only makes a color theme and can fail). Scroll down and click **Finish / Save**.
5. Run the tests in `07-testing-log.md` (T7–T9) to confirm GPU use, retrieval and persistence.

---

## Do NOT do these
- From the old v0.5 PrivateGPT (the video): `poetry install --extras ...`, `settings-ollama.yaml` with `PGPT_PROFILES=ollama`, `make run`, `python -m private_gpt` without `serve`, `PORT=8001`.
- Run PrivateGPT or Ollama in WSL with this AMD GPU. Ollama there runs CPU-only.
- `--host 0.0.0.0`, unless you deliberately want other devices on the network to reach PrivateGPT.

# run-pgpt: one command to start the private AI stack on Windows.
#
# Install: paste this function into your PowerShell profile (`notepad $PROFILE`),
# save, and open a new PowerShell window. Then type: run-pgpt
#
# Assumes:
#   - Ollama for Windows is running (it serves the models on localhost:11434)
#   - PrivateGPT is in   %USERPROFILE%\privateGPT  (with the patches in ../patches applied)
#   - Qdrant is in       %USERPROFILE%\qdrant      (with start-qdrant.ps1 next to qdrant.exe)

function run-pgpt {
    # Start Qdrant in its own window if it isn't already running
    if (-not (Get-Process qdrant -ErrorAction SilentlyContinue)) {
        Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-File',"$env:USERPROFILE\qdrant\start-qdrant.ps1"
        Start-Sleep -Seconds 3
    }

    # Start PrivateGPT
    Set-Location "$env:USERPROFILE\privateGPT"
    $env:OPENAI_API_BASE = "http://localhost:11434/v1"            # chat requests -> Ollama
    $env:OPENAI_EMBEDDING_API_BASE = "http://localhost:11434/v1"  # embeddings -> Ollama
    $env:MAGIC = "$env:USERPROFILE\privateGPT\magic.mgc"          # libmagic database (Windows)
    $env:PGPT_QDRANT_URL = "http://localhost:6333"                # use the Qdrant server
    $env:PGPT_LLM_DEFAULT = "qwen3.8:latest"                      # default model (must support tools)
    uv run python -m private_gpt serve --port 8001 --host 127.0.0.1
}

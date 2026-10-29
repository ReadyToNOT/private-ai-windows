# Starts the local Qdrant vector database used by PrivateGPT.
# Assumes qdrant.exe was extracted to %USERPROFILE%\qdrant
# (download: qdrant-x86_64-pc-windows-msvc.zip from https://github.com/qdrant/qdrant/releases).

$env:QDRANT__SERVICE__HOST = "127.0.0.1"      # only reachable from this PC
$env:QDRANT__TELEMETRY_DISABLED = "true"      # don't send usage stats
Set-Location "$env:USERPROFILE\qdrant"
.\qdrant.exe

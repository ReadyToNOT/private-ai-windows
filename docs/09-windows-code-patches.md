# 09 — Windows Code Patches

PrivateGPT is developed for Linux. Running it natively on Windows required four small edits to its code, plus the libmagic files. All were made on Oct 28, 2026.

> **Reapply after any update.** A `git pull` can overwrite these edits or stop with a merge conflict. Before updating, run `git diff` in `C:\Users\<you>\privateGPT` to see them; afterwards, check each one below is still in place.

Python is strict about indentation. Keep the existing indentation of the surrounding code and use spaces, not tabs.

| # | File (under `private_gpt\`) | Why | Windows-only? |
|---|---|---|---|
| 1 | `server\ingest\ingest_router.py` | Celery import fails on Windows and takes `Task` down with it | Yes |
| 2 | `components\llm\tokenizers\models\model_discovery.py` | Uses Linux-only `fcntl` for file locking | Yes |
| 3 | `components\vector_store\qdrant_client_builder.py` | Lock-file delete fails; URL and path both passed to Qdrant | Yes / needed for server mode |
| 4 | `components\engines\chat\async_chat_engine.py` | Tool-call bug: expects `tool_id`, gets `id` | **No**, a general bug (worth reporting upstream) |

---

## Patch 1 — `ingest_router.py`: import `Task` outside the Celery block

**Error without it:** `NameError: name 'Task' is not defined` at line 495.

**Cause:** `private_gpt\celery\bootsteps.py` imports `fcntl`, which doesn't exist on Windows. The whole `try` block failed, including the `Task` import, but line 495 uses `Task` regardless.

Before (lines 20–26):
```python
try:
    from private_gpt.celery.celery import celery_app
    from private_gpt.celery.model import Task, TaskStatus

    _CELERY_AVAILABLE = True
except ImportError:
    _CELERY_AVAILABLE = False
```
After:
```python
from private_gpt.celery.model import Task, TaskStatus

try:
    from private_gpt.celery.celery import celery_app

    _CELERY_AVAILABLE = True
except ImportError:
    _CELERY_AVAILABLE = False
```
**Effect:** Celery background ingestion stays off on Windows. Normal document upload doesn't need it.

---

## Patch 2 — `model_discovery.py`: `fcntl` shim using `msvcrt`

**Error without it:** every chat model logs `Skipping unavailable LLM model '...': No module named 'fcntl'`, leaving no usable chat model.

Replace line 4 (`import fcntl`) with:
```python
try:
    import fcntl
except ImportError:  # Windows: emulate fcntl.flock with msvcrt
    import msvcrt
    import os as _os

    class _FcntlShim:
        LOCK_EX = 2
        LOCK_NB = 4
        LOCK_UN = 8

        @staticmethod
        def flock(fd, op):
            _os.lseek(fd, 0, _os.SEEK_SET)
            if op & _FcntlShim.LOCK_UN:
                msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
            elif op & _FcntlShim.LOCK_NB:
                try:
                    msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
                except OSError as e:
                    raise BlockingIOError(*e.args) from e
            else:
                msvcrt.locking(fd, msvcrt.LK_LOCK, 1)

    fcntl = _FcntlShim()
```
Lines 129 and 151 (`fcntl.flock(...)`) are unchanged; they now call the shim on Windows. On Linux the real `fcntl` is still used.

---

## Patch 3 — `qdrant_client_builder.py`: two edits

### 3a. Don't crash when the lock file is in use (`clean_lock`)

**Error without it:** `PermissionError: [WinError 32] ... qdrant\.lock`. Linux allows deleting an open file; Windows doesn't.

```python
    @staticmethod
    def clean_lock(db_dir: str) -> None:
        lock_file = os.path.join(db_dir, ".lock")
        if os.path.exists(lock_file):
            try:
                os.remove(lock_file)
            except PermissionError:
                pass  # Windows: lock file is in use; leave it alone
```

### 3b. Use only the URL when a Qdrant server is configured (`build_clients`)

**Error without it:** `ValueError: Only one of <location>, <url>, <host> or <path> should be specified.` once `PGPT_QDRANT_URL` is set, because the default `path` from `settings.yaml` is passed too.

Insert directly above `client = QdrantClient(**config)` (around line 80), at the same indentation:
```python
if config.get("url"):
    config.pop("path", None)
client = QdrantClient(**config)
```
The async client a few lines below uses the same `config`, so it's covered too.

**Why the Qdrant server at all:** in embedded mode PrivateGPT opens the same database folder twice (a sync and an async client). On Linux it gets away with this by deleting the lock file between them; on Windows the second client fails with `Storage folder ... is already accessed by another instance of Qdrant client`. A local Qdrant server avoids the problem entirely.

---

## Patch 4 — `async_chat_engine.py`: accept `id` as well as `tool_id`

**Error without it:** `AttributeError: 'ChoiceDeltaToolCall' object has no attribute 'tool_id'` (line 1228) the first time a model calls the document-search tool.

**Cause:** PrivateGPT merges streamed tool-call pieces by `tool_id`, but the OpenAI library's objects call that field `id`. Package versions were identical on WSL and Windows (`openai 2.34.0`, `llama-index-core 0.14.21`, `llama-index-llms-openai 0.7.7`), so this is a PrivateGPT bug. It never showed up before because `dolphin-llama3` can't call tools.

Before (lines 1224–1229):
```python
                    for tc in existing:
                        if tc.tool_id:
                            by_id[tc.tool_id] = tc
                    for tc in value:
                        if tc.tool_id:
                            by_id[tc.tool_id] = tc
```
After:
```python
                    for tc in existing:
                        tc_id = getattr(tc, "tool_id", None) or getattr(tc, "id", None) or f"index-{getattr(tc, 'index', 0)}"
                        by_id[tc_id] = tc
                    for tc in value:
                        tc_id = getattr(tc, "tool_id", None) or getattr(tc, "id", None) or f"index-{getattr(tc, 'index', 0)}"
                        by_id[tc_id] = tc
```

---

## Not a code edit, but also Windows-only: libmagic

`python-magic` needs the libmagic C library, which Windows doesn't have (`ImportError: failed to find libmagic`). The fix copies `libmagic.dll` and `magic.mgc` from the `python-magic-bin` wheel into `C:\Users\<you>\privateGPT` and points `$env:MAGIC` at `magic.mgc`. Steps are in `02-installation.md`, step 4.3. These files aren't tracked by git, so updates won't remove them.

## Checking all patches are still in place

From `C:\Users\<you>\privateGPT`:
```powershell
Select-String private_gpt\server\ingest\ingest_router.py -Pattern "^from private_gpt.celery.model import Task"
Select-String private_gpt\components\llm\tokenizers\models\model_discovery.py -Pattern "_FcntlShim"
Select-String private_gpt\components\vector_store\qdrant_client_builder.py -Pattern "except PermissionError","config.pop\(`"path`""
Select-String private_gpt\components\engines\chat\async_chat_engine.py -Pattern "getattr\(tc, `"tool_id`""
```
Each command should print at least one matching line.

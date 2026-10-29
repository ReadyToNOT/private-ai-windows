# 07 — Testing Log

Record each test here so changes can be compared over time. Copy the template for each new test.

---

## T1 — Same model, different behavior: Ollama vs PrivateGPT

- **Date:** ~Aug 2026
- **Goal:** Check whether `dolphin-llama3:8b` behaves the same when run directly in Ollama and through PrivateGPT.
- **Setup:** Same prompt sent to `ollama run dolphin-llama3:8b` and to PrivateGPT (default settings).
- **Result:** The answers differed. Inside PrivateGPT the model declined or hedged on some prompts the direct version answered.
- **Explanation:** Both use the same model files. The difference comes from the **system prompt and prompt formatting**. Direct Ollama uses the model's built-in system prompt. PrivateGPT replaces it with its own instructions and adds RAG context.
- **Change:** PrivateGPT **Settings → system prompt**, replaced with the model's own default system prompt.
- **Result after change:** Behavior matched direct Ollama in a new chat.
- **Takeaway:** Much of a model's "personality" comes from the system prompt, not just the weights. The system prompt is the first setting to check when behavior differs between apps.
- **To do:** Record PrivateGPT's original default system prompt here, before my change, for reference.

## T1b — "Are you offline?" self-report

- **Observation:** Asked in PrivateGPT, the model claimed to be cloud-hosted and "a variant of GPT-3."
- **Explanation:** Models don't know where they're running. The answer is a guess based on training data and isn't evidence either way. T2 checks it properly.

---

## Windows rebuild acceptance tests (Oct 28, 2026)

## T7 — GPU is doing the work
- **Date:** Oct 28, 2026
- **Setup:** Windows Ollama; `qwen3.8:latest` (and earlier `dolphin-llama3:8b`).
- **Steps:** Ask a question, run `ollama ps` while it answers.
- **Result:** ✅ `qwen3.8:latest  17 GB  100% GPU  context 32768`. CPU no longer maxed.

## T8 — Retrieval from an uploaded document
- **Date:** Oct 28, 2026
- **Setup:** `qwen3.8:latest`, Qdrant server, document context on. Test file `pgpt-test.txt` with made-up facts (codename BLUE PELICAN, Dr. Ravi Okafor, $42,000), so the model couldn't know them from training.
- **Question:** "What is the project codename, who leads it, and what is the budget?"
- **Result:** ✅ Correct on all three. The model called `semantic_search`; the top chunk scored 0.606 and was cited as ①.
- **Problems found along the way:** dolphin can't use tools (fix: default to qwen3.8); a tool-call bug in PrivateGPT (patch 4).

## T9 — Data survives a restart
- **Date:** Oct 28, 2026
- **Steps:** Stop PrivateGPT, `run-pgpt` again, ask the T8 question without re-uploading.
- **Result:** ✅ Still answered correctly. Test document deleted afterwards.

## T10 — Getting answers to name their source
- **Date:** Oct 28, 2026
- **Problem:** The ① citation badge highlights on hover/click but shows no popup, and the browser console shows no errors.
- **Change:** System prompt (Settings) asking for `[filename]` after each fact.
- **Result:** ❌ The model ran `semantic_search` 3 times in one answer and still didn't show sources clearly. Prompt removed.
- **Takeaway:** Sources are available in the `server_tool_result` dropdown (`"file_name"`). Revisit if PrivateGPT updates its citation UI.

---

## Planned tests

### T2 — True offline test
- Disconnect Wi-Fi/Ethernet → `run-pgpt` (PowerShell) → chat and upload a document.
- Pass if everything works with no network errors in the terminal.
- Also check the terminal for any attempts to reach `api.openai.com` or other outside hosts.

### T3 — RAG accuracy on my own documents
(T8 confirmed retrieval works on one test file; this is the fuller version.)
- Upload this documentation folder.
- Ask 10 questions with known answers (e.g. "What port does PrivateGPT use?", "Why was Ollama moved to Windows?").
- Score each answer: correct / partly correct / wrong / made up. Note whether it cited the source.

### T4 — Model comparison
- Same 10 questions from T3 with the tool-capable models: `qwen3.8`, `gemma4:26b`, `nemotron-3.5-lightning` (dolphin can't search documents).
- Record accuracy, speed (tokens/sec or seconds to answer), and GPU memory (`ollama ps`).

### T5 — GPU vs CPU speed
- Time the same prompt on GPU vs CPU. Qualitative result from Oct 28: WSL Ollama on CPU maxed the 9800X3D on simple prompts; Windows Ollama runs at 100% GPU with the CPU calm. Still worth measuring tokens/sec.

### T6 — Network exposure check
- From a phone on the same Wi-Fi, try `http://<PC-IP>:8001/ui/`, `http://<PC-IP>:6333/collections` and `http://<PC-IP>:11434/api/tags`. PrivateGPT and Qdrant are now bound to `127.0.0.1` and should fail; Ollama depends on whether `OLLAMA_HOST` is still set.
- If either responds, decide whether to restrict the listening address or add firewall rules.

---

## Template

```
## T# — Title
- Date:
- Goal:
- Setup (model, settings, documents):
- Steps:
- Result:
- Explanation:
- Change made (if any):
- Result after change:
- Takeaway / next step:
```

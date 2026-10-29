# 05 — How RAG Works (in this setup)

**Retrieval-Augmented Generation (RAG)**: before the model answers, the app **retrieves** the most relevant passages from my documents and pastes them into the prompt. The model then **generates** an answer from those passages.

The model isn't retrained on my data. It "reads" the relevant pages each time I ask a question. That's why it can use new documents immediately, and why everything can stay on my PC.

## Step 1 — Ingestion (when I upload a document)

```
document.pdf
   │  1. extract text
   ▼
"...long text..."
   │  2. split into chunks (a few hundred words each, slightly overlapping)
   ▼
[chunk 1] [chunk 2] [chunk 3] ...
   │  3. embed each chunk with nomic-embed-text (via Ollama)
   ▼
[0.12, -0.80, ..., 0.33]   ← 768 numbers per chunk = its "meaning"
   │  4. store vector + original text in the vector store
   ▼
Qdrant server (C:\Users\<you>\qdrant\storage, collection pgpt_collection)
```

## Step 2 — Answering (when I ask a question)

```
"What port does PrivateGPT use?"
   │  0. the chat model (qwen3.8) decides to call the semantic_search tool
   │  1. embed the search query with nomic-embed-text
   ▼
question vector
   │  2. Qdrant finds the chunks whose vectors are closest (similarity search, top-k)
   ▼
best 2–5 chunks from my docs
   │  3. build the prompt:
   │       [system prompt] + [retrieved chunks] + [chat history] + [my question]
   ▼
qwen3.8 (via Ollama, on the GPU)
   │  4. generate the answer; each chunk has a citation ID (e.g. [LXRP]) shown as ① in the UI
   ▼
Answer in the Workbench UI
```

## Which component does what

| RAG step | Component here |
|---|---|
| Upload, text extraction, chunking | PrivateGPT |
| Embedding (text → vector) | `nomic-embed-text` in Ollama, via `OPENAI_EMBEDDING_API_BASE` |
| Vector storage and search | **Qdrant** server on `127.0.0.1:6333` |
| Deciding when to search | The chat model, through the `semantic_search` tool (needs a tool-capable model) |
| Prompt assembly and system prompt | PrivateGPT (editable in Settings) |
| Answer generation | Chat model in Ollama, via `OPENAI_API_BASE` |

## Why the answers depend on more than the model

- **System prompt:** PrivateGPT adds its own instructions to every request. Changing them changed the model's behavior a lot (test T1).
- **Retrieval quality:** if the right chunk isn't retrieved, the model can't use it, however good the model is.
- **Context window:** the retrieved chunks, chat history and answer all have to fit inside it. dolphin-llama3:8b has only 8,192 tokens; qwen3.8 has far more room (Ollama loaded it at 32,768).
- **Tool calling:** retrieval only happens if the model calls the search tool, so a model without tool support can't use documents at all.
- **Embedding model:** this decides what counts as "similar." A better embedding model gives better retrieval.

## Ideas to improve it (to test)
- Compare answer quality across the tool-capable models (qwen3.8, gemma4:26b, nemotron-3.5-lightning) on the same documents and questions
- Try a stronger embedding model (e.g. `mxbai-embed-large`, `bge-m3`) and re-ingest
- Adjust the chunk size, overlap and number of retrieved chunks, if PrivateGPT exposes them
- Better source display: the ① citation badge highlights on hover but shows nothing (no console errors). A system prompt asking for `[filename]` citations made qwen3.8 search 3 times per answer, so it was dropped. For now, the source file is in the `server_tool_result` dropdown (`"file_name"`).

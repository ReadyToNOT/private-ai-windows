# 08 — Related: Coding Agents with Local Models

This is a side experiment that came out of the PrivateGPT work. It's **not** part of the RAG pipeline, but it uses the same Windows Ollama server and models. `qwen2.5-coder:7b` is now installed on Windows for this.

## Concept: engine vs. car

- **Model (engine):** model files like `qwen3.8` or `dolphin-llama3`. On its own, a model only predicts text.
- **Agent app (car):** software that gives a model tools such as reading and editing files, running commands, and memory. Examples: Claude Code, OpenCode, Hermes Agent, OpenClaw.

Ollama's `ollama launch <app> --model <model>` sets up one of these apps to use a local model.

| App | Type | Used for |
|---|---|---|
| Claude Code | Terminal coding agent | Editing code across a project and running tests. Built for Anthropic's Claude models |
| OpenCode | Terminal coding agent | Same idea, built around open-model / OpenAI-style tool calling |
| Hermes Agent | General automation agent | Scheduled jobs, web search, shell tasks, persistent memory |
| OpenClaw | Messaging gateway | Chat with a local model from Discord, Telegram and similar apps |

## What I tried

- `ollama launch claude --model qwen3.8`, run inside PyCharm's terminal
- **Result:** Claude Code read files but **didn't make edits**. It kept replying conversationally ("I am ready to assist you...") instead of calling its edit tool.
- **Likely reason:** local general-purpose models often don't produce the structured tool calls the agent expects. Things to try:
  - Coding-tuned models (`qwen2.5-coder:7b`, `qwen3-coder`)
  - Direct commands ("Replace the contents of TEST.py with ...") instead of questions
  - OpenCode instead of Claude Code
- `ollama launch opencode` on Windows failed because the downloaded executable was incompatible. Option: `npm install -g opencode-ai`. (Running it from WSL is no longer an option worth pursuing, since the setup moved off WSL on Oct 28.)

## Status
Not finished. Could become its own tests (T7+) in `07-testing-log.md`.

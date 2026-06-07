# NPC-chat proxy

The little server that lets the cast chat with the player **without ever shipping the API key**. The game
POSTs the player's line here; this server adds your key and calls an LLM, then returns just the reply.
(Mirrors the GodotNPCAI course, upgraded so a public Itch.io build can't leak the key — which providers
like DeepSeek will auto-disable if found exposed.) Zero dependencies — just Node 18+.

**Provider-agnostic:** the game never changes. Point this proxy at whatever you can afford:

| Provider | Cost | `LLM_PROVIDER` | `LLM_URL` | `MODEL` |
|---|---|---|---|---|
| **DeepSeek** (default) | cheap, paid | `openai` | `https://api.deepseek.com/chat/completions` | `deepseek-chat` |
| **Google Gemini** | **free tier** | `openai` | `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` | `gemini-2.0-flash` |
| **Groq** | **free tier**, fast | `openai` | `https://api.groq.com/openai/v1/chat/completions` | `llama-3.3-70b-versatile` |
| **Ollama** (local) | **free**, no key | `openai` | `http://localhost:11434/v1/chat/completions` | `llama3.2` |
| **Claude** | paid | `anthropic` | `https://api.anthropic.com/v1/messages` | `claude-haiku-4-5` |

(Double-check each provider's current endpoint + model names in their docs — they shift occasionally.)

## Test it locally (do this first)

You're on **DeepSeek**, which is the default — so just set your key and run:

```powershell
# PowerShell, from the repo root. Make a key at platform.deepseek.com/api_keys (a fresh one for this).
$env:LLM_API_KEY = "sk-..."
node proxy/server.js
```

You should see `Shanty NPC-chat proxy on :8787  (provider openai, model deepseek-chat, ...)`. The game
already defaults to `http://127.0.0.1:8787/chat`, so run the game and **Chat** with any NPC — it talks for
real. No key lives in the game.

To use a **free** provider instead, set the matching row's env before running, e.g. Gemini:

```powershell
$env:LLM_API_KEY = "AIza..."
$env:LLM_URL     = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
$env:MODEL       = "gemini-2.0-flash"
node proxy/server.js
```

Local Ollama needs no key at all (`ollama serve` running, then set `LLM_URL`/`MODEL` from the table).

## Deploy it for the demo

Any host that runs a Node script works (Render, Railway, Fly.io, a small VPS — free tiers exist):

1. Push this `proxy/` folder (or just `server.js`).
2. Start command: `node server.js`
3. Set env vars on the host: `LLM_API_KEY` (**required**, your key — only ever here), plus the provider
   row's `LLM_URL`/`MODEL` if not DeepSeek. Recommended guards:
   - `SHARED_SECRET` — a random string; if set, the game must send it (`[npc_chat] secret` in
     `user://settings.cfg`). Stops casual drive-by abuse. Not bulletproof — also keep `MAX_TOKENS_CAP` low.
   - `ALLOWED_ORIGIN` — for an HTML5/web Itch build, set to the page origin (CORS).
   - `MAX_TOKENS_CAP` — hard reply-length ceiling (default 400) — your main cost dial.
4. Point the game at it: set `[npc_chat] endpoint = https://your-proxy.example.com/chat` in
   `user://settings.cfg` (and `secret = ...` if you set one).

## Contract (game ↔ proxy)

- **→ proxy:** `POST /chat` `{ "system": "<NPC system prompt>", "messages": [{role,content}...], "max_tokens": 300 }`
- **← proxy:** `{ "reply": "<NPC line>" }` (or `{ "error": "..." }`)

The **model is fixed server-side** and tokens are clamped here, so a tampered client can't pick an
expensive model or run up huge replies.

## Cost notes

DeepSeek is ~10–20× cheaper than Claude; each NPC line is tiny (short system prompt + ~12 turns of capped
history + ~300-token replies). Keep `MAX_TOKENS_CAP` low, the history short (the game already caps it), and
`SHARED_SECRET` on, and a demo's spend stays trivial. Watch your usage on the provider's dashboard during
the playtest.

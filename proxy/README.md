# NPC-chat proxy

The little server that lets the cast chat with the player **without ever shipping the API key**. The game
POSTs the player's line here; this server adds your Anthropic key and calls **Claude Haiku 4.5**, then
returns just the reply. (Mirrors the GodotNPCAI course, upgraded so a public Itch.io build can't leak the
key.) Zero dependencies — just Node 18+.

## Test it locally (do this first)

```powershell
# PowerShell, from the repo root
$env:ANTHROPIC_API_KEY = "sk-ant-..."   # from https://console.anthropic.com
node proxy/server.js
```

You should see `Shanty NPC-chat proxy on :8787`. The game already defaults to `http://127.0.0.1:8787/chat`,
so now run the game and **Chat** with any NPC — it'll talk for real. (No key lives in the game.)

## Deploy it for the demo

Any host that runs a Node script works (Render, Railway, Fly.io, a small VPS — all have free tiers):

1. Push this `proxy/` folder (or just `server.js`) to the host.
2. Start command: `node server.js`
3. Set env vars on the host:
   - `ANTHROPIC_API_KEY` — **required**, your key (only ever lives here).
   - `SHARED_SECRET` — *optional but recommended*: a random string. If set, the game must send it as a
     header. Set the same value in the game (`[npc_chat] secret` in `user://settings.cfg`). Stops casual
     drive-by abuse of your endpoint. (Not bulletproof — a determined user can pull it from the build —
     so also keep `MAX_TOKENS_CAP` low and watch your usage.)
   - `ALLOWED_ORIGIN` — *optional*: if the demo is an **HTML5/web** export on Itch, set this to the page
     origin for CORS (default `*` works but is open).
   - `MAX_TOKENS_CAP` — *optional*: hard ceiling on reply length (default 400) — your main cost dial.
4. Point the game at it: set `[npc_chat] endpoint = https://your-proxy.example.com/chat` in
   `user://settings.cfg`, or change `NpcBrain.DEFAULT_ENDPOINT`.

## What the game sends / gets

- **→ proxy:** `POST /chat` `{ "system": "<NPC system prompt>", "messages": [{role,content}...], "max_tokens": 300 }`
- **← proxy:** `{ "reply": "<NPC line>" }` (or `{ "error": "..." }`)

The **model is fixed server-side** (Haiku 4.5) and tokens are clamped here, so a tampered client can't
pick an expensive model or run up huge replies.

## Cost notes

Haiku 4.5 is the cheapest tier ($1 / $5 per 1M in/out). Each NPC line is tiny (short system prompt +
~12 turns of history capped, ~300-token replies). Keep `MAX_TOKENS_CAP` low, the rolling history short
(the game already caps it), and `SHARED_SECRET` on, and a demo's usage stays trivial. Watch the Anthropic
console during the playtest.

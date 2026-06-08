# Deploy the NPC-chat proxy to Render (one page)

This is how the cast talks for **everyone** — playtesters and the public Itch build — not just you. Once
this is live, every player's game calls your proxy, the proxy holds your key and calls the LLM, and nobody
can extract the key. Every reply runs on **your** bill, so the steps below also cap the cost.

> **Do Step 0 first.** It's the only *unbreakable* protection — everything else is a speed bump on top of it.

---

## Step 0 — Cap the spend at the provider (the hard ceiling) ⚠️

In your **DeepSeek** dashboard (platform.deepseek.com): make a **fresh API key** for this, and **only top up a
small amount** (e.g. $5–$10). Your balance *is* your hard limit — even if every guard below were bypassed,
you can never lose more than you put in. Do not enable auto-recharge.

---

## Step 1 — Get the code on GitHub

Push this repo to GitHub (Render deploys from a repo). The whole `proxy/` folder is all Render needs.

## Step 2 — Create the service on Render

Easiest — **Blueprint** (uses `proxy/render.yaml`):
1. [dashboard.render.com](https://dashboard.render.com) → **New ▸ Blueprint** → connect your repo → **Apply**.
2. It creates a free Web Service running `node server.js` with a `/health` check.

Or **by hand** — **New ▸ Web Service** → connect the repo, then:
- **Root Directory:** `proxy`  ·  **Build:** `npm install`  ·  **Start:** `npm start`  ·  **Health check path:** `/health`  ·  **Plan:** Free

## Step 3 — Set the environment variables (Render ▸ your service ▸ Environment)

| Key | Value |
|---|---|
| `LLM_API_KEY` | your DeepSeek key (`sk-...`) — **required**, lives only here |
| `SHARED_SECRET` | a long random string (e.g. run `openssl rand -hex 24`) |
| `ADMIN_SECRET` | a *different* long random string (gates the kill switch) |
| `DAILY_TOKEN_BUDGET` | `1500000` (≈ a few $/day on DeepSeek; tune to taste) |
| `RATE_LIMIT_RPM` | `15` · `IP_DAILY_CAP` `400` · `MAX_TOKENS_CAP` `400` |

Render sets `PORT` itself — don't add it. Save → it deploys. You'll get a URL like
`https://shivaliva-npc-proxy.onrender.com`.

## Step 4 — Smoke-test it

```bash
curl https://YOUR-APP.onrender.com/health
# → {"ok":true,"enabled":true}

curl -X POST https://YOUR-APP.onrender.com/chat \
  -H "content-type: application/json" -H "x-shanty-key: YOUR_SHARED_SECRET" \
  -d '{"system":"You are Kerr, a gruff smith.","messages":[{"role":"user","content":"hey"}],"max_tokens":60}'
# → {"reply":"..."}
```

## Step 5 — Point the game at it

In **`autoloads/npc_brain.gd`**, set the default endpoint to your Render URL, then export the build:
```gdscript
const DEFAULT_ENDPOINT : String = "https://YOUR-APP.onrender.com/chat"
```
And put the shared secret in the build so the game sends it (per-machine override, no recompile needed):
`user://settings.cfg` → `[npc_chat]` → `secret = "YOUR_SHARED_SECRET"`. *(Or, for testers only, they can set
`endpoint` + `secret` in their own settings.cfg instead of you re-exporting.)*

> The URL and shared-secret **will** be inside the shipped build — that's expected and fine. The *key* never
> is. The secret only stops casual drive-by abuse; the rate-limit + daily budget + Step 0 are the real guards.

---

## Operating it (during a playtest / launch)

- **Watch usage:** `curl https://YOUR-APP.onrender.com/admin/stats -H "x-admin-key: YOUR_ADMIN_SECRET"`
  → `{enabled, tokensToday, tokenBudget, requestsToday, blockedToday, uniqueIpsToday}`. Also: Render **Logs**
  (every chat prints `[chat] ip=… tokens=… day=…/…`) + your DeepSeek dashboard balance.
- **Kill switch** (instantly silence all chat, no redeploy — if you see abuse or a cost spike):
  ```bash
  curl -X POST https://YOUR-APP.onrender.com/admin/disable -H "x-admin-key: YOUR_ADMIN_SECRET"   # off
  curl -X POST https://YOUR-APP.onrender.com/admin/enable  -H "x-admin-key: YOUR_ADMIN_SECRET"   # back on
  ```
  While off, players just see the graceful "AI offline" notice (canned lines) — the game still plays fine.
  The runtime switch resets to ON if Render restarts (a sleep/wake or redeploy). For a **durable** kill, set
  `DISABLED=1` in the service's env vars (it persists across restarts); delete it to turn chat back on.

## The free-tier catch (cold starts)

Render's free plan **sleeps the service after ~15 min idle**; the next request wakes it (~30–50 s). So the
first chat after a quiet spell shows "AI offline" for a moment, then works. Two fixes:
- **Keep it warm (free):** a free *external* uptime pinger (UptimeRobot / cron-job.org) hitting `/health`
  every ~10 min. (Render's own health check does **not** keep a free service awake — only outside traffic does.)
- **Always-on ($7/mo):** upgrade the service to the Starter plan.

## Notes on the guards (layered, honest)

`DAILY_TOKEN_BUDGET` and the rate limits are **in-memory** — they reset if Render restarts the service (incl.
waking from sleep). They stop floods and runaway loops, but the **provider balance from Step 0 is the only
ceiling that can't be reset** — which is why Step 0 is non-negotiable. Per-IP limits key on the *trusted* proxy
hop of `X-Forwarded-For` (`TRUSTED_PROXY_HOPS`, default 1 for Render) so they're hard to spoof — but the
*global* budget + Step 0 still sit behind them as the real guard. (If you deploy behind a different number of
proxies/CDNs, set `TRUSTED_PROXY_HOPS` to match, or per-IP limits get weaker — never looser than the budget.)

**CORS** (`ALLOWED_ORIGIN`) only matters for an **HTML5/web** Itch build — a downloadable **desktop** build
isn't subject to it, so the shared secret + budget are the guard there; leave the default `*` for desktop.

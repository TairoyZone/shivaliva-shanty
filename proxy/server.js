// Shivaliva Shanty — NPC-chat PROXY (zero-dependency Node, 18+).
//
// THE WHY: the game must never ship the API key (a public Itch.io build can be unzipped and the key
// extracted + abused). So the game POSTs the player's message here; THIS server holds the key (an env var)
// and calls the LLM server-side, returning just the reply text. Mirrors the GodotNPCAI course pattern,
// upgraded for safe PUBLIC distribution — every player's chat runs on YOUR key, so this guards the bill.
//
// PUBLIC-SAFE GUARDS (layered — see proxy/DEPLOY.md). Hardened after an adversarial security review:
//   1. SHARED_SECRET     — the game must send x-shanty-key (constant-time compared). Stops casual drive-by.
//   2. Per-IP RATE LIMIT — RATE_LIMIT_RPM/min + IP_DAILY_CAP/day, keyed on the TRUSTED proxy hop of XFF.
//   3. DAILY_TOKEN_BUDGET— a global tokens/day ceiling, RESERVED before each upstream call (race-safe) so
//                          even concurrent / failed / zero-usage calls can't overrun it. Offline until UTC reset.
//   4. KILL SWITCH       — POST /admin/disable (x-admin-key: ADMIN_SECRET) silences chat instantly, no redeploy.
//                          For a DURABLE kill across restarts, set the DISABLED env var (see DEPLOY.md).
//   5. PROVIDER BALANCE   — the HARD backstop: only top up $X on the provider; in-memory counters reset on
//                          restart (Render free tier sleeps), so the provider balance is the true ceiling. Set it.
//
// PROVIDER-AGNOSTIC: the game's contract never changes ({system, messages, max_tokens} -> {reply}); this
// proxy translates to whichever LLM you can afford (DeepSeek default; Gemini/Groq free tiers; Claude; Ollama).
// See proxy/README.md for per-provider env blocks.
//
// RUN LOCALLY (dev):  $env:LLM_API_KEY="sk-..."; node proxy/server.js   (game defaults to http://127.0.0.1:8787/chat)
//
// ENV (all optional except LLM_API_KEY in production):
//   LLM_PROVIDER "openai"(default)|"anthropic" · LLM_URL · LLM_API_KEY · MODEL · TEMPERATURE(0.8)
//   SHARED_SECRET / ADMIN_SECRET (set both in production) · ALLOWED_ORIGIN (CORS; moot for desktop builds)
//   MAX_TOKENS_CAP(400) · RATE_LIMIT_RPM(15) · IP_DAILY_CAP(400) · DAILY_TOKEN_BUDGET(1_500_000)
//   TRUSTED_PROXY_HOPS(1 — Render) · MAX_TRACKED_IPS(50000) · DISABLED(start OFF) · PORT(8787)

const http = require("node:http");
const crypto = require("node:crypto");

const PROVIDER = (process.env.LLM_PROVIDER || "openai").toLowerCase();
const DEFAULT_URL = PROVIDER === "anthropic"
  ? "https://api.anthropic.com/v1/messages"
  : "https://api.deepseek.com/chat/completions";
const LLM_URL = process.env.LLM_URL || DEFAULT_URL;
const API_KEY = process.env.LLM_API_KEY || process.env.ANTHROPIC_API_KEY || process.env.DEEPSEEK_API_KEY || "";
const MODEL = process.env.MODEL || (PROVIDER === "anthropic" ? "claude-haiku-4-5" : "deepseek-chat");
const TEMPERATURE = parseFloat(process.env.TEMPERATURE || "0.8");
const SHARED_SECRET = process.env.SHARED_SECRET || "";
const ADMIN_SECRET = process.env.ADMIN_SECRET || "";
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || "*";
const MAX_TOKENS_CAP = pint(process.env.MAX_TOKENS_CAP, 400);
const RATE_LIMIT_RPM = pint(process.env.RATE_LIMIT_RPM, 15);
const IP_DAILY_CAP = pint(process.env.IP_DAILY_CAP, 400);
const DAILY_TOKEN_BUDGET = pint(process.env.DAILY_TOKEN_BUDGET, 1500000);
const TRUSTED_PROXY_HOPS = pint(process.env.TRUSTED_PROXY_HOPS, 1);   // Render = 1 hop; the real client is that many from the right
const MAX_TRACKED_IPS = pint(process.env.MAX_TRACKED_IPS, 50000);
const PORT = pint(process.env.PORT, 8787);
const DISABLED_AT_BOOT = /^(1|true|yes|on)$/i.test(process.env.DISABLED || "");

const IS_LOCAL = /localhost|127\.0\.0\.1/.test(LLM_URL);   // local Ollama needs no key

function pint(v, d) { const n = parseInt(v, 10); return Number.isFinite(n) && n > 0 ? n : d; }

// Constant-time secret compare (avoids a timing oracle on the header). Unset secret => never matches.
function secretOk(provided, expected) {
  if (!expected) return false;
  const a = Buffer.from(String(provided || ""));
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// --- runtime state (in-memory; resets on restart — the provider balance is the true ceiling) ----------
let enabled = !DISABLED_AT_BOOT;
let dayStamp = utcDay();
let tokensToday = 0;
let requestsToday = 0;
let blockedToday = 0;
const ipMinute = new Map();   // ip -> { start, count }  per-minute rate window
const ipDay = new Map();      // ip -> count             per-UTC-day request count

function utcDay() { return new Date().toISOString().slice(0, 10); }

function rollDayIfNeeded() {
  const d = utcDay();
  if (d !== dayStamp) { dayStamp = d; tokensToday = 0; requestsToday = 0; blockedToday = 0; ipDay.clear(); }
}

function normalizeIp(s) {
  let ip = String(s || "").trim().toLowerCase().replace(/^\[|\]$/g, "").replace(/%[^%]*$/, "");
  if (ip.startsWith("::ffff:")) ip = ip.slice(7);   // collapse IPv4-mapped IPv6
  return ip;
}
function validIp(ip) { return ip.length > 0 && ip.length <= 45 && (/^[0-9.]+$/.test(ip) || /^[0-9a-f:]+$/.test(ip)); }

// Trusted client IP. Behind Render the real client is the hop TRUSTED_PROXY_HOPS from the RIGHT of XFF (the
// proxy appends it); the leftmost entries are attacker-controlled. Validated + normalized so it's safe to
// key on AND safe to log. Per-IP limits are a flood speed-bump; the global budget + provider balance are the
// wallet guard (a client could still spoof if TRUSTED_PROXY_HOPS is misconfigured).
function clientIp(req) {
  const xff = req.headers["x-forwarded-for"];
  if (xff) {
    const parts = String(xff).split(",").map((s) => s.trim()).filter(Boolean);
    if (parts.length) {
      const cand = normalizeIp(parts[Math.max(0, parts.length - TRUSTED_PROXY_HOPS)]);
      if (validIp(cand)) return cand;
    }
  }
  const sock = normalizeIp((req.socket && req.socket.remoteAddress) || "");
  return validIp(sock) ? sock : "unknown";
}

// Per-IP fixed-minute-window rate limit. Won't grow the Map past MAX_TRACKED_IPS (the global budget backstops).
function allowRate(ip) {
  const now = Date.now();
  const w = ipMinute.get(ip);
  if (w && now - w.start < 60000) {
    if (w.count >= RATE_LIMIT_RPM) return false;
    w.count++;
    return true;
  }
  if (!w && ipMinute.size >= MAX_TRACKED_IPS) return true;   // map full of real clients — don't grow
  ipMinute.set(ip, { start: now, count: 1 });
  return true;
}

// Rough token estimate when the upstream doesn't report usage (chars/4 + the capped reply).
function estimateTokens(system, messages, maxTokens) {
  let chars = system.length;
  for (const m of messages) chars += (m && typeof m.content === "string" ? m.content.length : 0);
  return Math.ceil(chars / 4) + maxTokens;
}

// Sweep stale rate-window entries so the Map can't grow unbounded.
setInterval(() => {
  const now = Date.now();
  for (const [ip, w] of ipMinute) if (now - w.start >= 120000) ipMinute.delete(ip);
}, 120000).unref();

function cors(res) {
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Headers", "content-type, x-shanty-key");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  // A cross-origin-ISOLATED page (itch's "SharedArrayBuffer support" sets COEP: require-corp, needed for the
  // threaded Godot web build) blocks every cross-origin response that doesn't explicitly opt in. Without this
  // header the WEB build's chat fetch is dropped by the browser → "AI offline" even though the proxy is up.
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
}
function sendJson(res, code, obj, extra) {
  if (res.headersSent || res.writableEnded) return;
  cors(res);
  res.writeHead(code, Object.assign({ "content-type": "application/json" }, extra || {}));
  res.end(JSON.stringify(obj));
}

// Build the upstream request + a reply/usage extractor for the active provider. Same game contract either way.
function buildUpstream(system, messages, maxTokens) {
  if (PROVIDER === "anthropic") {
    return {
      headers: { "content-type": "application/json", "x-api-key": API_KEY, "anthropic-version": "2023-06-01" },
      body: { model: MODEL, max_tokens: maxTokens, system: system, messages: messages },
      extract: (d) => {
        const b = Array.isArray(d.content) ? d.content.find((x) => x.type === "text") : null;
        return b ? b.text : "";
      },
      usage: (d) => (d.usage ? (d.usage.input_tokens || 0) + (d.usage.output_tokens || 0) : 0),
    };
  }
  // openai-compatible (DeepSeek / Gemini / Groq / Ollama / OpenAI): system becomes the first message.
  const headers = { "content-type": "application/json" };
  if (API_KEY) headers["authorization"] = "Bearer " + API_KEY;
  const oaiMessages = system ? [{ role: "system", content: system }, ...messages] : messages;
  return {
    headers,
    body: { model: MODEL, messages: oaiMessages, max_tokens: maxTokens, temperature: TEMPERATURE, stream: false },
    extract: (d) => {
      const c = d.choices && d.choices[0] && d.choices[0].message ? d.choices[0].message.content : "";
      return typeof c === "string" ? c : "";
    },
    usage: (d) => (d.usage && d.usage.total_tokens ? d.usage.total_tokens : 0),
  };
}

const server = http.createServer((req, res) => {
  req.on("error", () => {});   // swallow client aborts (mid-upload resets etc.)
  if (req.method === "OPTIONS") { cors(res); res.writeHead(204); res.end(); return; }

  const path = String(req.url || "").split("?")[0];
  const ip = clientIp(req);

  // Health (Render health check + an external keep-alive ping). `enabled` lets the keep-alive ping double as a
  // kill-switch readout; no other internal state leaked.
  if (req.method === "GET" && (path === "/health" || path === "/")) return sendJson(res, 200, { ok: true, enabled });

  // Admin (kill switch + live stats) — constant-time-gated by ADMIN_SECRET. With no ADMIN_SECRET, /admin is closed.
  if (path.startsWith("/admin")) {
    if (!secretOk(req.headers["x-admin-key"], ADMIN_SECRET)) return sendJson(res, 401, { error: "admin auth" });
    rollDayIfNeeded();
    if (req.method === "POST" && path === "/admin/disable") { enabled = false; return sendJson(res, 200, { enabled }); }
    if (req.method === "POST" && path === "/admin/enable") { enabled = true; return sendJson(res, 200, { enabled }); }
    if (req.method === "GET" && path === "/admin/stats") {
      return sendJson(res, 200, {
        enabled, day: dayStamp, tokensToday, tokenBudget: DAILY_TOKEN_BUDGET,
        requestsToday, blockedToday, uniqueIpsToday: ipDay.size,
      });
    }
    return sendJson(res, 404, { error: "admin route" });
  }

  if (req.method !== "POST" || path !== "/chat") return sendJson(res, 404, { error: "POST /chat only" });
  if (!API_KEY && !IS_LOCAL) return sendJson(res, 500, { error: "server missing LLM_API_KEY" });
  if (!enabled) { blockedToday++; return sendJson(res, 503, { error: "chat temporarily disabled" }); }
  if (SHARED_SECRET && !secretOk(req.headers["x-shanty-key"], SHARED_SECRET)) {
    return sendJson(res, 401, { error: "bad or missing x-shanty-key" });
  }

  rollDayIfNeeded();
  if (tokensToday >= DAILY_TOKEN_BUDGET) { blockedToday++; return sendJson(res, 503, { error: "daily budget reached" }); }
  if (!allowRate(ip)) { blockedToday++; return sendJson(res, 429, { error: "rate limited" }, { "retry-after": "60" }); }
  if ((ipDay.get(ip) || 0) >= IP_DAILY_CAP) { blockedToday++; return sendJson(res, 429, { error: "daily per-ip cap" }, { "retry-after": "3600" }); }

  let raw = "";
  let tooBig = false;
  req.on("data", (chunk) => {
    if (tooBig) return;
    raw += chunk;
    if (raw.length > 64 * 1024) { tooBig = true; sendJson(res, 413, { error: "body too large" }); req.destroy(); }
  });
  req.on("end", async () => {
    if (tooBig) return;
    let payload;
    try { payload = JSON.parse(raw); } catch { return sendJson(res, 400, { error: "bad json" }); }

    const system = typeof payload.system === "string" ? payload.system : "";
    const messages = Array.isArray(payload.messages) ? payload.messages : [];
    if (messages.length === 0) return sendJson(res, 400, { error: "no messages" });
    if (messages.length > 40) return sendJson(res, 400, { error: "too many messages" });
    if (!messages.every((m) => m && typeof m.content === "string")) return sendJson(res, 400, { error: "message content must be a string" });
    const maxTokens = Math.min(pint(payload.max_tokens, 300), MAX_TOKENS_CAP);

    // RESERVE the pessimistic cost BEFORE the await, so concurrent / failed / zero-usage calls can't race
    // past the ceiling (reconcile UP to the real usage on success; never refund — fail-closed on the wallet).
    const reserve = estimateTokens(system, messages, maxTokens);
    if (tokensToday + reserve > DAILY_TOKEN_BUDGET) { blockedToday++; return sendJson(res, 503, { error: "daily budget reached" }); }
    tokensToday += reserve;
    requestsToday++;
    if (ipDay.size < MAX_TRACKED_IPS || ipDay.has(ip)) ipDay.set(ip, (ipDay.get(ip) || 0) + 1);

    const up = buildUpstream(system, messages, maxTokens);
    try {
      const upstream = await fetch(LLM_URL, { method: "POST", headers: up.headers, body: JSON.stringify(up.body) });
      const data = await upstream.json();
      if (!upstream.ok) {
        console.error("LLM error", upstream.status, data && (data.error || data));
        return sendJson(res, 502, { error: "upstream " + upstream.status });   // reserve stands (fail-closed)
      }
      const reported = up.usage(data) || 0;
      if (reported > reserve) tokensToday += reported - reserve;   // reconcile upward only
      console.log(`[chat] ip=${ip} tok=${Math.max(reported, reserve)} day=${tokensToday}/${DAILY_TOKEN_BUDGET} reqs=${requestsToday}`);
      return sendJson(res, 200, { reply: (up.extract(data) || "").trim() });
    } catch (e) {
      console.error("proxy fetch failed", e && e.message);
      return sendJson(res, 502, { error: "proxy fetch failed" });   // reserve stands (fail-closed)
    }
  });
});

// A malformed/garbage connection must never take the server down.
server.on("clientError", (_err, socket) => { try { socket.destroy(); } catch {} });
process.on("uncaughtException", (e) => console.error("uncaughtException", e && e.message));
process.on("unhandledRejection", (e) => console.error("unhandledRejection", e && (e.message || e)));

server.listen(PORT, () => {
  console.log(`Shanty NPC-chat proxy on :${PORT}  (provider ${PROVIDER}, model ${MODEL}, `
    + `secret ${SHARED_SECRET ? "on" : "OFF"}, admin ${ADMIN_SECRET ? "on" : "OFF"}, `
    + `budget ${DAILY_TOKEN_BUDGET} tok/day, ${RATE_LIMIT_RPM}/min/ip, start ${enabled ? "enabled" : "DISABLED"})`);
});

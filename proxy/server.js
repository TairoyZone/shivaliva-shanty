// Shivaliva Shanty — NPC-chat PROXY (zero-dependency Node, 18+).
//
// THE WHY: the game must never ship the Anthropic API key (a public Itch.io build can be unzipped and
// the key extracted + abused). So the game POSTs the player's message here; THIS server holds the key
// (in an env var) and calls Claude server-side, returning just the reply text. Mirrors the GodotNPCAI
// course pattern, upgraded for safe public distribution. The unique hook — keep it cheap + locked down.
//
// RUN LOCALLY (dev — test the in-game chat right now, no key in the game):
//   1. Get an Anthropic key: https://console.anthropic.com
//   2. PowerShell:  $env:ANTHROPIC_API_KEY = "sk-ant-..."; node proxy/server.js
//   3. The game's default endpoint (http://127.0.0.1:8787/chat) already points here.
//
// DEPLOY (for the demo): drop this on any free host that runs Node (Render / Railway / Fly / a small
// VPS), set ANTHROPIC_API_KEY (+ optionally SHARED_SECRET, ALLOWED_ORIGIN), and point the game's
// endpoint at the deployed URL (set [npc_chat] endpoint in user://settings.cfg, or NpcBrain.endpoint).
//
// SECURITY / COST GUARDS (tune for your demo):
//   - ANTHROPIC_API_KEY   (required)  the key, only ever here
//   - SHARED_SECRET       (optional)  if set, requests must send  x-shanty-key: <secret>  (kept in the
//                                     game build; not bulletproof, but stops trivial drive-by abuse)
//   - ALLOWED_ORIGIN      (optional)  CORS allow-origin (e.g. https://itch.io build host); default "*"
//   - MODEL               (optional)  default claude-haiku-4-5 (cheapest/fastest tier)
//   - MAX_TOKENS_CAP      (optional)  hard ceiling on reply length (default 400) — the server clamps
//   - PORT                (optional)  default 8787
//
// The client sends { system, messages, max_tokens }. The MODEL + key + ceilings are decided HERE so a
// tampered client can't run up cost. Returns { reply } on success, { error } otherwise.

const http = require("node:http");

const API_KEY = process.env.ANTHROPIC_API_KEY || "";
const SHARED_SECRET = process.env.SHARED_SECRET || "";
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || "*";
const MODEL = process.env.MODEL || "claude-haiku-4-5";
const MAX_TOKENS_CAP = parseInt(process.env.MAX_TOKENS_CAP || "400", 10);
const PORT = parseInt(process.env.PORT || "8787", 10);

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";

function cors(res) {
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Headers", "content-type, x-shanty-key");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
}

function sendJson(res, code, obj) {
  cors(res);
  res.writeHead(code, { "content-type": "application/json" });
  res.end(JSON.stringify(obj));
}

const server = http.createServer((req, res) => {
  if (req.method === "OPTIONS") { cors(res); res.writeHead(204); res.end(); return; }
  if (req.method !== "POST" || !req.url.startsWith("/chat")) {
    return sendJson(res, 404, { error: "POST /chat only" });
  }
  if (!API_KEY) return sendJson(res, 500, { error: "server missing ANTHROPIC_API_KEY" });
  if (SHARED_SECRET && req.headers["x-shanty-key"] !== SHARED_SECRET) {
    return sendJson(res, 401, { error: "bad or missing x-shanty-key" });
  }

  let raw = "";
  let tooBig = false;
  req.on("data", (chunk) => {
    raw += chunk;
    if (raw.length > 64 * 1024) { tooBig = true; req.destroy(); }   // cap inbound body (abuse guard)
  });
  req.on("end", async () => {
    if (tooBig) return;
    let payload;
    try { payload = JSON.parse(raw); } catch { return sendJson(res, 400, { error: "bad json" }); }

    const system = typeof payload.system === "string" ? payload.system : "";
    const messages = Array.isArray(payload.messages) ? payload.messages : [];
    if (messages.length === 0) return sendJson(res, 400, { error: "no messages" });
    // The CLIENT never picks the model; the server caps tokens. Keep cost predictable.
    const maxTokens = Math.min(parseInt(payload.max_tokens || 300, 10) || 300, MAX_TOKENS_CAP);

    try {
      const upstream = await fetch(ANTHROPIC_URL, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({ model: MODEL, max_tokens: maxTokens, system, messages }),
      });
      const data = await upstream.json();
      if (!upstream.ok) {
        console.error("Claude error", upstream.status, data && data.error);
        return sendJson(res, 502, { error: "upstream " + upstream.status });
      }
      const block = Array.isArray(data.content) ? data.content.find((b) => b.type === "text") : null;
      const reply = block ? block.text : "";
      return sendJson(res, 200, { reply });
    } catch (e) {
      console.error("proxy fetch failed", e);
      return sendJson(res, 502, { error: "proxy fetch failed" });
    }
  });
});

server.listen(PORT, () => {
  console.log(`Shanty NPC-chat proxy on :${PORT}  (model ${MODEL}, secret ${SHARED_SECRET ? "on" : "off"})`);
});

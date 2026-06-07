// Shivaliva Shanty — NPC-chat PROXY (zero-dependency Node, 18+).
//
// THE WHY: the game must never ship the API key (a public Itch.io build can be unzipped and the key
// extracted + abused). So the game POSTs the player's message here; THIS server holds the key (an env var)
// and calls the LLM server-side, returning just the reply text. Mirrors the GodotNPCAI course pattern,
// upgraded for safe public distribution.
//
// PROVIDER-AGNOSTIC: the game's contract never changes ({system, messages, max_tokens} -> {reply}); this
// proxy translates to whichever LLM you can afford. Two modes:
//   - "openai"    : any OpenAI-compatible API — DeepSeek (cheap), Google Gemini (FREE tier), Groq (FREE),
//                   OpenRouter, Ollama (LOCAL, free, no key), or OpenAI itself.
//   - "anthropic" : Claude (x-api-key + system param).
// Pick by env (see proxy/README.md for copy-paste blocks). Default = DeepSeek (OpenAI-compatible).
//
// RUN LOCALLY (dev — test the in-game chat now, no key in the game):
//   PowerShell, from repo root:
//     $env:LLM_API_KEY = "sk-..."        # your DeepSeek / Gemini / Groq key (omit for local Ollama)
//     node proxy/server.js               # the game defaults to http://127.0.0.1:8787/chat
//
// ENV:
//   LLM_PROVIDER   "openai" (default) | "anthropic"
//   LLM_URL        full chat endpoint. Default https://api.deepseek.com/chat/completions
//                  (Gemini: https://generativelanguage.googleapis.com/v1beta/openai/chat/completions ·
//                   Groq:   https://api.groq.com/openai/v1/chat/completions ·
//                   Ollama: http://localhost:11434/v1/chat/completions ·
//                   Claude: https://api.anthropic.com/v1/messages  with LLM_PROVIDER=anthropic)
//   LLM_API_KEY    your key (falls back to ANTHROPIC_API_KEY / DEEPSEEK_API_KEY). Optional for localhost.
//   MODEL          default deepseek-chat (Gemini: gemini-2.0-flash · Groq: llama-3.3-70b-versatile ·
//                  Ollama: llama3.2 · Claude: claude-haiku-4-5)
//   TEMPERATURE    default 0.8 (livelier NPCs; openai mode only)
//   SHARED_SECRET  optional — if set, the game must send  x-shanty-key: <secret>  (abuse guard)
//   ALLOWED_ORIGIN optional CORS origin (default "*"; set to your itch build origin for an HTML5 export)
//   MAX_TOKENS_CAP optional hard ceiling on reply length (default 400) — your main cost dial
//   PORT           default 8787

const http = require("node:http");

const PROVIDER = (process.env.LLM_PROVIDER || "openai").toLowerCase();
const DEFAULT_URL = PROVIDER === "anthropic"
  ? "https://api.anthropic.com/v1/messages"
  : "https://api.deepseek.com/chat/completions";
const LLM_URL = process.env.LLM_URL || DEFAULT_URL;
const API_KEY = process.env.LLM_API_KEY || process.env.ANTHROPIC_API_KEY || process.env.DEEPSEEK_API_KEY || "";
const MODEL = process.env.MODEL || (PROVIDER === "anthropic" ? "claude-haiku-4-5" : "deepseek-chat");
const TEMPERATURE = parseFloat(process.env.TEMPERATURE || "0.8");
const SHARED_SECRET = process.env.SHARED_SECRET || "";
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || "*";
const MAX_TOKENS_CAP = parseInt(process.env.MAX_TOKENS_CAP || "400", 10);
const PORT = parseInt(process.env.PORT || "8787", 10);

const IS_LOCAL = /localhost|127\.0\.0\.1/.test(LLM_URL);   // local Ollama needs no key

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

// Build the upstream request + a reply-extractor for the active provider. Same game contract either way.
function buildUpstream(system, messages, maxTokens) {
  if (PROVIDER === "anthropic") {
    return {
      headers: { "content-type": "application/json", "x-api-key": API_KEY, "anthropic-version": "2023-06-01" },
      body: { model: MODEL, max_tokens: maxTokens, system: system, messages: messages },
      extract: (d) => {
        const b = Array.isArray(d.content) ? d.content.find((x) => x.type === "text") : null;
        return b ? b.text : "";
      },
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
  };
}

const server = http.createServer((req, res) => {
  if (req.method === "OPTIONS") { cors(res); res.writeHead(204); res.end(); return; }
  if (req.method !== "POST" || !req.url.startsWith("/chat")) {
    return sendJson(res, 404, { error: "POST /chat only" });
  }
  if (!API_KEY && !IS_LOCAL) return sendJson(res, 500, { error: "server missing LLM_API_KEY" });
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
    const maxTokens = Math.min(parseInt(payload.max_tokens || 300, 10) || 300, MAX_TOKENS_CAP);

    const up = buildUpstream(system, messages, maxTokens);
    try {
      const upstream = await fetch(LLM_URL, {
        method: "POST",
        headers: up.headers,
        body: JSON.stringify(up.body),
      });
      const data = await upstream.json();
      if (!upstream.ok) {
        console.error("LLM error", upstream.status, data && (data.error || data));
        return sendJson(res, 502, { error: "upstream " + upstream.status });
      }
      const reply = (up.extract(data) || "").trim();
      return sendJson(res, 200, { reply });
    } catch (e) {
      console.error("proxy fetch failed", e);
      return sendJson(res, 502, { error: "proxy fetch failed" });
    }
  });
});

server.listen(PORT, () => {
  console.log(`Shanty NPC-chat proxy on :${PORT}  (provider ${PROVIDER}, model ${MODEL}, secret ${SHARED_SECRET ? "on" : "off"})`);
});

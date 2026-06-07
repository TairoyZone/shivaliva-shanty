## NpcBrain — the live NPC-CHAT brain (THE unique hook). The player talks freely to a cast member and the
## NPC answers IN CHARACTER via Claude (Haiku 4.5), driven by that NPC's [NpcPersonality] chat fields. The
## game NEVER holds the API key: it POSTs to a small PROXY you host (see proxy/server.js), which adds the
## key + calls Claude server-side. Mirrors the GodotNPCAI course's GameManager pattern, upgraded for safe
## public distribution. Maintains a short rolling history per conversation; falls back to canned lines on
## any error (caller decides how). Autoloaded (project.godot) so any scene can open a chat.
##
## Foundation for richer AI later (memory, affinity-aware mood, tool-use). Keep replies SHORT + cheap.
extends Node


## The proxy endpoint. Default = a LOCAL proxy you run for dev (proxy/server.js, no key in the game);
## point it at your deployed proxy for the public demo. Override at runtime without recompiling via
## user://settings.cfg: [npc_chat] endpoint="https://..."  (and optional secret="...").
const DEFAULT_ENDPOINT : String = "http://127.0.0.1:8787/chat"
const REPLY_MAX_TOKENS : int = 300        # short, snappy NPC lines (cheap + low latency; proxy also caps)
const HISTORY_MESSAGES : int = 24         # rolling cap (~12 exchanges) sent each call — a cost guard
const REQUEST_TIMEOUT : float = 20.0

## Global canon + behaviour guardrails, prepended to every NPC's system prompt. Keeps replies in-world,
## in-character, short, and free of AI/real-world leakage. (Sky-canon: floating islands, THE STARDUST.)
const WORLD_RULES : String = (
	"You are a character in 'Shivaliva Shanty', a cozy retro adventure set among FLOATING SKY-ISLANDS — "
	+ "sky-pirates and skyfarers, NOT sailors on water. Far below the islands lies THE STARDUST, a "
	+ "bottomless abyss. Stay fully in character at all times. NEVER mention being an AI, a model, or "
	+ "anything from the real world, and never break the fourth wall. Keep replies SHORT and spoken — 1 to "
	+ "3 sentences, no narration, no asterisks, no markdown, no emoji. Speak naturally to the traveller "
	+ "before you, and don't invent major world events that would contradict a simple island life.")

signal npc_replied(text: String)     # a reply came back (also appended to history)
signal chat_failed(reason: String)   # the request failed — caller should fall back to canned lines
signal thinking_started               # a request went out — show a "…" / typing state

var endpoint : String = DEFAULT_ENDPOINT
var _secret : String = ""              # optional x-shanty-key header (matches the proxy's SHARED_SECRET)
var _http : HTTPRequest
var _persona : NpcPersonality = null
var _messages : Array = []             # [{role, content}] rolling history for the active conversation
var _busy : bool = false


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS   # chat panel pauses the tree; the request must still complete
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_config()


# Endpoint + secret are overridable from user://settings.cfg so the proxy URL can change per build / per
# tester without recompiling (the deploy step just writes the URL there). Defaults work for the local proxy.
func _load_config() -> void:

	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	endpoint = String(cfg.get_value("npc_chat", "endpoint", DEFAULT_ENDPOINT))
	_secret = String(cfg.get_value("npc_chat", "secret", ""))


## True while a request is in flight (the panel disables input). One conversation at a time.
func is_busy() -> bool:

	return _busy


## Begin a fresh conversation with [param persona] (an [NpcPersonality]). Clears prior history.
func enter_chat(persona: NpcPersonality) -> void:

	_persona = persona
	_messages = []


func end_chat() -> void:

	_persona = null
	_messages = []
	# Don't clear _busy — an in-flight reply still resolves harmlessly (guarded on emit).


## Ask the NPC for an opening greeting (a stage-direction first turn, so Claude leads in character).
func request_opening() -> void:

	if _persona == null or _busy:
		return
	_messages.append({"role": "user",
		"content": "(A traveller walks up to you.) Greet them in character, in a sentence or two."})
	_post()


## Send the player's line and ask for a reply.
func send(player_text: String) -> void:

	if _persona == null or _busy:
		return
	var text : String = player_text.strip_edges()
	if text.is_empty():
		return
	_messages.append({"role": "user", "content": text})
	_post()


# Build the system prompt from the persona's chat fields + the world rules, then POST to the proxy.
func _post() -> void:

	_trim_history()
	_busy = true
	thinking_started.emit()
	var body : String = JSON.stringify({
		"system": _system_prompt(),
		"messages": _messages,
		"max_tokens": REPLY_MAX_TOKENS,
	})
	var headers : PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if not _secret.is_empty():
		headers.append("x-shanty-key: " + _secret)
	var err : int = _http.request(endpoint, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_busy = false
		chat_failed.emit("request error %d (is the proxy running at %s?)" % [err, endpoint])


# Compose the per-NPC system prompt — the part you tweak via the .tres chat fields. Empty fields are
# skipped, so a half-filled persona still works.
func _system_prompt() -> String:

	if _persona == null:
		return WORLD_RULES
	var parts : PackedStringArray = PackedStringArray([WORLD_RULES])
	var who : String = "You are %s." % _persona.npc_name
	if not _persona.chat_appearance.is_empty():
		who += " " + _persona.chat_appearance
	if not _persona.chat_persona.is_empty():
		who += " " + _persona.chat_persona
	parts.append(who)
	if not _persona.chat_locale.is_empty():
		parts.append("You are at %s." % _persona.chat_locale)
	if not _persona.chat_secret.is_empty():
		parts.append("A secret you hold (do NOT volunteer it; only hint at it, or reveal it, if the "
			+ "player pointedly digs for it): " + _persona.chat_secret)
	return "\n\n".join(parts)


# Keep the rolling history bounded (cost guard). Trim from the front, then ensure it still starts on a
# 'user' turn (Claude requires the first message to be the user).
func _trim_history() -> void:

	if _messages.size() > HISTORY_MESSAGES:
		_messages = _messages.slice(_messages.size() - HISTORY_MESSAGES)
	while not _messages.is_empty() and String(_messages[0].get("role", "")) != "user":
		_messages.remove_at(0)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:

	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		chat_failed.emit("network result %d (proxy unreachable?)" % result)
		return
	if response_code != 200:
		chat_failed.emit("proxy returned %d" % response_code)
		return
	var json : JSON = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		chat_failed.emit("bad response")
		return
	var data : Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY or not data.has("reply"):
		chat_failed.emit("no reply in response")
		return
	var reply : String = String(data["reply"]).strip_edges()
	if reply.is_empty():
		chat_failed.emit("empty reply")
		return
	_messages.append({"role": "assistant", "content": reply})
	npc_replied.emit(reply)

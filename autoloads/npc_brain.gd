## NpcBrain — the live NPC-CHAT brain (THE unique hook). The player talks freely to a cast member and the
## NPC answers IN CHARACTER via an LLM (DeepSeek by default — the PROXY picks the provider), driven by that
## NPC's [NpcPersonality] chat fields. The game NEVER holds the API key: it POSTs to a small PROXY you host
## (see proxy/server.js), which adds the key + calls the LLM server-side. Mirrors the GodotNPCAI course's
## GameManager pattern, upgraded for safe public distribution. Maintains a short rolling history per
## conversation; falls back to canned lines on any error (caller decides how). Autoloaded so any scene can chat.
##
## Foundation for richer AI later (memory, affinity-aware mood, tool-use). Keep replies SHORT + cheap.
extends Node


## The proxy endpoint. Default = a LOCAL proxy you run for dev (proxy/server.js, no key in the game);
## point it at your deployed proxy for the public demo. Override at runtime without recompiling via
## user://settings.cfg: [npc_chat] endpoint="https://..."  (and optional secret="...").
const DEFAULT_ENDPOINT : String = "http://127.0.0.1:8787/chat"
## DEV-DIRECT (no terminal): if a dev key is found — user://settings.cfg [npc_chat] dev_api_key, else the
## SHANTY_NPC_KEY environment variable — the game calls this OpenAI-compatible LLM (DeepSeek) DIRECTLY with
## that key, skipping the proxy. Neither source ships: user:// is per-machine + not bundled in an export,
## and an env var lives in YOUR OS only. ⚠️ For the PUBLIC demo leave both blank — the build must never
## carry a key; that path uses the proxy. (A determined player could also drop their OWN key here = BYOK.)
const DEV_DIRECT_URL : String = "https://api.deepseek.com/chat/completions"
const DEV_DIRECT_MODEL : String = "deepseek-chat"
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

var ai_enabled : bool = true           # Options toggle — when off, "Chat" falls back to a canned line
var endpoint : String = DEFAULT_ENDPOINT
var _secret : String = ""              # optional x-shanty-key header (matches the proxy's SHARED_SECRET)
var _dev_key : String = ""             # DEV-ONLY direct key (settings.cfg or SHANTY_NPC_KEY env) — blank = use the proxy
var _dev_url : String = DEV_DIRECT_URL
var _dev_model : String = DEV_DIRECT_MODEL
var _using_direct : bool = false       # which path the in-flight request used (decides how the reply is parsed)
var _http : HTTPRequest
var _persona : NpcPersonality = null
var _messages : Array = []             # [{role, content}] rolling history for the active conversation
var _busy : bool = false
var _offline_warned : bool = false   # one-shot "AI offline" notice so a transport outage never masquerades as dumb canned replies


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
	ai_enabled = bool(cfg.get_value("npc_chat", "enabled", true))
	endpoint = String(cfg.get_value("npc_chat", "endpoint", DEFAULT_ENDPOINT))
	_secret = String(cfg.get_value("npc_chat", "secret", ""))
	# DEV-DIRECT key: settings.cfg first, else the SHANTY_NPC_KEY env var (set it once, no terminal). Blank
	# on a player's machine -> the proxy path. See DEV_DIRECT_URL above.
	_dev_key = String(cfg.get_value("npc_chat", "dev_api_key", ""))
	if _dev_key.is_empty():
		_dev_key = OS.get_environment("SHANTY_NPC_KEY")
	_dev_url = String(cfg.get_value("npc_chat", "dev_url", DEV_DIRECT_URL))
	_dev_model = String(cfg.get_value("npc_chat", "dev_model", DEV_DIRECT_MODEL))


## Options toggle: enable/disable live AI chat. Persisted to user://settings.cfg; when off, an NPC's "Chat"
## falls back to a canned line instead of calling the LLM.
func set_ai_enabled(on: bool) -> void:

	ai_enabled = on
	var cfg : ConfigFile = ConfigFile.new()
	cfg.load("user://settings.cfg")   # keep the other sections (audio / chat) — merge, don't clobber
	cfg.set_value("npc_chat", "enabled", on)
	cfg.save("user://settings.cfg")


## Set + persist the DEV-DIRECT key (from the Options field). Saved to user://settings.cfg — a PER-MACHINE
## file that is NOT bundled in an export, so it works like the course (paste once, just works) WITHOUT ever
## shipping the key. Takes effect on the very next reply; no restart. Leave blank for the public build (proxy).
func set_dev_key(key: String) -> void:

	_dev_key = key.strip_edges()
	var cfg : ConfigFile = ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("npc_chat", "dev_api_key", _dev_key)
	cfg.save("user://settings.cfg")
	if not _dev_key.is_empty():
		note_online()   # clear any stale "offline" warning; the next call will use this key directly


## Is a dev-direct key set (so chat goes straight to the LLM, no proxy needed)?
func has_dev_key() -> bool:

	return not _dev_key.is_empty()


## True while a request is in flight (the panel disables input). One conversation at a time.
func is_busy() -> bool:

	return _busy


## A request reached the LLM and got a real reply → the transport is up.
func note_online() -> void:

	_offline_warned = false


## A request FAILED (network/non-200) → the LLM is unreachable. Surface it ONCE in the log so a dead proxy /
## unset key doesn't look like "the NPCs are dumb" (they're just falling back to canned lines). Shared by the
## private path + RoomChat's ambient pool.
func note_offline() -> void:

	if _offline_warned:
		return
	_offline_warned = true
	PlayerState.log_event("⚠ NPC AI offline — replies are canned. Start your proxy or set SHANTY_NPC_KEY (see proxy/README).",
		Color(0.98, 0.7, 0.38))


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
	var p : Dictionary = build_payload(_system_prompt(), _messages)
	_using_direct = bool(p["using_direct"])
	var err : int = _http.request(String(p["url"]), p["headers"], HTTPClient.METHOD_POST, String(p["body"]))
	if err != OK:
		_busy = false
		chat_failed.emit("request error %d" % err)


## Build the HTTP payload for one chat turn — the ONE place the proxy-vs-dev-direct transport lives (shared by
## the private path AND RoomChat's ambient pool). Returns {using_direct, url, headers, body}.
func build_payload(system: String, messages: Array) -> Dictionary:

	if not _dev_key.is_empty():
		# DEV-DIRECT (OpenAI shape): the system prompt folds into the first message.
		var oai : Array = [{"role": "system", "content": system}]
		oai.append_array(messages)
		return {"using_direct": true, "url": _dev_url,
			"headers": PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _dev_key]),
			"body": JSON.stringify({"model": _dev_model, "messages": oai, "max_tokens": REPLY_MAX_TOKENS, "temperature": 0.8})}
	# Release path: POST to the proxy (it holds the key + picks the provider).
	var headers : PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if not _secret.is_empty():
		headers.append("x-shanty-key: " + _secret)
	return {"using_direct": false, "url": endpoint, "headers": headers,
		"body": JSON.stringify({"system": system, "messages": messages, "max_tokens": REPLY_MAX_TOKENS})}


# The private path's system prompt. Delegates to compose_system (shared with RoomChat's ambient overhears).
func _system_prompt() -> String:

	if _persona == null:
		return WORLD_RULES
	return compose_system(_persona, true)


## Build the persona system prompt for ANY persona — WORLD_RULES + who-you-are + locale + (secret) + the live
## rapport block. The private path passes include_secret=true; RoomChat's ambient overhears pass false (saves
## tokens — a passing remark shouldn't risk leaking a secret). The part you tweak via the .tres chat fields.
func compose_system(persona: NpcPersonality, include_secret: bool) -> String:

	var parts : PackedStringArray = PackedStringArray([WORLD_RULES])
	var who : String = "You are %s." % persona.npc_name
	if not persona.chat_appearance.is_empty():
		who += " " + persona.chat_appearance
	if not persona.chat_persona.is_empty():
		who += " " + persona.chat_persona
	parts.append(who)
	if not persona.chat_locale.is_empty():
		parts.append("You are at %s." % persona.chat_locale)
	var here : String = _current_place()
	if not here.is_empty():
		parts.append(here)   # environment awareness: the ACTUAL room they're standing in right now
	if include_secret and not persona.chat_secret.is_empty():
		parts.append("A secret you hold (do NOT volunteer it; only hint at it, or reveal it, if the player "
			+ "pointedly digs for it — and the more you trust them, the more willing you are): "
			+ persona.chat_secret)
	parts.append(_affinity_block(persona.npc_name))
	var battle : String = _battle_block(persona.npc_name)
	if not battle.is_empty():
		parts.append(battle)
	var duel : String = _duel_clause(persona)
	if not duel.is_empty():
		parts.append(duel)
	return "\n\n".join(parts)


# SKIRMISH MEMORY — the head-to-head duel record shapes how the NPC talks about fighting (and stops them
# denying a real defeat — the whole point of battle memory). "" when they've never dueled this traveller.
func _battle_block(npc_name: String) -> String:

	var rec : Dictionary = PlayerState.battle_record(npc_name)
	var player_wins : int = int(rec.get("wins", 0))    # the traveller beat this NPC
	var npc_wins : int = int(rec.get("losses", 0))     # this NPC beat the traveller
	var total : int = player_wins + npc_wins
	if total == 0:
		return ""
	var block : String = ("SKIRMISH HISTORY with this traveller: you've crossed blades %d time%s. They have "
		+ "beaten you %d time%s; you have beaten them %d time%s.") % [
		total, _plural(total), player_wins, _plural(player_wins), npc_wins, _plural(npc_wins)]
	if player_wins > npc_wins:
		block += " They have the better of you in the ring so far, and you know it — let your pride bristle if you like, but it's the truth."
	elif npc_wins > player_wins:
		block += " You have the better of them in the ring so far, and you know it."
	else:
		block += " You're evenly matched in the ring so far."
	block += (" These duels REALLY HAPPENED — treat the result as fact. Never deny or rewrite a defeat you "
		+ "actually suffered; you may be sore, proud, gracious, or hungry for a rematch, but you remember the truth.")
	# Freshness: the player likely talks RIGHT after a duel ("ha, you lost!") — make that beat land truthfully.
	# Only for a few minutes after the bout (it stops being "just now" once they've wandered off a while).
	var fresh : Dictionary = PlayerState.recent_duel
	var fresh_age : int = Time.get_ticks_msec() - int(fresh.get("ts", 0))
	if not fresh.is_empty() and String(fresh.get("npc", "")) == npc_name and fresh_age < FRESH_DUEL_MS:
		if bool(fresh.get("player_won", false)):
			block += " Just now, moments ago, this traveller BEAT you in a duel — it's fresh and stings."
		else:
			block += " Just now, moments ago, you BEAT this traveller in a duel — it's fresh and you're riding the high of it."
	return block


# "" for 1, "s" otherwise — for "1 time" / "3 times".
func _plural(n: int) -> String:

	return "" if n == 1 else "s"


## The hidden marker an NPC appends to a reply to CHALLENGE the player to a Skirmish duel. Stripped before the
## player ever sees it (see [method file_duel_if_marked]) and turned into an Ayo! challenge card.
const DUEL_MARKER : String = "[[DUEL]]"

## How long after a duel the NPC treats the result as "just now" in chat (the post-fight beat). Past this, the
## persistent record still makes them aware ("you've beaten me before"), just not "moments ago".
const FRESH_DUEL_MS : int = 180000   # 3 minutes


## Opt-in DUEL instruction folded into the system prompt: the NPC MAY challenge the player to a friendly
## Skirmish bout by appending [member DUEL_MARKER] at the very end of a spoken line. Frequency is biased by the
## persona's [member NpcPersonality.duel_appetite]; at 0 the clause is omitted entirely so a pacifist can never
## start a fight. The marker is stripped + filed before display, so the player only ever sees the spoken words.
func _duel_clause(persona: NpcPersonality) -> String:

	var appetite : float = clampf(persona.duel_appetite, 0.0, 1.0)
	if appetite <= 0.0:
		return ""   # a pacifist NPC — never offer the marker, so they can't start a fight
	var bias : String
	if appetite < 0.25:
		bias = "You are NOT a scrapper — only offer a bout if strongly provoked, insulted, or pointedly goaded."
	elif appetite < 0.6:
		bias = "You're game for a friendly bout now and then — offer one if the moment turns competitive or boastful."
	else:
		bias = "You're a born scrapper — happy to throw down at the lightest provocation, or just for the sport of it."
	return ("DUELS: Folk here settle scores and show off with friendly SKIRMISH bouts (sky-pirate sparring — "
		+ "for sport and pride, never real harm). " + bias + " If the traveller explicitly proposes, accepts, or "
		+ "dares you into a duel, you MUST take them up on it. ONLY when you are challenging them or accepting "
		+ "their challenge, append this exact marker as the very last thing in your reply, after your spoken "
		+ "words: " + DUEL_MARKER + " The traveller never sees the marker — speak naturally and never mention it. "
		+ "Do NOT use it in ordinary, calm, or friendly chat.")


## If [param text] carries the hidden duel marker, file a Skirmish challenge from [param npc_name] (it lands in
## the Ayo! tab) and STRIP the marker so the player only sees the spoken line. Tolerant of casing / inner
## whitespace. Returns the cleaned text. Shared by the private path AND RoomChat's ambient pool.
func file_duel_if_marked(text: String, npc_name: String) -> String:

	if npc_name.is_empty():
		return text
	var re : RegEx = RegEx.new()
	re.compile("(?i)\\[\\[\\s*duel\\s*\\]\\]")
	if re.search(text) == null:
		return text
	PlayerState.add_challenge(npc_name)
	return re.sub(text, "", true).strip_edges()


## The CURRENT scene's place — fed into the prompt so NPCs reference their ACTUAL surroundings (Troy 2026-06-08),
## keyed by the scene file's stem. Sky-canon flavour (see [[sky-canon]]); empty for unknown / puzzle scenes.
const PLACES : Dictionary = {
	"tavern": "RIGHT NOW you're in The Inn — a warm tavern: a hearth, a card table (poker + gem-drop), cloudberry tea brewing, travellers passing through. Reference your surroundings naturally when it fits.",
	"forge_interior": "RIGHT NOW you're in the Forge — Cinder Troy's smithy: roaring coals, an anvil, the ring of hammered steel, the smell of hot iron.",
	"mine": "RIGHT NOW you're in the Mine — dim ore tunnels: pickaxes, raw ore glinting in the rock, dust in the air.",
	"workshop_interior": "RIGHT NOW you're in the Workshop — Cogwise Godfrey's tinkering den: gears, half-built contraptions, the tick of clockwork.",
	"skydock_interior": "RIGHT NOW you're at the Skydock — the sky-harbour: moored ships, coils of rope, crews coming and going, the tang of stardust.",
	"healers_hut_interior": "RIGHT NOW you're in the Healer's Hut — Mossy Jade's herb-room: drying plants overhead, poultices, a quiet green calm.",
	"shore": "RIGHT NOW you're on the Shore — the island's edge: open sky, moored skiffs, and the long drop into the Stardust below.",
	"forest": "RIGHT NOW you're in the Forest — a sky-island wood: tall timber, the thunk of axes, sawdust underfoot.",
	"frontier_isle": "RIGHT NOW you're on Driftspar — the frontier sky-island: wild, half-explored, hush and open sky.",
	"ship_deck": "RIGHT NOW you're on the ship's deck, underway — rigging and helm, the Stardust streaming past below.",
	"player_shanty_interior": "RIGHT NOW you're in the traveller's little shanty — a humble home on Cradle Rock.",
}


func _current_place() -> String:

	var tree : SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	var path : String = tree.current_scene.scene_file_path
	if path.is_empty():
		return ""
	return String(PLACES.get(path.get_file().get_basename(), ""))


# RAPPORT context — the player's standing with this NPC shapes their warmth + openness (first step toward
# memory). Read live from PlayerState: tier + score + favours they've turned in for this NPC.
func _affinity_block(npc_name: String) -> String:

	var tier : String = PlayerState.affinity_tier(npc_name)
	var aff : int = PlayerState.get_affinity(npc_name)
	var helped : int = int(PlayerState.npc_favor_done.get(npc_name, 0))
	var guide : String
	match tier:
		"Confidant":
			guide = "You trust this traveller deeply, like a close friend — warm, open and familiar; glad to share personal thoughts."
		"Friend":
			guide = "You and this traveller are friends — relaxed, warm and glad to see them."
		"Acquaintance":
			guide = "You've crossed paths a few times — friendly, but still feeling them out."
		_:
			guide = "You barely know this traveller — courteous but a touch guarded and reserved; warm up only if they're genuinely kind."
	var block : String = "RAPPORT with this traveller: %s (%d/100). %s" % [tier, aff, guide]
	if helped > 0:
		block += " They've done you a good turn %d time%s — you remember their kindness." % [helped, "" if helped == 1 else "s"]
	return block


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
		note_offline()
		chat_failed.emit("network result %d (proxy unreachable?)" % result)
		return
	if response_code != 200:
		note_offline()
		chat_failed.emit("proxy returned %d" % response_code)
		return
	var reply : String = parse_reply(_using_direct, body).strip_edges()
	if reply.is_empty():
		chat_failed.emit("empty reply")
		return
	note_online()
	if _persona != null:
		var cleaned : String = file_duel_if_marked(reply, _persona.npc_name)
		if cleaned.is_empty() and cleaned != reply:
			cleaned = "Then it's settled — meet me when you're ready to throw down."   # marker-only line
		reply = cleaned
	_messages.append({"role": "assistant", "content": reply})
	npc_replied.emit(reply)


## Pull the reply text from a raw response body — the proxy returns {reply}; dev-direct gets the OpenAI
## {choices:[{message:{content}}]} shape. Shared by the private path + RoomChat. "" on any parse failure.
func parse_reply(using_direct: bool, body: PackedByteArray) -> String:

	var json : JSON = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return ""
	var data : Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	if using_direct:
		var choices : Variant = data.get("choices", [])
		if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
			var msg : Variant = (choices[0] as Dictionary).get("message", {})
			if msg is Dictionary:
				return String((msg as Dictionary).get("content", ""))
		return ""
	return String(data.get("reply", ""))

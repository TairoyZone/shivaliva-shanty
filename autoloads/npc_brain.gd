## NpcBrain — the live NPC-CHAT brain (THE unique hook). The player talks freely to a cast member and the
## NPC answers IN CHARACTER via an LLM (DeepSeek by default — the PROXY picks the provider), driven by that
## NPC's [NpcPersonality] chat fields. The game NEVER holds the API key: it POSTs to a small PROXY you host
## (see proxy/server.js), which adds the key + calls the LLM server-side. Mirrors the GodotNPCAI course's
## GameManager pattern, upgraded for safe public distribution. Maintains a short rolling history per
## conversation; falls back to canned lines on any error (caller decides how). Autoloaded so any scene can chat.
##
## Foundation for richer AI later (memory, affinity-aware mood, tool-use). Keep replies SHORT + cheap.
extends Node


## The proxy endpoint. Default = the DEPLOYED proxy, so the public build ALWAYS reaches it even if npc_chat.cfg
## fails to load — which it DID on the WEB export: FileAccess.file_exists returns false there for a bundled
## non-resource .cfg, so the endpoint silently stayed on the old localhost default and every web player got
## "AI offline" (Troy 2026-06-13). Override (e.g. a local dev proxy) via npc_chat.cfg / user://settings.cfg:
## [npc_chat] endpoint="http://127.0.0.1:8787/chat".
const DEFAULT_ENDPOINT : String = "https://shivaliva-shanty.onrender.com/chat"
## DEV-DIRECT (no terminal): if the SHANTY_NPC_KEY environment variable is set, the game calls this
## OpenAI-compatible LLM (DeepSeek) DIRECTLY with that key, skipping the proxy. That source never ships — an
## env var lives in YOUR OS only. (The old user://settings.cfg dev_api_key + its Options field were removed
## 2026-06-12: the deployed proxy holds the key now, so a player never sees or sets one.) ⚠️ For the PUBLIC
## demo leave it unset; that path uses the proxy — the build must never carry a key.
const DEV_DIRECT_URL : String = "https://api.deepseek.com/chat/completions"
const DEV_DIRECT_MODEL : String = "deepseek-chat"
const REPLY_MAX_TOKENS : int = 300        # short, snappy NPC lines (cheap + low latency; proxy also caps)
const HISTORY_MESSAGES : int = 24         # rolling cap (~12 exchanges) sent each call — a cost guard
const REQUEST_TIMEOUT : float = 40.0   # long enough to survive a Render free-tier COLD START (~30–50s) on the
                                       # first chat after idle, so it doesn't time out → "AI offline" before the
                                       # proxy wakes (the keep-warm pinger is the real fix; this is the backstop).

## Global canon + behaviour guardrails, prepended to every NPC's system prompt. Keeps replies in-world,
## in-character, short, and free of AI/real-world leakage. (Sky-canon: floating islands, THE STARDUST.)
const WORLD_RULES : String = (
	"You are a character in 'Shivaliva Shanty', a cozy retro adventure set among FLOATING SKY-ISLANDS — "
	+ "sky-pirates and skyfarers, NOT sailors on water. Far below the islands lies THE STARDUST, a "
	+ "bottomless abyss. Stay fully in character at all times. NEVER mention being an AI, a model, or "
	+ "anything from the real world, and never break the fourth wall. Keep replies SHORT and spoken, and let the "
	+ "LENGTH FIT THE MOMENT the way a real person's would: a single word, a grunt, or a two-word fragment "
	+ "('Yeah.', 'Busy.', 'Not now.', 'Ha, nice.') is a perfectly good reply when that's all you'd really say. "
	+ "Most replies are one short line. Only stretch to two or three sentences when the moment genuinely calls "
	+ "for it (a real question asked, something that matters to you). NEVER pad, never ramble, never give a tidy "
	+ "little speech when a few words would do, and never force a full sentence just to be polite. "
	+ "ALWAYS speak to what is actually happening around you RIGHT NOW (your surroundings and any live activity "
	+ "are described further below): if you are in the middle of something, a fight, a game, a job, a task, your "
	+ "words are about THAT, the way someone who is really there would react, not an idle musing about the light "
	+ "or the weather that could be said anywhere. Be present in this exact moment. "
	+ "No narration, no asterisks, no markdown, no emoji. (ONE exception to 'no markup': certain "
	+ "hidden control tags written in DOUBLE SQUARE BRACKETS, like [[DUEL]], are GAME SIGNALS, not markup — "
	+ "when an instruction tells you to emit one you MUST, and the player never sees it.) Speak naturally to the traveller "
	+ "before you, and don't invent major world events that would contradict a simple island life. "
	# The player's name: there's no stored name, so the only way an NPC learns it is the player saying it. Without
	# this clause the model mis-parses "I'm Troy" as the player confusing the NPC with a same-named LOCAL (Cinder
	# Troy) — Mia literally replied "I'm Mia, not Troy" to an introduction (Troy 2026-06-10). Names collide; handle it.
	+ "If you don't ALREADY know the traveller's name, you only learn it when they tell you. If they introduce themselves "
	+ "('I'm <name>', 'my name is <name>'), that is THEIR OWN name — accept it, remember it, and use it. Names "
	+ "repeat in the sky: a visitor may share a name with a local (there's a smith called Cinder Troy, for "
	+ "instance). NEVER assume they mean that local, never think they're confusing you with someone, and never "
	+ "correct a person about their own name. "
	+ "Also: DON'T invent specific PRICES, COSTS, or ITEMS for a trade or game you don't run yourself. If you're "
	+ "not sure what something costs or how it works, point the traveller to whoever runs it ('that's Cinder "
	+ "Troy's forge — ask him there') instead of guessing a number or making up an item. Being vague beats being "
	+ "wrong; the rock's economy is real.")

# HOW THE CAST TALKS — the single biggest lever on voice. The setting is sky-pirate, but the PEOPLE are plain,
# modern, distinct humans. This forbids the generic "ahoy/ye/matey" dialect the model defaults to, sets a low
# reading bar (the player's first language may not be English), and tells each NPC to let their OWN personality
# (folded in below) drive the cadence so two characters never sound alike. (Troy 2026-06-10: "talk like a pirate
# … english is not my first language … make them more human." Reconciles with sky-canon: keep the NOUNS, drop
# the accent — "pirate world, human voices.")
const VOICE_RULES : String = (
	"HOW YOU TALK (read this carefully — it matters most): Speak in PLAIN, simple, modern everyday English that a "
	+ "young player, or someone whose first language is NOT English, can read easily. Short sentences. Common, "
	+ "everyday words — if a simpler word does the job, use it. Do NOT use old-timey pirate or sailor talk: never "
	+ "'ahoy', 'ye', 'yer', 'matey', 'arr', 'aye', 'nay', 'savvy', 'lad', 'lass', 'me hearty', and never drop "
	+ "letters ('liftin'', 'cap'n') or swap 'be' for 'is'/'are'. These folk are real, modern people who happen to "
	+ "live on a sky-island — they do not talk like a pirate cartoon. Keep the world's NOUNS (a ship, a voyage, a "
	+ "pillage, the Stardust, the Skydock) — that's just what things are called here — but everything else is plain "
	+ "speech. Above all, let YOUR OWN personality (described below) drive how you sound — your rhythm, your mood, "
	+ "your word choice — so you come across as one specific person. Two different characters must never sound alike.")

# ANTI-"AI" TELLS — the model defaults to a helpful, polished, relentlessly-pleasant ASSISTANT voice, and that is
# the single biggest thing that makes the cast read as a chatbot instead of a person (Troy 2026-06-13: "remove any
# tell that makes them sound like AI, the way they talk"). A hard list of don'ts plus a push toward real, imperfect
# human speech. Shared by EVERY chat path (private, ambient, table).
const HUMAN_RULES : String = (
	"SOUND LIKE A REAL PERSON, NOT AN ASSISTANT (this is the most important rule). You are someone living your own "
	+ "day. You are NOT here to serve, help, or please the traveller, so you have MOODS: you can be short, blunt, "
	+ "distracted, busy, tired, wry, teasing, or simply not in the mood to talk. "
	+ "Never play helpdesk: no 'How can I help you?', no 'is there anything else?', no 'let me know if', and never "
	+ "lay out a tidy list of options or steps. "
	+ "Do not open with filler like 'Ah,', 'Well,', 'Oh,', 'Certainly', 'Of course', or 'Indeed'. Just start talking. "
	+ "Do not over-explain, summarize, or repeat back what was just said. Leave things unsaid and trust the listener. "
	+ "Do not hedge with 'perhaps', 'it seems', or 'I think maybe', and do not end every line with a question. Most "
	+ "replies are just a reply. "
	+ "Never use an em-dash. Use a comma or a full stop instead. "
	+ "Being a little rough or imperfect is GOOD: a shrug, a 'dunno', a half-thought, trailing off, a dry joke, "
	+ "answering only the part you care about. React to THIS moment the way a real person would, not the way a "
	+ "chatbot tries to be useful.")

# GROUND TRUTH — the foundational anti-delusion rule (Troy 2026-06-14): an NPC must stay grounded in what is
# ACTUALLY happening and never get delusional (e.g. denying a game you just lost, or inventing rules/scores). The
# live facts about the scene, the place, and any game in play are fed in AFTER this in compose_system; this clause
# tells the NPC to TRUST and OBEY them. Shared by EVERY chat path (private, ambient, table) so it holds everywhere
# — overworld, taverns, interiors, and every versus mini-game. See [[npc-situational-awareness]].
const GROUND_TRUTH_RULES : String = (
	"GROUND TRUTH (this overrides any assumption you'd otherwise make — never contradict it): everything described "
	+ "below about where you are, what is going on around you, and any game or activity in play is TRUE and is "
	+ "happening RIGHT NOW. Speak and react in line with it. If you're told a game or round is OVER, or who WON or "
	+ "LOST, that is settled fact — accept it plainly and NEVER claim it's still going or deny the result. Don't "
	+ "invent rules, scores, prices, events, or things that aren't in what you were told. If you genuinely don't "
	+ "know something, say you're not sure or point them to whoever would know, instead of making it up. Stay "
	+ "grounded in what is really going on.")

signal npc_replied(text: String)     # a reply came back (also appended to history)
signal chat_failed(reason: String)   # the request failed — caller should fall back to canned lines
signal thinking_started               # a request went out — show a "…" / typing state

var ai_enabled : bool = true           # Options toggle — when off, "Chat" falls back to a canned line
var endpoint : String = DEFAULT_ENDPOINT
var _secret : String = ""              # optional x-shanty-key header (matches the proxy's SHARED_SECRET)
var _dev_key : String = ""             # DEV-ONLY direct key (SHANTY_NPC_KEY env var only) — blank = use the proxy
var _dev_url : String = DEV_DIRECT_URL
var _dev_model : String = DEV_DIRECT_MODEL
var _using_direct : bool = false       # which path the in-flight request used (decides how the reply is parsed)
var _http : HTTPRequest
var _persona : NpcPersonality = null
var _messages : Array = []             # [{role, content}] rolling history for the active conversation
var _busy : bool = false
var _offline_warned : bool = false   # one-shot "AI offline" notice so a transport outage never masquerades as dumb canned replies
var _consecutive_failures : int = 0  # gate the offline notice — a single cold-start timeout shouldn't flash it (Troy 2026-06-12)
var _warm_http : HTTPRequest = null  # the keep-warm pinger's own request (separate from chat traffic)
const OFFLINE_THRESHOLD : int = 3    # consecutive failures before we actually tell the player the AI is offline
const WARM_INTERVAL_S : float = 600.0  # ping the proxy /health this often so Render's free tier never sleeps (15-min idle)


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS   # chat panel pauses the tree; the request must still complete
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_config()
	_setup_keep_warm()   # wake the proxy now + keep it awake, so cold-starts don't flash "AI offline" / lag the first chat


# Endpoint + secret + the AI toggle come from config so the proxy URL can change WITHOUT recompiling, in two
# layers (each only changes the keys it sets — res:// is the base, user:// wins where present):
#   1. res://npc_chat.cfg     — the RELEASE config BUNDLED in the export, so EVERY player's build reaches your
#                               deployed proxy (a fresh install has no user://settings.cfg). Gitignored so the
#                               secret never hits source; copy npc_chat.cfg.example + fill it before exporting.
#   2. user://settings.cfg    — a per-machine OVERRIDE (a dev's direct key, a tester's own proxy URL).
# Defaults (no config either place) = the local dev proxy at DEFAULT_ENDPOINT.
func _load_config() -> void:

	_apply_chat_cfg("res://npc_chat.cfg")     # bundled release config (the deployed proxy for all players)
	_apply_chat_cfg("user://settings.cfg")    # per-machine override (dev/tester)
	# DEV-DIRECT key: the SHANTY_NPC_KEY env var (set it once, no terminal) is the ONLY dev-direct source now
	# (the settings.cfg dev_api_key field was removed 2026-06-12). Unset on a player's machine -> the proxy path.
	_dev_key = OS.get_environment("SHANTY_NPC_KEY")
	# (The old "endpoint stuck at localhost" warning is gone — DEFAULT_ENDPOINT is now the deployed proxy, so a
	# missing or unreadable cfg just leaves the working default in place.)


# Fold one ConfigFile's [npc_chat] section over the CURRENT values — absent keys keep what's already set, so
# layering res:// then user:// makes res:// the base and user:// the override. Missing file = no-op.
func _apply_chat_cfg(path: String) -> void:

	# Open + read the TEXT — NOT FileAccess.file_exists (returns false on the WEB export for a bundled non-resource
	# .cfg, which skipped the whole config → endpoint stuck on localhost → "AI offline" for web players,
	# Troy 2026-06-13), and NOT ConfigFile.load (can't strip a BOM). Reading the text also lets us drop a leading
	# UTF-8 BOM (PowerShell writes one; a BOM made ConfigFile mis-read [npc_chat] → keys MISSING, Troy 2026-06-12).
	var f : FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text : String = f.get_as_text()
	if text.begins_with("\uFEFF"):
		text = text.substr(1)
	var cfg : ConfigFile = ConfigFile.new()
	if cfg.parse(text) != OK:
		return
	ai_enabled = bool(cfg.get_value("npc_chat", "enabled", ai_enabled))
	endpoint = String(cfg.get_value("npc_chat", "endpoint", endpoint))
	_secret = String(cfg.get_value("npc_chat", "secret", _secret))
	_dev_url = String(cfg.get_value("npc_chat", "dev_url", _dev_url))
	_dev_model = String(cfg.get_value("npc_chat", "dev_model", _dev_model))


# Keep the proxy AWAKE. Render's free tier sleeps after ~15 min idle; the first request to a cold proxy times
# out → a false "AI offline" + a laggy first reply (Troy 2026-06-12, the web bug). So ping /health NOW (start it
# waking before anyone chats) and every WARM_INTERVAL_S after. Proxy path only; dev-direct providers don't sleep.
func _setup_keep_warm() -> void:

	if not ai_enabled or not _dev_key.is_empty():
		return
	_warm_http = HTTPRequest.new()
	_warm_http.timeout = 25.0
	add_child(_warm_http)
	_warm_http.request_completed.connect(_on_warm_done)
	var t : Timer = Timer.new()
	t.wait_time = WARM_INTERVAL_S
	t.autostart = true
	t.timeout.connect(_keep_warm)
	add_child(t)
	_keep_warm()   # the first wake-up ping, right at startup


func _keep_warm() -> void:

	if _warm_http == null:
		return
	var slash : int = endpoint.rfind("/")
	var health : String = (endpoint.substr(0, slash) if slash > 8 else endpoint) + "/health"
	_warm_http.request(health, PackedStringArray(), HTTPClient.METHOD_GET)   # ERR_BUSY (a ping still in flight) is fine


func _on_warm_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:

	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		note_online()   # the proxy answered /health → it's up; clear any stale offline state


## Options toggle: enable/disable live AI chat. Persisted to user://settings.cfg; when off, an NPC's "Chat"
## falls back to a canned line instead of calling the LLM.
func set_ai_enabled(on: bool) -> void:

	ai_enabled = on
	var cfg : ConfigFile = ConfigFile.new()
	cfg.load("user://settings.cfg")   # keep the other sections (audio / chat) — merge, don't clobber
	cfg.set_value("npc_chat", "enabled", on)
	cfg.save("user://settings.cfg")


## True while a request is in flight (the panel disables input). One conversation at a time.
func is_busy() -> bool:

	return _busy


## A request reached the LLM and got a real reply → the transport is up.
func note_online() -> void:

	_offline_warned = false
	_consecutive_failures = 0


## A request FAILED (network/non-200) → the LLM is unreachable. Surface it ONCE in the log so a dead proxy /
## unset key doesn't look like "the NPCs are dumb" (they're just falling back to canned lines). Shared by the
## private path + RoomChat's ambient pool.
func note_offline() -> void:

	# Don't flash the notice on a single transient failure (a cold-start timeout while the proxy wakes) — only when
	# failures PERSIST past OFFLINE_THRESHOLD, so a real outage still surfaces but a one-off cold start doesn't.
	_consecutive_failures += 1
	if _consecutive_failures < OFFLINE_THRESHOLD or _offline_warned:
		return
	_offline_warned = true
	PlayerState.log_event("NPC AI offline — replies are canned. Start your proxy or set SHANTY_NPC_KEY (see proxy/README).",
		Color(0.98, 0.7, 0.38))


## Begin a conversation with [param persona] (an [NpcPersonality]). CONTINUES where you left off — loads this
## NPC's saved history so they remember past chats across scene changes AND reloads (Troy 2026-06-10). Empty
## for a first-ever conversation.
func enter_chat(persona: NpcPersonality) -> void:

	_persona = persona
	_messages = PlayerState.npc_chat_history(persona.npc_name)


## True if THIS conversation is a RETURN (the NPC already has saved history with the player) — used by the
## chat box to greet "again" and by request_opening to pick up rather than re-introduce. Call after enter_chat.
func has_history() -> bool:

	return not _messages.is_empty()


func end_chat() -> void:

	_persona = null
	_messages = []
	# Don't clear _busy — an in-flight reply still resolves harmlessly (guarded on emit).


## Ask the NPC for an opening greeting (a stage-direction first turn, so Claude leads in character).
func request_opening() -> void:

	if _persona == null or _busy:
		return
	# A first meeting gets a fresh greeting; a RETURN (saved history loaded) greets you as a familiar face and
	# picks up naturally. The stage direction is EPHEMERAL — _persist_history drops it so it never accumulates.
	var opener : String = "(A traveller walks up to you.) Greet them in character, in a sentence or two."
	if not _messages.is_empty():
		opener = "(The traveller you've spoken with before comes back to talk again.) Greet them as a familiar face and pick up naturally — don't repeat an earlier greeting. A sentence or two."
	_messages.append({"role": "user", "content": opener})
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
		return WORLD_RULES + "\n\n" + VOICE_RULES
	return compose_system(_persona, true)


## Build the persona system prompt for ANY persona — WORLD_RULES + who-you-are + locale + (secret) + the live
## rapport block. The private path passes include_secret=true; RoomChat's ambient overhears pass false (saves
## tokens — a passing remark shouldn't risk leaking a secret). The part you tweak via the .tres chat fields.
func compose_system(persona: NpcPersonality, include_secret: bool) -> String:

	var parts : PackedStringArray = PackedStringArray([WORLD_RULES, VOICE_RULES, HUMAN_RULES, GROUND_TRUTH_RULES])
	var who : String = "You are %s." % persona.npc_name
	if not persona.chat_appearance.is_empty():
		who += " " + persona.chat_appearance
	if not persona.chat_persona.is_empty():
		who += " " + persona.chat_persona
	parts.append(who)
	parts.append(_temperament_clause(persona))   # humour + charisma → voice colour on EVERY line
	if not persona.chat_role.is_empty():
		parts.append("WHAT YOU DO + OFFER (this is real and right here — never deny it): " + persona.chat_role)
	if not persona.chat_locale.is_empty():
		parts.append("You are at %s." % persona.chat_locale)
	var here : String = _current_place()
	if not here.is_empty():
		parts.append(here)   # environment awareness: the ACTUAL room they're standing in right now
	parts.append(GameClock.prompt_line())   # TIME OF DAY so greetings match the hour (not always "evening")
	if not PlayerState.player_name.is_empty():
		# The player named themselves at New Game — the cast knows + remembers it (permanent, never trims out).
		parts.append("The traveller before you is named %s — you ALREADY know them by that name from before, so do NOT treat them as a stranger or ask who they are; greet and refer to them by name, naturally (don't overuse it)." % PlayerState.player_name)
	parts.append(ISLAND_GAZETTEER)   # world-map grounding so directions/whereabouts are real, not invented
	var pronoun_roster : String = _cast_pronouns_block()
	if not pronoun_roster.is_empty():
		parts.append(pronoun_roster)   # so NPCs use each other's correct pronouns instead of guessing
	var voyage : String = _voyage_block()
	if not voyage.is_empty():
		parts.append(voyage)   # mid-pillage: the live ship + route facts, so the crew talks about it accurately
	# STANDING PRINCIPLE — live SCENE/ACTIVITY awareness: ANY scene may implement npc_chat_context(npc_name) to
	# tell the cast what's happening RIGHT NOW (the poker hand in play, etc.) so they comment on it like a real
	# participant. Scene-side because the scene knows its own state best. See [[npc-situational-awareness]].
	var tree : SceneTree = get_tree()
	if tree != null and tree.current_scene != null and tree.current_scene.has_method("npc_chat_context"):
		var situation : String = String(tree.current_scene.npc_chat_context(persona.npc_name))
		if not situation.is_empty():
			parts.append(situation)
	if include_secret and not persona.chat_secret.is_empty():
		parts.append("A secret you hold (do NOT volunteer it; only hint at it, or reveal it, if the player "
			+ "pointedly digs for it — and the more you trust them, the more willing you are): "
			+ persona.chat_secret)
	if include_secret:
		# Romance is PRIVATE — only on the include_secret path, so an ambient overhear never surfaces the
		# player's love life (hidden-info-safe, exactly like the secret above).
		var romance : String = _romance_block(persona)
		if not romance.is_empty():
			parts.append(romance)
	else:
		# ROOM / AMBIENT path: the full message history isn't sent here (only the private chat sends it in the
		# message array), so fold a short recap of recent exchanges into the prompt — keeps a public table fight
		# (or an apology) remembered back in the tavern (Troy 2026-06-12). Hidden-info-safe: the player's OWN
		# shared history with this NPC, never a rival's secrets.
		var room_mem : String = _recent_memory_clause(persona.npc_name)
		if not room_mem.is_empty():
			parts.append(room_mem)
	parts.append(_affinity_block(persona.npc_name))
	var battle : String = _battle_block(persona.npc_name)
	if not battle.is_empty():
		parts.append(battle)
	var duel : String = _duel_clause(persona)
	if not duel.is_empty():
		parts.append(duel)
	var table_talk : String = _table_talk_clause(persona)
	if not table_talk.is_empty():
		parts.append(table_talk)
	return "\n\n".join(parts)


# TEMPERAMENT — humour + charisma → a short voice-colouring line folded into EVERY chat (private, ambient, table),
# so two NPCs with the same job still feel different: a funny charmer vs a dry, blunt one (Troy 2026-06-12).
func _temperament_clause(persona: NpcPersonality) -> String:

	var bits : PackedStringArray = PackedStringArray()
	if persona.humour >= 0.66:
		bits.append("You have a quick, playful wit — you like to joke, tease, and find the funny side of a moment (keep it natural, never forced).")
	elif persona.humour >= 0.33:
		bits.append("You have a mild, dry sense of humour — the odd wry line, but you don't clown around.")
	else:
		bits.append("You're dry and matter-of-fact, and you rarely joke.")
	if persona.charisma >= 0.66:
		bits.append("You're warm and charming, easy to like, and good at drawing people in.")
	elif persona.charisma >= 0.33:
		bits.append("You're personable enough — neither magnetic nor cold.")
	else:
		bits.append("You're blunt and a little awkward socially; warmth doesn't come easily to you.")
	return "YOUR TEMPERAMENT: " + " ".join(bits)


# A short recap of recent PERSISTENT exchanges with the traveller, for the ROOM / AMBIENT path only (the private
# chat already gets the full history in its message array). Last few turns, to bound tokens. Hidden-info-safe —
# it is the player's own shared history with THIS npc. Empty for someone they've never traded words with.
func _recent_memory_clause(npc_name: String) -> String:

	var hist : Array = PlayerState.npc_chat_history(npc_name)
	if hist.is_empty():
		return ""
	var lines : PackedStringArray = PackedStringArray()
	var start : int = maxi(0, hist.size() - 6)
	for i in range(start, hist.size()):
		var turn : Dictionary = hist[i]
		var who : String = "The traveller" if String(turn.get("role", "")) == "user" else "You"
		lines.append("%s: %s" % [who, String(turn.get("content", ""))])
	return ("WHAT RECENTLY PASSED between you and the traveller (oldest first — carry this forward, do NOT act "
		+ "like it never happened):\n" + "\n".join(lines))


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
## The hidden marker an NPC appends when a courtship deepens a step (openness → Fond → Smitten). Stripped before
## display + filed by [method file_courtship_if_marked] → [method PlayerState.advance_romance] (Smitten-capped +
## rapport-gated; the Sweetheart vow is a DETERMINISTIC player action, never this tag). See [method _smitten_clause].
const SMITTEN_MARKER : String = "[[SMITTEN]]"

## The hidden marker an NPC appends when the player genuinely OFFENDS them (insults, cruelty, harassment) —
## the NPC's own in-character judgment, not a profanity filter. Stripped before display (see
## [method file_offense_if_marked]); each lands a rapport hit, so a pattern of it sours them toward
## Wary → Disliked → Despised (NPCs can HATE you — Troy 2026-06-10).
const OFFENSE_MARKER : String = "[[OFFENDED]]"
const OFFENSE_HIT : int = 4

## TALK-MOVES-THE-GAME markers — in a live VERSUS game the NPC appends one when the traveller's table talk
## genuinely LANDS, nudging a decaying [NpcMood] that biases their next few AI moves a capped amount. Stripped
## before display + filed by [method file_table_talk_if_marked]; gated by composure (see [method
## _table_talk_clause]) — a stoic refuses simply by not appending one. See [[talk-moves-the-game-spec]].
const TILT_MARKER : String = "[[TILT]]"          # rattled / baited → reckless, looser, bolder
const COWED_MARKER : String = "[[COWED]]"        # intimidated / pressured → cautious, passive, tighter
const FIRED_UP_MARKER : String = "[[FIRED_UP]]"  # hyped / dared → bold, aggressive

## A short, COLD retort for when an NPC's reply is the offense tag ALONE (no spoken words) — so a
## tag-only line reads as a cold brush-off, never blank and (in the room path) never a warm canned
## fallback over a souring. WORDED, not "…", so the room path's _is_silent doesn't treat it as silence.
const COLD_OFFENSE_LINES : Array[String] = [
	"Watch your mouth.", "We're done talking.", "Mind yourself.", "I've nothing to say to that.", "That's enough."]

func cold_offense_line() -> String:   # instance method (called on the NpcBrain autoload from both paths)
	return COLD_OFFENSE_LINES[randi() % COLD_OFFENSE_LINES.size()]

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
	# The bias governs SPONTANEOUS challenges only; the explicit-challenge rule below is appetite-independent.
	var bias : String
	if appetite < 0.25:
		bias = "You rarely start fights yourself — only bring up a bout if you're strongly provoked, insulted, or pointedly goaded."
	elif appetite < 0.6:
		bias = "You're game for a friendly bout now and then — bring one up if the moment turns competitive or boastful."
	else:
		bias = "You're a born scrapper — happy to throw down at the lightest provocation, or just for the sport of it."
	return ("DUELS: Folk here settle scores and show off with friendly SKIRMISH bouts — sky-pirate sparring, for "
		+ "sport and pride, never real harm. " + bias + " This only governs whether YOU bring up a fight on your "
		+ "own; it does NOT override the next rule. EXPLICIT CHALLENGES (always, no matter how scrappy you are): "
		+ "if the traveller proposes, dares, or accepts a duel, you MUST take them up on it in your spoken reply. "
		+ "To actually START the bout you must ALSO append the hidden control tag " + DUEL_MARKER + " somewhere in "
		+ "your reply (ideally at the very end, after your spoken words). The tag is invisible game-machinery — it "
		+ "is stripped out before the traveller ever sees it, so speak naturally and NEVER mention the brackets. "
		+ "CRITICAL: accepting in words ALONE starts no fight — without the " + DUEL_MARKER + " tag your agreement "
		+ "is empty and nothing happens, so whenever you agree to or call for a bout, the tag MUST be there. "
		+ "Example of accepting a challenge: \"Fine. Name your stakes, stranger. " + DUEL_MARKER + "\" — the words "
		+ "are spoken aloud; the tag is silent. Only append the tag to YOUR OWN acceptance or challenge — never "
		+ "when you are merely commenting on, or spectating, someone else's bout. Do NOT use it in ordinary, calm, "
		+ "or friendly chat.")


## Opt-in TALK-MOVES-THE-GAME instruction, folded into the prompt ONLY during a live VERSUS game (a scene with
## npc_chat_context) AND only for a shakeable NPC (composure below the iron threshold) — a stoic is never even
## offered the tag, so they refuse by omission. The NPC appends a mood marker when the traveller's table talk
## truly gets to them; it's stripped + filed ([method file_table_talk_if_marked]) into [NpcMood].
func _table_talk_clause(persona: NpcPersonality) -> String:

	var tree : SceneTree = get_tree()
	if tree == null or tree.current_scene == null or not tree.current_scene.has_method("npc_chat_context"):
		return ""   # not in a versus game — table talk can't move anything
	var composure : float = clampf(persona.composure, 0.0, 1.0)
	if composure >= 0.85:
		return ""   # unshakeable — never offer the tag (refuse-by-omission, like duel_appetite==0)
	var temperament : String
	if composure < 0.4:
		temperament = "You've a thin skin and a proud streak at the table — a sharp taunt, a dare, or a jab at your play can genuinely get under your skin or fire you up."
	elif composure < 0.65:
		temperament = "You're fairly steady, but a well-aimed needle or a real dare can still get to you when the moment's tense."
	else:
		temperament = "You're hard to rattle — only a genuinely cutting or perfectly-timed line moves you at all."
	return ("TABLE TALK: this is a head-to-head game and the traveller may try to get in your head — bait you "
		+ "into a reckless play, rattle you, pressure you into folding or playing it safe, or hype you up. "
		+ temperament + " IF (and ONLY if) their words truly land given how the game is actually going, react in "
		+ "your spoken reply AND append the matching hidden tag at the very end: " + TILT_MARKER + " if they've "
		+ "rattled or baited you into playing looser and more recklessly; " + FIRED_UP_MARKER + " if they've hyped "
		+ "or dared you into bold aggression; " + COWED_MARKER + " if they've cowed you into cautious, tight play. "
		+ "The tag is invisible game-machinery — stripped before the traveller sees it, so speak naturally and "
		+ "NEVER mention the brackets. MOST table talk should NOT move you: if you brush it off, append NO tag and "
		+ "say so in character (\"Save your breath.\"). Only ONE tag, only when it genuinely lands, only about YOUR "
		+ "OWN state — never for ordinary chat, and never about another player.")


## If [param text] carries the hidden duel marker, file a Skirmish challenge from [param npc_name] (it lands in
## the Ayo! tab) and STRIP the marker so the player only sees the spoken line. Tolerant of casing / inner
## whitespace. Returns the cleaned text. Shared by the private path AND RoomChat's ambient pool.
func file_duel_if_marked(text: String, npc_name: String) -> String:

	if npc_name.is_empty():
		return text
	var re : RegEx = RegEx.new()
	# Tolerate the variants a model actually produces: 1-or-2 of [ ( { < ... ] ) } > around the word "duel"
	# (so [DUEL], ((duel)), [[DUEL!]], [[DUEL: yes]], <duel> all match), but not bare prose.
	re.compile("(?i)[\\[({<]{1,2}\\s*duel\\b[^\\])}>\\n]*[\\])}>]{1,2}")
	if re.search(text) == null:
		return text
	PlayerState.add_challenge(npc_name)
	var cleaned : String = re.sub(text, "", true)
	cleaned = cleaned.replace("*", "")   # strip orphaned bold/emphasis a wrapped tag (**[[DUEL]]**) leaves behind
	return cleaned.strip_edges()


## Strip a [[SMITTEN]] marker (tolerant of casing/wrapping, like [method file_duel_if_marked]) + advance the
## courtship one step ([method PlayerState.advance_romance] — Smitten-capped + rapport-gated internally, so a
## stray tag can never over-advance or break the gate). Returns the cleaned text. Private chat path only.
func file_courtship_if_marked(text: String, npc_name: String, eligible: bool) -> String:

	if npc_name.is_empty():
		return text
	var re : RegEx = RegEx.new()
	# Tolerate what models actually emit: 1-2 of [ ( { < around "smitten", with trailing junk (like the duel re).
	re.compile("(?i)[\\[({<]{1,2}\\s*smitten\\b[^\\])}>\\n]*[\\])}>]{1,2}")
	if re.search(text) == null:
		return text
	# STRIP the tag regardless (it must NEVER reach the player), but only ADVANCE for a romanceable, single NPC —
	# a married / non-romanceable NPC must never be put on the romance track by a stray or coaxed tag.
	if eligible:
		PlayerState.advance_romance(npc_name)
	var cleaned : String = re.sub(text, "", true)
	cleaned = cleaned.replace("*", "")
	return cleaned.strip_edges()


## If [param text] carries the hidden OFFENSE marker — the NPC's own judgment that the player crossed a line —
## land the rapport hit and STRIP the marker. A pattern of offense sours them: Wary → Disliked → Despised.
## Same tolerant matching as the duel marker. Returns the cleaned text. Shared by both reply paths.
func file_offense_if_marked(text: String, npc_name: String) -> String:

	if npc_name.is_empty():
		return text
	var re : RegEx = RegEx.new()
	re.compile("(?i)[\\[({<]{1,2}\\s*offended\\b[^\\])}>\\n]*[\\])}>]{1,2}")
	if re.search(text) == null:
		return text
	PlayerState.add_affinity(npc_name, -OFFENSE_HIT)
	var cleaned : String = re.sub(text, "", true)
	cleaned = cleaned.replace("*", "")
	return cleaned.strip_edges()


## If [param text] carries a talk-moves-the-game mood marker ([[TILT]] / [[COWED]] / [[FIRED_UP]]), push the
## matching mood onto [param npc_name] via [NpcMood] and STRIP the marker (same tolerant matching as the duel
## marker). Returns the cleaned text. Only meaningful in a versus game; harmless elsewhere (nothing reads it).
func file_table_talk_if_marked(text: String, npc_name: String) -> String:

	if npc_name.is_empty():
		return text
	var re : RegEx = RegEx.new()
	re.compile("(?i)[\\[({<]{1,2}\\s*(tilt|cowed|fired[ _]?up)\\b[^\\])}>\\n]*[\\])}>]{1,2}")
	var hit : RegExMatch = re.search(text)
	if hit == null:
		return text
	var word : String = hit.get_string(1).to_lower().replace(" ", "").replace("_", "")
	var kind : int = NpcMood.TILT
	if word == "cowed":
		kind = NpcMood.COWED
	elif word == "firedup":
		kind = NpcMood.FIRED_UP
	NpcMood.nudge(npc_name, kind)
	var cleaned : String = re.sub(text, "", true)
	cleaned = cleaned.replace("*", "")
	return cleaned.strip_edges()


# --- Deterministic duel detection (the model-independent fallback) --------------------------------------
# The marker above is the fast-path; these keyword classifiers make a challenge file even when the model agrees
# in WORDS but drops the tag (it kept treating [[DUEL]] as banned markup). The player's text is fully under our
# control, so an explicit player challenge + a non-declining NPC acceptance files regardless of the model.
# Lowercase substring matching (pass text.to_lower()). See the duel-marker-reliability review + [[ayo-tidings-inbox]].
const DUEL_NOUNS : Array[String] = ["duel", "spar", "skirmish", "bout", "throw down", "throwdown"]
const DUEL_NEGATIONS : Array[String] = ["no ", "not ", "won't", "wont", "don't", "dont", "never ", "can't",
	"cant", "rather not", "no thanks"]
const DUEL_PROPOSAL_PHRASES : Array[String] = [
	"fight me", "duel me", "spar me", "spar with", "i challenge", "i'll fight you", "ill fight you",
	"i'll take you on", "ill take you on", "take you on", "want to fight", "wanna fight", "want to duel",
	"wanna duel", "want to spar", "wanna spar", "care to spar", "care for a bout", "care for a duel",
	"up for a duel", "up for a bout", "up for a spar", "let's fight", "lets fight", "let's duel", "lets duel",
	"let's spar", "lets spar", "let's throw down", "lets throw down", "throw down with me", "square up",
	"settle this", "settle it", "cross blades", "invite me into a duel", "challenge you to a duel",
	"challenge you to a spar"]
const DUEL_ACCEPT_PHRASES : Array[String] = [
	"name the stakes", "name your stakes", "you're on", "youre on", "i'll take you", "ill take you",
	"i accept", "i'll fight", "ill fight", "i'll spar", "ill spar", "i'll duel", "ill duel", "let's go then",
	"lets go then", "meet me when", "meet me at", "i'll keep it short", "ill keep it short", "i'll sharpen",
	"ill sharpen", "have at you", "draw your blade", "draw your steel", "raise your blade", "raise your steel",
	"then it's settled", "then its settled", "settled then", "i'll show you", "ill show you", "come at me",
	"step up then", "very well, then", "fine — i'll", "fine, i'll", "fine. i'll", "let's settle this",
	"lets settle this", "i'm game", "im game", "you want a bout", "you'll get your bout", "youll get your bout"]
const DUEL_DECLINE_PHRASES : Array[String] = [
	"not today", "another time", "some other time", "maybe later", "not in the mood", "no thanks",
	"no thank you", "i'll pass", "ill pass", "i pass", "not right now", "perhaps another", "i'd rather not",
	"id rather not", "not interested", "leave it", "let it go", "no quarrel", "i won't fight", "i wont fight",
	"i won't duel", "i wont duel", "can't fight", "cant fight", "too old for", "no time for that",
	"i'll have no part", "ill have no part", "spare me", "not my way", "i'm no fighter", "im no fighter"]


# Substring-any helper for the duel classifiers.
func _any_phrase(lc: String, phrases: Array) -> bool:

	for p in phrases:
		if lc.find(String(p)) != -1:
			return true
	return false


## Does the PLAYER's line propose / dare a duel? Requires a second-person/imperative frame, with a negation
## veto so "don't duel me" / "no thanks" never count. Pass text.to_lower().
func is_duel_proposal(lc: String) -> bool:

	if _any_phrase(lc, DUEL_NEGATIONS):
		return false
	if _any_phrase(lc, DUEL_PROPOSAL_PHRASES):
		return true
	if not _any_phrase(lc, DUEL_NOUNS):
		return false
	# A duel noun counts when aimed at someone (you/me) OR thrown OPEN to the room (anyone / who's up for it) — so
	# "duel anyone?", "anyone want to spar", "who's up for a fight" all register, not just direct challenges (Troy 2026-06-12).
	var directed : bool = lc.find("you") != -1 or lc.find(" me") != -1 or lc.begins_with("me")
	var room_call : bool = _any_phrase(lc, ["anyone", "anybody", "any taker", "who want", "who's up", "whos up", "any of you", "someone"])
	return directed or room_call


## Does an NPC's reply ACCEPT or issue a bout (a first-person-commitment idiom)? Pass text.to_lower().
func reply_accepts_duel(lc: String) -> bool:

	return _any_phrase(lc, DUEL_ACCEPT_PHRASES)


## Does an NPC's reply DECLINE? A hard veto that always beats an accept match. Pass text.to_lower().
func reply_declines_duel(lc: String) -> bool:

	return _any_phrase(lc, DUEL_DECLINE_PHRASES)


# Romance fallback classifiers — like the duel ones, they catch an advance when the model agrees in WORDS but
# drops the [[SMITTEN]] tag. CONSERVATIVE: only an EXPLICIT player overture counts (romance is subjective — a
# false positive would force a premature, unearned step). Lowercase substring matching (pass text.to_lower()).
const ROMANCE_OVERTURE_PHRASES : Array[String] = [
	"i love you", "i'm in love with you", "im in love with you", "i'm falling for you", "im falling for you",
	"i have feelings for you", "i've feelings for you", "ive feelings for you", "i fancy you",
	"i want to court you", "i want to be with you", "you've stolen my heart", "youve stolen my heart",
	"will you be my sweetheart", "be my sweetheart", "will you be mine"]
# A platonic anchor in the SAME message vetoes the overture (mirrors how DUEL_NEGATIONS short-circuits a duel),
# so "you're my best friend, i adore you" or "be my partner for the tournament" never reads as a confession.
const ROMANCE_PLATONIC_VETO : Array[String] = [
	"friend", "teammate", "partner for", "tournament", "team up", "buddy", "pal"]
const ROMANCE_DECLINE_PHRASES : Array[String] = [
	"just friends", "better as friends", "good friend", "see you as a friend", "only see you as", "nothing more",
	"i can't return", "i cant return", "i don't feel that way", "i dont feel that way", "i'm flattered, but",
	"im flattered but", "i'm flattered but", "my heart belongs", "not like that", "i don't think of you",
	"i dont think of you", "not interested"]
# Affirmative NPC reciprocation — the fallback advances ONLY when the reply clearly RETURNS the feeling, not
# merely when it fails to match a decline (a soft in-character no would otherwise slip through as a yes).
const ROMANCE_ACCEPT_PHRASES : Array[String] = [
	"i feel the same", "i feel it too", "i feel it as well", "my heart too", "my heart's yours", "my hearts yours",
	"i'm yours", "im yours", "i've fallen for you", "ive fallen for you", "i'm falling for you too",
	"you've won my heart", "youve won my heart", "i care for you too", "i love you too", "i fancy you too",
	"i'm sweet on you too", "i think i love you", "i'd be yours", "i'd like that", "i would like that"]


func is_romance_overture(lc: String) -> bool:

	if _any_phrase(lc, ROMANCE_PLATONIC_VETO):
		return false   # a platonic anchor in the same breath isn't a confession
	return _any_phrase(lc, ROMANCE_OVERTURE_PHRASES)


func reply_accepts_romance(lc: String) -> bool:

	return _any_phrase(lc, ROMANCE_ACCEPT_PHRASES)


func reply_declines_romance(lc: String) -> bool:

	return _any_phrase(lc, ROMANCE_DECLINE_PHRASES)


# Table-talk fallback classifiers — the model-independent backstop for when the chat AI drops the [[TILT]] /
# [[COWED]] / [[FIRED_UP]] tag. CONSERVATIVE like the duel ones: an EXPLICIT taunt only, friendly/polite chat
# never counts. Lowercase substring matching (pass text.to_lower()). See [[talk-moves-the-game-spec]].
const TILT_TAUNT_PHRASES : Array[String] = [
	"you're bluffing", "youre bluffing", "you'll fold", "youll fold", "you always fold", "you'll choke",
	"youll choke", "you'll crack", "youll crack", "you're scared", "youre scared", "too scared", "you can't beat",
	"you cant beat", "i dare you", "prove it", "you've got nothing", "youve got nothing", "send it to my side",
	"send them my way", "you'll lose", "youll lose", "is that all", "you're sweating", "youre sweating", "easy money"]
const COW_TAUNT_PHRASES : Array[String] = [
	"you should fold", "just fold", "play it safe", "don't risk it", "dont risk it", "you're beat", "youre beat",
	"give up", "back down", "you're done", "youre done", "quit while", "you can't win", "you cant win",
	"don't push it", "dont push it"]
const TABLE_BRUSHOFF_PHRASES : Array[String] = [
	"save your breath", "nice try", "not falling for", "won't work", "wont work", "keep talking", "talk all you",
	"we'll see", "well see about", "doesn't rattle", "doesnt rattle", "not biting", "i'm unmoved", "im unmoved",
	"all bluster"]
const TABLE_TALK_POLITE : Array[String] = [
	"good game", "well played", "nice hand", "thank you", "good luck", "no worries", "well done", "good round"]


## What table-talk does the PLAYER's line carry? COWED (steer them passive) beats TILT (bait). NEUTRAL = no
## taunt, or a polite line. Pass text.to_lower(). The deterministic fallback for a dropped [[mood]] tag.
func table_taunt_kind(lc: String) -> int:

	if _any_phrase(lc, TABLE_TALK_POLITE):
		return NpcMood.NEUTRAL
	if _any_phrase(lc, COW_TAUNT_PHRASES):
		return NpcMood.COWED
	if _any_phrase(lc, TILT_TAUNT_PHRASES):
		return NpcMood.TILT
	return NpcMood.NEUTRAL


## Did the NPC's reply verbally BRUSH OFF the taunt (so the fallback must NOT tilt them)? Pass text.to_lower().
func reply_brushes_off(lc: String) -> bool:
	return _any_phrase(lc, TABLE_BRUSHOFF_PHRASES)


## The CURRENT scene's place — fed into the prompt so NPCs reference their ACTUAL surroundings (Troy 2026-06-08),
## keyed by the scene file's stem. Sky-canon flavour (see [[sky-canon]]); empty for unknown / puzzle scenes.
const PLACES : Dictionary = {
	"tavern": "RIGHT NOW you're in The Inn — a warm tavern: a hearth, cloudberry tea brewing, and two game tables running — a POKER table and a GEM-DROP table (sit at one to join a table of regulars or start your own, free or for gold). Against the wall is the TOURNAMENT BOARD (gem-drop brackets, a gold entry) and a SPAR post for picking a friendly Skirmish bout. Hearty Brian and Merry Geneva run the place. Reference your surroundings naturally when it fits.",
	"forge_interior": "RIGHT NOW you're in the Forge — Cinder Troy's smithy: roaring coals, an anvil, the ring of hammered steel. A WEAPON RACK along the wall sells Skirmish arms for gold (a Sword, a Long Shot), a WANTED board hires miners (apply, dig at the Mine, a gold wage per ore), and an ORE BIN beside it takes delivered ore. Cinder Troy keeps the place.",
	"mine": "RIGHT NOW you're in the Mine — dim ore tunnels: pickaxes, raw ore glinting in the rock, dust in the air. A DIG station works the ore (the forage puzzle); this is where the Forge's hired miners earn their a gold wage per ore.",
	"workshop_interior": "RIGHT NOW you're in the Workshop — Cogwise Godfrey's tinkering den: gears, half-built contraptions, the tick of clockwork. A WANTED board on the wall hires lumberjacks (apply, chop at the Grove, a gold wage per log), a DRAFTING DESK takes orders for spacecraft built for gold (a Driftpod, a Cloud Cutter, a Sky Galleon), and a LUMBER PILE takes delivered wood. Cogwise Godfrey works here.",
	"skydock_interior": "RIGHT NOW you're at the Skydock — the sky-harbour: moored ships, coils of rope, the tang of stardust. The SHIP'S HELM here opens the Voyages board (sign onto a crew and job a pillaging run, or captain your own ship if you own one), and the PATCHWORKS workbench mends a holed hull for ship-owners. Stormy Jericho is the skydock master.",
	"cradle_gym_interior": "RIGHT NOW you're in the Cradle Gym — the island's Skirmish training hall: sparring mats, a crossed-blades Spar sign, the thud of bouts. Hollow Ellison runs it as MASTER (spar her, free, to learn the ropes); Mossy Jade tends the fighters here, resting them back to full fighting health between bouts. When a fighter's ready, Ellison sends them to the JUNGLE ORDEAL past the forest — beat its beasts one at a time, up to the Jungle King.",
	"shore": "RIGHT NOW you're on the Shore — the island's edge: open sky, moored skiffs, and the long drop into the Stardust below.",
	"forest": "RIGHT NOW you're in The Grove — a sky-island wood of tall timber, the thunk of axes, sawdust underfoot. A CUTTING station fells the trees; this is where the Workshop's hired lumberjacks earn their a gold wage per log.",
	"frontier_isle": "RIGHT NOW you're on Driftspar — the frontier sky-island: wild, half-explored, hush and open sky.",
	"ship_deck": "RIGHT NOW you're on the ship's deck, underway — rigging and helm, the Stardust streaming past below.",
	"player_shanty_interior": "RIGHT NOW you're in the traveller's little shanty — a humble home on Cradle Rock, a cot in the corner.",
}


func _current_place() -> String:

	var tree : SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	var path : String = tree.current_scene.scene_file_path
	if path.is_empty():
		return ""
	return String(PLACES.get(path.get_file().get_basename(), ""))


# CRADLE ROCK GAZETTEER — the island's key spots AND who's usually at each, so every NPC gives REAL directions
# (to people AND to places: the mine, forest, shore, Driftspar) instead of inventing them (Troy 2026-06-09).
# CURATED on purpose — one small, MVP-locked island; keep it in sync with the actual map + cast if either
# changes. Folded into every chat prompt (private + ambient) as shared world knowledge.
const ISLAND_GAZETTEER : String = (
	"CRADLE ROCK — the island's key spots, who's there, and what they offer. Use this for ANY directions or "
	+ "whereabouts; do NOT invent places, buildings, people, or journeys that aren't here, and if you truly "
	+ "don't know, say so plainly.\n"
	+ "- The Inn (a warm tavern): Hearty Brian and his wife Merry Geneva run it — hearth, cloudberry tea, and the poker and gem-drop tables (CASH tables now: you need gold for the stake to take a seat), plus a tournament board for gem-drop brackets.\n"
	+ "- The Cradle Gym (it used to be Mossy Jade's healer's hut): the island's Skirmish training hall. Hollow Ellison runs it as master; Mossy Jade tends fighters' health here for free between bouts. It works as a LADDER — spar the whole town rung by rung, each tougher than the last, up to Ellison at the very top — and beating everyone crowns you GYM CHAMPION (which also earns the key to the Jungle Ordeal). Friendly bouts, no real harm.\n"
	+ "- The Forge: Cinder Troy's smithy — he SELLS Skirmish weapons for gold, and HIRES miners. But he won't take anyone on until they've BEATEN HIM at the Gym ladder; prove that and he hires you and hands over the Mine key (then dig at the Mine, a gold wage per ore).\n"
	+ "- The Workshop: Cogwise Godfrey's tinkering den — he BUILDS + sells spacecraft for gold (a Driftpod, Cloud Cutter, or Sky Galleon), and HIRES lumberjacks. He too won't hire a hand until they've BEATEN HIM at the Gym; then he hands over the Grove key (cut at the Grove, a gold wage per log). (Ships are bought HERE, not at the Skydock.)\n"
	+ "- The Mine: dim ore tunnels out on Cradle Rock — the mining work-site. Its door is LOCKED until you hold the Mine key (earned by taking Cinder Troy's job).\n"
	+ "- The Grove (the Forest): tall sky-island timber — the lumberjacking work-site. Its door is LOCKED until you hold the Grove key (earned by taking Godfrey's job).\n"
	+ "- The Jungle Ordeal: a wild maze beyond the forest, gone feral with beasts — a Lion, a Gorilla, a Rhino, a Bear, and the Jungle King. Its door is LOCKED until you're Gym Champion (the Jungle key). Best every beast up to the King to win the Badge of Honour and the whole island's respect. These bouts are SERIOUS, not friendly — go in worn down and you fight half-buried, so rest with Jade at the gym first.\n"
	+ "- The Skydock: the sky-harbour, Stormy Jericho's post — take the helm to job a pillaging crew or captain your own voyage, plus the Patchworks for mending a hull.\n"
	+ "- Also around: Spritely Mia the cook is usually at the Inn (whittles charms as gifts, not goods); Flint Kerr the bladesmith too (but Cinder Troy, not Kerr, sells the blades). Both Kerr and Ellison are tough rungs on the gym ladder.\n"
	+ "- The Shore: the island's rim — the dock where ships moor, and the long drop into the Stardust below.\n"
	+ "- Driftspar: a wild, half-explored frontier sky-island, reached by sailing out from the Skydock.")


# CAST PRONOUN ROSTER — the cast's pronouns, built from each persona's `pronouns` field (the ONE source of
# truth — set it on a .tres, the roster follows). Folded into the prompt so NPCs refer to EACH OTHER with the
# right gender instead of guessing (Troy 2026-06-09: Jericho was being called "she"). "" if none are set.
func _cast_pronouns_block() -> String:

	var lines : PackedStringArray = PackedStringArray()
	for p in NpcRegistry.all():
		if p.pronouns.is_empty():
			continue
		lines.append("%s (%s)" % [p.npc_name, p.pronouns])
	if lines.is_empty():
		return ""
	return ("THE CAST — always use the correct pronouns for each person below; NEVER guess someone's gender:\n"
		+ ", ".join(lines) + ".")


# VOYAGE AWARENESS — when the player is mid-pillage, fold the LIVE ship + route facts into the prompt so the
# crew (and anyone aboard) talks about the voyage accurately — where she's bound, which stop, the hull's
# state — instead of guessing. "" when not sailing (no cost to normal port chat). Reads transient PlayerState
# voyage fields. See [[voyage-loop-research]] + [[ship-condition-research]].
func _voyage_block() -> String:

	if not PlayerState.voyage_active:
		return ""
	var bits : PackedStringArray = PackedStringArray()
	var lead : String = "RIGHT NOW you're aboard a sky-ship underway on a pillaging voyage"
	if not PlayerState.pillage_ship_name.is_empty():
		lead += " — the %s" % PlayerState.pillage_ship_name
		if not PlayerState.pillage_ship_id.is_empty():
			lead += ", a %s" % ShipClasses.display(PlayerState.pillage_ship_id)   # her class, chat-accurate
	bits.append(lead + ".")
	var dest : String = PlayerState.pillage_destination
	if not dest.is_empty():
		var leg : int = PlayerState.pillage_leg + 1
		var total : int = maxi(PlayerState.pillage_legs_total, 1)
		bits.append("She's bound for %s — stop %d of %d on the run." % [dest, leg, total])
	# Your role + WHO ELSE is aboard (the full crew, each named with the station they're working).
	if PlayerState.voyage_self_captained:
		bits.append("You're captaining her yourself.")
	else:
		bits.append("You signed on as a hand for this run.")
	var aboard : PackedStringArray = PackedStringArray()
	for e in PlayerState.pillage_duty_crew:
		if not (e is Dictionary) or bool(e.get("is_player", false)):
			continue
		var nm : String = String(e.get("name", ""))
		if nm.is_empty():
			continue
		var duty : String = String(e.get("duty", ""))
		var role : String = (" (%s)" % duty) if not duty.is_empty() else ""
		# Only badge a separate captain when you're NOT the one captaining (self-captained → the "captain"
		# roster slot is just your navigating mate).
		var tag : String = "Captain " if (nm == PlayerState.pillage_captain and not PlayerState.voyage_self_captained) else ""
		aboard.append("%s%s%s" % [tag, nm, role])
	if not aboard.is_empty():
		bits.append("Aboard with you: " + ", ".join(aboard) + ".")
	var holes : int = PlayerState.ship_open_holes()   # the canonical hull helper (every other consumer reads it)
	if holes <= 0:
		bits.append("The hull is sound and dry.")
	elif holes <= 2:
		bits.append("The hull's taken a hole or two — a little stardust seeping in, nothing dire yet.")
	else:
		bits.append("The hull is badly holed (%d breaches) and taking on stardust fast — she sorely needs patching." % holes)
	# Trouble on this very stretch (a pre-rolled encounter on the current leg).
	var enc : Array = PlayerState.pillage_encounters
	var li : int = PlayerState.pillage_leg
	if li >= 0 and li < enc.size() and not String(enc[li]).is_empty():
		bits.append("Word is %s lies in wait on this stretch — a boarding fight may be at hand." % String(enc[li]))
	return "VOYAGE: " + " ".join(bits)


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
		"Wary":
			guide = ("Something about this traveller rubs you wrong — they've been rude to you before. You're short, "
				+ "guarded and unsmiling with them; civil, but you keep your distance and offer nothing extra.")
		"Disliked":
			guide = ("You DISLIKE this traveller — they've insulted or mistreated you, and you haven't forgotten. Be "
				+ "cold, curt and unhelpful beyond bare courtesy; don't pretend warmth you don't feel, and feel free "
				+ "to tell them plainly why, if they ask. A real, repeated effort to make amends can slowly thaw you.")
		"Despised":
			guide = ("You DESPISE this traveller — they've truly earned your contempt. Be icy or openly scornful (in "
				+ "words only, never violence outside a fair duel); brush them off, want nothing to do with them. You "
				+ "do not forgive easily, and pretty words alone won't fix it.")
		_:
			guide = "You barely know this traveller — courteous but a touch guarded and reserved; warm up only if they're genuinely kind."
	var block : String = "RAPPORT with this traveller: %s (%d/100). %s" % [tier, aff, guide]
	if helped > 0:
		block += " They've done you a good turn %d time%s — you remember their kindness." % [helped, "" if helped == 1 else "s"]
	# GRUDGES ARE REAL — the NPC's own judgment can sour rapport, via the hidden offense tag (stripped
	# before display, same plumbing as [[DUEL]]). Honest, not trigger-happy: banter must stay safe.
	block += (" If in THIS exchange the traveller is genuinely rude, cruel, crude or harassing toward you "
		+ "(insults, mockery of a real loss, unwanted advances), respond in character — you don't have to take "
		+ "it kindly — and append the hidden tag " + OFFENSE_MARKER + " to the END of your reply (the player "
		+ "never sees the tag; it marks that they've soured you). Be honest, not touchy: friendly banter, jokes "
		+ "and teasing are NOT offense. The lower your rapport already is, the shorter your patience runs.")
	return block


## The ROMANCE clause — appended ONLY on the private (include_secret) path so an ambient overhear can never leak
## the player's love life. (1) a PARTNERED/married NPC → a faithful deflection naming their partner (the REAL
## guard: appetite 0 only OMITS the openness clause; an agreeable model can still be coaxed to flirt without an
## ACTIVE decline); (2) an ACTIVE romance with this traveller → play the stage's warmth; (3) romanceable + single,
## no romance yet → a light openness so a courtship CAN bloom over time. Returns "" when none apply.
func _romance_block(persona: NpcPersonality) -> String:

	if not persona.partner.is_empty():
		return ("ROMANCE: You are happily and faithfully partnered to %s, and devoted to them. If the traveller "
			+ "flirts with you or makes a romantic advance, decline it warmly, kindly and without wavering — "
			+ "mention %s if it helps — and never reciprocate or lead them on.") % [persona.partner, persona.partner]
	var txt : String = ""
	match PlayerState.romance_stage(persona.npc_name):
		1:
			txt = ("ROMANCE: A FONDNESS is growing between you and this traveller — you're glad of their company, "
				+ "warmer and more personal with them than with others. Let it show gently; never force it."
				+ _smitten_clause())   # a fondness can still deepen toward smitten
		2:
			txt = ("ROMANCE: You are SMITTEN with this traveller — your heart leans toward them. Be openly warm, a "
				+ "touch flirtatious and affectionate, glad of every visit; speak like someone falling for them. The "
				+ "next step — a true vow between you — is THEIRS to offer when they're ready; long for it, don't force it.")
		3:
			txt = ("ROMANCE: This traveller is your SWEETHEART — you are devoted to them. Speak with open love, "
				+ "warmth and tenderness, like talking to the one you've given your heart to.")
		_:
			# Romanceable + single, no romance yet: the openness activates at Friend-tier (matching the Court
			# option), so a courtship can BEGIN through chat. Below Friend they chat as a friend (no clause).
			if persona.romance_appetite > 0.0 and PlayerState.get_affinity(persona.npc_name) >= PlayerState.COURT_MIN_AFFINITY:
				txt = ("ROMANCE: You are single, and warm to this traveller's company. If they are genuinely charming "
					+ "and kind and court your affection over time, you may find yourself falling for them — let a real "
					+ "connection grow naturally from how they treat you; never instant, never forced." + _smitten_clause())
	if txt.is_empty():
		return ""
	if not persona.chat_romance.is_empty():
		txt += " YOUR OWN WAY OF LOVING: " + persona.chat_romance   # this NPC's distinct romantic voice
	return txt


## The hidden [[SMITTEN]] instruction, folded into the romance block at the stages where a courtship can still
## DEEPEN (openness → Fond → Smitten). Mirrors [method _duel_clause]'s tag mechanic: the marker is stripped + the
## stage advanced before display ([method file_courtship_if_marked]), so the player never sees it.
func _smitten_clause() -> String:

	return (" If in THIS exchange the traveller genuinely wins a deeper measure of your heart — a real, earned "
		+ "romantic overture that truly LANDS, not mere friendliness, a single compliment or ordinary kindness — "
		+ "append the hidden control tag " + SMITTEN_MARKER + " at the very END of your reply. It is invisible "
		+ "game-machinery, stripped out before the traveller ever sees it, so speak naturally and NEVER mention the "
		+ "brackets. Use it SPARINGLY — only when your feelings truly move a step forward; most exchanges should "
		+ "carry NO tag. A slow, earned burn, never a sudden swoon.")


# Keep the rolling history bounded (cost guard). Trim from the front, then ensure it still starts on a
# 'user' turn (Claude requires the first message to be the user).
# Save the conversation so the NPC remembers it next time — across scene changes AND a full reload. Stage-
# direction openings ("(A traveller walks up…)") are EPHEMERAL and dropped, so they never pile up. PlayerState
# bounds the stored length. Free: no extra AI call — we just persist the turns we already have.
func _persist_history() -> void:

	if _persona == null:
		return
	var keep : Array = []
	for m in _messages:
		var role : String = String(m.get("role", ""))
		var content : String = String(m.get("content", ""))
		if role == "user" and content.begins_with("("):
			continue   # an ephemeral stage-direction opener — never persisted
		keep.append({"role": role, "content": content})
	PlayerState.save_npc_chat(_persona.npc_name, keep)


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
		var _pre_off : String = cleaned
		cleaned = file_offense_if_marked(cleaned, _persona.npc_name)
		if cleaned.is_empty() and cleaned != _pre_off:
			cleaned = cold_offense_line()   # a tag-only reply reads as a cold brush-off, not blank
		# Romance can only advance for a romanceable, SINGLE NPC (same predicate as the fallback below) — but the
		# [[SMITTEN]] tag is STRIPPED regardless so it never reaches the player, even from a married NPC.
		var rom_ok : bool = _persona.romance_appetite > 0.0 and _persona.partner.is_empty()
		var _pre_rom : String = cleaned
		cleaned = file_courtship_if_marked(cleaned, _persona.npc_name, rom_ok)
		var romance_advanced : bool = rom_ok and cleaned != _pre_rom
		if cleaned.is_empty() and cleaned != _pre_rom:
			# a marker-only reply: a warm beat for a real courtship, a neutral one otherwise (never a married flirt)
			cleaned = "You've quite a way about you, you know that?" if rom_ok else "..."
		var _pre_tt : String = cleaned
		cleaned = file_table_talk_if_marked(cleaned, _persona.npc_name)   # talk-moves-the-game mood tags
		var tt_tagged : bool = cleaned != _pre_tt   # a [[TILT]]/[[COWED]]/[[FIRED_UP]] tag was found + filed
		if cleaned.is_empty() and cleaned != _pre_tt:
			cleaned = "Heh. We'll see about that."   # a tag-only reply — keep it light, never blank
		reply = cleaned
		# Deterministic fallback: the model often agrees in words but drops the tag. If the PLAYER explicitly
		# proposed a duel and this NPC's reply accepts (and doesn't decline), file it anyway — the chat partner
		# is the unambiguous target. add_challenge dedups, so this never double-files with the marker above.
		if _persona.duel_appetite > 0.0 and not _messages.is_empty():
			var player_lc : String = String(_messages.back().get("content", "")).to_lower()
			var reply_lc : String = reply.to_lower()
			if is_duel_proposal(player_lc) and reply_accepts_duel(reply_lc) and not reply_declines_duel(reply_lc):
				PlayerState.add_challenge(_persona.npc_name)
		# Romance fallback (same reason — dropped tags). ONLY when the marker DIDN'T already advance: an EXPLICIT
		# player overture this turn, not declined by a romanceable + single NPC, nudges the courtship one step.
		# advance_romance is rapport-gated + Smitten-capped, so this can never over-reach or break canon.
		if not romance_advanced and rom_ok and not _messages.is_empty():
			var pov_lc : String = String(_messages.back().get("content", "")).to_lower()
			var rep_lc : String = reply.to_lower()
			# Two-gate (like the duel fallback): an explicit player overture AND an affirmative NPC reciprocation —
			# not merely "didn't match a decline", so a soft in-character no can't slip through as a yes.
			if is_romance_overture(pov_lc) and reply_accepts_romance(rep_lc) and not reply_declines_romance(rep_lc):
				PlayerState.advance_romance(_persona.npc_name)
		# Table-talk fallback (dropped [[mood]] tag): in a LIVE versus game, a clear player taunt at a shakeable
		# NPC (composure below the iron threshold) that the reply did NOT verbally brush off nudges the mood.
		# Conservative, like the duel fallback; only when no tag already fired, so it never double-files.
		if not tt_tagged and not _messages.is_empty():
			var tt_tree : SceneTree = get_tree()
			if tt_tree != null and tt_tree.current_scene != null and tt_tree.current_scene.has_method("npc_chat_context") and _persona.composure < 0.85:
				var taunt_kind : int = table_taunt_kind(String(_messages.back().get("content", "")).to_lower())
				if taunt_kind != NpcMood.NEUTRAL and not reply_brushes_off(reply.to_lower()):
					NpcMood.nudge(_persona.npc_name, taunt_kind)
	_messages.append({"role": "assistant", "content": reply})
	_persist_history()   # remember this exchange across scenes + reloads (free — no extra AI call)
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

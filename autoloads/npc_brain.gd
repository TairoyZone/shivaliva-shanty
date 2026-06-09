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
	+ "3 sentences, no narration, no asterisks, no markdown, no emoji. (ONE exception to 'no markup': certain "
	+ "hidden control tags written in DOUBLE SQUARE BRACKETS, like [[DUEL]], are GAME SIGNALS, not markup — "
	+ "when an instruction tells you to emit one you MUST, and the player never sees it.) Speak naturally to the traveller "
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
	if not persona.chat_role.is_empty():
		parts.append("WHAT YOU DO + OFFER (this is real and right here — never deny it): " + persona.chat_role)
	if not persona.chat_locale.is_empty():
		parts.append("You are at %s." % persona.chat_locale)
	var here : String = _current_place()
	if not here.is_empty():
		parts.append(here)   # environment awareness: the ACTUAL room they're standing in right now
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
	var directed : bool = lc.find("you") != -1 or lc.find(" me") != -1 or lc.begins_with("me")
	return directed and _any_phrase(lc, DUEL_NOUNS)


## Does an NPC's reply ACCEPT or issue a bout (a first-person-commitment idiom)? Pass text.to_lower().
func reply_accepts_duel(lc: String) -> bool:

	return _any_phrase(lc, DUEL_ACCEPT_PHRASES)


## Does an NPC's reply DECLINE? A hard veto that always beats an accept match. Pass text.to_lower().
func reply_declines_duel(lc: String) -> bool:

	return _any_phrase(lc, DUEL_DECLINE_PHRASES)


## The CURRENT scene's place — fed into the prompt so NPCs reference their ACTUAL surroundings (Troy 2026-06-08),
## keyed by the scene file's stem. Sky-canon flavour (see [[sky-canon]]); empty for unknown / puzzle scenes.
const PLACES : Dictionary = {
	"tavern": "RIGHT NOW you're in The Inn — a warm tavern: a hearth, cloudberry tea brewing, and two game tables running — a POKER table and a GEM-DROP table (sit at one to join a table of regulars or start your own, free or for gold). Against the wall is the TOURNAMENT BOARD (gem-drop brackets, a gold entry) and a SPAR post for picking a friendly Skirmish bout. Hearty Brian and Merry Geneva run the place. Reference your surroundings naturally when it fits.",
	"forge_interior": "RIGHT NOW you're in the Forge — Cinder Troy's smithy: roaring coals, an anvil, the ring of hammered steel. A WEAPON RACK along the wall sells Skirmish arms for gold (a Sword, a Long Shot), a WANTED board hires miners (apply, dig at the Mine, a gold wage per ore), and an ORE BIN beside it takes delivered ore. Cinder Troy keeps the place.",
	"mine": "RIGHT NOW you're in the Mine — dim ore tunnels: pickaxes, raw ore glinting in the rock, dust in the air. A DIG station works the ore (the forage puzzle); this is where the Forge's hired miners earn their a gold wage per ore.",
	"workshop_interior": "RIGHT NOW you're in the Workshop — Cogwise Godfrey's tinkering den: gears, half-built contraptions, the tick of clockwork. A WANTED board on the wall hires lumberjacks (apply, chop at the Grove, a gold wage per log), a DRAFTING DESK takes orders for spacecraft built for gold (a Driftpod, a Cloud Cutter, a Sky Galleon), and a LUMBER PILE takes delivered wood. Cogwise Godfrey works here.",
	"skydock_interior": "RIGHT NOW you're at the Skydock — the sky-harbour: moored ships, coils of rope, the tang of stardust. The SHIP'S HELM here opens the Voyages board (sign onto a crew and job a pillaging run, or captain your own ship if you own one), and the PATCHWORKS workbench mends a holed hull for ship-owners. Stormy Jericho is the skydock master.",
	"healers_hut_interior": "RIGHT NOW you're in the Healer's Hut — Mossy Jade's herb-room: drying plants overhead, poultices, a quiet green calm. It's a place of rest and remedies, not trade — no shop or service to buy here, just Jade's care.",
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
	+ "- The Inn (a warm tavern): Hearty Brian and his wife Merry Geneva run it — hearth, cloudberry tea, the poker and gem-drop tables (sit to play a hand, free or for gold), a tournament board for gem-drop brackets, and a Spar post for friendly bouts.\n"
	+ "- The Forge: Cinder Troy's smithy — he SELLS Skirmish weapons for gold and HIRES miners at his Wanted board (dig at the Mine, a gold wage per ore).\n"
	+ "- The Mine: dim ore tunnels — where folk dig ore; the work-site for the Forge's mining job.\n"
	+ "- The Grove (the Forest): tall sky-island timber — where wood is cut; the work-site for the Workshop's lumberjacking job.\n"
	+ "- The Skydock: the sky-harbour, Stormy Jericho's post — take the helm to job a pillaging crew or captain your own voyage, plus the Patchworks for mending a hull. (Ships are BOUGHT at the Workshop, not here.)\n"
	+ "- The Workshop: Cogwise Godfrey's tinkering den — he HIRES lumberjacks at his Wanted board (cut at the Grove, a gold wage per log) and BUILDS + sells spacecraft for gold at his drafting desk.\n"
	+ "- The Healer's Hut and gardens: Mossy Jade's green refuge of herbs and flowers — care and remedies, nothing for sale.\n"
	+ "- Also AT THE INN: Spritely Mia the cook (whittles charms as gifts, not goods); Flint Kerr the bladesmith + keenest scrapper (the one to Spar — but Cinder Troy, not Kerr, sells the blades); and Hollow Ellison the loremaster + long-range duelist by the fire (good for a story, or a hard Spar if pressed).\n"
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
	var holes : int = PlayerState.voyage_open_holes
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
		# Deterministic fallback: the model often agrees in words but drops the tag. If the PLAYER explicitly
		# proposed a duel and this NPC's reply accepts (and doesn't decline), file it anyway — the chat partner
		# is the unambiguous target. add_challenge dedups, so this never double-files with the marker above.
		if _persona.duel_appetite > 0.0 and not _messages.is_empty():
			var player_lc : String = String(_messages.back().get("content", "")).to_lower()
			var reply_lc : String = reply.to_lower()
			if is_duel_proposal(player_lc) and reply_accepts_duel(reply_lc) and not reply_declines_duel(reply_lc):
				PlayerState.add_challenge(_persona.npc_name)
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

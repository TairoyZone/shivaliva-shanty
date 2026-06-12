## RoomChat — AMBIENT scene-wide NPC chat (the "living room" layer). When the player speaks PUBLICLY in the
## chat box, the NPCs PRESENT in the scene may pipe up. A free main-thread HEURISTIC picks responders; the
## LLM (via NpcBrain's shared transport) writes the lines through a small pool of HTTPRequests, staggered.
##
## THREE kinds of player line:
##  • NAME-MENTION ("Kerr, ...")        → that NPC is FORCED to answer (no silence).
##  • ROOM-ADDRESS (a question, or "everyone/anyone/hello/how is...") → a couple of present NPCs reliably
##    answer (no silence; at least one is guaranteed) — you spoke TO the room, the room answers.
##  • OVERHEARD remark                  → NPCs may react or stay quiet (the (silent) gate), weighted by
##    personality/affinity/proximity/topic — silence is a fine, common, cheap outcome.
##
## A rolling ROOM TRANSCRIPT is fed into every reply so NPCs respond IN CONTEXT (and never repeat) + can
## riff on what was just said. The private 1-on-1 "Chat" ([ChatBox.start_private_chat]) is untouched.
## Designed via a 4-agent workflow + adversarial review (2026-06-09). FEEL KNOBS: AMBIENT_BASE + ROOM_ADDRESS_BONUS.
extends Node


const POOL_SIZE : int = 3              # concurrent LLM calls cap (hard cost ceiling)
const MAX_RESPONDERS : int = 2         # responders per OVERHEARD line (a room-address gets +1; names are exempt)
const AMBIENT_BASE : float = 0.35      # baseline reply chance for an overheard line (raised — the room felt dead)
const AMBIENT_MAX : float = 0.92
const ROOM_ADDRESS_BONUS : float = 0.45  # added when you clearly address the room (a question / greeting)
const NPC_COOLDOWN_MS : int = 6000     # an NPC that just spoke is off the rolled pool this long (a name / room-address can still pull them)
const CONTINUATION_MS : int = 18000    # a recently-spoken NPC keeps answering your plain follow-ups (no re-naming needed) — conversational continuity
const DUEL_PROPOSAL_MS : int = 18000   # after the player dares the room, an NPC reply that ACCEPTS within this files a duel (the marker-independent fallback)
const ROOM_DEBOUNCE_MS : int = 1800    # ignore a fresh OVERHEARD line within this of the last (anti-spam; names/room-address bypass)
const NEAR_RANGE : float = 240.0       # px; within this ≈ max proximity weight
const MIN_CHARS : int = 3
const TRANSCRIPT_MAX : int = 10        # rolling room memory fed into each reply (so they don't repeat / respond in context)
const BANTER_CHAINS : bool = false     # (vestigial flag — banter now emerges for free from the shared transcript + stagger)

# --- AMBIENT UNPROMPTED REMARKS (Troy 2026-06-12) — NPCs pipe up on their OWN: observant, personality-gated.
# See [[ambient-npc-remarks]]. The gates keep it sparse + cheap: most ticks fire NO LLM call at all.
const AMBIENT_TICK_MS : int = 8000          # how often we even CONSIDER an unprompted remark (a cheap check, not a call)
const AMBIENT_GAP_MIN_MS : int = 20000      # randomized global pacing between actual remarks (the room breathes)
const AMBIENT_GAP_MAX_MS : int = 45000
const AMBIENT_NPC_COOLDOWN_MS : int = 40000 # an NPC won't self-remark again this soon (a name / room-address can still pull them)
const AMBIENT_QUIET_MS : int = 7000         # wait this long after ANY spoken line before piping up unprompted (don't barge in)
const AMBIENT_BASE_CHANCE : float = 0.6     # base fire chance once the gap elapses, scaled by chattiness — silence stays the default

## Tiny per-NPC interest keywords → a topic nudge (the smith perks up at "blade"). Cheap liveliness.
const INTERESTS : Dictionary = {
	"Flint Kerr": ["blade", "sword", "ore", "forge", "steel", "duel", "spar", "sharp"],
	"Cinder Troy": ["forge", "fire", "coal", "iron", "metal", "craft", "smith"],
	"Hearty Brian": ["inn", "ale", "drink", "food", "room", "rest", "hearth", "warm"],
	"Merry Geneva": ["inn", "gossip", "cards", "game", "drink", "back room"],
	"Spritely Mia": ["charm", "whittle", "carve", "wood", "trinket", "sky", "adventure", "little"],
	"Mossy Jade": ["plant", "garden", "flower", "herb", "grow", "green", "soil"],
	"Cogwise Godfrey": ["gear", "contraption", "invent", "machine", "cog", "tinker", "fix"],
	"Stormy Jericho": ["ship", "sail", "voyage", "stardust", "crew", "captain", "pillage", "sky"],
	"Hollow Ellison": ["letter", "old days", "lonely", "far", "quiet", "long-range", "gone"],
}

var _pool : Array = []                 # [{http, busy, npc, persona, token, answer, fallback, using_direct, thinking}]
var _cooldowns : Dictionary = {}       # npc_name -> Time.get_ticks_msec() when they last spoke
var _transcript : Array = []           # [{speaker, text}] rolling room conversation, capped
var _scene_token : int = 0             # bumped on scene change → invalidates in-flight + staggered work
var _last_scene : Node = null
var _last_overheard_ms : int = -100000
var _last_proposal_ms : int = -100000   # when the player last dared the room to a duel (arms the accept-fallback window)
var _queue : Array = []                # responders waiting their TURN — fired one at a time so each sees the prior reply (awareness)
var _last_ambient_ms : int = -100000   # when an unprompted remark last fired (global pacing)
var _last_ambient_check_ms : int = 0   # throttles the per-frame ambient consideration to AMBIENT_TICK_MS
var _ambient_gap : int = 30000         # the current randomized gap until the next allowed unprompted remark


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS   # replies should resolve even if a menu paused the tree
	for _i in POOL_SIZE:
		var h : HTTPRequest = HTTPRequest.new()
		h.timeout = 20.0
		add_child(h)
		var slot : Dictionary = {"http": h, "busy": false, "npc": null, "persona": null, "token": -1,
			"answer": false, "fallback": [], "using_direct": false, "thinking": null, "ambient": false}
		h.request_completed.connect(_on_slot_done.bind(slot))
		_pool.append(slot)


# Bump the scene token + cancel stale in-flight + reset the room memory on ANY scene change (not only when
# the player next speaks) — so an old room's reply can never leak, and a new room is a fresh conversation.
func _process(_delta: float) -> void:

	_check_scene()
	_maybe_ambient_remark()


## THE ENTRY POINT — ChatBox calls this on the PUBLIC speak path. May wake present NPCs.
func hear(line: String) -> void:

	if not NpcBrain.ai_enabled:
		return
	_check_scene()
	var text : String = line.strip_edges()
	if text.is_empty():
		return
	var present : Array = _present_npcs()
	if present.is_empty():
		return
	var lc : String = text.to_lower()
	if NpcBrain.is_duel_proposal(lc):
		_last_proposal_ms = Time.get_ticks_msec()   # arm the duel-accept fallback window (see _on_slot_done)
	var mentioned : Dictionary = _mentioned_set(lc, present)
	var room_address : bool = _is_room_address(lc)
	# Substance + debounce gates — bypassed by a name-mention OR a clear room-address (those always engage).
	if mentioned.is_empty() and not room_address:
		if text.length() < MIN_CHARS:
			return
		var now : int = Time.get_ticks_msec()
		if now - _last_overheard_ms < ROOM_DEBOUNCE_MS:
			return
		_last_overheard_ms = now
	_record("Traveller", text)   # the player's line goes into the room memory (context for every reply)
	_last_overheard_ms = Time.get_ticks_msec()   # ANY player line (addressed or overheard) re-arms the ambient quiet gate
	var responders : Array = _select(present, mentioned, room_address, lc)
	if responders.is_empty():
		return
	var others : PackedStringArray = PackedStringArray()
	for e in present:
		others.append(_short(e["persona"].npc_name))
	_dispatch(responders, others, _scene_token)


# THE UNPROMPTED PATH — called every frame; mostly a no-op. When the gates open, ONE present NPC (weighted by
# chattiness + charisma + proximity) may make a brief, observant remark on their own. Hidden-info-safe + cheap:
# the probability roll happens BEFORE any LLM call, so most ticks cost nothing. See [[ambient-npc-remarks]].
func _maybe_ambient_remark() -> void:

	if not NpcBrain.ai_enabled:
		return
	var tree : SceneTree = get_tree()
	if tree == null or tree.paused or tree.current_scene == null:
		return   # don't blurt over a pause menu / modal, or with no scene
	if ChatBox != null and (ChatBox.is_typing() or ChatBox.is_log_open()):
		return   # the player has the chat bar open / is composing — let them drive, don't barge a bubble in
	var now : int = Time.get_ticks_msec()
	if now - _last_ambient_check_ms < AMBIENT_TICK_MS:
		return
	_last_ambient_check_ms = now
	if now - _last_ambient_ms < _ambient_gap:
		return   # global pacing — the room only breathes so often
	if _any_busy() or not _queue.is_empty():
		return   # a real conversation is live — don't pile on
	if now - _last_overheard_ms < AMBIENT_QUIET_MS:
		return   # someone spoke a beat ago — let the quiet settle first
	var present : Array = _present_npcs()
	if present.is_empty():
		return
	var player : Node = _player_node()
	# Pick ONE candidate, weighted by chattiness/charisma/proximity/affinity (randomized so it's not always the same).
	var best : Dictionary = {}
	var best_w : float = 0.0
	for e in present:
		var persona : NpcPersonality = e["persona"]
		var nm : String = persona.npc_name
		if _in_flight(nm):
			continue
		if now - int(_cooldowns.get(nm, -100000)) < AMBIENT_NPC_COOLDOWN_MS:
			continue
		var w : float = _ambient_weight(persona, e["node"], player) * randf()
		if w > best_w:
			best_w = w
			best = {"node": e["node"], "persona": persona, "answer": false, "chance": 1.0}
	if best.is_empty():
		return
	# Final gate: even chosen, a remark only fires sometimes (chattiness-scaled). Reset the pacing either way.
	var chosen : NpcPersonality = best["persona"]
	var fire_chance : float = AMBIENT_BASE_CHANCE * clampf(chosen.chattiness, 0.0, 1.0)   # no floor — a low-chattiness NPC approaches silence
	_last_ambient_ms = now
	_ambient_gap = randi_range(AMBIENT_GAP_MIN_MS, AMBIENT_GAP_MAX_MS)
	if randf() > fire_chance:
		return   # stayed quiet this round (paced, so we don't re-roll instantly next tick)
	var others : PackedStringArray = PackedStringArray()
	for e in present:
		others.append(_short(e["persona"].npc_name))
	_cooldowns[chosen.npc_name] = now   # reserve the self-remark cooldown up front, so even a (silent) ambient reply still paces them
	_queue.append({"r": best, "others": others, "token": _scene_token, "ambient": true})
	_pump()


# How likely this NPC is the one to pipe up unprompted — chatty, charming, near + liked souls hold the floor.
func _ambient_weight(persona: NpcPersonality, node: Node, player: Node) -> float:

	var w : float = 0.15 + persona.chattiness
	w += 0.20 * persona.charisma
	w += 0.15 * _proximity01(node, player)
	w += 0.10 * _affinity01(persona.npc_name)
	return w


func _check_scene() -> void:

	var tree : SceneTree = get_tree()
	var sc : Node = tree.current_scene if tree != null else null
	if sc != _last_scene:
		_last_scene = sc
		_scene_token += 1
		_last_ambient_ms = Time.get_ticks_msec()   # a fresh room waits a beat before anyone pipes up unprompted
		_transcript.clear()   # a new room = a fresh conversation
		_queue.clear()        # drop any responders still waiting their turn from the old room
		for slot in _pool:
			if slot["busy"]:
				slot["http"].cancel_request()
			slot["busy"] = false
			slot["npc"] = null
			slot["persona"] = null


# Present, chat-capable NPCs in the current scene (a node group + a resolvable persona).
func _present_npcs() -> Array:

	var out : Array = []
	var tree : SceneTree = get_tree()
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("npc"):
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var persona : NpcPersonality = _persona_for(n)
		if persona != null:
			out.append({"node": n, "persona": persona})
	return out


func _persona_for(npc_node: Node) -> NpcPersonality:

	if not ("npc_name" in npc_node):
		return null
	var nm : String = String(npc_node.npc_name)
	for p in NpcRegistry.all():
		if p.npc_name == nm:
			return p
	return null


# --- selection (free, instant) ---------------------------------------

# True when the player is clearly addressing the room (a question, or a greeting / "everyone"-style call).
func _is_room_address(lc: String) -> bool:

	if lc.find("?") != -1:
		return true
	for w in ["everyone", "anyone", "you all", "you guys", "y'all", "folks", "hello", "greetings",
			"how is", "how are", "what's up", "whats up", "good morn", "good day"]:
		if lc.find(w) != -1:
			return true
	return lc.begins_with("hi") or lc.begins_with("hey") or lc.begins_with("ahoy") or lc.begins_with("yo ")


func _mentioned_set(lc: String, present: Array) -> Dictionary:

	var out : Dictionary = {}
	for e in present:
		var nm : String = e["persona"].npc_name
		for key in _name_keys(nm):
			if _word_in(lc, key):
				out[nm] = true
				break
	return out


func _name_keys(npc_name: String) -> Array:

	var keys : Array = [npc_name.to_lower()]
	for w in npc_name.to_lower().split(" ", false):
		if w.length() >= 3:
			keys.append(w)
	return keys


# Whole-word match so "broken" doesn't fire "Brian". Names are plain letters → safe straight in the regex.
func _word_in(lc: String, key: String) -> bool:

	var re : RegEx = RegEx.new()
	if re.compile("\\b" + key + "\\b") != OK:
		return lc.find(key) != -1
	return re.search(lc) != null


func _select(present: Array, mentioned: Dictionary, room_address: bool, lc: String) -> Array:

	var now : int = Time.get_ticks_msec()
	var player : Node = _player_node()
	var plain : bool = mentioned.is_empty() and not room_address   # a continuation-style line (a reply, not a broadcast)
	var forced : Array = []
	var rolled : Array = []
	for e in present:
		var persona : NpcPersonality = e["persona"]
		var nm : String = persona.npc_name
		if _in_flight(nm):
			continue   # already answering a previous line — don't double-fire
		if mentioned.has(nm):
			forced.append({"node": e["node"], "persona": persona, "answer": true, "chance": 2.0})
			continue
		if plain and now - int(_cooldowns.get(nm, -100000)) < CONTINUATION_MS:
			# You've been talking with them — a plain follow-up CONTINUES the thread (they answer, no cooldown).
			rolled.append({"node": e["node"], "persona": persona, "answer": true, "chance": 1.5})
			continue
		if now - int(_cooldowns.get(nm, -100000)) < NPC_COOLDOWN_MS:
			continue   # recently spoke → off the rolled pool (a name-mention would have forced them above)
		var chance : float = _reply_chance(persona, e["node"], player, lc)
		if room_address:
			chance += ROOM_ADDRESS_BONUS
		if randf() <= chance:
			# A room-address responder ANSWERS (no (silent) option); an overhear MAY stay silent.
			rolled.append({"node": e["node"], "persona": persona, "answer": room_address, "chance": chance})
	rolled.sort_custom(func(a, b): return a["chance"] > b["chance"])
	var cap : int = MAX_RESPONDERS + (1 if room_address else 0)   # a greeting/question earns one extra voice
	var responders : Array = forced.duplicate()
	for r in rolled:
		if responders.size() >= cap:
			break
		responders.append(r)
	# Guarantee that addressing the room gets AT LEAST one reply (the chattiest present soul answers).
	if room_address and responders.is_empty():
		var best : Dictionary = _best_candidate(present, now, player, lc)
		if not best.is_empty():
			responders.append(best)
	return responders


func _reply_chance(persona: NpcPersonality, node: Node, player: Node, lc: String) -> float:

	# Talkativeness — now driven mostly by the real `chattiness` knob, blended with the old synth (pushy + impatient
	# + blurty) so a quiet-but-aggressive NPC still isn't silent and the reactive path matches the ambient one.
	var synth : float = 0.55 * persona.aggression + 0.30 * (1.0 - persona.patience) + 0.15 * persona.risk_tolerance
	var talk : float = clampf(0.6 * persona.chattiness + 0.4 * synth, 0.0, 1.0)
	var p : float = AMBIENT_BASE
	p += 0.45 * talk
	p += 0.18 * _affinity01(persona.npc_name)
	p += 0.15 * _proximity01(node, player)
	if _hits_interest(persona.npc_name, lc):
		p += 0.22
	p += randf_range(-0.06, 0.06)
	return clampf(p, 0.0, AMBIENT_MAX)


# The most-likely present NPC to answer (off-cooldown, not in-flight) — used to guarantee a room-address reply.
func _best_candidate(present: Array, now: int, player: Node, lc: String) -> Dictionary:

	var best : Dictionary = {}
	var best_c : float = -1.0
	for e in present:
		var nm : String = e["persona"].npc_name
		if _in_flight(nm) or now - int(_cooldowns.get(nm, -100000)) < NPC_COOLDOWN_MS:
			continue
		var c : float = _reply_chance(e["persona"], e["node"], player, lc)
		if c > best_c:
			best_c = c
			best = {"node": e["node"], "persona": e["persona"], "answer": true, "chance": c}
	return best


func _affinity01(npc_name: String) -> float:

	return clampf(float(PlayerState.get_affinity(npc_name)) / 100.0, 0.0, 1.0)


func _proximity01(node: Node, player: Node) -> float:

	if player == null or not (node is Node2D) or not (player is Node2D):
		return 0.5
	var d : float = (node as Node2D).global_position.distance_to((player as Node2D).global_position)
	return clampf(1.0 - d / (NEAR_RANGE * 3.0), 0.0, 1.0)


func _hits_interest(npc_name: String, lc: String) -> bool:

	for k in INTERESTS.get(npc_name, []):
		if lc.find(String(k)) != -1:
			return true
	return false


# --- dispatch (one TURN at a time, so each responder sees the prior reply → real awareness) ----------

func _dispatch(responders: Array, others: PackedStringArray, token: int) -> void:

	for r in responders:
		_queue.append({"r": r, "others": others, "token": token, "ambient": false})
	_pump()


# Fire the next queued responder — but only once the previous one has finished, so its reply is already in
# the transcript and the next NPC can react to it (turn-taking, not everyone barking over each other).
func _pump() -> void:

	if _any_busy() or _queue.is_empty():
		return
	var job : Dictionary = _queue.pop_front()
	if int(job["token"]) != _scene_token:
		_pump()   # stale (scene changed) — skip to the next
		return
	_fire(job["r"], job["others"], int(job["token"]), bool(job.get("ambient", false)))


func _any_busy() -> bool:

	for slot in _pool:
		if slot["busy"]:
			return true
	return false


func _fire(r: Dictionary, others: PackedStringArray, token: int, ambient := false) -> void:

	var slot : Dictionary = _free_slot()
	if slot.is_empty():
		return   # pool saturated → drop this responder (silence is always acceptable)
	var node : Node = r["node"]
	var persona : NpcPersonality = r["persona"]
	var answer : bool = r["answer"]
	slot["busy"] = true
	slot["npc"] = node
	slot["persona"] = persona
	slot["token"] = token
	slot["answer"] = answer
	slot["ambient"] = ambient
	slot["fallback"] = (node.dialog_lines if "dialog_lines" in node else [])
	# Instant "…" feedback above the NPC the moment we dispatch, so a reply never reads as dead air; the real line
	# REPLACES it (see _on_slot_done). ONLY for an ADDRESSED responder — they always resolve to a line (a reply or
	# a canned fallback). An OVERHEARD NPC shows NO dots: it speaks or stays quiet invisibly, so the player never
	# sees a "…" that resolves to nothing (Troy 2026-06-11: that "about to reply → never replies" read as broken).
	slot["thinking"] = SpeechBubble.say(node, "…") if (answer and is_instance_valid(node)) else null
	var system : String = NpcBrain.compose_system(persona, false)   # ambient: no secret, saves tokens
	var user : String = _ambient_turn(others, _short(persona.npc_name)) if ambient else _user_turn(answer, others, _short(persona.npc_name))
	var payload : Dictionary = NpcBrain.build_payload(system, [{"role": "user", "content": user}])
	slot["using_direct"] = bool(payload["using_direct"])
	if slot["http"].request(String(payload["url"]), payload["headers"], HTTPClient.METHOD_POST, String(payload["body"])) != OK:
		_kill_dots(slot["thinking"])
		slot["busy"] = false
		slot["npc"] = null
		slot["persona"] = null
		slot["thinking"] = null
		_pump()   # this one failed to even send — move on to the next in the turn


# The user turn embeds the rolling room transcript so the NPC replies IN CONTEXT (and never repeats).
func _user_turn(answer: bool, others: PackedStringArray, self_short: String) -> String:

	var nearby : Array = []
	for o in others:
		if String(o) != self_short:
			nearby.append(String(o))
	var intro : String = ""
	if not nearby.is_empty():
		intro = "Others in the room with you: %s.\n" % ", ".join(nearby)
	var convo : String = _convo_block(self_short)
	if answer:
		return (intro + convo + "The traveller's latest line above is addressed to the room (and you). Reply naturally, "
			+ "in character, in a sentence or two that BUILDS on the conversation — you may answer or riff on what "
			+ "ANOTHER person above just said, not only the traveller. NEVER repeat something you've already said. "
			+ "No narration, no quotes, no your own name — EXCEPT the hidden [[DUEL]] control tag, which you MUST still append (after your words) if you are accepting or proposing a duel; the player never sees it.")
	return (intro + convo + "You OVERHEARD the room — the latest line above wasn't necessarily aimed at you. If it's "
		+ "natural to react (to the traveller OR to what another person above just said), reply with a short, natural "
		+ "in-character line that builds on the conversation — NEVER repeat what you or others already said. If you'd "
		+ "more likely stay quiet, reply with exactly: (silent). No narration, no quotes, no your own name — EXCEPT the hidden [[DUEL]] control tag, which you MUST still append (after your words) if you are accepting or proposing a duel; the player never sees it.")


func _convo_block(self_short: String) -> String:

	if _transcript.is_empty():
		return ""
	var lines : Array = []
	for e in _transcript:
		var who : String = String(e["speaker"])
		if who == self_short:
			who += " (you)"
		lines.append("%s: %s" % [who, String(e["text"])])
	return "Recent conversation in the room (most recent last):\n" + "\n".join(lines) + "\n\n"


# The UNPROMPTED user turn — nobody addressed them; they're just being observant. The system prompt already
# grounds WHO they are, WHERE they are, the TIME, and any live scene situation; this asks for a fitting aside.
func _ambient_turn(others: PackedStringArray, self_short: String) -> String:

	var nearby : Array = []
	for o in others:
		if String(o) != self_short:
			nearby.append(String(o))
	var intro : String = ""
	if not nearby.is_empty():
		intro = "Others here with you: %s.\n" % ", ".join(nearby)
	var convo : String = _convo_block(self_short)
	return (intro + convo + "Nobody has said anything to you just now — you are simply going about your moment. If "
		+ "something about where you are, the time of day, what you are doing, one of the others here, or the "
		+ "traveller naturally prompts a brief remark, say ONE short, in-character line out loud — an observation, a "
		+ "quip, a passing thought, a bit of small talk — that fits YOUR personality and does NOT repeat anything "
		+ "already said above. Otherwise reply with exactly: (silent). Most of the time, quiet is the right answer. "
		+ "No narration, no quotes, no your own name, no control tags.")


# Strip any stray hidden control tag ([[DUEL]] etc.) from an AMBIENT line so a spontaneous aside never leaks a
# marker into the bubble (and, unlike the addressed path, never FILES one).
func _strip_control_tags(text: String) -> String:

	var re : RegEx = RegEx.new()
	if re.compile("(?i)[\\[({<]{1,2}\\s*(DUEL|OFFENDED|SMITTEN|TILT|COWED|FIRED_UP)\\s*[\\])}>]{1,2}") != OK:
		return text
	return re.sub(text, "", true).strip_edges()


func _on_slot_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, slot: Dictionary) -> void:

	var node : Node = slot["npc"]
	var persona : NpcPersonality = slot["persona"]
	var answer : bool = slot["answer"]
	var ambient : bool = bool(slot.get("ambient", false))
	var token : int = slot["token"]
	var fallback : Array = slot["fallback"]
	var using_direct : bool = slot["using_direct"]
	var thinking : Variant = slot["thinking"]
	# Free the slot first (so it's reusable even if we early-out below).
	slot["busy"] = false
	slot["npc"] = null
	slot["persona"] = null
	slot["thinking"] = null
	if persona == null or token != _scene_token:
		_kill_dots(thinking)
		_pump()
		return   # scene changed while in flight → drop, but keep the turn moving
	var reply : String = ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		reply = NpcBrain.parse_reply(using_direct, body).strip_edges()
		NpcBrain.note_online()
	else:
		NpcBrain.note_offline()   # surfaces the "AI offline" notice once (so canned fallbacks aren't mistaken for dumb AI)
	# File any duel challenge BEFORE the silent/empty gate — a marker-only line still issues the challenge.
	# AMBIENT remarks never file control tags (a spontaneous aside shouldn't start a duel / grudge) — just strip them.
	if ambient:
		reply = _strip_control_tags(reply)
	elif persona != null and not reply.is_empty():
		var cleaned : String = NpcBrain.file_duel_if_marked(reply, persona.npc_name)
		if cleaned.is_empty() and cleaned != reply:
			cleaned = "Reckon it's time we settled this — meet me when you're ready."   # marker-only line
		var pre_off : String = cleaned
		cleaned = NpcBrain.file_offense_if_marked(cleaned, persona.npc_name)   # grudge tag → rapport hit, stripped
		# A tag-ONLY reply strips to empty/silent. WITHOUT this, the empty-reply branch below speaks a warm
		# canned dialog_line — a friendly chirp over the exact moment they soured. Show a cold line instead.
		if cleaned != pre_off and (cleaned.is_empty() or _is_silent(cleaned)):
			cleaned = NpcBrain.cold_offense_line()
		reply = cleaned
		# Deterministic fallback: if the player recently dared the room and THIS NPC's OWN reply accepts (and
		# doesn't decline), file it — covers the model agreeing in words but dropping the tag. Per-responder, so
		# a spectator's line never files; add_challenge dedups so the marker + fallback can't double-file.
		if persona.duel_appetite > 0.0 and Time.get_ticks_msec() - _last_proposal_ms < DUEL_PROPOSAL_MS:
			var rlc : String = reply.to_lower()
			if NpcBrain.reply_accepts_duel(rlc) and not NpcBrain.reply_declines_duel(rlc):
				PlayerState.add_challenge(persona.npc_name)
	if reply.is_empty() or _is_silent(reply):
		# Addressed (name / room) → a canned line on failure (silence reads broken). Overheard → let the "…"
		# fade naturally (reads as "they considered it, stayed quiet").
		if answer and not fallback.is_empty():
			_kill_dots(thinking)
			_say(node, persona, String(fallback[randi() % fallback.size()]))
		_pump()
		return
	_kill_dots(thinking)
	_say(node, persona, reply)
	_pump()   # the next queued responder can now react to what was just said


func _say(node: Node, persona: NpcPersonality, text: String) -> void:

	if not is_instance_valid(node) or not node.is_inside_tree():
		return   # NPC gone (scene change / freed) — drop (await-after-free safety)
	SpeechBubble.say(node, text)
	PlayerState.log_event("%s: %s" % [_short(persona.npc_name), text], persona.portrait_color.lightened(0.35))
	_cooldowns[persona.npc_name] = Time.get_ticks_msec()   # cool down only when they ACTUALLY spoke (not on silence)
	_last_overheard_ms = Time.get_ticks_msec()             # any spoken line re-arms the AMBIENT_QUIET gate (no barging in right after)
	_record(_short(persona.npc_name), text)                # their line joins the room memory


func _record(speaker: String, text: String) -> void:

	_transcript.append({"speaker": speaker, "text": text})
	while _transcript.size() > TRANSCRIPT_MAX:
		_transcript.remove_at(0)


func _kill_dots(bubble: Variant) -> void:

	if bubble != null and is_instance_valid(bubble):
		bubble.queue_free()


func _is_silent(reply: String) -> bool:

	var r : String = reply.to_lower()
	return r.find("(silent)") != -1 or r == "..." or r == "…"


func _free_slot() -> Dictionary:

	for slot in _pool:
		if not slot["busy"]:
			return slot
	return {}


# Is an NPC currently mid-reply (a busy pool slot)? Keeps a follow-up line from double-firing the same NPC.
func _in_flight(npc_name: String) -> bool:

	for slot in _pool:
		if slot["busy"] and slot["persona"] != null and String(slot["persona"].npc_name) == npc_name:
			return true
	return false


func _player_node() -> Node:

	var tree : SceneTree = get_tree()
	return tree.get_first_node_in_group("player") if tree != null else null


func _short(npc_name: String) -> String:

	var parts : PackedStringArray = npc_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else npc_name

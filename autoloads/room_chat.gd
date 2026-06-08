## RoomChat — AMBIENT scene-wide NPC chat (the "living room" layer). When the player speaks PUBLICLY in the
## chat box, the NPCs PRESENT in the scene may pipe up: a free main-thread HEURISTIC picks 0–2 responders
## (personality-weighted chance; a NAME-MENTION is a forced, reliable reply), then a small pool of
## HTTPRequests fires one short LLM line each (staggered) through NpcBrain's shared transport. Silence is the
## common, free default ("they may or may not reply"). The private 1-on-1 "Chat" ([ChatBox.start_private_chat])
## is untouched. Designed via a 4-agent design workflow (2026-06-09). Autoloaded after NpcBrain + ChatBox.
##
## THE TWO FEEL KNOBS to tune in playtest: AMBIENT_BASE (room livelier/quieter) + MAX_RESPONDERS.
extends Node


const POOL_SIZE : int = 3              # concurrent LLM calls cap (hard cost ceiling)
const MAX_RESPONDERS : int = 2         # responders per general line (a name-mention is always answered, exempt)
const AMBIENT_BASE : float = 0.20      # baseline reply chance — LOW so the room is mostly quiet by default
const AMBIENT_MAX : float = 0.78       # a general line is never a guaranteed reply
const NPC_COOLDOWN_MS : int = 9000     # an NPC that just spoke is off the rolled pool this long (name-mention overrides)
const ROOM_DEBOUNCE_MS : int = 2200    # ignore a fresh general line within this of the last (anti-spam)
const STAGGER_S : float = 0.7          # gap between staggered responders, so it reads as turn-taking
const NEAR_RANGE : float = 240.0       # px; within this ≈ max proximity weight
const MIN_CHARS : int = 4              # a general line shorter than this is ignored (a name-mention bypasses)
const BANTER_CHAINS : bool = false     # v2: NPCs react to EACH OTHER's lines — wire later, flip this

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

var _pool : Array = []                 # [{http, busy, npc, persona, token, directed, fallback, using_direct}]
var _cooldowns : Dictionary = {}       # npc_name -> Time.get_ticks_msec() when they last spoke
var _scene_token : int = 0             # bumped on scene change → invalidates in-flight + staggered work
var _last_scene : Node = null
var _last_general_ms : int = -100000


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS   # replies should resolve even if a menu paused the tree
	for _i in POOL_SIZE:
		var h : HTTPRequest = HTTPRequest.new()
		h.timeout = 20.0
		add_child(h)
		var slot : Dictionary = {"http": h, "busy": false, "npc": null, "persona": null,
			"token": -1, "directed": false, "fallback": [], "using_direct": false}
		h.request_completed.connect(_on_slot_done.bind(slot))
		_pool.append(slot)


# Bump the scene token + cancel stale in-flight on ANY scene change — not only when the player next speaks
# (so an old room's reply can never pass the token guard after you've walked away in silence).
func _process(_delta: float) -> void:

	_check_scene()


## THE ENTRY POINT — ChatBox calls this on the PUBLIC speak path. May wake 0–2 present NPCs.
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
	var mentioned : Dictionary = _mentioned_set(text.to_lower(), present)
	# Substance + debounce gates (a name-mention bypasses BOTH — addressing someone always works).
	if mentioned.is_empty():
		if text.length() < MIN_CHARS:
			return
		var now : int = Time.get_ticks_msec()
		if now - _last_general_ms < ROOM_DEBOUNCE_MS:
			return
		_last_general_ms = now
	var responders : Array = _select(text, present, mentioned)
	if responders.is_empty():
		return
	var others : PackedStringArray = PackedStringArray()
	for e in present:
		others.append(_short(e["persona"].npc_name))
	_dispatch(responders, text, others, _scene_token)


# Bump the scene token + cancel stale work when the player changes scene (replies for the old room are dropped).
func _check_scene() -> void:

	var tree : SceneTree = get_tree()
	var sc : Node = tree.current_scene if tree != null else null
	if sc != _last_scene:
		_last_scene = sc
		_scene_token += 1
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


# --- selection (free, instant, the design's heart) -------------------

func _mentioned_set(line_lc: String, present: Array) -> Dictionary:

	var out : Dictionary = {}
	for e in present:
		var nm : String = e["persona"].npc_name
		for key in _name_keys(nm):
			if _word_in(line_lc, key):
				out[nm] = true
				break
	return out


# Match keys for an NPC: the full name + each ≥3-letter name word ("hearty brian" → ["hearty brian","hearty","brian"]).
func _name_keys(npc_name: String) -> Array:

	var keys : Array = [npc_name.to_lower()]
	for w in npc_name.to_lower().split(" ", false):
		if w.length() >= 3:
			keys.append(w)
	return keys


# Whole-word match so "broken" doesn't fire "Brian". Names are plain letters → safe to put straight in the regex.
func _word_in(line_lc: String, key: String) -> bool:

	var re : RegEx = RegEx.new()
	if re.compile("\\b" + key + "\\b") != OK:
		return line_lc.find(key) != -1
	return re.search(line_lc) != null


func _select(line: String, present: Array, mentioned: Dictionary) -> Array:

	var now : int = Time.get_ticks_msec()
	var line_lc : String = line.to_lower()
	var player : Node = _player_node()
	var forced : Array = []
	var rolled : Array = []
	for e in present:
		var persona : NpcPersonality = e["persona"]
		var nm : String = persona.npc_name
		if _in_flight(nm):
			continue   # already answering a previous line — don't double-fire (even on a name-mention)
		if mentioned.has(nm):
			forced.append({"node": e["node"], "persona": persona, "directed": true, "chance": 2.0})
			continue
		if now - int(_cooldowns.get(nm, -100000)) < NPC_COOLDOWN_MS:
			continue   # recently spoke → not on the rolled pool (a name-mention would have forced them above)
		var chance : float = _reply_chance(persona, e["node"], player, line_lc)
		if randf() <= chance:
			rolled.append({"node": e["node"], "persona": persona, "directed": false, "chance": chance})
	rolled.sort_custom(func(a, b): return a["chance"] > b["chance"])
	# Named NPCs always answer (exempt from the cap); fill the rest up to MAX_RESPONDERS with the top rolls.
	var responders : Array = forced.duplicate()
	for r in rolled:
		if responders.size() >= MAX_RESPONDERS:
			break
		responders.append(r)
	return responders


func _reply_chance(persona: NpcPersonality, node: Node, player: Node, line_lc: String) -> float:

	# Derived "talkativeness" — we have no extraversion field, so synthesise: pushy + impatient + blurty.
	var talk : float = clampf(0.55 * persona.aggression + 0.30 * (1.0 - persona.patience)
		+ 0.15 * persona.risk_tolerance, 0.0, 1.0)
	var p : float = AMBIENT_BASE
	p += 0.45 * talk
	p += 0.18 * _affinity01(persona.npc_name)
	p += 0.20 * _proximity01(node, player)
	if _hits_interest(persona.npc_name, line_lc):
		p += 0.22
	p += randf_range(-0.06, 0.06)
	return clampf(p, 0.0, AMBIENT_MAX)


func _affinity01(npc_name: String) -> float:

	return clampf(float(PlayerState.get_affinity(npc_name)) / 100.0, 0.0, 1.0)


func _proximity01(node: Node, player: Node) -> float:

	if player == null or not (node is Node2D) or not (player is Node2D):
		return 0.5   # neutral when we can't measure
	var d : float = (node as Node2D).global_position.distance_to((player as Node2D).global_position)
	return clampf(1.0 - d / (NEAR_RANGE * 3.0), 0.0, 1.0)


func _hits_interest(npc_name: String, line_lc: String) -> bool:

	for k in INTERESTS.get(npc_name, []):
		if line_lc.find(String(k)) != -1:
			return true
	return false


# --- dispatch (staggered LLM calls through the pool) -----------------

func _dispatch(responders: Array, line: String, others: PackedStringArray, token: int) -> void:

	var i : int = 0
	for r in responders:
		_fire_after(float(i) * STAGGER_S, r, line, others, token)
		i += 1


func _fire_after(delay: float, r: Dictionary, line: String, others: PackedStringArray, token: int) -> void:

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if token != _scene_token:
		return   # scene changed during the stagger — abandon
	_fire(r, line, others, token)


func _fire(r: Dictionary, line: String, others: PackedStringArray, token: int) -> void:

	var slot : Dictionary = _free_slot()
	if slot.is_empty():
		return   # pool saturated → drop this responder (silence is always acceptable)
	var node : Node = r["node"]
	var persona : NpcPersonality = r["persona"]
	var directed : bool = r["directed"]
	slot["busy"] = true
	slot["npc"] = node
	slot["persona"] = persona
	slot["token"] = token
	slot["directed"] = directed
	slot["fallback"] = (node.dialog_lines if "dialog_lines" in node else [])
	# A "…" thinking bubble ONLY for a DIRECTED (named) reply — an overhear that turns out (silent) should
	# leave no trace, so un-named candidates get no dots.
	if directed and is_instance_valid(node):
		SpeechBubble.say(node, "…")
	var system : String = NpcBrain.compose_system(persona, false)   # ambient: no secret, saves tokens
	var user : String = _user_turn(line, directed, others, _short(persona.npc_name))
	var payload : Dictionary = NpcBrain.build_payload(system, [{"role": "user", "content": user}])
	slot["using_direct"] = bool(payload["using_direct"])
	if slot["http"].request(String(payload["url"]), payload["headers"], HTTPClient.METHOD_POST, String(payload["body"])) != OK:
		slot["busy"] = false
		slot["npc"] = null
		slot["persona"] = null


func _user_turn(line: String, directed: bool, others: PackedStringArray, self_short: String) -> String:

	if directed:
		return ("A traveller looks at YOU and says aloud: \"%s\". Answer them directly, in character, in one or "
			+ "two short spoken sentences. No narration, no quotes, no your own name.") % line
	var nearby : Array = []
	for o in others:
		if String(o) != self_short:
			nearby.append(String(o))
	var nearby_str : String = ", ".join(nearby) if not nearby.is_empty() else "no one in particular"
	return ("You're in a room with others nearby (%s). A traveller says aloud, to the room: \"%s\". You OVERHEAR "
		+ "it — it wasn't necessarily aimed at you. If it's natural for YOU to react, reply in ONE short spoken "
		+ "sentence, in character. If you'd more likely stay quiet, reply with exactly: (silent). No narration, "
		+ "no quotes, no your own name.") % [nearby_str, line]


func _on_slot_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, slot: Dictionary) -> void:

	var node : Node = slot["npc"]
	var persona : NpcPersonality = slot["persona"]
	var directed : bool = slot["directed"]
	var token : int = slot["token"]
	var fallback : Array = slot["fallback"]
	var using_direct : bool = slot["using_direct"]
	# Free the slot first (so it's reusable even if we early-out below).
	slot["busy"] = false
	slot["npc"] = null
	slot["persona"] = null
	if persona == null or token != _scene_token:
		return   # scene changed while in flight → drop
	var reply : String = ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		reply = NpcBrain.parse_reply(using_direct, body).strip_edges()
	if reply.is_empty() or _is_silent(reply):
		# General overhear → silence (graceful). DIRECTED → a canned line (you addressed them; silence reads broken).
		if directed and not fallback.is_empty():
			_say(node, persona, String(fallback[randi() % fallback.size()]))
		return
	_say(node, persona, reply)


func _say(node: Node, persona: NpcPersonality, text: String) -> void:

	if not is_instance_valid(node) or not node.is_inside_tree():
		return   # NPC gone (scene change / freed) — drop (await-after-free safety)
	SpeechBubble.say(node, text)
	PlayerState.log_event("%s: %s" % [_short(persona.npc_name), text], persona.portrait_color.lightened(0.35))
	_cooldowns[persona.npc_name] = Time.get_ticks_msec()   # cool down only when they ACTUALLY spoke (not on silence)


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

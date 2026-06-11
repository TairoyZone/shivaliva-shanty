## Base class for every named character the player can talk to.
## Extends [Interactable] but replaces the proximity-marker tooltip with
## a PERMANENT name tag floating above the NPC (white, YPP-style; it
## brightens to gold when the player is close enough to talk). Press E
## to open dialog.
##
## `interact()` opens the [Overlay] dialog with the NPC's lines and a
## rapport-tier header, and grants a per-visit affinity bump (see
## [PlayerState]). Concrete NPCs that need unique behavior (a shopkeeper,
## a quest-giver, an NPC that rewards an item on first talk) extend this
## class. Pure-dialog NPCs only need an instance with @export values set.
@tool
class_name Npc
extends Interactable


## Rapport gained the first time the player talks to this NPC each
## visit (resets when the scene reloads, so you can't farm it by
## spamming E — leave and come back for another bump).
const TALK_AFFINITY : int = 1

## Rapport granted for completing a standing favour. Tuned DOWN 2026-05-31
## (was 15) — befriending was too fast. Favours are still the strongest
## single rapport tap (they cost real items), just not a fast track.
const FAVOR_AFFINITY : int = 8

## The 1v1 Skirmish DUEL scene — the radial menu's "Spar" launches it against THIS NPC (mirrors the
## Spar post). See [[combat-puzzle-direction]].
const SKIRMISH_DUEL_SCENE : String = "res://puzzles/skirmish/skirmish_duel.tscn"

## Standing favours, keyed by NPC name — the cozy "do a good turn first"
## rapport tap (the One Piece "earn their liking by helping" feeling). Each
## is a small ask for something the player already produces (wood/ore), and
## deliberately NOT the resource that NPC buys for gold, so a favour never
## reads as "just the job again". Completing one grants [constant
## FAVOR_AFFINITY] rapport, offered once per visit (resets on scene reload).
## NPCs absent from this table simply have no favour — data, not code, so
## giving an NPC a favour is a one-entry edit. See [[parlor-social-system]].
const NPC_FAVORS : Dictionary = {
	"Hearty Brian": {"item": "wood", "amount": 4,
		"ask": "Oh, hello there! The inn's hearth has burned down to embers — could you spare a few logs to keep it going?",
		"thanks": "Bless you! The common room'll be warm tonight. You're alright, friend."},
	"Stormy Jericho": {"item": "ore", "amount": 3,
		"ask": "Hmph. My gear's seized up and I'm an ingot's worth of ore short. ...Bring me some, would you?",
		"thanks": "...Huh. You actually came back with it. Obliged. I won't forget it."},
	"Flint Kerr": {"item": "ore", "amount": 4,
		"ask": "I'm honing a new blade and I've run clean out of good ore. Fancy fetching me a little?",
		"thanks": "Now THAT'S the stuff. Sharp as you are kind. Cheers, mate."},
	"Cinder Troy": {"item": "wood", "amount": 5,
		"ask": "The forge is starving for kindling and I can't leave the coals. Could you run me some wood?",
		"thanks": "That'll keep her roaring. Good of you — the forge and I both thank you."},
	"Cogwise Godfrey": {"item": "ore", "amount": 4,
		"ask": "I'm fitting a new bracket and I'm an ingot short. Spare a bit of ore for an old tinker?",
		"thanks": "Perfect fit. You've a knack for turning up just when you're needed. Ta."},
	"Spritely Mia": {"item": "wood", "amount": 3,
		"ask": "Ooh — I'm whittling little charms but I'm all out of wood! Could you bring me some?",
		"thanks": "Yay! I'll carve you one too, just you wait. You're the best!"},
	"Mossy Jade": {"item": "ore", "amount": 3,
		"ask": "I'm setting stones into a planter and I need a touch of ore for the bands. Help a soul out?",
		"thanks": "Lovely. It'll grow all the better for your kindness. Thank you, truly."},
	"Hollow Ellison": {"item": "wood", "amount": 4,
		"ask": "...The boards on my place are giving way. A little wood would go a long way. If you would.",
		"thanks": "...You came through. Not many do. That means more than you know. Thank you."},
}

## YPP-style name tag colors. NPC names float permanently above their
## heads in white (players would be gold/yellow). When the player is
## close enough to talk, the name brightens to gold as the "press E"
## affordance — no separate marker popup.
const NAME_TAG_COLOR : Color = Color(0.96, 0.96, 0.98, 1.0)
const NAME_TAG_NEAR_COLOR : Color = Color(0.98, 0.85, 0.40, 1.0)

@export var npc_name : String = "Stranger"
@export var dialog_lines : Array[String] = []
## Modulate applied to the NPC's iso sprite — gives each NPC a unique
## tunic / silhouette tint so they read apart at a glance.
@export var portrait_color : Color = Color(0.95, 0.74, 0.28) :
	set(value):
		portrait_color = value
		_apply_tint()

@onready var _sprite : Sprite2D = %Sprite

# True once this NPC has granted its per-visit rapport bump. Reset
# implicitly because the NPC node is rebuilt on every scene load.
var _granted_affinity_this_visit : bool = false

# Per-visit gates (reset because the Npc node is rebuilt on every scene load) so trade/favour rewards can't be farmed.
var _traded_this_visit : bool = false
var _favor_handled_this_visit : bool = false

# Open guard for the favour modal.
var _favor_modal : FavorModal = null


func _ready() -> void:

	super._ready()
	if marker_label.is_empty():
		marker_label = npc_name
	_apply_tint()
	_setup_name_tag()
	if not Engine.is_editor_hint():
		add_to_group("npc")   # so RoomChat can find present cast for ambient scene chat
		Juice.bob(self, 2.5, randf_range(1.7, 2.5))   # a gentle idle breathe; varied dur desyncs the cast
		_maybe_post_fight_banter()   # if the player just dueled THIS NPC, they greet the return with a reaction


# Repurpose the inherited proximity tooltip into a PERMANENT name tag —
# always visible, shows just the name (no "[E]" marker), white per the
# YPP convention. Runs in the editor too so names are visible while
# placing NPCs in the scene.
func _setup_name_tag() -> void:

	if _tooltip == null:
		_tooltip = get_node_or_null("Tooltip") as Label
		if _tooltip == null:
			return
	_tooltip.text = npc_name
	_tooltip.modulate = NAME_TAG_COLOR
	_tooltip.visible = true


func _apply_tint() -> void:

	if _sprite == null:
		_sprite = get_node_or_null("Sprite") as Sprite2D
		if _sprite == null:
			return
	_sprite.modulate = portrait_color


# Override the base proximity behavior: the name tag is always shown,
# so "near" just brightens it to gold (the press-E affordance) and
# "far" returns it to white. No "[E]" marker text, no show/hide.
func set_tooltip_visible(value: bool) -> void:

	if _tooltip == null:
		return
	_tooltip.text = npc_name
	_tooltip.modulate = NAME_TAG_NEAR_COLOR if value else NAME_TAG_COLOR
	_tooltip.visible = true


func interact() -> void:

	if Engine.is_editor_hint():
		return
	# Click an NPC → a RADIAL options menu (YPP-style), NOT a dialogue box. The favour is just ONE option
	# here, never demanded to your face. See [NpcMenu] / [[Official:Communications]].
	var opts : Array = [{"label": "Chat", "action": _chat}, {"label": "Spar", "action": _challenge}]
	opts.append({"label": "Trade", "action": _open_trade})
	# A SOURED NPC (negative rapport) entrusts you with no favours — hate withholds the BONUS loop only;
	# chat/trade/spar (the core) stay open, per the parlor LAW. Make amends and the option returns.
	if NPC_FAVORS.has(npc_name) and PlayerState.get_affinity(npc_name) >= 0:
		opts.append({"label": "Favour", "action": _open_favor_modal})
	# Court → the Sweethearts romance path. Only for a ROMANCEABLE, single NPC (their .tres opts in via
	# romance_appetite, no partner) once you're at least Friends, and not once they're already your Sweetheart —
	# the AI plays the courtship out IN the chat. Married/partnered + soured + strangers never see it.
	var rom_persona : NpcPersonality = _resolve_personality()
	if rom_persona != null and rom_persona.romance_appetite > 0.0 and rom_persona.partner.is_empty() \
			and not PlayerState.is_sweetheart(npc_name):
		if PlayerState.romance_stage(npc_name) >= 2 and PlayerState.get_affinity(npc_name) >= PlayerState.VOW_MIN_AFFINITY:
			opts.append({"label": "Propose", "action": _propose})   # Smitten + Confidant → the deterministic vow
		elif PlayerState.get_affinity(npc_name) >= PlayerState.COURT_MIN_AFFINITY:
			opts.append({"label": "Court", "action": _court})
	opts.append({"label": "Profile", "action": _open_profile})
	var at : Vector2 = get_global_transform_with_canvas().origin + Vector2(0.0, -36.0)
	NpcMenu.open(self, at, npc_name, portrait_color, opts)
	interacted.emit()


# Chat → a free-form AI CONVERSATION with this NPC (the unique hook), driven by their NpcPersonality chat
# fields via [NpcBrain]. Runs RIGHT IN THE CHAT BOX (a private "→ Name" mode) — no separate window. Grants
# the per-visit rapport bump. Falls back to the quick canned bubble if this NPC has no personality profile.
func _chat() -> void:

	var persona : NpcPersonality = _resolve_personality()
	if persona == null or not NpcBrain.ai_enabled:
		_talk()   # no profile, or AI chat switched off in Options → a quick canned line instead
		return
	if not _granted_affinity_this_visit and not npc_name.is_empty():
		PlayerState.add_affinity(npc_name, TALK_AFFINITY)
		_granted_affinity_this_visit = true
	ChatBox.start_private_chat(persona, self, dialog_lines)


## Public entry to start this NPC's private chat — used by the chat box's scope selector (pick "→ Name")
## as well as the radial Chat option.
func open_chat() -> void:

	_chat()


# Court → open this NPC's private chat as a COURTSHIP. The romance plays out IN the conversation (the AI warms
# in-character, advancing Fond → Smitten as real overtures land — see [NpcBrain._romance_block]); this option
# just makes the pursuit a clear, discoverable choice. Gated in interact() to romanceable, single, Friends+ NPCs.
func _court() -> void:

	_chat()


# Propose → the deterministic Sweetheart VOW modal (a clean player confirm, NEVER an AI call). Shown in the
# radial menu only at Smitten + Confidant; on "Aye" it makes you Sweethearts (monogamous). See [RomanceVowModal].
func _propose() -> void:

	RomanceVowModal.open(self, npc_name, portrait_color)


# This NPC's [NpcPersonality] profile, matched by name from the [NpcRegistry] (null if unlisted).
func _resolve_personality() -> NpcPersonality:

	for profile in NpcRegistry.all():
		if profile.npc_name == npc_name:
			return profile
	return null


# Talk → a flavour line floats above the NPC (a speech bubble, no dialogue box) + the per-visit rapport bump.
func _talk() -> void:

	if not _granted_affinity_this_visit and not npc_name.is_empty():
		PlayerState.add_affinity(npc_name, TALK_AFFINITY)
		_granted_affinity_this_visit = true
	var lines : Array[String] = dialog_lines if not dialog_lines.is_empty() else ["..."]
	SpeechBubble.say(self, lines[randi() % lines.size()])


# Hearts → your Hearties page (rapport with the cast), via the backpack's Hearts tab.
func _open_hearts() -> void:

	if HUD != null:
		HUD._open_inventory_tab("relationships")


# Spar → challenge THIS NPC to a 1v1 Skirmish duel. Mirrors the Spar post's launch: seat this NPC as the
# opponent (consumed by SkirmishDuel._resolve_opponent), set the return anchor next to them, change scene.
func _challenge() -> void:

	for profile in NpcRegistry.all():
		if profile.npc_name == npc_name:
			PlayerState.skirmish_opponent = profile.resource_path
			break
	PlayerState.request_spawn_at_anchor(name)
	Audio.play_sfx("whoosh")
	get_tree().change_scene_to_file(SKIRMISH_DUEL_SCENE)


# POST-FIGHT BANTER — if the player just finished a duel against THIS NPC, greet their return to the world with
# a quick reaction bubble (a sore concession if they lost, a gloat if they won). Fires ONCE per duel: the
# recent_duel dict is the live autoload ref, so marking "bantered" consumes it for every NPC. The richer,
# personality-aware acknowledgement lives in the AI chat (NpcBrain._battle_block); this is the immediate beat.
func _maybe_post_fight_banter() -> void:

	var rd : Dictionary = PlayerState.recent_duel
	if rd.is_empty() or String(rd.get("npc", "")) != npc_name or bool(rd.get("bantered", false)):
		return
	rd["bantered"] = true   # consume — mutates the shared autoload dict so it can't re-fire on a later reload
	var player_won : bool = bool(rd.get("player_won", false))
	await get_tree().create_timer(0.5).timeout   # let the scene settle so it reads as "noticing you walk back"
	if not is_instance_valid(self) or not is_inside_tree():
		return
	SpeechBubble.say(self, _banter_line(player_won))


# A canned post-fight line. [param player_won] = the player beat this NPC (so the NPC CONCEDES); else they GLOAT.
func _banter_line(player_won: bool) -> String:

	var concede : Array[String] = [
		"Gah! You bested me that round. Don't let it go to your head.",
		"...Well struck. The win was yours, fair and true.",
		"Pah — beginner's luck. I'll have you next time.",
		"You got me. Aye, you got me. Good fight, that.",
		"Hmph. Enjoy it while it lasts — I'm only just warmed up.",
	]
	var gloat : Array[String] = [
		"Ha! Better luck next time, eh?",
		"That's how it's done. Come back when you've sharpened up.",
		"A valiant effort — but that round was mine.",
		"Down you go! No shame in it; few can best me.",
		"Heh, good scrap. Train up and try me again.",
	]
	var pool : Array[String] = concede if player_won else gloat
	return pool[randi() % pool.size()]


# Open this NPC's favour offer. The modal is self-contained — it checks
# the player's inventory, spends the items, grants rapport + records the
# favour, and shows the thank-you, all on its own.
func _open_favor_modal() -> void:

	if is_instance_valid(_favor_modal):
		return
	var favor : Dictionary = NPC_FAVORS[npc_name]
	var item_id : String = String(favor["item"])
	var amount : int = int(favor["amount"])
	# Got the goods? Hand them over AS A TRADE — the favour handover IS a trade (Troy 2026-06-08). Otherwise
	# the ask/accept modal.
	if PlayerState.item_count(item_id) >= amount:
		if _favor_handled_this_visit:
			_talk()   # already helped this visit — a flavour line, not another favour grant (once-per-visit)
			return
		TradeWindow.open(self, {"npc_name": npc_name, "npc_color": portrait_color, "on_traded": _on_traded,
			"favor": {"item_id": item_id, "amount": amount, "affinity": FAVOR_AFFINITY,
				"ask": String(favor["ask"]), "thanks": String(favor["thanks"])}})
		return
	_favor_modal = FavorModal.create({
		"npc_name": npc_name,
		"item_id": item_id,
		"amount": amount,
		"ask": String(favor["ask"]),
		"thanks": String(favor["thanks"]),
		"affinity": FAVOR_AFFINITY,
		"accepted": PlayerState.has_active_favor(npc_name),
	})
	_favor_modal.closed.connect(func() -> void: _favor_modal = null)
	add_child(_favor_modal)


# Trade → the YPP-style trade window: offer goods from your bag, the NPC pays fair gold (+ a bonus for an
# item they especially want) + rapport. The favour handover routes here too. See [TradeWindow].
func _open_trade() -> void:

	var liked : String = String((NPC_FAVORS.get(npc_name, {}) as Dictionary).get("item", ""))
	TradeWindow.open(self, {"npc_name": npc_name, "npc_color": portrait_color, "liked_item": liked,
		"grant_rapport": not _traded_this_visit, "on_traded": _on_traded})


# A successful trade flips the per-visit gate so trade/favour rewards can't be farmed by re-trading this visit.
func _on_traded(was_favor: bool) -> void:

	if was_favor:
		_favor_handled_this_visit = true
	else:
		_traded_this_visit = true


# Profile → the NPC's character page (role, your rapport, bio, their favour) + the CREW recruit/rank panel.
func _open_profile() -> void:

	var persona : NpcPersonality = _resolve_personality()
	var bio : String = persona.chat_appearance if persona != null else ""
	var favor : Dictionary = {}
	if NPC_FAVORS.has(npc_name):
		var f : Dictionary = NPC_FAVORS[npc_name]
		favor = {"item": String(f["item"]), "amount": int(f["amount"]), "ask": String(f["ask"])}
	NpcProfileCard.open(self, {"npc_name": npc_name, "npc_color": portrait_color, "bio": bio, "favor": favor})


# Speaker header shown in the dialog overlay — name plus current rapport
# tier so the player can read their standing at a glance ("Hearty Brian
# · Friend"). Plain name if this NPC has no name set.
func _speaker_header() -> String:

	if npc_name.is_empty():
		return "Stranger"
	return "%s   ·   %s" % [npc_name, PlayerState.affinity_tier(npc_name)]

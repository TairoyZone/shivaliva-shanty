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
		"ask": "Ahoy! The inn's hearth is near burned down to embers — could you spare a few logs to keep it roaring?",
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

# True once this visit's favour interaction has happened (given OR
# deferred) so repeated E-presses fall back to normal dialog instead of
# re-nagging. Resets on scene reload, like _granted_affinity_this_visit.
var _favor_handled_this_visit : bool = false
# Open guard for the favour modal.
var _favor_modal : FavorModal = null


func _ready() -> void:

	super._ready()
	if marker_label.is_empty():
		marker_label = npc_name
	_apply_tint()
	_setup_name_tag()


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
	# Grant the per-visit rapport bump before showing dialog so the
	# tier line in the header reflects the new total.
	if not _granted_affinity_this_visit and not npc_name.is_empty():
		PlayerState.add_affinity(npc_name, TALK_AFFINITY)
		_granted_affinity_this_visit = true
	# Lead with a standing favour the first time this visit (then fall back
	# to normal chat for the rest of the visit, so it never nags).
	if not _favor_handled_this_visit and NPC_FAVORS.has(npc_name):
		_favor_handled_this_visit = true
		_open_favor_modal()
		interacted.emit()
		return
	var lines : Array[String] = dialog_lines if not dialog_lines.is_empty() else ["..."]
	Overlay.show_dialog(_speaker_header(), lines)
	interacted.emit()


# Open this NPC's favour offer. The modal is self-contained — it checks
# the player's inventory, spends the items, grants rapport + records the
# favour, and shows the thank-you, all on its own.
func _open_favor_modal() -> void:

	if is_instance_valid(_favor_modal):
		return
	var favor : Dictionary = NPC_FAVORS[npc_name]
	_favor_modal = FavorModal.create({
		"npc_name": npc_name,
		"item_id": String(favor["item"]),
		"amount": int(favor["amount"]),
		"ask": String(favor["ask"]),
		"thanks": String(favor["thanks"]),
		"affinity": FAVOR_AFFINITY,
		"accepted": PlayerState.has_active_favor(npc_name),
	})
	_favor_modal.closed.connect(func() -> void: _favor_modal = null)
	add_child(_favor_modal)


# Speaker header shown in the dialog overlay — name plus current rapport
# tier so the player can read their standing at a glance ("Hearty Brian
# · Friend"). Plain name if this NPC has no name set.
func _speaker_header() -> String:

	if npc_name.is_empty():
		return "Stranger"
	return "%s   ·   %s" % [npc_name, PlayerState.affinity_tier(npc_name)]

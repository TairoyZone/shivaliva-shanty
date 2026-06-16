## A BEAST GATE in the Jungle Ordeal maze — a corridor blocked by a beast. While the beast still stands the
## gate is SOLID (a child StaticBody walls the cell) and clicking it launches that beast's serious Skirmish
## bout (health stakes); win and the gate clears (collision drops, vines part) so you can pass. Placed by
## [JungleOrdeal] along the maze's solution path. Extends [Interactable] for the click-ON-target prompt.
@tool
class_name BeastGate
extends Interactable

const DUEL_SCENE : String = "res://puzzles/skirmish/skirmish_duel.tscn"
const SOLID_LAYER : int = 2   # the wall/building layer the player collides with

@export var beast_id : String = "lion"
@export_file("*.tres") var beast_path : String = ""
@export var beast_label : String = "Maned Lion"
@export var beast_color : Color = Color(0.82, 0.6, 0.26, 1.0)

var _down : bool = false
var _blocker : StaticBody2D


func _ready() -> void:

	super._ready()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	marker_label = "%s  —  fight" % beast_label
	_down = PlayerState.ordeal_defeated(beast_id)
	if not _down:
		_blocker = StaticBody2D.new()
		_blocker.collision_layer = SOLID_LAYER
		_blocker.collision_mask = 0
		var cs : CollisionShape2D = CollisionShape2D.new()
		var shape : RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(72.0, 72.0)   # fills the corridor cell so the beast bars the way
		cs.shape = shape
		_blocker.add_child(cs)
		add_child(_blocker)
	queue_redraw()


# Click the gate (while in range) → launch this beast's SERIOUS Skirmish bout; return spawns you back here.
func interact() -> void:

	if Engine.is_editor_hint() or _down:
		return
	PlayerState.skirmish_opponent = beast_path
	PlayerState.skirmish_stakes = true            # health footing + a loss docks health
	PlayerState.jungle_ordeal_pending = beast_id  # the Ordeal records the result on return
	PlayerState.request_spawn_at_anchor(name)     # come back to this gate
	Audio.play_sfx("whoosh")
	get_tree().change_scene_to_file(DUEL_SCENE)


# A cleared gate shows no prompt (nothing left to fight).
func set_tooltip_visible(value: bool) -> void:

	if _down:
		return
	super.set_tooltip_visible(value)


func _draw() -> void:

	if _down:
		_draw_cleared()
	else:
		_draw_gate()


# Standing gate — a cluster of thick vines/claws barring the corridor in the beast's hue, eyes peering through.
func _draw_gate() -> void:

	var col : Color = beast_color
	var dark : Color = col.darkened(0.55)
	for i in 5:
		var x : float = -40.0 + float(i) * 20.0
		var h : float = 80.0 - absf(float(i) - 2.0) * 6.0
		draw_rect(Rect2(x - 4.0, -h, 8.0, h), col)
		draw_rect(Rect2(x - 4.0, -h, 8.0, h), dark, false, 1.5)
		draw_circle(Vector2(x, -h * 0.55), 5.0, col.lightened(0.12))
	# A pair of watching eyes in the dark behind the bars.
	draw_circle(Vector2(-11.0, -46.0), 4.5, Color(0.99, 0.9, 0.42))
	draw_circle(Vector2(11.0, -46.0), 4.5, Color(0.99, 0.9, 0.42))
	draw_circle(Vector2(-11.0, -46.0), 2.0, Color(0.1, 0.08, 0.05))
	draw_circle(Vector2(11.0, -46.0), 2.0, Color(0.1, 0.08, 0.05))


# Cleared gate — broken vine stubs parted aside, the way open.
func _draw_cleared() -> void:

	var faded : Color = beast_color.darkened(0.35)
	faded.a = 0.55
	draw_rect(Rect2(-42.0, -22.0, 7.0, 22.0), faded)
	draw_rect(Rect2(35.0, -22.0, 7.0, 22.0), faded)
	draw_rect(Rect2(-42.0, -22.0, 7.0, 22.0), faded.darkened(0.3), false, 1.0)
	draw_rect(Rect2(35.0, -22.0, 7.0, 22.0), faded.darkened(0.3), false, 1.0)

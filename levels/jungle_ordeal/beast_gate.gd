## A BEAST GATE in the Jungle Ordeal maze — a corridor barred by a beast. The gate BLOCKS its own cell with a
## "Blocker" StaticBody (an iso-diamond the size of one tile, on the same physics layer as the maze walls), so
## it bars the corridor no matter how the maze is painted around it. This Area2D is the INTERACTABLE marker on
## it — a beast-hue banner + glowing eyes. Click it (in range) to launch the beast's serious Skirmish bout; win
## and the Blocker drops (the scene reloads with the gate beaten) so you pass. Extends [Interactable].
@tool
class_name BeastGate
extends Interactable

const DUEL_SCENE : String = "res://puzzles/skirmish/skirmish_duel.tscn"

@export var beast_id : String = "lion"
@export_file("*.tres") var beast_path : String = ""
@export var beast_label : String = "Maned Lion"
@export var beast_color : Color = Color(0.82, 0.6, 0.26, 1.0)

var _down : bool = false


func _ready() -> void:

	super._ready()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	marker_label = "%s  —  fight" % beast_label
	_down = PlayerState.ordeal_defeated(beast_id)
	# The gate bars its corridor cell (the "Blocker" StaticBody) until the beast is beaten; once down, open it.
	var blocker : Node = get_node_or_null("Blocker")
	if blocker != null:
		for c in blocker.get_children():
			if c is CollisionShape2D or c is CollisionPolygon2D:
				c.set_deferred("disabled", _down)
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


# Generous click target spanning the raised iso wall (the standing click-ON-target box is sized for a
# 1-tile figure; a beast gate is a whole raised wall, so widen it).
func contains_click(point: Vector2) -> bool:

	var local : Vector2 = point - global_position
	return absf(local.x) <= 92.0 and local.y <= 36.0 and local.y >= -150.0


func _draw() -> void:

	if _down:
		_draw_cleared()
	else:
		_draw_gate()


# Standing gate — a beast-hue banner crowning the raised wall + a glowing-eyed recess, so a gate reads
# apart from a plain tree-wall. Drawn UP from the cell's floor origin onto the raised tile.
func _draw_gate() -> void:

	var col : Color = beast_color
	var eye : Vector2 = Vector2(0.0, -92.0)
	# Soft aura in the beast's hue.
	for i in 4:
		draw_circle(eye, 14.0 + float(i) * 10.0, Color(col.r, col.g, col.b, 0.09))
	# Dark recess + a pair of glowing eyes peering from the wall.
	draw_circle(eye, 15.0, Color(0.05, 0.04, 0.03, 0.9))
	for ex in [-7.0, 7.0]:
		draw_circle(eye + Vector2(ex, -1.0), 3.6, Color(1.0, 0.9, 0.42))
		draw_circle(eye + Vector2(ex, -1.0), 1.6, Color(0.08, 0.05, 0.03))
	# A banner crowning the wall-top (pennant cut), in the beast's colour.
	var bw : float = 30.0
	var pennant : PackedVector2Array = PackedVector2Array([
		Vector2(-bw, -134.0), Vector2(bw, -134.0), Vector2(bw, -120.0), Vector2(0.0, -112.0), Vector2(-bw, -120.0)])
	draw_colored_polygon(pennant, col)
	draw_polyline(pennant + PackedVector2Array([Vector2(-bw, -134.0)]), col.darkened(0.5), 1.5)
	# Three claw-gashes either side — the beast's mark on the stone.
	for s in [-1.0, 1.0]:
		for k in 3:
			var gx : float = s * (24.0 + float(k) * 6.0)
			draw_line(Vector2(gx, -106.0), Vector2(gx + s * 5.0, -78.0), col.lightened(0.1), 2.0)


# Cleared gate — a fallen, faded banner on the open floor where the beast once barred the way.
func _draw_cleared() -> void:

	var faded : Color = beast_color.darkened(0.3)
	faded.a = 0.45
	var lying : PackedVector2Array = PackedVector2Array([
		Vector2(-26.0, -8.0), Vector2(26.0, -8.0), Vector2(20.0, 8.0), Vector2(-20.0, 8.0)])
	draw_colored_polygon(lying, faded)
	draw_polyline(lying + PackedVector2Array([Vector2(-26.0, -8.0)]), faded.darkened(0.3), 1.2)

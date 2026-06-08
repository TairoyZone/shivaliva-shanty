## THE DOCK — a wooden pier jutting off Cradle Rock's edge into the open sky, where your ship is berthed
## ([MooredShip] sits at its far end). Procedural iso plank walkway on posts, with COLLISION RAILS that fence
## the player onto the planks (open only on the island/top side, walled on the two rails + the far end so you
## can't walk off into the void). Size is tunable in the inspector (steps / step_len / plank_width) to fit the
## gap. Built 2026-06-09. See [[voyage-loop-research]].
@tool
class_name Dock
extends Node2D


const COLOR_PLANK : Color = Color(0.50, 0.35, 0.19, 1.0)
const COLOR_PLANK_DARK : Color = Color(0.34, 0.23, 0.12, 1.0)
const COLOR_POST : Color = Color(0.26, 0.17, 0.08, 1.0)
const COLOR_EDGE : Color = Color(0.19, 0.12, 0.05, 1.0)
const POST_DROP : float = 64.0

## How many plank-steps the pier runs out (tune to fit the gap).
@export var steps : int = 6:
	set(value):
		steps = maxi(1, value)
		queue_redraw()
## One plank-step OUT along the pier (iso 2:1, down-right). Bigger = longer pier.
@export var step_len : Vector2 = Vector2(54.0, 27.0):
	set(value):
		step_len = value
		queue_redraw()
## Across the pier's width (iso). Bigger = wider walkway.
@export var plank_width : Vector2 = Vector2(64.0, -32.0):
	set(value):
		plank_width = value
		queue_redraw()


func _ready() -> void:

	if Engine.is_editor_hint():
		return
	_build_walls()


# The four walkway corners: A(top/island), B(top-right), C(far), D(bottom-left).
func _corners() -> Array:

	var far : Vector2 = step_len * float(steps)
	return [Vector2.ZERO, plank_width, far + plank_width, far]


# Wall only the VOID sides (the right rail B-C + the far end C-D) so you can't walk off into the stars. The
# two ISLAND-facing edges (near A-B + left D-A) stay OPEN — fencing them was blocking the way ON from Cradle
# Rock. (If you can still slip off a side, tell me which and I'll wall it.)
func _build_walls() -> void:

	var c : Array = _corners()
	var body : StaticBody2D = StaticBody2D.new()
	body.collision_layer = 2   # "Walls" — what the player's body collides against
	body.collision_mask = 0
	add_child(body)
	for edge in [[c[1], c[2]], [c[2], c[3]]]:   # B-C (right rail) + C-D (far end) — the void sides only
		var seg : SegmentShape2D = SegmentShape2D.new()
		seg.a = edge[0]
		seg.b = edge[1]
		var cs : CollisionShape2D = CollisionShape2D.new()
		cs.shape = seg
		body.add_child(cs)


func _draw() -> void:

	var c : Array = _corners()
	var quad : PackedVector2Array = PackedVector2Array([c[0], c[1], c[2], c[3]])
	draw_colored_polygon(quad, COLOR_PLANK)
	var loop : PackedVector2Array = quad.duplicate()
	loop.append(c[0])
	draw_polyline(loop, COLOR_EDGE, 2.0)
	# Plank seams across the walk.
	for i in range(1, steps):
		var a : Vector2 = step_len * float(i)
		draw_line(a, a + plank_width, COLOR_PLANK_DARK, 1.5)
	# Support posts dropping into the void under the pier.
	for i in [1, maxi(1, steps - 2), steps]:
		var bl : Vector2 = step_len * float(i)
		var br : Vector2 = bl + plank_width
		draw_line(bl, bl + Vector2(0.0, POST_DROP), COLOR_POST, 4.0)
		draw_line(br, br + Vector2(0.0, POST_DROP), COLOR_POST, 4.0)

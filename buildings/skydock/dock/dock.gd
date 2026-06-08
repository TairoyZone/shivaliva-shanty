## THE DOCK — a wooden pier jutting off Cradle Rock's edge into the open sky, where your ship is berthed
## ([MooredShip] sits at its far end). Procedural iso plank walkway on posts. Size is tunable in the inspector
## (steps / step_len / plank_width) to fit the gap; the COLLISION that keeps the player off the void is an
## EDITABLE CollisionPolygon2D in the scene (the "Rails" StaticBody) — shape it on sight. See [[voyage-loop-research]].
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


# The four walkway corners (used by the drawn outline).
func _corners() -> Array:

	var far : Vector2 = step_len * float(steps)
	return [Vector2.ZERO, plank_width, far + plank_width, far]


# NOTE: collision is now an EDITABLE CollisionPolygon2D in dock.tscn (the "Rails" StaticBody) — shape it
# on-sight in the editor (no more guessing the iso edges in code).

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

## THE DOCK — a wooden pier jutting off Cradle Rock's edge into the open sky, where your ship is berthed
## ([MooredShip] sits at its far end). Pure scenery (procedural iso plank walkway on posts); the ship is the
## interactive part. Origin = the island-edge end; the walkway recedes down-right into the void. Built 2026-06-09.
@tool
class_name Dock
extends Node2D


const COLOR_PLANK : Color = Color(0.50, 0.35, 0.19, 1.0)
const COLOR_PLANK_DARK : Color = Color(0.34, 0.23, 0.12, 1.0)
const COLOR_POST : Color = Color(0.26, 0.17, 0.08, 1.0)
const COLOR_EDGE : Color = Color(0.19, 0.12, 0.05, 1.0)

const STEP : Vector2 = Vector2(40.0, 20.0)    # one plank-step out along the pier (iso 2:1, down-right)
const CROSS : Vector2 = Vector2(46.0, -23.0)  # across the pier's width (iso)
const STEPS : int = 5
const POST_DROP : float = 64.0


func _draw() -> void:

	var far : Vector2 = STEP * float(STEPS)
	# Walkway surface (a long iso parallelogram) + outline.
	var quad : PackedVector2Array = PackedVector2Array([Vector2.ZERO, CROSS, far + CROSS, far])
	draw_colored_polygon(quad, COLOR_PLANK)
	var loop : PackedVector2Array = quad.duplicate()
	loop.append(quad[0])
	draw_polyline(loop, COLOR_EDGE, 2.0)
	# Plank seams across the walk.
	for i in range(1, STEPS):
		var a : Vector2 = STEP * float(i)
		draw_line(a, a + CROSS, COLOR_PLANK_DARK, 1.5)
	# Support posts dropping into the void under the pier.
	for i in [1, 3, STEPS]:
		var bl : Vector2 = STEP * float(i)
		var br : Vector2 = bl + CROSS
		draw_line(bl, bl + Vector2(0.0, POST_DROP), COLOR_POST, 4.0)
		draw_line(br, br + Vector2(0.0, POST_DROP), COLOR_POST, 4.0)

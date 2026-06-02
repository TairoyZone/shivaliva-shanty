## A decorative boulder for the Mine — pure visual placeholder (no
## collision), drawn procedurally so it reads as a chunk of cavern rock.
## Scatter a few in the Mine scene. `size_variation` scales it so a
## cluster doesn't look uniform.
@tool
class_name Boulder
extends Node2D


@export_range(0.6, 1.6, 0.05) var size_variation : float = 1.0 :
	set(value):
		size_variation = value
		queue_redraw()


const COLOR_ROCK : Color = Color(0.40, 0.42, 0.48, 1.0)
const COLOR_DARK : Color = Color(0.24, 0.26, 0.31, 1.0)
const COLOR_LIGHT : Color = Color(0.58, 0.61, 0.68, 1.0)
const COLOR_VEIN : Color = Color(0.80, 0.60, 0.28, 0.9)


func _draw() -> void:

	var s : float = 34.0 * size_variation
	# Ground shadow.
	draw_circle(Vector2(0.0, 2.0), s * 0.9, Color(0, 0, 0, 0.22))
	# Rough boulder body — origin (0,0) is its base on the ground.
	var body : PackedVector2Array = PackedVector2Array([
		Vector2(-s, 0.0),
		Vector2(-s * 0.7, -s * 0.8),
		Vector2(-s * 0.1, -s * 1.05),
		Vector2(s * 0.6, -s * 0.85),
		Vector2(s, -s * 0.2),
		Vector2(s * 0.6, 0.0),
	])
	draw_colored_polygon(body, COLOR_ROCK)
	draw_polyline(body + PackedVector2Array([body[0]]), COLOR_DARK, 2.0)
	# Lit top-left facet.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-s * 0.7, -s * 0.8),
		Vector2(-s * 0.1, -s * 1.05),
		Vector2(-s * 0.2, -s * 0.45),
		Vector2(-s * 0.6, -s * 0.4),
	]), COLOR_LIGHT)
	# A faint ore vein.
	draw_line(Vector2(-s * 0.3, -s * 0.25), Vector2(s * 0.45, -s * 0.6), COLOR_VEIN, 2.4)
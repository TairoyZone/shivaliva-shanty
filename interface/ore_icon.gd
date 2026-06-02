## Procedural ore icon — small Control drawn purely via [_draw], no
## texture dependency. A rough chunk of ore: a stone body with a lit
## facet and a metallic vein. Reads as "ore" at a glance. The Mining-side
## mirror of [WoodIcon]; used in the inventory panel.
##
## Resize via [member custom_minimum_size] / Control sizing; the chunk
## fills the smallest dimension and centers within the rect.
@tool
class_name OreIcon
extends Control


const COLOR_ROCK : Color = Color(0.44, 0.46, 0.52, 1.0)
const COLOR_DARK : Color = Color(0.26, 0.28, 0.33, 1.0)
const COLOR_LIGHT : Color = Color(0.64, 0.67, 0.74, 1.0)
const COLOR_VEIN : Color = Color(0.82, 0.62, 0.28, 1.0)


func _ready() -> void:

	custom_minimum_size = Vector2(36.0, 36.0)
	tooltip_text = "Ore — raw mineral. Deliver to Cinder Troy for gold."
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _draw() -> void:

	var r : float = minf(size.x, size.y) * 0.42
	var c : Vector2 = size * 0.5
	# Rough ore chunk body.
	var body : PackedVector2Array = PackedVector2Array([
		c + Vector2(-r, r * 0.35),
		c + Vector2(-r * 0.55, -r * 0.9),
		c + Vector2(r * 0.5, -r),
		c + Vector2(r, -r * 0.1),
		c + Vector2(r * 0.55, r),
		c + Vector2(-r * 0.5, r * 0.95),
	])
	draw_colored_polygon(body, COLOR_ROCK)
	draw_polyline(body + PackedVector2Array([body[0]]), COLOR_DARK, 1.6)
	# Lit top-left facet.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.55, -r * 0.9),
		c + Vector2(r * 0.1, -r * 0.95),
		c + Vector2(-r * 0.2, -r * 0.1),
		c + Vector2(-r * 0.6, -r * 0.15),
	]), COLOR_LIGHT)
	# Gold/copper vein.
	draw_line(c + Vector2(-r * 0.4, r * 0.3), c + Vector2(r * 0.5, -r * 0.4), COLOR_VEIN,
		maxf(1.6, r * 0.18))
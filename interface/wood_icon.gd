## Procedural wood icon — small Control drawn purely via [_draw], no
## texture dependency. A log cross-section: bark rim, sapwood ring,
## heartwood face, two concentric growth rings, and a tiny pith dot in
## the middle. Reads as "wood / lumber" at any size without resorting to
## a literal stamp. Used in the [HUD] wood pouch and anywhere else a
## lumber count needs to read at a glance.
##
## Resize via [member custom_minimum_size] / Control sizing; the disc
## fills the smallest dimension and centers within the rect.
@tool
class_name WoodIcon
extends Control


const COLOR_BARK : Color = Color(0.32, 0.20, 0.10, 1.0)        # dark outer bark
const COLOR_SAPWOOD : Color = Color(0.72, 0.52, 0.30, 1.0)     # pale ring just inside bark
const COLOR_HEARTWOOD : Color = Color(0.55, 0.36, 0.18, 1.0)   # main face — warm brown
const COLOR_RING : Color = Color(0.38, 0.24, 0.10, 1.0)        # growth rings
const COLOR_PITH : Color = Color(0.28, 0.16, 0.06, 1.0)        # dark center dot


func _ready() -> void:

	custom_minimum_size = Vector2(36.0, 36.0)
	tooltip_text = "Wood — raw lumber. Deliver to Cogwise Godfrey for gold."
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _draw() -> void:

	var radius : float = minf(size.x, size.y) * 0.5
	var center : Vector2 = size * 0.5
	# Bark — dark outer rim disc.
	draw_circle(center, radius, COLOR_BARK)
	# Sapwood — slightly lighter ring just inside the bark.
	draw_circle(center, radius * 0.86, COLOR_SAPWOOD)
	# Heartwood — main warm-brown face.
	draw_circle(center, radius * 0.74, COLOR_HEARTWOOD)
	# Two concentric growth rings — thin arcs that read as a cut log.
	var ring_width : float = maxf(1.0, radius * 0.06)
	draw_arc(center, radius * 0.55, 0.0, TAU, 24, COLOR_RING, ring_width)
	draw_arc(center, radius * 0.34, 0.0, TAU, 20, COLOR_RING, ring_width)
	# Pith — small dark dot at the center.
	draw_circle(center, maxf(1.5, radius * 0.10), COLOR_PITH)
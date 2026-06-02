## Procedural gold coin — small Control drawn purely via [_draw],
## no texture dependency. Concentric gold disc with a darker rim, an
## inner embossed ring, and a center dot — reads as "coin" at any size
## without resorting to a literal letter stamp. Used in the [HUD]
## gold panel and anywhere else a coin needs to read at a glance.
##
## Resize via [member custom_minimum_size] / Control sizing; the disc
## fills the smallest dimension and centers within the rect.
@tool
class_name CoinIcon
extends Control


const COLOR_RIM : Color = Color(0.62, 0.40, 0.10, 1.0)   # dark brass rim
const COLOR_FACE : Color = Color(0.97, 0.78, 0.28, 1.0)  # bright gold face
const COLOR_HIGHLIGHT : Color = Color(1.0, 0.92, 0.55, 1.0)  # specular dot
const COLOR_STAMP : Color = Color(0.42, 0.26, 0.06, 1.0) # embossed details


func _ready() -> void:

	custom_minimum_size = Vector2(36.0, 36.0)
	tooltip_text = "Gold"
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _draw() -> void:

	var radius : float = minf(size.x, size.y) * 0.5
	var center : Vector2 = size * 0.5
	# Outer rim — a slightly darker disc behind the face.
	draw_circle(center, radius, COLOR_RIM)
	# Bright gold face.
	draw_circle(center, radius * 0.84, COLOR_FACE)
	# Specular highlight — small offset dot top-left to fake roundness.
	draw_circle(
		center + Vector2(-radius * 0.30, -radius * 0.30),
		radius * 0.18,
		COLOR_HIGHLIGHT)
	# Inner embossed ring — a thin concentric arc that reads as a
	# coin's medallion stamp without being a literal letter.
	draw_arc(center, radius * 0.52, 0.0, TAU, 28, COLOR_STAMP,
		maxf(1.5, radius * 0.10))
	# Center pip — small dot in the middle of the medallion.
	draw_circle(center, maxf(1.5, radius * 0.13), COLOR_STAMP)

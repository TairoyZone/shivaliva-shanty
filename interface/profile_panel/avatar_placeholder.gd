## Procedural placeholder avatar for the Profile page — a simple skyfarer bust
## (sky backdrop, head, rust coat, tricorne) drawn with [method _draw], no art
## assets ([[placeholder-first-preference]]). Swap for real character art later
## by replacing this node; nothing else in the profile depends on how it draws.
@tool
class_name ProfileAvatar
extends Control


const COLOR_SKY : Color = Color(0.40, 0.56, 0.70, 1.0)
const COLOR_SKY_LO : Color = Color(0.30, 0.44, 0.58, 1.0)
const COLOR_SKIN : Color = Color(0.86, 0.68, 0.52, 1.0)
const COLOR_COAT : Color = Color(0.80, 0.44, 0.20, 1.0)
const COLOR_COAT_TRIM : Color = Color(0.95, 0.80, 0.40, 1.0)
const COLOR_HAT : Color = Color(0.20, 0.14, 0.10, 1.0)


func _ready() -> void:

	resized.connect(queue_redraw)


func _draw() -> void:

	var w : float = size.x
	var h : float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var cx : float = w * 0.5

	# Sky backdrop (two bands for a hint of depth).
	draw_rect(Rect2(0.0, 0.0, w, h), COLOR_SKY)
	draw_rect(Rect2(0.0, h * 0.55, w, h * 0.45), COLOR_SKY_LO)

	# Coat / shoulders — a wide block rising from the bottom, with a trim sash.
	var coat_w : float = w * 0.70
	var coat_top : float = h * 0.64
	draw_rect(Rect2(cx - coat_w * 0.5, coat_top, coat_w, h - coat_top), COLOR_COAT)
	draw_line(Vector2(cx - coat_w * 0.42, coat_top + 6.0),
		Vector2(cx + coat_w * 0.30, h), COLOR_COAT_TRIM, 4.0)

	# Head.
	var head_r : float = w * 0.17
	var head_c : Vector2 = Vector2(cx, h * 0.50)
	draw_circle(head_c, head_r, COLOR_SKIN)

	# Tricorne hat — a broad triangle sitting over the brow.
	var brim : float = head_c.y - head_r * 0.55
	var hat_w : float = w * 0.52
	var pts : PackedVector2Array = [
		Vector2(cx - hat_w * 0.5, brim),
		Vector2(cx + hat_w * 0.5, brim),
		Vector2(cx, brim - head_r * 1.25),
	]
	draw_colored_polygon(pts, COLOR_HAT)
## Procedural placeholder tree for the Forest scene — chunky trunk with a
## leafy crown, drawn purely via [_draw]. Origin (0, 0) is at the foot
## of the trunk so y-sort places it correctly in the overworld iso flow.
##
## Per scene-per-component principle: standalone .tscn so swapping for
## pixel art later only touches this file.
@tool
class_name ForestTree
extends Node2D


const TRUNK_WIDTH : float = 16.0
const TRUNK_HEIGHT : float = 44.0
const CROWN_RADIUS : float = 48.0
const CROWN_OFFSET_Y : float = -14.0   # crown center above trunk top

## Slight per-tree variation — Forest scene sets a different size per
## instance so the grove doesn't look like clones in a line.
@export var size_variation : float = 1.0 :
	set(value):
		size_variation = clampf(value, 0.6, 1.4)
		queue_redraw()

@export var trunk_color : Color = Color(0.36, 0.22, 0.10, 1.0) :
	set(value):
		trunk_color = value
		queue_redraw()
@export var crown_color : Color = Color(0.28, 0.54, 0.24, 1.0) :
	set(value):
		crown_color = value
		queue_redraw()


func _draw() -> void:

	var s : float = size_variation
	# Trunk — narrow vertical rectangle anchored at the foot.
	var trunk_w : float = TRUNK_WIDTH * s
	var trunk_h : float = TRUNK_HEIGHT * s
	var trunk_rect : Rect2 = Rect2(
		-trunk_w * 0.5, -trunk_h, trunk_w, trunk_h)
	draw_rect(trunk_rect, trunk_color)
	draw_rect(trunk_rect, trunk_color.darkened(0.35), false, 1.4)
	# Crown — three overlapping circles for a chunky leafy silhouette.
	var crown_r : float = CROWN_RADIUS * s
	var crown_center : Vector2 = Vector2(0.0, -trunk_h + CROWN_OFFSET_Y * s)
	draw_circle(crown_center, crown_r, crown_color)
	draw_circle(
		crown_center + Vector2(-crown_r * 0.42, -crown_r * 0.22),
		crown_r * 0.62, crown_color.lightened(0.10))
	draw_circle(
		crown_center + Vector2(crown_r * 0.42, -crown_r * 0.18),
		crown_r * 0.58, crown_color.darkened(0.10))
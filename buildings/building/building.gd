## Base class for any walkable-world building. Bundles the shared
## drawing logic (rectangular wall + triangular roof + flanking
## windows) and parameterizes it via @exports — concrete variants
## (OutpostBuilding, future Doraka burrows, Trader halls, Pirate
## strongholds, Pillar-tier architecture) extend this and either tweak
## the @exports for a visual remix, or override `_draw()` entirely for
## architecturally distinct shapes (mushroom-cap roofs, etc.).
##
## Origin (0,0) is at the CENTER of the iso footprint diamond. That
## center point is what y-sort uses to decide whether the player
## renders in front of or behind the building (player.y < position.y →
## behind). Putting the origin at the center means the sort line lives
## at the building's midpoint regardless of footprint size — buildings
## of any width behave consistently against the player.
##
## Foundation collision is NOT auto-generated — each building scene
## carries its own CollisionShape2D child sized to match its walls.
## This is intentional: it keeps the size visible + editable in the
## scene editor instead of buried inside a script.
@tool
class_name Building
extends StaticBody2D


## Iso wall direction normalized: (2, -1) / sqrt(5). Same constants the
## Door uses so wall-mounted decorations all align.
const _ISO_DX : float = 0.894427
const _ISO_DY : float = -0.447214


@export var wall_width : float = 240.0
@export var wall_height : float = 140.0
@export var roof_overhang : float = 28.0
@export var roof_height : float = 72.0
@export var window_size : Vector2 = Vector2(30.0, 30.0)
## Toggle individual windows. Disable the one on the wall that hosts a
## door so the door doesn't sit on top of a window panel.
@export var window_front_left : bool = true
@export var window_front_right : bool = true

@export_group("Colors")
@export var color_walls : Color = Color(0.55, 0.40, 0.22)
@export var color_walls_outline : Color = Color(0.28, 0.18, 0.08)
@export var color_roof : Color = Color(0.35, 0.20, 0.10)
@export var color_roof_outline : Color = Color(0.18, 0.10, 0.04)
@export var color_window : Color = Color(0.85, 0.92, 1.0, 0.6)
@export var color_window_frame : Color = Color(0.45, 0.28, 0.10)


func _draw() -> void:

	# Iso placeholder: a cube-shape with two visible walls (front-left
	# in shadow, front-right in sun-light) topped with a flat diamond
	# roof. Origin (0,0) is the CENTER of the footprint diamond — the
	# front vertex sits BELOW origin (+hh) and the back vertex sits
	# ABOVE origin (-hh).
	var hw : float = wall_width * 0.5
	var hh : float = wall_width * 0.25  # iso 2:1 ratio for the footprint diamond
	# Footprint diamond corners (at ground level), centered on origin so
	# the sort line is the building's midpoint.
	var front : Vector2 = Vector2(0.0, hh)
	var right : Vector2 = Vector2(hw, 0.0)
	var back : Vector2 = Vector2(0.0, -hh)
	var left : Vector2 = Vector2(-hw, 0.0)
	# Roof diamond corners (directly above each footprint corner by wall_height).
	var roof_front : Vector2 = front + Vector2(0.0, -wall_height)
	var roof_right : Vector2 = right + Vector2(0.0, -wall_height)
	var roof_back : Vector2 = back + Vector2(0.0, -wall_height)
	var roof_left : Vector2 = left + Vector2(0.0, -wall_height)
	# Front-left wall (shadow side, slightly darker).
	draw_colored_polygon(
		PackedVector2Array([left, front, roof_front, roof_left]),
		color_walls.darkened(0.18))
	# Front-right wall (sun-lit side, base color).
	draw_colored_polygon(
		PackedVector2Array([front, right, roof_right, roof_front]),
		color_walls)
	# Roof — flat diamond on top.
	draw_colored_polygon(
		PackedVector2Array([roof_front, roof_right, roof_back, roof_left]),
		color_roof)
	# Wall outlines.
	draw_polyline(
		PackedVector2Array([left, front, right, roof_right, roof_front, roof_left, left]),
		color_walls_outline, 1.8)
	draw_line(front, roof_front, color_walls_outline, 1.8)
	# Roof outline.
	draw_polyline(
		PackedVector2Array([roof_left, roof_front, roof_right, roof_back, roof_left]),
		color_roof_outline, 1.5)
	# Windows — flat parallelograms aligned with the iso wall surface.
	# Same direction math the Door uses for its side-wall slab.
	if window_front_left:
		var fl_center : Vector2 = (left + front + roof_front + roof_left) * 0.25
		_draw_iso_window(fl_center, -1.0)
	if window_front_right:
		var fr_center : Vector2 = (front + right + roof_right + roof_front) * 0.25
		_draw_iso_window(fr_center, 1.0)


## sign_x = +1 for the right wall (slants up-right toward the back),
## sign_x = -1 for the left wall (slants up-left toward the back).
func _draw_iso_window(center: Vector2, sign_x: float) -> void:

	var hax : float = window_size.x * 0.5 * _ISO_DX * sign_x
	var hay : float = window_size.x * 0.5 * _ISO_DY
	var half_h : float = window_size.y * 0.5
	var bc : Vector2 = center + Vector2(-hax, -hay + half_h)
	var bf : Vector2 = center + Vector2(hax, hay + half_h)
	var tf : Vector2 = center + Vector2(hax, hay - half_h)
	var tc : Vector2 = center + Vector2(-hax, -hay - half_h)
	draw_colored_polygon(PackedVector2Array([bc, bf, tf, tc]), color_window)
	draw_polyline(PackedVector2Array([bc, bf, tf, tc, bc]), color_window_frame, 1.5)

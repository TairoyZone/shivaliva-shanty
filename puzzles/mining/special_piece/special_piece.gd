## A special tool piece on the Mining board — the reskin of YPP
## Foraging's five special pieces. A 1x1 piece that never matches and
## cannot be rotated as part of a 2x2; instead the cursor shrinks to 1x1
## over it and a click activates it (then it is consumed). Specials
## appear more often the bigger your clears, and they exist to free
## chunks that have wedged themselves into the rock.
##
##   PICKAXE  (Foraging shovel)    — clears the whole column BELOW it
##   DRILL    (Foraging machete)   — clears the row to the LEFT or RIGHT
##   CAVE_IN  (Foraging monkey)    — blasts the 5x5 around it; everything
##                                   above collapses down into the void
##   TREMOR   (Foraging earthquake)— shifts the WHOLE board one cell L/R
##   SEEPAGE  (Foraging ant)       — auto-eats the tile it faces each move;
##                                   click to re-aim; dies on its countdown
##                                   or when it hits a wall / hole / chunk
##
## Standalone scene per the scene-per-component principle. The board owns
## placement; this scene only draws itself. See [[mining-spec]].
@tool
class_name SpecialPiece
extends Node2D


enum SpecialKind { PICKAXE, DRILL, CAVE_IN, TREMOR, SEEPAGE }

## Seepage facing — index into MiningBoard.ANT_DIRS. 0=up 1=right 2=down 3=left.
enum Facing { UP, RIGHT, DOWN, LEFT }


## MUST match MiningBoard.CELL.
const CELL : float = 44.0
const PAD : float = 3.0


## Plate accent color + label per kind.
const KIND_STYLE : Dictionary = {
	SpecialKind.PICKAXE: { "accent": Color(1.0, 0.58, 0.20, 1.0), "label": "Pickaxe" },
	SpecialKind.DRILL: { "accent": Color(0.32, 0.82, 0.92, 1.0), "label": "Drill" },
	SpecialKind.CAVE_IN: { "accent": Color(0.74, 0.46, 0.92, 1.0), "label": "Cave-In" },
	SpecialKind.TREMOR: { "accent": Color(0.52, 0.86, 0.46, 1.0), "label": "Tremor" },
	SpecialKind.SEEPAGE: { "accent": Color(0.88, 0.42, 0.30, 1.0), "label": "Seepage" },
}


@export var special_kind : SpecialKind = SpecialKind.PICKAXE :
	set(value):
		special_kind = value
		queue_redraw()

## Seepage-only state (ignored by the other kinds). The board reads/writes
## these as the ant eats + is re-aimed.
@export var facing : Facing = Facing.DOWN :
	set(value):
		facing = value
		queue_redraw()
@export var charges : int = 5 :
	set(value):
		charges = value
		queue_redraw()

## Set true by the board while the cursor frames this tool — pops its NAME
## label so the player knows what it does (Troy 2026-06-15). Bumps z so the
## label + token draw above neighbouring tiles.
var framed : bool = false :
	set(value):
		if framed == value:
			return
		framed = value
		z_index = 4 if value else 0
		queue_redraw()


func label() -> String:
	return KIND_STYLE[special_kind]["label"]


func _draw() -> void:

	var style : Dictionary = KIND_STYLE[special_kind]
	var accent : Color = style["accent"]
	var centre : Vector2 = Vector2(CELL, CELL) * 0.5
	var radius : float = (CELL - 2.0 * PAD) * 0.5
	# Accent-COLOURED token so each tool reads as its own colour at a glance,
	# with a soft glow, a dark inset for the white icon to pop against, and a
	# bright rim — far more legible than the old near-identical steel discs.
	draw_circle(centre, radius + 1.5, Color(accent.r, accent.g, accent.b, 0.22))
	draw_circle(centre, radius, accent.darkened(0.30))
	draw_circle(centre, radius * 0.80, Color(0.10, 0.11, 0.14, 1.0))
	draw_arc(centre, radius - 1.0, 0.0, TAU, 28, accent.lightened(0.30), 2.5)
	match special_kind:
		SpecialKind.PICKAXE:
			_draw_pickaxe(centre, radius)
		SpecialKind.DRILL:
			_draw_drill(centre, radius)
		SpecialKind.CAVE_IN:
			_draw_cave_in(centre, radius)
		SpecialKind.TREMOR:
			_draw_tremor(centre, radius)
		SpecialKind.SEEPAGE:
			_draw_seepage(centre, radius, accent)
	if framed:
		_draw_name_label(centre, accent)


# A floating name pill above the token (shown while the cursor frames it) so
# the player can read which tool it is and learn what it does.
func _draw_name_label(centre: Vector2, accent: Color) -> void:

	var font : Font = ThemeDB.fallback_font
	if font == null:
		return
	var txt : String = label().to_upper()
	var fs : int = 13
	var tw : float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pill : Rect2 = Rect2(centre.x - tw * 0.5 - 7.0, -23.0, tw + 14.0, 19.0)
	draw_rect(pill, Color(0.05, 0.06, 0.09, 0.96), true)
	draw_rect(pill, accent, false, 1.5)
	draw_string(font, Vector2(centre.x - tw * 0.5, pill.position.y + 14.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.97, 0.86, 1.0))


# A pick: a curved double head with a handle dropping to the lower-right.
func _draw_pickaxe(centre: Vector2, radius: float) -> void:

	var r : float = radius * 0.66
	var head : PackedVector2Array = PackedVector2Array([
		centre + Vector2(-r, r * 0.2),
		centre + Vector2(-r * 0.4, -r * 0.5),
		centre + Vector2(0.0, -r * 0.62),
		centre + Vector2(r * 0.4, -r * 0.5),
		centre + Vector2(r, r * 0.2),
		centre + Vector2(r * 0.7, r * 0.34),
		centre + Vector2(0.0, -r * 0.2),
		centre + Vector2(-r * 0.7, r * 0.34),
	])
	draw_colored_polygon(head, Color(0.92, 0.94, 0.98, 1.0))
	draw_line(centre + Vector2(0.0, -r * 0.2), centre + Vector2(r * 0.45, r * 0.85),
		Color(0.6, 0.42, 0.24, 1.0), radius * 0.18)


# A drill: a horizontal double-headed arrow (clears left or right).
func _draw_drill(centre: Vector2, radius: float) -> void:

	var r : float = radius * 0.62
	var col : Color = Color(0.92, 0.97, 1.0, 1.0)
	draw_line(centre + Vector2(-r, 0.0), centre + Vector2(r, 0.0), col, radius * 0.16)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-r, 0.0),
		centre + Vector2(-r * 0.5, -r * 0.45),
		centre + Vector2(-r * 0.5, r * 0.45),
	]), col)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(r, 0.0),
		centre + Vector2(r * 0.5, -r * 0.45),
		centre + Vector2(r * 0.5, r * 0.45),
	]), col)


# Cave-in: a circular shuffle arrow (re-mixes the area).
func _draw_cave_in(centre: Vector2, radius: float) -> void:

	var r : float = radius * 0.52
	var col : Color = Color(0.95, 0.92, 1.0, 1.0)
	draw_arc(centre, r, deg_to_rad(40.0), deg_to_rad(300.0), 24, col, radius * 0.13)
	var tip : Vector2 = centre + Vector2(cos(deg_to_rad(40.0)), sin(deg_to_rad(40.0))) * r
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(r * 0.05, -r * 0.5),
		tip + Vector2(r * 0.55, r * 0.05),
		tip + Vector2(-r * 0.15, r * 0.35),
	]), col)


# Tremor: a board frame with big left+right arrows (whole-board shift).
func _draw_tremor(centre: Vector2, radius: float) -> void:

	var r : float = radius * 0.6
	var col : Color = Color(0.92, 1.0, 0.9, 1.0)
	# End bars (the board's sides).
	draw_line(centre + Vector2(-r, -r * 0.6), centre + Vector2(-r, r * 0.6), col, radius * 0.12)
	draw_line(centre + Vector2(r, -r * 0.6), centre + Vector2(r, r * 0.6), col, radius * 0.12)
	# Double arrow between them.
	draw_line(centre + Vector2(-r * 0.6, 0.0), centre + Vector2(r * 0.6, 0.0), col, radius * 0.10)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-r * 0.62, 0.0),
		centre + Vector2(-r * 0.2, -r * 0.38),
		centre + Vector2(-r * 0.2, r * 0.38),
	]), col)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(r * 0.62, 0.0),
		centre + Vector2(r * 0.2, -r * 0.38),
		centre + Vector2(r * 0.2, r * 0.38),
	]), col)


# Seepage: a bug body, a fang/arrow showing its facing, and the remaining
# bite count.
func _draw_seepage(centre: Vector2, radius: float, accent: Color) -> void:

	var body : Color = Color(0.55, 0.24, 0.14, 1.0)
	var r : float = radius * 0.5
	# Three body segments.
	draw_circle(centre + Vector2(0.0, r * 0.5), r * 0.42, body)
	draw_circle(centre, r * 0.38, body)
	draw_circle(centre + Vector2(0.0, -r * 0.45), r * 0.34, body)
	# Facing arrow (points the way it will eat).
	var dir : Vector2 = _facing_vector()
	var tip : Vector2 = centre + dir * r * 1.05
	var perp : Vector2 = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		tip,
		tip - dir * (r * 0.5) + perp * (r * 0.32),
		tip - dir * (r * 0.5) - perp * (r * 0.32),
	]), accent)
	# Remaining bites.
	var font : Font = ThemeDB.fallback_font
	if font:
		draw_string(font, centre + Vector2(-radius * 0.95, radius * 0.95), str(charges),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.95, 0.7, 1.0))


func _facing_vector() -> Vector2:

	match facing:
		Facing.UP:
			return Vector2(0.0, -1.0)
		Facing.RIGHT:
			return Vector2(1.0, 0.0)
		Facing.DOWN:
			return Vector2(0.0, 1.0)
		Facing.LEFT:
			return Vector2(-1.0, 0.0)
	return Vector2(0.0, 1.0)

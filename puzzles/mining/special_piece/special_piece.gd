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
	SpecialKind.PICKAXE: { "accent": Color(1.0, 0.58, 0.20, 1.0), "label": "Pickaxe", "effect": "Digs the column below" },
	SpecialKind.DRILL: { "accent": Color(0.32, 0.82, 0.92, 1.0), "label": "Drill", "effect": "Clears the row left / right" },
	SpecialKind.CAVE_IN: { "accent": Color(0.74, 0.46, 0.92, 1.0), "label": "Cave-In", "effect": "Blasts a 5x5 open (frees ore)" },
	SpecialKind.TREMOR: { "accent": Color(0.52, 0.86, 0.46, 1.0), "label": "Tremor", "effect": "Shifts the whole board L / R" },
	SpecialKind.SEEPAGE: { "accent": Color(0.88, 0.42, 0.30, 1.0), "label": "Seepage", "effect": "Eats the tile it faces" },
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
		# Sit ABOVE the board's frame overlay (z 30) when framed, so the name +
		# effect label is never hidden behind the frame (Troy 2026-06-15).
		z_index = 60 if value else 0
		queue_redraw()


func label() -> String:
	return KIND_STYLE[special_kind]["label"]


func effect() -> String:
	return KIND_STYLE[special_kind].get("effect", "")


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


# A floating pill above the token (shown while the cursor frames it) with the
# tool's NAME and a one-line description of what it DOES, so the player learns
# each tool's purpose, not just its name (Troy 2026-06-15).
func _draw_name_label(centre: Vector2, accent: Color) -> void:

	var font : Font = ThemeDB.fallback_font
	if font == null:
		return
	var name_txt : String = label().to_upper()
	var eff_txt : String = effect()
	var fs_n : int = 13
	var fs_e : int = 11
	var wn : float = font.get_string_size(name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_n).x
	var we : float = font.get_string_size(eff_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_e).x
	var w : float = maxf(wn, we)
	var pill : Rect2 = Rect2(centre.x - w * 0.5 - 8.0, -41.0, w + 16.0, 37.0)
	draw_rect(pill, Color(0.05, 0.06, 0.09, 0.96), true)
	draw_rect(pill, accent, false, 1.5)
	draw_string(font, Vector2(centre.x - wn * 0.5, pill.position.y + 15.0), name_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs_n, Color(1.0, 0.97, 0.86, 1.0))
	draw_string(font, Vector2(centre.x - we * 0.5, pill.position.y + 30.0), eff_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs_e, Color(0.80, 0.86, 0.96, 1.0))


# PICKAXE — a pick (head arms + wooden handle) with a DOWN arrow: it digs the
# whole column BELOW it.
func _draw_pickaxe(centre: Vector2, radius: float) -> void:

	var col : Color = Color(0.93, 0.95, 1.0, 1.0)
	var wood : Color = Color(0.64, 0.45, 0.26, 1.0)
	var r : float = radius * 0.62
	# Wooden handle.
	draw_line(centre + Vector2(0.0, -r * 0.45), centre + Vector2(0.0, r * 0.35), wood, radius * 0.16)
	# Pick head — a shallow arc across the top (two arms).
	draw_line(centre + Vector2(-r, -r * 0.08), centre + Vector2(0.0, -r * 0.52), col, radius * 0.16)
	draw_line(centre + Vector2(0.0, -r * 0.52), centre + Vector2(r, -r * 0.08), col, radius * 0.16)
	# Down arrow (clears the column BELOW).
	draw_line(centre + Vector2(-r * 0.45, r * 0.52), centre + Vector2(0.0, r * 0.95), col, radius * 0.12)
	draw_line(centre + Vector2(r * 0.45, r * 0.52), centre + Vector2(0.0, r * 0.95), col, radius * 0.12)


# DRILL — a bold horizontal double-arrow: clears the row left or right.
func _draw_drill(centre: Vector2, radius: float) -> void:

	var r : float = radius * 0.64
	var col : Color = Color(0.92, 0.97, 1.0, 1.0)
	draw_line(centre + Vector2(-r * 0.7, 0.0), centre + Vector2(r * 0.7, 0.0), col, radius * 0.16)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-r, 0.0), centre + Vector2(-r * 0.5, -r * 0.45), centre + Vector2(-r * 0.5, r * 0.45)]), col)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(r, 0.0), centre + Vector2(r * 0.5, -r * 0.45), centre + Vector2(r * 0.5, r * 0.45)]), col)


# CAVE-IN — an EXPLOSION burst (it blasts a 5x5 open to free a stuck chunk).
# Drawn as a hot core + spiky star (each spike a convex triangle, so no
# concave-polygon render error).
func _draw_cave_in(centre: Vector2, radius: float) -> void:

	var r : float = radius * 0.70
	var flare : Color = Color(1.0, 0.92, 0.55, 1.0)
	var hot : Color = Color(1.0, 0.66, 0.28, 1.0)
	draw_circle(centre, r * 0.52, hot)
	var spikes : int = 8
	for i in spikes:
		var a : float = TAU * float(i) / float(spikes) - PI * 0.5
		var a1 : float = a - PI / float(spikes) * 0.55
		var a2 : float = a + PI / float(spikes) * 0.55
		draw_colored_polygon(PackedVector2Array([
			centre + Vector2(cos(a), sin(a)) * r,
			centre + Vector2(cos(a1), sin(a1)) * r * 0.5,
			centre + Vector2(cos(a2), sin(a2)) * r * 0.5]), flare)
	draw_circle(centre, r * 0.28, Color(1.0, 1.0, 0.92, 1.0))


# TREMOR — two board-edge bars with a double-arrow between: it shifts the WHOLE
# board left or right (the side bars are what set it apart from the Drill).
func _draw_tremor(centre: Vector2, radius: float) -> void:

	var r : float = radius * 0.62
	var col : Color = Color(0.92, 1.0, 0.9, 1.0)
	draw_line(centre + Vector2(-r, -r * 0.7), centre + Vector2(-r, r * 0.7), col, radius * 0.13)
	draw_line(centre + Vector2(r, -r * 0.7), centre + Vector2(r, r * 0.7), col, radius * 0.13)
	draw_line(centre + Vector2(-r * 0.55, 0.0), centre + Vector2(r * 0.55, 0.0), col, radius * 0.10)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-r * 0.6, 0.0), centre + Vector2(-r * 0.2, -r * 0.34), centre + Vector2(-r * 0.2, r * 0.34)]), col)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(r * 0.6, 0.0), centre + Vector2(r * 0.2, -r * 0.34), centre + Vector2(r * 0.2, r * 0.34)]), col)


# SEEPAGE — a clear little bug (segmented body + legs + antennae) with an accent
# facing arrow showing the way it eats, and its remaining bite count.
func _draw_seepage(centre: Vector2, radius: float, accent: Color) -> void:

	var body : Color = Color(0.64, 0.42, 0.24, 1.0)
	var leg : Color = Color(0.40, 0.26, 0.15, 1.0)
	var r : float = radius * 0.5
	var dir : Vector2 = _facing_vector()
	var perp : Vector2 = Vector2(-dir.y, dir.x)
	var head : Vector2 = centre + dir * r * 0.55
	var tail : Vector2 = centre - dir * r * 0.55
	# Legs (3 pairs).
	for k in [-0.45, 0.0, 0.45]:
		var seg : Vector2 = centre + dir * (r * k)
		draw_line(seg, seg + perp * r * 0.75, leg, 1.6)
		draw_line(seg, seg - perp * r * 0.75, leg, 1.6)
	# Body segments.
	draw_circle(tail, r * 0.34, body)
	draw_circle(centre, r * 0.42, body)
	draw_circle(head, r * 0.34, body.lightened(0.12))
	# Antennae.
	draw_line(head, head + dir * r * 0.5 + perp * r * 0.28, leg, 1.3)
	draw_line(head, head + dir * r * 0.5 - perp * r * 0.28, leg, 1.3)
	# Facing arrow (accent) showing the eat direction.
	var tip : Vector2 = head + dir * r * 0.95
	draw_colored_polygon(PackedVector2Array([
		tip, tip - dir * r * 0.45 + perp * r * 0.30, tip - dir * r * 0.45 - perp * r * 0.30]), accent)
	# Remaining bites.
	var font : Font = ThemeDB.fallback_font
	if font:
		draw_string(font, centre + Vector2(-radius * 0.95, radius * 0.98), str(charges),
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

## A BREATH-STONE — one tile in THE LOFT match-3 lift puzzle (see [[loft-spec]]).
## Placeholder-first art: a flat rounded body in its hue + a distinct GLYPH, so the
## five hues read WITHOUT colour (colourblind-safe + art-swappable later, per the
## scene-per-component principle). The [LoftBoard] owns it — sets its hue, tweens
## its position, scales it to nothing on a clear. It just holds a hue + draws itself.
class_name LoftStone
extends Node2D


## Pixel size of a stone — MUST match LoftBoard.CELL. The body is drawn centred on
## the node origin, so the board positions it at the cell CENTRE.
const SIZE : float = 44.0

## Breath-stone hues (index = hue id). Homey / mythic-light, NOT candy.
const HUES : Array[Color] = [
	Color(0.95, 0.74, 0.30),  # 0 Saffron
	Color(0.46, 0.74, 0.95),  # 1 Sky
	Color(0.93, 0.43, 0.36),  # 2 Ember
	Color(0.52, 0.78, 0.46),  # 3 Moss
	Color(0.72, 0.56, 0.90),  # 4 Dusk
]


## Ballast colours (the special "dross-stone" — see [[loft-spec]] specials).
const BALLAST_BODY : Color = Color(0.24, 0.26, 0.32, 1.0)
const BALLAST_GLYPH : Color = Color(0.08, 0.09, 0.12, 1.0)


var hue : int = 0 :
	set(value):
		hue = value
		queue_redraw()

## A BALLAST (the bilging "crab" reskin): a heavy dross-stone. Matches no hue + can't be
## swapped, but FALLS like any stone; you sink it into THE STARDUST (clear beneath it, or
## let the Stardust rise to it) and it sloughs for a big LIFT bonus. The board treats it specially.
var is_ballast : bool = false :
	set(value):
		is_ballast = value
		queue_redraw()

## Drawn with a bright ring when it's the player's current pick.
var selected : bool = false :
	set(value):
		selected = value
		queue_redraw()


func _draw() -> void:

	if is_ballast:
		_draw_ballast()
		return
	var col : Color = HUES[hue % HUES.size()]
	var half : float = SIZE * 0.5 - 3.0
	_draw_gem(col, half)
	_draw_glyph(col.darkened(0.55))   # the colour-blind-safe glyph, etched in the table
	if selected:
		var s : float = SIZE * 0.5 - 1.0
		draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), Color(1.0, 1.0, 1.0, 0.95), false, 3.0)


# A faceted, LUMINOUS cut-gem (the breath-stone "sings alight"): four crown facets
# (top brightest, bottom darkest) around a glowing TABLE, with cut-edge sparkle, a
# specular shine, and a beveled rim. Reads as a glowing jewel, not a flat tile.
func _draw_gem(col: Color, half: float) -> void:

	var b_tl : Vector2 = Vector2(-half, -half)
	var b_tr : Vector2 = Vector2(half, -half)
	var b_br : Vector2 = Vector2(half, half)
	var b_bl : Vector2 = Vector2(-half, half)
	var t : float = half * 0.5
	var t_tl : Vector2 = Vector2(-t, -t)
	var t_tr : Vector2 = Vector2(t, -t)
	var t_br : Vector2 = Vector2(t, t)
	var t_bl : Vector2 = Vector2(-t, t)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), col.darkened(0.10))   # pavilion base
	draw_colored_polygon(PackedVector2Array([b_tl, b_tr, t_tr, t_tl]), col.lightened(0.36))  # top facet
	draw_colored_polygon(PackedVector2Array([b_bl, b_tl, t_tl, t_bl]), col.lightened(0.12))  # left facet
	draw_colored_polygon(PackedVector2Array([b_tr, b_br, t_br, t_tr]), col.darkened(0.14))   # right facet
	draw_colored_polygon(PackedVector2Array([b_br, b_bl, t_bl, t_br]), col.darkened(0.30))   # bottom facet
	draw_rect(Rect2(t_tl, Vector2(t * 2.0, t * 2.0)), col.lightened(0.22))                   # the table
	var glow : Color = col.lightened(0.5)
	draw_circle(Vector2.ZERO, t * 0.80, Color(glow.r, glow.g, glow.b, 0.42))                 # inner core glow
	var edge : Color = Color(glow.r, glow.g, glow.b, 0.7)
	draw_line(t_tl, b_tl, edge, 1.0)   # cut-edge sparkle (table corners -> body corners)
	draw_line(t_tr, b_tr, edge, 1.0)
	draw_line(t_br, b_br, edge, 1.0)
	draw_line(t_bl, b_bl, edge, 1.0)
	draw_circle(Vector2(-t * 0.42, -t * 0.5), t * 0.30, Color(1, 1, 1, 0.6))                 # specular shine
	draw_line(b_tl, b_tr, col.lightened(0.45), 1.5)   # beveled rim
	draw_line(b_tl, b_bl, col.lightened(0.30), 1.5)
	draw_line(b_bl, b_br, col.darkened(0.45), 1.5)
	draw_line(b_tr, b_br, col.darkened(0.38), 1.5)


# The BALLAST — a heavy IRON dross-stone (clearly NOT a bright gem): a matte banded
# block with corner rivets + an embossed weight glyph = "immovable dead weight".
func _draw_ballast() -> void:

	var half : float = SIZE * 0.5 - 3.0
	var body : Rect2 = Rect2(-half, -half, half * 2.0, half * 2.0)
	var face : Color = BALLAST_BODY
	draw_rect(body, face)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 0.46), face.lightened(0.07))   # dull top sheen
	# Matte bevel (heavy, not glossy).
	draw_line(Vector2(-half, -half), Vector2(half, -half), face.lightened(0.24), 2.0)
	draw_line(Vector2(-half, -half), Vector2(-half, half), face.lightened(0.15), 2.0)
	draw_line(Vector2(-half, half), Vector2(half, half), face.darkened(0.5), 2.0)
	draw_line(Vector2(half, -half), Vector2(half, half), face.darkened(0.4), 2.0)
	# An iron band across the middle (the dross is strapped).
	draw_rect(Rect2(-half, -3.5, half * 2.0, 7.0), face.darkened(0.32))
	draw_line(Vector2(-half, -3.5), Vector2(half, -3.5), face.lightened(0.18), 1.0)
	# Embossed weight glyph: a trapezoid (wider at the bottom = heavy).
	var s : float = 10.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-s * 0.6, -s * 0.7), Vector2(s * 0.6, -s * 0.7),
		Vector2(s, s * 0.7), Vector2(-s, s * 0.7)]), BALLAST_GLYPH)
	draw_line(Vector2(-s * 0.6, -s * 0.7), Vector2(s * 0.6, -s * 0.7), face.lightened(0.3), 1.0)
	# Corner rivets (raised: dark base + light cap).
	var rv : float = half - 5.0
	for p in [Vector2(-rv, -rv), Vector2(rv, -rv), Vector2(-rv, rv), Vector2(rv, rv)]:
		draw_circle(p, 2.8, face.darkened(0.45))
		draw_circle(p - Vector2(0.7, 0.7), 1.1, face.lightened(0.4))
	if selected:
		var sr : float = SIZE * 0.5 - 1.0
		draw_rect(Rect2(-sr, -sr, sr * 2.0, sr * 2.0), Color(1.0, 1.0, 1.0, 0.6), false, 2.0)


# A distinct simple glyph per hue so the stones read without relying on colour.
func _draw_glyph(c: Color) -> void:

	var s : float = 9.0
	match hue % HUES.size():
		0:  # Saffron — dot
			draw_circle(Vector2.ZERO, s * 0.75, c)
		1:  # Sky — ring
			draw_arc(Vector2.ZERO, s, 0.0, TAU, 28, c, 3.0)
		2:  # Ember — triangle
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -s), Vector2(s, s * 0.8), Vector2(-s, s * 0.8)]), c)
		3:  # Moss — bar
			draw_rect(Rect2(-s, -s * 0.34, s * 2.0, s * 0.68), c, true)
		4:  # Dusk — diamond
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -s), Vector2(s, 0.0), Vector2(0.0, s), Vector2(-s, 0.0)]), c)
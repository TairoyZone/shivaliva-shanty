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
	var body : Rect2 = Rect2(-half, -half, half * 2.0, half * 2.0)
	draw_rect(body, col, true)
	# Bevel highlight + dark edge for a chunky, readable stone.
	draw_rect(Rect2(-half + 2.0, -half + 2.0, half * 2.0 - 4.0, half * 2.0 - 4.0),
		col.lightened(0.14), false, 2.0)
	draw_rect(body, col.darkened(0.4), false, 2.0)
	_draw_glyph(col.darkened(0.55))
	if selected:
		var s : float = SIZE * 0.5 - 1.0
		draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), Color(1.0, 1.0, 1.0, 0.95), false, 3.0)


# The BALLAST — a dark, heavy, riveted block (clearly NOT one of the bright hues): a
# weight-trapezoid glyph + corner rivets read "immovable dead weight". Placeholder art.
func _draw_ballast() -> void:

	var half : float = SIZE * 0.5 - 3.0
	var body : Rect2 = Rect2(-half, -half, half * 2.0, half * 2.0)
	draw_rect(body, BALLAST_BODY, true)
	draw_rect(Rect2(-half + 2.0, -half + 2.0, half * 2.0 - 4.0, half * 2.0 - 4.0),
		BALLAST_BODY.lightened(0.16), false, 2.0)
	draw_rect(body, BALLAST_BODY.darkened(0.5), false, 2.0)
	# Weight glyph: a trapezoid (wider at the bottom = heavy).
	var s : float = 10.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-s * 0.6, -s * 0.7), Vector2(s * 0.6, -s * 0.7),
		Vector2(s, s * 0.7), Vector2(-s, s * 0.7)]), BALLAST_GLYPH)
	# Corner rivets.
	var rv : float = half - 5.0
	for p in [Vector2(-rv, -rv), Vector2(rv, -rv), Vector2(-rv, rv), Vector2(rv, rv)]:
		draw_circle(p, 2.4, BALLAST_BODY.lightened(0.35))
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
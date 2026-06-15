## A knot — the Lumberjacking equivalent of SwordFighting's damage
## piece. Dropped into the bin by the difficulty-escalating timer when
## the log "fights back." Goes through a faithful SwF 4-turn decay
## before becoming a standard, shatterable wood block.
##
## On-concept with the Minecraft-plank wood pass (Troy 2026-06-15): it is a
## gnarled HARDWOOD knot — a dark walnut block whose grain swirls around a
## tough knot-eye, iron-braced so it reads as IMMOVABLE — that visibly
## LOOSENS (cracks) then DISSOLVES (sawdust) into a normal plank.
##
## State timeline (advanced once per pair-spawn by the board):
##   Turn 1 (arrival) : SILVER_KNOT — crisp iron-braced knot, immovable
##   Turn 2           : OPAQUE      — loosening: brace rusts, knot cracks
##   Turn 3           : TRANSLUCENT — dissolving: fading, sawdust crumbles
##   Turn 4+          : RESOLVED    — emit [signal resolved]; the board
##                                    replaces this with a LogPiece of a
##                                    randomly-chosen wood kind.
##
## See [[lumberjacking-spec]] for the full state semantics. Per the
## scene-per-component principle, this is a standalone .tscn so art
## can be swapped in later without touching board logic.
@tool
class_name Knot
extends Node2D


enum State { SILVER_KNOT, OPAQUE, TRANSLUCENT, RESOLVED }

## Emitted when the knot has decayed through all of its non-shatterable
## stages and is ready to be replaced with a normal [LogPiece]. The
## board listens, picks a wood kind (random uniform across the 4),
## removes this knot, and slots a LogPiece into the same grid cell.
signal resolved


const CELL_SIZE : float = LogPiece.CELL_SIZE  # mirror LogPiece so we slot in cleanly
const CELL_PAD : float = 2.0

# Dark gnarled-hardwood palette — deliberately APART from the 4 plank kinds
# (deep walnut, almost black at the knot eye) so a knot never reads as a
# normal plank the player could clear.
const WOOD_FACE : Color = Color(0.34, 0.22, 0.12, 1.0)
const WOOD_LIGHT : Color = Color(0.47, 0.32, 0.18, 1.0)
const WOOD_SHADOW : Color = Color(0.20, 0.12, 0.06, 1.0)
const GRAIN : Color = Color(0.16, 0.09, 0.04, 1.0)
const RING_DARK : Color = Color(0.11, 0.06, 0.03, 1.0)   # the knot eye
const RING_MID : Color = Color(0.25, 0.14, 0.07, 1.0)
const RING_LIGHT : Color = Color(0.44, 0.29, 0.15, 1.0)
const IRON : Color = Color(0.31, 0.32, 0.35, 1.0)
const IRON_HI : Color = Color(0.66, 0.68, 0.72, 1.0)
const IRON_RUST : Color = Color(0.42, 0.26, 0.16, 1.0)
const SAWDUST : Color = Color(0.78, 0.62, 0.38, 1.0)


@export var state : State = State.SILVER_KNOT :
	set(value):
		state = value
		queue_redraw()


## Called by the board once per pair-spawn (a "turn" in SwF terms).
## Advances state one notch; emits [signal resolved] on the final tick.
func advance_turn() -> void:

	if state == State.RESOLVED:
		return
	# Enum values are contiguous 0..RESOLVED, so the index IS the next
	# state — no need to allocate State.values() each turn (audit minor).
	state = mini(state + 1, State.RESOLVED) as State
	if state == State.RESOLVED:
		resolved.emit()


## Knots are NEVER shatterable until they've decayed to RESOLVED (at
## which point the board converts them to a regular LogPiece, which is
## shatterable). Used by the board's shatter pass to filter out knots.
func is_shatterable() -> bool:

	return false


func _draw() -> void:

	var inner : Rect2 = Rect2(
		CELL_PAD, CELL_PAD,
		CELL_SIZE - 2.0 * CELL_PAD,
		CELL_SIZE - 2.0 * CELL_PAD)
	match state:
		State.SILVER_KNOT:
			# Crisp, iron-braced, fully opaque: a tough knot you can't cut yet.
			_draw_knot(inner, 1.0, 0, 0.0)
		State.OPAQUE:
			# Loosening — brace rusts to one bracket, hairline cracks open.
			_draw_knot(inner, 1.0, 1, 0.45)
		State.TRANSLUCENT:
			# Dissolving into a plank — fading, brace gone, sawdust crumbling.
			_draw_knot(inner, 0.55, 2, 0.9)
		State.RESOLVED:
			# About to be replaced by a LogPiece — nothing to draw.
			pass


# One gnarled-knot renderer shared by every live state.
#   alpha : overall opacity (1 fresh → fades as it dissolves)
#   brace : 0 = full iron brace, 1 = one rusted bracket, 2 = none
#   crack : 0..1 how far the loosening cracks + sawdust have progressed
func _draw_knot(inner: Rect2, alpha: float, brace: int, crack: float) -> void:

	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE  # fixed — knots are identical; stable = no shimmer
	var center : Vector2 = inner.position + inner.size * Vector2(0.5, 0.52)

	# Drop shadow + the dark hardwood face with a top-lit / bottom-shaded wash.
	var sh : Rect2 = inner
	sh.position.y += 1.5
	draw_rect(sh, _a(WOOD_SHADOW, alpha))
	draw_rect(inner, _a(WOOD_FACE, alpha))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.32)),
		_a(WOOD_LIGHT, alpha * 0.5))
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - inner.size.y * 0.28),
		Vector2(inner.size.x, inner.size.y * 0.28)), _a(WOOD_SHADOW, alpha * 0.5))

	# Grain that BOWS around the knot — the signature "wood swirls past a knot"
	# read. Lines above the eye lift up, below press down, near the center.
	var span : float = inner.size.x * 0.42
	for i in range(5):
		var y0 : float = inner.position.y + inner.size.y * (0.14 + 0.18 * i)
		_grain_line(y0, center, span, _a(GRAIN, alpha * 0.85), inner)

	# The knot whorl: concentric growth rings into a near-black eye.
	var radius : float = inner.size.x * 0.30
	draw_circle(center, radius, _a(RING_MID, alpha))
	draw_circle(center, radius * 0.96, _a(RING_LIGHT, alpha * 0.5))
	draw_arc(center, radius * 0.74, 0.0, TAU, 24, _a(RING_DARK, alpha * 0.7), 1.4)
	draw_circle(center, radius * 0.50, _a(RING_MID, alpha))
	draw_circle(center, radius * 0.26, _a(RING_DARK, alpha))
	draw_circle(center + Vector2(-radius * 0.10, -radius * 0.10), radius * 0.10,
		_a(RING_LIGHT, alpha * 0.6))  # tiny wet-wood glint in the eye

	# Loosening cracks — jagged hairlines splitting OUT from the knot as it gives.
	if crack > 0.0:
		var cracks : int = 2 if crack < 0.7 else 3
		for c in range(cracks):
			var ang : float = rng.randf_range(0.0, TAU)
			var dir : Vector2 = Vector2(cos(ang), sin(ang))
			var p : Vector2 = center + dir * radius * 0.7
			var pts : PackedVector2Array = PackedVector2Array([p])
			var seg : float = (inner.size.x * 0.5) * crack
			for s in range(3):
				var jitter : Vector2 = Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
				p += dir * (seg / 3.0) + jitter
				pts.append(p)
			draw_polyline(pts, _a(Color(0.05, 0.03, 0.01, 1.0), alpha), 1.3)

	# Sawdust crumbling off the bottom as it dissolves toward a plank.
	if crack > 0.6:
		for _d in range(5):
			var dp : Vector2 = Vector2(
				inner.position.x + rng.randf_range(2.0, inner.size.x - 2.0),
				inner.end.y - rng.randf_range(0.0, inner.size.y * 0.32 * crack))
			draw_circle(dp, rng.randf_range(0.8, 1.6), _a(SAWDUST, alpha * 0.8))

	# Iron bracing — the "immovable" cue. Full brace fresh, one rusted bracket
	# as it loosens, gone once it is dissolving.
	if brace == 0:
		_draw_bracket(inner.position + Vector2(1.0, 1.0), 1.0, false, alpha)
		_draw_bracket(inner.end - Vector2(1.0, 1.0), -1.0, false, alpha)
	elif brace == 1:
		_draw_bracket(inner.position + Vector2(1.0, 1.0), 1.0, true, alpha)

	# Bevel — only fresh/loosening; dissolving has no crisp edge.
	if alpha > 0.7:
		draw_line(inner.position, Vector2(inner.end.x, inner.position.y), _a(WOOD_LIGHT, alpha), 1.4)
		draw_line(inner.position, Vector2(inner.position.x, inner.end.y), _a(WOOD_LIGHT, alpha * 0.8), 1.2)
		draw_line(Vector2(inner.position.x, inner.end.y), inner.end, _a(WOOD_SHADOW, alpha), 1.6)
		draw_line(Vector2(inner.end.x, inner.position.y), inner.end, _a(WOOD_SHADOW, alpha), 1.4)


# A grain stroke that bows away from `center` near the knot — a 7-point
# polyline so the wood visibly flows past the knot eye instead of through it.
func _grain_line(y0: float, center: Vector2, span: float, color: Color, inner: Rect2) -> void:

	var pts : PackedVector2Array = PackedVector2Array()
	var sign_y : float = -1.0 if y0 < center.y else 1.0
	for i in range(7):
		var t : float = i / 6.0
		var x : float = inner.position.x + 2.0 + t * (inner.size.x - 4.0)
		var d : float = (x - center.x) / span
		var bow : float = sign_y * 5.0 * exp(-d * d)  # gaussian lift near the eye
		pts.append(Vector2(x, y0 + bow))
	draw_polyline(pts, color, 1.1)


# A small forged-iron corner bracket with a rivet — the reinforcement read.
# `sx` flips it for the opposite corner; `rust` swaps steel for rusted tone.
func _draw_bracket(corner: Vector2, sx: float, rust: bool, alpha: float) -> void:

	var body : Color = _a(IRON_RUST if rust else IRON, alpha)
	var leg : float = 9.0
	draw_line(corner, corner + Vector2(leg * sx, 0.0), body, 2.6)
	draw_line(corner, corner + Vector2(0.0, leg * sx), body, 2.6)
	if not rust:
		draw_line(corner + Vector2(1.0 * sx, 0.5 * sx), corner + Vector2(leg * sx, 0.5 * sx),
			_a(IRON_HI, alpha * 0.8), 1.0)
	draw_circle(corner + Vector2(3.0 * sx, 3.0 * sx), 1.8, body)
	draw_circle(corner + Vector2(2.4 * sx, 2.4 * sx), 0.7, _a(IRON_HI, alpha * 0.7))


# Apply an overall opacity multiplier to a color (for the dissolve fade).
func _a(c: Color, alpha: float) -> Color:

	return Color(c.r, c.g, c.b, c.a * alpha)

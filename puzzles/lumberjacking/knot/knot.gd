## A knot — the Lumberjacking equivalent of SwordFighting's damage
## piece. Dropped into the bin by the difficulty-escalating timer when
## the log "fights back." Goes through a faithful SwF 4-turn decay
## before becoming a standard, shatterable wood block.
##
## On-concept with the Minecraft-plank wood pass (Troy 2026-06-15): a gnarled
## dark-hardwood knot — grain swirling around a tough knot-eye, iron-braced so
## it reads as IMMOVABLE — that LOOSENS (its eventual plank colour seeps through
## the cracks) then DISSOLVES TRANSPARENT to REVEAL the plank it becomes,
## telegraphing the colour before it resolves (the YPP "broken piece resolves
## into a known block" read). Everything is contained WITHIN the cell — no
## outline bleeds over neighbours.
##
## State timeline (advanced once per pair-spawn by the board):
##   Turn 1 (arrival) : SILVER_KNOT — crisp iron-braced knot, immovable
##   Turn 2           : OPAQUE      — loosening: colour seeps through cracks
##   Turn 3           : TRANSLUCENT — dissolving: fades to reveal its plank
##   Turn 4+          : RESOLVED    — emit [signal resolved]; the board
##                                    replaces this with the LogPiece of the
##                                    ALREADY-REVEALED kind ([member reveal_config]).
##
## See [[lumberjacking-spec]] for the full state semantics. Per the
## scene-per-component principle, this is a standalone .tscn so art
## can be swapped in later without touching board logic.
@tool
class_name Knot
extends Node2D


enum State { SILVER_KNOT, OPAQUE, TRANSLUCENT, RESOLVED }

## Emitted when the knot has decayed through all of its non-shatterable
## stages and is ready to be replaced with a normal [LogPiece]. The board
## listens, removes this knot, and slots a LogPiece built from
## [member reveal_config] (the SAME kind the decay already telegraphed).
signal resolved


const CELL_SIZE : float = LogPiece.CELL_SIZE  # mirror LogPiece so we slot in cleanly
const CELL_PAD : float = 2.0

# Dark gnarled-hardwood palette — deliberately APART from the 4 plank kinds
# (deep walnut, near-black at the knot eye) so a fresh knot never reads as a
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
const CRACK_CORE : Color = Color(0.05, 0.03, 0.01, 1.0)


@export var state : State = State.SILVER_KNOT :
	set(value):
		state = value
		queue_redraw()

## The piece config {kind, variant} this knot will resolve into, chosen UP
## FRONT by the board at spawn so the decay can telegraph the colour. Empty =
## standalone preview (defaults to a jungle reveal so the effect is visible).
var reveal_config : Dictionary = {} :
	set(value):
		reveal_config = value
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
	# knot_alpha = opacity of the gnarled hardwood; reveal = how much of the
	# eventual plank shows beneath. They cross-fade so the knot dissolves
	# transparent INTO its plank colour.
	match state:
		State.SILVER_KNOT:
			_draw_knot(inner, 1.0, 0.0, true, 0.0)
		State.OPAQUE:
			_draw_knot(inner, 0.92, 0.30, true, 0.5)
		State.TRANSLUCENT:
			_draw_knot(inner, 0.38, 0.85, false, 0.9)
		State.RESOLVED:
			# About to be replaced by a LogPiece — nothing to draw.
			pass


# One gnarled-knot renderer shared by every live state. EVERY primitive is
# clamped to `inner`, so nothing bleeds over a neighbouring tile.
#   knot_alpha : opacity of the dark hardwood knot on top
#   reveal     : 0..1 opacity of the eventual plank shown UNDERNEATH
#   brace      : draw the iron reinforcement (the "immovable" cue)
#   crack      : 0..1 how far the loosening cracks + sawdust have progressed
func _draw_knot(inner: Rect2, knot_alpha: float, reveal: float, brace: bool, crack: float) -> void:

	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE  # fixed — knots are identical; stable = no shimmer
	var center : Vector2 = inner.position + inner.size * Vector2(0.5, 0.52)
	var kind : int = reveal_config.get("kind", LogPiece.WoodKind.JUNGLE)
	var plank : Dictionary = LogPiece.KIND_COLORS[kind]

	# 0. The eventual PLANK, revealed underneath (telegraph the colour).
	if reveal > 0.01:
		_draw_target_plank(inner, plank, reveal)

	# 1. Dark hardwood face + a top-lit / bottom-shaded wash, at knot opacity.
	var sh : Rect2 = inner
	sh.position.y += 1.5
	sh.size.y = inner.size.y - 1.5
	draw_rect(sh, _a(WOOD_SHADOW, knot_alpha))
	draw_rect(inner, _a(WOOD_FACE, knot_alpha))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.32)),
		_a(WOOD_LIGHT, knot_alpha * 0.5))
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - inner.size.y * 0.28),
		Vector2(inner.size.x, inner.size.y * 0.28)), _a(WOOD_SHADOW, knot_alpha * 0.5))

	# 2. Grain that BOWS around the knot — wood swirling past the eye.
	var span : float = inner.size.x * 0.42
	for i in range(5):
		var y0 : float = inner.position.y + inner.size.y * (0.14 + 0.18 * i)
		_grain_line(y0, center, span, _a(GRAIN, knot_alpha * 0.85), inner)

	# 3. The knot whorl — concentric growth rings into a near-black eye.
	var radius : float = inner.size.x * 0.30
	draw_circle(center, radius, _a(RING_MID, knot_alpha))
	draw_circle(center, radius * 0.96, _a(RING_LIGHT, knot_alpha * 0.5))
	draw_arc(center, radius * 0.74, 0.0, TAU, 24, _a(RING_DARK, knot_alpha * 0.7), 1.4)
	draw_circle(center, radius * 0.50, _a(RING_MID, knot_alpha))
	draw_circle(center, radius * 0.26, _a(RING_DARK, knot_alpha))
	draw_circle(center + Vector2(-radius * 0.10, -radius * 0.10), radius * 0.10,
		_a(RING_LIGHT, knot_alpha * 0.6))  # tiny wet-wood glint in the eye

	# 4. Loosening cracks — the eventual plank colour SEEPS through the splits
	# (a coloured glow over a dark core), all clamped inside the cell.
	if crack > 0.0:
		var glow : Color = (plank["face"] as Color).lightened(0.18)
		var cracks : int = 2 if crack < 0.7 else 3
		for c in range(cracks):
			var ang : float = rng.randf_range(0.0, TAU)
			var dir : Vector2 = Vector2(cos(ang), sin(ang))
			var p : Vector2 = center + dir * radius * 0.7
			var pts : PackedVector2Array = PackedVector2Array([_clampv(p, inner)])
			var seg : float = (inner.size.x * 0.36) * crack
			for s in range(3):
				var jit : Vector2 = Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
				p += dir * (seg / 3.0) + jit
				pts.append(_clampv(p, inner))
			draw_polyline(pts, _a(glow, minf(1.0, reveal + 0.35)), 2.0)
			draw_polyline(pts, _a(CRACK_CORE, knot_alpha), 1.0)

	# 5. Sawdust crumbling off the bottom as it dissolves toward a plank.
	if crack > 0.6:
		for _d in range(5):
			var dp : Vector2 = Vector2(
				inner.position.x + rng.randf_range(2.0, inner.size.x - 2.0),
				inner.end.y - rng.randf_range(0.0, inner.size.y * 0.30 * crack))
			draw_circle(_clampv(dp, inner), rng.randf_range(0.8, 1.5), _a(SAWDUST, knot_alpha + 0.4))

	# 6. Iron bracing — the "immovable" cue. Full brace fresh; gone once it
	# is dissolving. Drawn after the face so it reads on top.
	if brace:
		var rust : bool = crack > 0.2
		_draw_bracket(inner.position + Vector2(1.0, 1.0), 1.0, rust, knot_alpha)
		if not rust:
			_draw_bracket(inner.end - Vector2(1.0, 1.0), -1.0, false, knot_alpha)

	# 7. Bevel — only while crisp; dissolving has no hard edge.
	if knot_alpha > 0.7:
		draw_line(inner.position, Vector2(inner.end.x, inner.position.y), _a(WOOD_LIGHT, knot_alpha), 1.4)
		draw_line(inner.position, Vector2(inner.position.x, inner.end.y), _a(WOOD_LIGHT, knot_alpha * 0.8), 1.2)
		draw_line(Vector2(inner.position.x, inner.end.y), inner.end, _a(WOOD_SHADOW, knot_alpha), 1.6)
		draw_line(Vector2(inner.end.x, inner.position.y), inner.end, _a(WOOD_SHADOW, knot_alpha), 1.4)


# The plank this knot becomes, drawn faintly underneath (face + wash + two
# seams) so the player reads the incoming colour. Contained to `inner`.
func _draw_target_plank(inner: Rect2, plank: Dictionary, alpha: float) -> void:

	var face : Color = plank["face"]
	var grain : Color = plank["grain"]
	draw_rect(inner, _a(face, alpha))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.34)), _a(face.lightened(0.08), alpha))
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - inner.size.y * 0.30),
		Vector2(inner.size.x, inner.size.y * 0.30)), _a(face.darkened(0.08), alpha))
	for b in range(1, 3):
		var by : float = inner.position.y + inner.size.y * (float(b) / 3.0)
		draw_line(Vector2(inner.position.x, by), Vector2(inner.end.x, by), _a(grain, alpha * 0.85), 1.3)


# A grain stroke that bows away from `center` near the knot — a 7-point
# polyline so the wood visibly flows past the knot eye. Clamped to `inner`.
func _grain_line(y0: float, center: Vector2, span: float, color: Color, inner: Rect2) -> void:

	var pts : PackedVector2Array = PackedVector2Array()
	var sign_y : float = -1.0 if y0 < center.y else 1.0
	for i in range(7):
		var t : float = i / 6.0
		var x : float = inner.position.x + 2.0 + t * (inner.size.x - 4.0)
		var d : float = (x - center.x) / span
		var bow : float = sign_y * 5.0 * exp(-d * d)  # gaussian lift near the eye
		pts.append(_clampv(Vector2(x, y0 + bow), inner))
	draw_polyline(pts, color, 1.1)


# A small forged-iron corner bracket with a rivet — the reinforcement read.
# `sx` flips it for the opposite corner; `rust` swaps steel for rusted tone.
# Legs run INWARD so the bracket stays inside the cell.
func _draw_bracket(corner: Vector2, sx: float, rust: bool, alpha: float) -> void:

	var body : Color = _a(IRON_RUST if rust else IRON, alpha)
	var leg : float = 8.0
	draw_line(corner, corner + Vector2(leg * sx, 0.0), body, 2.6)
	draw_line(corner, corner + Vector2(0.0, leg * sx), body, 2.6)
	if not rust:
		draw_line(corner + Vector2(1.0 * sx, 0.5 * sx), corner + Vector2(leg * sx, 0.5 * sx),
			_a(IRON_HI, alpha * 0.8), 1.0)
	draw_circle(corner + Vector2(3.0 * sx, 3.0 * sx), 1.8, body)
	draw_circle(corner + Vector2(2.4 * sx, 2.4 * sx), 0.7, _a(IRON_HI, alpha * 0.7))


# Clamp a point inside a rect (keeps every stroke from bleeding over the cell).
func _clampv(p: Vector2, inner: Rect2) -> Vector2:

	return Vector2(clampf(p.x, inner.position.x, inner.end.x),
		clampf(p.y, inner.position.y, inner.end.y))


# Apply an overall opacity multiplier to a color (for the dissolve fade).
func _a(c: Color, alpha: float) -> Color:

	return Color(c.r, c.g, c.b, c.a * clampf(alpha, 0.0, 1.0))

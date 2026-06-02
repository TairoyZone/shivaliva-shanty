## A knot — the Lumberjacking equivalent of SwordFighting's damage
## piece. Dropped into the bin by the difficulty-escalating timer when
## the log "fights back." Goes through a faithful SwF 4-turn decay
## before becoming a standard, shatterable wood block.
##
## State timeline (advanced once per pair-spawn by the board):
##   Turn 1 (arrival) : SILVER_KNOT — immovable gnarled-knot image
##   Turn 2           : OPAQUE      — opaque gray block, knot image fades
##   Turn 3           : TRANSLUCENT — gray-translucent, visibly resolving
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
const COLOR_SILVER_FACE : Color = Color(0.78, 0.80, 0.84, 1.0)
const COLOR_SILVER_SHADOW : Color = Color(0.42, 0.44, 0.48, 1.0)
const COLOR_OPAQUE : Color = Color(0.38, 0.38, 0.40, 1.0)
const COLOR_TRANSLUCENT : Color = Color(0.50, 0.50, 0.52, 0.55)
const COLOR_KNOT_DARK : Color = Color(0.22, 0.14, 0.08, 1.0)
const COLOR_KNOT_RING : Color = Color(0.32, 0.20, 0.10, 1.0)


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
			_draw_silver_knot(inner)
		State.OPAQUE:
			_draw_opaque(inner)
		State.TRANSLUCENT:
			_draw_translucent(inner)
		State.RESOLVED:
			# About to be replaced by a LogPiece — nothing to draw.
			pass


# Turn-1 look: a silver block with a gnarled-knot stamp in the center.
# The knot stamp is two concentric dark ovals with a few cross-grain
# spurs — reads as "wood knot" at any size.
func _draw_silver_knot(inner: Rect2) -> void:

	var shadow_rect : Rect2 = inner
	shadow_rect.position.y += 1.5
	draw_rect(shadow_rect, COLOR_SILVER_SHADOW)
	draw_rect(inner, COLOR_SILVER_FACE)
	var center : Vector2 = inner.position + inner.size * 0.5
	var radius : float = inner.size.x * 0.30
	# Two concentric dark ovals — the knot whorl.
	draw_circle(center, radius, COLOR_KNOT_DARK)
	draw_circle(center, radius * 0.62, COLOR_KNOT_RING)
	draw_circle(center, radius * 0.30, COLOR_KNOT_DARK)
	# Cross-grain spurs radiating out — three short lines for "gnarl."
	for i in range(3):
		var angle : float = (i / 3.0) * TAU
		var p0 : Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.85
		var p1 : Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + 4.0)
		draw_line(p0, p1, COLOR_KNOT_DARK, 1.5)


# Turn-2: opaque gray block, knot image gone. Still immovable.
func _draw_opaque(inner: Rect2) -> void:

	var shadow_rect : Rect2 = inner
	shadow_rect.position.y += 1.5
	draw_rect(shadow_rect, COLOR_OPAQUE.darkened(0.25))
	draw_rect(inner, COLOR_OPAQUE)


# Turn-3: translucent — visibly resolving into a normal block soon.
func _draw_translucent(inner: Rect2) -> void:

	draw_rect(inner, COLOR_TRANSLUCENT)
## A single see-saw switch (the "paddle") on the Gem Drop board. Owns
## its own visual (beam + pad + pivot) AND its rocking animation
## (visual_pad_t lerping toward pad_side). Standalone @tool scene so
## the paddle visual can be replaced later by swapping its [_draw] or
## adding a sprite — board.gd never touches the drawing code anymore.
##
## ## Local coordinates
##
## The Switch is positioned by [GemDropBoard] at the PIVOT point
## (between col_left and col_right, at the row's Y). All drawing is
## relative to this origin: beam ends rise ±[const SWITCH_RISE] from
## (0, 0) depending on [member visual_pad_t]; the pad slides along the
## tilted beam between the two ends.
##
## ## State
##
##   [member col_left] / [member col_right] — column indices in the
##   board's grid (for game-logic routing, NOT for drawing scale).
##
##   [member pad_side] — current pad orientation, +1 = right, -1 = left.
##   Mutated by the board's collision resolution; the animation eases
##   [member visual_pad_t] toward it.
##
##   [member resting_coin] — the [Gem] currently resting on the pad,
##   or null. Set/cleared by the board's resolve methods.
@tool
class_name Switch
extends Node2D


# --- Geometry constants (was on GemDropBoard) ----------------------------
const SWITCH_RISE : float = 9.0
const SWITCH_BEAM_THICKNESS : float = 8.0
const SWITCH_PAD_GAP : float = 1.0
const SWITCH_PAD_HEIGHT : float = 5.0
## How far the cradle's lips rise above its centre dip — turns the flat plate
## into a concave cup the round coin nestles into (Troy 2026-06-14). Purely
## visual; the landing plane (the dip) stays at the old pad-top level.
const SWITCH_PAD_CUP_DEPTH : float = 5.0

## Forged-STEEL mechanism palette (Troy 2026-06-15 — rebuilt to an intricate
## see-saw: riveted arm + cradle cup + bronze counterweight + screw-bolt pivot).
## Steel reads cool against the gold coins, so coin-on-paddle never blends.
const STEEL : Color = Color(0.58, 0.62, 0.70, 1.0)
const STEEL_HI : Color = Color(0.90, 0.93, 0.99, 1.0)
const STEEL_EDGE : Color = Color(0.14, 0.16, 0.22, 1.0)
const KNOB : Color = Color(0.76, 0.56, 0.30, 1.0)        # warm bronze counterweight ball
const KNOB_HI : Color = Color(0.97, 0.84, 0.52, 1.0)
## Y offset (from pivot) at which the pad's TOP surface sits when the
## beam is fully tilted to that side. The pad's top is the contact
## plane — a gem's bottom should land exactly on this line.
const PAD_TOP_OFFSET_FROM_ROW_Y : float = SWITCH_RISE - SWITCH_BEAM_THICKNESS - SWITCH_PAD_GAP  # = 1.0
const PAD_HALF_WIDTH : float = 14.0  # pad is 28 px wide

# --- Animation constants -------------------------------------------------
## Linear units per second for the visual rocking. visual_pad_t spans
## -1..+1 (range 2), so e.g. 5.0 means a full side-to-side swing takes
## about 0.4s — visibly readable, not a snap. Wobble kicks share this
## rate so the impact dip settles in proportion.
const PADDLE_SWING_SPEED : float = 5.0
## How far past the OLD pad side visual_pad_t is nudged on an
## occupied-pad bounce — gives the paddle an "impact dip" before it
## tips through to its new orientation.
const BOUNCE_WOBBLE_KICK : float = 0.45
## Clamp magnitude for visual_pad_t during bounces. Limits the wobble.
const MAX_VISUAL_TILT : float = 1.6

# --- Side flags ----------------------------------------------------------
const PAD_LEFT : int = -1
const PAD_RIGHT : int = 1


# --- Exports (configurable per-instance in editor) -----------------------
## Distance in pixels between two adjacent column centers — should
## match [const GemDropBoard.COLUMN_SPACING]. The Switch uses this to
## scale its beam width from col_left/col_right indices.
@export var column_spacing : float = 36.0 :
	set(value):
		column_spacing = value
		queue_redraw()
## Left column index in the board's grid (game-logic routing).
@export var col_left : int = 0 :
	set(value):
		col_left = value
		queue_redraw()
## Right column index in the board's grid (game-logic routing).
@export var col_right : int = 1 :
	set(value):
		col_right = value
		queue_redraw()
## Pad orientation at scene start. +1 = right, -1 = left. Read once on
## _ready into [member pad_side]; further changes during gameplay live
## on [member pad_side] directly.
@export_enum("Left:-1", "Right:1") var initial_pad_side : int = PAD_RIGHT :
	set(value):
		initial_pad_side = value
		# In editor, preview the orientation live.
		if Engine.is_editor_hint():
			pad_side = value
			visual_pad_t = float(value)
			queue_redraw()

@export_category("Colors")
@export var color_beam : Color = Color(0.58, 0.62, 0.70, 1.0)   # steel arm
@export var color_pad : Color = Color(0.72, 0.76, 0.83, 1.0)    # brighter steel cradle cup
@export var color_pivot : Color = Color(0.66, 0.70, 0.77, 1.0)  # steel pivot boss


# --- Runtime state -------------------------------------------------------
## Current pad orientation. Mutated by the board's resolve methods.
var pad_side : int = PAD_RIGHT
## Animated tilt value — lerps toward [member pad_side]. Values past
## ±1 are transient impact-wobble during occupied-pad bounces.
var visual_pad_t : float = 1.0
## The [Gem] currently sitting on this switch's pad, or null.
var resting_coin : Gem = null


func _ready() -> void:

	pad_side = initial_pad_side
	visual_pad_t = float(initial_pad_side)
	queue_redraw()


func _process(delta: float) -> void:

	# Move visual_pad_t toward pad_side at a constant linear rate —
	# linear (move_toward) reads as a deliberate physical rock rather
	# than the snappy-then-crawl curve a lerpf would give. Once it
	# reaches pad_side exactly, the early-return makes this a no-op.
	var target : float = float(pad_side)
	if visual_pad_t == target:
		return
	visual_pad_t = move_toward(visual_pad_t, target, PADDLE_SWING_SPEED * delta)
	queue_redraw()


func _draw() -> void:

	# All coordinates are local — Switch.position is the pivot point.
	# The beam ROTATES around the pivot rather than tilting in place;
	# the pad is pegged to one PHYSICAL end of the beam and SWINGS
	# with it through an arc that passes over the top, matching the
	# YPP see-saw paddle behavior. The pad's REST positions sit just
	# below the pivot (SWITCH_RISE pixels down) so a resting coin
	# lands at the same Y the board's collision math expects.
	var half_w : float = (col_right - col_left) * column_spacing * 0.5
	var t : float = visual_pad_t
	# Geometry: at rest the beam tilts so the pad-end is at
	# (±half_w, +SWITCH_RISE). The beam length from pivot to pad-end
	# is the hypotenuse, and the rest angle (below horizontal) is the
	# atan2 of those two.
	var rest_angle : float = atan2(SWITCH_RISE, half_w)
	var beam_radius : float = sqrt(half_w * half_w + SWITCH_RISE * SWITCH_RISE)
	# Map visual_pad_t → rotation angle (math convention: +x = 0,
	# +PI/2 = up, PI = -x). Arc goes through the top so the pad
	# physically swings up-and-over to the other column.
	#   t = +1 → angle = -rest_angle (pad-end at LOWER-RIGHT, rest)
	#   t =  0 → angle = +PI/2       (pad-end straight UP, mid-swing)
	#   t = -1 → angle = PI + rest_angle (pad-end at LOWER-LEFT, rest)
	var angle : float = lerpf(-rest_angle, PI + rest_angle, (1.0 - t) * 0.5)
	var dir : Vector2 = Vector2(cos(angle), -sin(angle))  # negate sin: math up → Godot y-down
	var pad_end : Vector2 = dir * beam_radius
	var lever_end : Vector2 = -dir * beam_radius
	# Perpendicular to the beam direction — used for beam thickness.
	var perp : Vector2 = Vector2(-dir.y, dir.x)
	var ht : float = SWITCH_BEAM_THICKNESS * 0.5
	# Beam polygon: rotated rectangle from pad_end → lever_end.
	var beam_poly : PackedVector2Array = PackedVector2Array([
		pad_end + perp * ht,
		lever_end + perp * ht,
		lever_end - perp * ht,
		pad_end - perp * ht,
	])
	# --- The steel lever ARM, beveled with a centre sheen + flanking rivets ---
	draw_colored_polygon(beam_poly, color_beam)
	draw_line(pad_end + perp * ht, lever_end + perp * ht, STEEL_HI, 1.2)    # lit top edge
	draw_line(pad_end - perp * ht, lever_end - perp * ht, STEEL_EDGE, 1.2)  # shadowed bottom edge
	draw_line(pad_end, lever_end, STEEL_HI, 1.0)                            # rounded-metal sheen down the arm
	_draw_rivet(dir * (half_w * 0.55))
	_draw_rivet(-dir * (half_w * 0.55))

	# --- Bronze COUNTERWEIGHT knob on the lever end (a ball on a short neck) ---
	var neck : Vector2 = lever_end - dir * 3.0
	var knob : Vector2 = lever_end - dir * 7.0
	draw_line(neck, knob, color_beam, SWITCH_BEAM_THICKNESS * 0.7)
	draw_circle(knob, 7.0, STEEL_EDGE)                          # dark rim
	draw_circle(knob, 6.0, KNOB)                                # bronze ball
	draw_arc(knob, 5.0, PI * 0.9, PI * 1.65, 12, KNOB_HI, 1.4)  # lit crescent
	draw_circle(knob + Vector2(-1.6, -1.8), 1.4, KNOB_HI)       # specular

	# --- LEVEL steel cradle CUP mounted at the pad end (coin rests centred) ---
	# C is the cup's centre dip, exactly where the board rests the coin's bottom-
	# centre (pad end lifted by SWITCH_RISE to the row line); a stem keeps it
	# mounted to the arm through the whole swing.
	var C : Vector2 = Vector2(pad_end.x, pad_end.y - SWITCH_RISE)
	draw_line(pad_end, C, color_beam, SWITCH_BEAM_THICKNESS * 0.8)
	var samples : int = 6
	var top_edge : PackedVector2Array = PackedVector2Array()
	var bottom_edge : PackedVector2Array = PackedVector2Array()
	for i in samples + 1:
		var s : float = lerpf(-PAD_HALF_WIDTH, PAD_HALF_WIDTH, float(i) / float(samples))
		var rise : float = SWITCH_PAD_CUP_DEPTH * pow(s / PAD_HALF_WIDTH, 2.0)   # lips rise above the centre dip
		top_edge.append(C + Vector2(s, -rise))
		bottom_edge.append(C + Vector2(s, -rise + SWITCH_PAD_HEIGHT))
	for i in samples:
		draw_colored_polygon(PackedVector2Array([
			top_edge[i], top_edge[i + 1], bottom_edge[i + 1], bottom_edge[i]]), color_pad)
	draw_polyline(top_edge, STEEL_HI, 1.6)                                          # lit cradle rim
	draw_line(bottom_edge[0], bottom_edge[bottom_edge.size() - 1], STEEL_EDGE, 1.2) # shadowed under-edge
	draw_circle(top_edge[0], 2.2, STEEL_HI)                                         # upturned lip horns
	draw_circle(top_edge[top_edge.size() - 1], 2.2, STEEL_HI)

	# --- Two screw-bolt PIVOTS, both real axes of rotation (Troy 2026-06-15):
	# the CUP-HOLDER pivot at the arm tip (the cradle gimbals on it to stay
	# level as the arm tilts) and the CENTRE fulcrum (the whole arm see-saws
	# around it). The cup pivot draws first so the fulcrum reads as the anchor.
	_draw_bolt(pad_end, 5.0)
	_draw_bolt(Vector2.ZERO, 7.0)


# A small forged rivet (dark seat + domed steel head + specular) on the arm.
func _draw_rivet(p: Vector2) -> void:

	draw_circle(p, 2.4, STEEL_EDGE)
	draw_circle(p, 1.7, STEEL_HI.lerp(STEEL, 0.35))
	draw_circle(p + Vector2(-0.5, -0.6), 0.7, STEEL_HI)


# A screw-bolt PIVOT (steel boss + dark ring + domed inner + cross-slot +
# specular). Used for BOTH rotation axes — the centre fulcrum and the cup pivot.
func _draw_bolt(p: Vector2, r: float) -> void:

	draw_circle(p, r, color_pivot)
	draw_arc(p, r, 0.0, TAU, 20, STEEL_EDGE, 1.4)
	draw_circle(p, r * 0.57, STEEL_HI.lerp(color_pivot, 0.45))
	var s : float = r * 0.43
	draw_line(p + Vector2(-s, 0.0), p + Vector2(s, 0.0), STEEL_EDGE, 1.2)
	draw_line(p + Vector2(0.0, -s), p + Vector2(0.0, s), STEEL_EDGE, 1.2)
	draw_circle(p + Vector2(-r * 0.3, -r * 0.32), maxf(0.9, r * 0.18), STEEL_HI)


# --- Convenience methods used by the board ------------------------------

## Column where the PAD currently sits (the resting-side column).
func pad_col() -> int:

	return col_right if pad_side == PAD_RIGHT else col_left


## Column where the LEVER currently sits (the side that flips the
## switch when a coin passes through it).
func lever_col() -> int:

	return col_left if pad_side == PAD_RIGHT else col_right


## Flip pad_side to the opposite orientation.
func flip() -> void:

	pad_side = -pad_side


## Kick visual_pad_t past the current side by [const BOUNCE_WOBBLE_KICK]
## — gives the paddle an impact dip on a bounce before the lerp tips
## it through to its new orientation.
func wobble_kick() -> void:

	var kick : float = BOUNCE_WOBBLE_KICK * float(pad_side)
	visual_pad_t = clampf(visual_pad_t + kick, -MAX_VISUAL_TILT, MAX_VISUAL_TILT)
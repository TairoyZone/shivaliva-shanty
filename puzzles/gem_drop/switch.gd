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
@export var color_beam : Color = Palette.BRASS_FRAME   # brass mechanism on the dark Stardust field = max contrast
@export var color_pad : Color = Palette.BRASS_PAD
@export var color_pivot : Color = Palette.BRASS_FRAME


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
	draw_colored_polygon(beam_poly, color_beam)
	# Bevel the beam for volume: a bright top edge + a dark bottom edge (one consistent up-left key light), instead
	# of a flat outline — the same highlight/shadow-pair language as the poker pass.
	draw_line(pad_end + perp * ht, lever_end + perp * ht, Palette.BRASS_BRIGHT, 1.0)
	draw_line(pad_end - perp * ht, lever_end - perp * ht, Palette.SKY_VOID, 1.0)
	# Pad: a LEVEL (horizontal) cupped cradle mounted at the beam's pad end, so the round coin always rests flat and
	# perfectly CENTRED in it no matter how the see-saw is tilted (Troy 2026-06-14 — the parallel-to-beam cup made
	# the upright coin look awkward at the ~27 deg rest angle). C is the cup's centre dip, and it equals EXACTLY
	# where the board rests the coin's bottom-centre (the pad end lifted by SWITCH_RISE back up to the row line).
	# A short stem keeps the cup mounted to the beam through the swing.
	var C : Vector2 = Vector2(pad_end.x, pad_end.y - SWITCH_RISE)
	draw_line(pad_end, C, color_beam, SWITCH_BEAM_THICKNESS * 0.8)
	var samples : int = 6
	var top_edge : PackedVector2Array = PackedVector2Array()
	var bottom_edge : PackedVector2Array = PackedVector2Array()
	for i in samples + 1:
		var s : float = lerpf(-PAD_HALF_WIDTH, PAD_HALF_WIDTH, float(i) / float(samples))
		var rise : float = SWITCH_PAD_CUP_DEPTH * pow(s / PAD_HALF_WIDTH, 2.0)   # lips rise above the centre dip
		top_edge.append(C + Vector2(s, -rise))                            # level: dip at centre, lips curve up
		bottom_edge.append(C + Vector2(s, -rise + SWITCH_PAD_HEIGHT))     # plate underside
	# Fill as a strip of CONVEX quads (one concave polygon trips draw_colored_polygon's convex-only path).
	for i in samples:
		draw_colored_polygon(PackedVector2Array([
			top_edge[i], top_edge[i + 1], bottom_edge[i + 1], bottom_edge[i]]), color_pad)
	draw_polyline(top_edge, Palette.BRASS_BRIGHT, 1.5)                                       # lit cradle rim
	draw_line(bottom_edge[0], bottom_edge[bottom_edge.size() - 1], Palette.SKY_VOID, 1.0)    # shadowed under-edge
	# Pivot BOLT at the origin — a real anchor the eye can read row-to-row (was a tiny 4px dot).
	draw_circle(Vector2.ZERO, 6.0, Palette.BRASS_FRAME)
	draw_circle(Vector2.ZERO, 3.0, Palette.BRASS_PAD)
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Palette.SKY_VOID, 1.0)
	draw_circle(Vector2(-1.5, -1.5), 1.0, Palette.GOLD_GLOW)


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
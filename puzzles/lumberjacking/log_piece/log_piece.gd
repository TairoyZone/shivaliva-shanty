## A single board cell in the Lumberjacking puzzle — one of 4 wood
## kinds, either SOLID (lands and stays) or BREAKER (shatters connected
## same-kind solids on contact). Mirrors the YPP SwordFighting piece
## model precisely, just reskinned for wood.
##
## The board owns position + state. This scene only knows how to draw
## itself given its kind + variant. Per the scene-per-component
## principle, this is a standalone .tscn so art can swap in later
## without touching the board logic.
##
## See [[lumberjacking-spec]] for the full mechanical spec.
@tool
class_name LogPiece
extends Node2D


## Four wood kinds — fantasy-lore names (the floating-island universe
## grows otherworldly woods, not Earth species). All 4 are mechanically
## identical, YPP-SwF-style — color is purely a sorting/matching
## identifier.
##   SUNPINE   — touched by the sun pillar; bright golden yellow
##   CORALWOOD — warm crimson, grows around the warm pillars
##   MOSSWOOD  — vibrant green, from the verdant islands
##   STORMWOOD — steel blue, weathered by the storm winds
enum WoodKind { SUNPINE, CORALWOOD, MOSSWOOD, STORMWOOD }

## SOLID = lands and remains. BREAKER = shatters on adjacent same-kind
## contact (axe-bitten cutout look).
enum Variant { SOLID, BREAKER }


## Cell size in pixels — also the board's grid step. 36px reads chunky
## like SwF without crowding a 6-wide board on a 1080p screen.
const CELL_SIZE : float = 36.0
## Inner padding so adjacent same-kind solids visibly TOUCH at their
## edges (the fusion read works because the inner rects share edges).
const CELL_PAD : float = 2.0
## Grain stripes drawn across the face — gives the cell a "log section"
## read at any size.
const GRAIN_STRIPE_COUNT : int = 3
const GRAIN_STRIPE_WIDTH : float = 1.4


## Per-kind face + shadow + grain colors. BELIEVABLE WOOD tones, not rainbow
## candy (Troy 2026-06-15, the same call as the Mining terrain pass): four
## distinct stains that still read apart at speed but clearly look like wood.
##   SUNPINE   — pale honey pine
##   CORALWOOD — warm red cedar
##   MOSSWOOD  — moss-aged olive wood
##   STORMWOOD — weathered grey-blue driftwood
const KIND_COLORS : Dictionary = {
	WoodKind.SUNPINE: {
		"face": Color(0.84, 0.68, 0.42, 1.0),
		"shadow": Color(0.60, 0.46, 0.24, 1.0),
		"grain": Color(0.46, 0.33, 0.16, 1.0),
	},
	WoodKind.CORALWOOD: {
		"face": Color(0.71, 0.40, 0.29, 1.0),
		"shadow": Color(0.48, 0.24, 0.17, 1.0),
		"grain": Color(0.34, 0.16, 0.11, 1.0),
	},
	WoodKind.MOSSWOOD: {
		"face": Color(0.53, 0.57, 0.35, 1.0),
		"shadow": Color(0.34, 0.39, 0.21, 1.0),
		"grain": Color(0.23, 0.27, 0.13, 1.0),
	},
	WoodKind.STORMWOOD: {
		"face": Color(0.47, 0.53, 0.59, 1.0),
		"shadow": Color(0.29, 0.35, 0.41, 1.0),
		"grain": Color(0.18, 0.23, 0.29, 1.0),
	},
}


@export var wood_kind : WoodKind = WoodKind.SUNPINE :
	set(value):
		wood_kind = value
		queue_redraw()
@export var variant : Variant = Variant.SOLID :
	set(value):
		variant = value
		queue_redraw()


## A stable per-piece seed so the grain figure is varied but never shimmers
## (re-seeding off the changing fall position would). Set once on _ready.
var _seed : int = 0


func _ready() -> void:

	_seed = randi()


func _draw() -> void:

	var palette : Dictionary = KIND_COLORS[wood_kind]
	var face_color : Color = palette["face"]
	var shadow_color : Color = palette["shadow"]
	var grain_color : Color = palette["grain"]
	# The cell extends from origin (top-left) to (CELL_SIZE, CELL_SIZE).
	# Inner rect leaves a thin pad so neighbors abut cleanly.
	var inner : Rect2 = Rect2(
		CELL_PAD, CELL_PAD,
		CELL_SIZE - 2.0 * CELL_PAD,
		CELL_SIZE - 2.0 * CELL_PAD)
	# Drop shadow for a touch of depth.
	var shadow_rect : Rect2 = inner
	shadow_rect.position.y += 1.5
	draw_rect(shadow_rect, shadow_color)
	# Rounded (cylindrical) face: light top -> dark bottom bands for volume.
	var bands : int = 4
	for b in bands:
		var bt : float = float(b) / float(bands - 1)
		var bc : Color = face_color.lightened(0.10).lerp(face_color.darkened(0.10), bt)
		draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * float(b) / float(bands),
			inner.size.x, inner.size.y / float(bands) + 1.0), bc)
	# End-grain rings + a per-kind grain SIGNATURE (a sawn-log read + a second
	# identity channel: SUNPINE knot, CORALWOOD big rings, MOSSWOOD flecks,
	# STORMWOOD checks).
	_draw_grain_signature(inner, grain_color)
	# Two-step beveled chamfer (lit top/left, shadowed bottom/right).
	var c_tl : Vector2 = inner.position
	var c_tr : Vector2 = Vector2(inner.end.x, inner.position.y)
	var c_bl : Vector2 = Vector2(inner.position.x, inner.end.y)
	var c_br : Vector2 = inner.end
	draw_line(c_tl, c_tr, face_color.lightened(0.28), 1.5)
	draw_line(c_tl, c_bl, face_color.lightened(0.20), 1.5)
	draw_line(c_bl, c_br, shadow_color.darkened(0.12), 1.6)
	draw_line(c_tr, c_br, shadow_color.darkened(0.06), 1.4)
	draw_line(c_tl + Vector2(1.5, 1.5), c_tr + Vector2(-1.5, 1.5), face_color.lightened(0.14), 1.0)
	# Corner specular (upper-left key, matches the backdrops' dawn / lantern light).
	draw_circle(inner.position + Vector2(3.0, 3.0), 2.0, Color(1.0, 1.0, 1.0, 0.26))
	# Breaker variant — stamp a big dark AXE silhouette across the face
	# so the player can read "this is a breaker" at a single glance,
	# even at the bottom of a busy stack. The axe is a chunky
	# wedge-headed shape with a vertical handle, drawn in near-black so
	# it punches through any wood-kind color.
	if variant == Variant.BREAKER:
		_draw_axe_stamp()


# End-grain growth rings from an off-center pith + a per-kind accent, so each
# plank reads as a sawn log section and each wood has its own figure.
func _draw_grain_signature(inner: Rect2, grain: Color) -> void:

	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed
	var g : Color = Color(grain.r, grain.g, grain.b, 0.5)
	var left : bool = (rng.randi() % 2 == 0)
	var pith : Vector2 = inner.position + Vector2(inner.size.x * (0.22 if left else 0.78), inner.size.y * 0.80)
	var base_ang : float = (inner.get_center() - pith).angle()
	var step : float = inner.size.x * 0.26
	if wood_kind == WoodKind.CORALWOOD:
		step = inner.size.x * 0.33   # cedar = big loose rings (its fingerprint)
	elif wood_kind == WoodKind.SUNPINE:
		step = inner.size.x * 0.20   # pine = tight straight-ish grain
	for i in range(1, 4):
		draw_arc(pith, step * float(i), base_ang - 1.3, base_ang + 1.3, 14, g, 1.2)
	draw_circle(pith, 1.4, grain)
	match wood_kind:
		WoodKind.SUNPINE:
			var kp : Vector2 = inner.position + inner.size * Vector2(0.64, 0.30)   # a small knot
			draw_circle(kp, 2.6, grain)
			draw_arc(kp, 3.6, 0.0, TAU, 10, g, 1.0)
		WoodKind.MOSSWOOD:
			for _i in 4:
				var fp : Vector2 = inner.position + inner.size * Vector2(rng.randf_range(0.20, 0.80), rng.randf_range(0.25, 0.78))
				draw_circle(fp, 1.4, grain.darkened(0.10))
		WoodKind.STORMWOOD:
			var dg : Color = grain.darkened(0.10)   # dry checks/cracks
			draw_line(inner.position + inner.size * Vector2(0.32, 0.42), inner.position + inner.size * Vector2(0.32, 0.72), dg, 1.0)
			draw_line(inner.position + inner.size * Vector2(0.62, 0.28), inner.position + inner.size * Vector2(0.62, 0.56), dg, 1.0)


# Big dark axe silhouette: triangular wedge-head at the TOP-LEFT (the
# blade), a thin handle running diagonally toward the bottom-right.
# Drawn in dark grain tone — reads on any wood-kind face color.
func _draw_axe_stamp() -> void:

	var stamp_color : Color = Color(0.06, 0.04, 0.02, 1.0)
	var stamp_highlight : Color = Color(0.92, 0.82, 0.55, 0.85)
	# Axe head — a wide pentagon (wedge blade). Drawn in the upper-left
	# corner of the cell, pointing diagonally.
	var head : PackedVector2Array = PackedVector2Array([
		Vector2(CELL_SIZE * 0.10, CELL_SIZE * 0.20),  # top-back of blade
		Vector2(CELL_SIZE * 0.62, CELL_SIZE * 0.16),  # top-front of blade
		Vector2(CELL_SIZE * 0.78, CELL_SIZE * 0.36),  # cutting edge tip
		Vector2(CELL_SIZE * 0.46, CELL_SIZE * 0.48),  # bottom-front of blade
		Vector2(CELL_SIZE * 0.18, CELL_SIZE * 0.42),  # bottom-back of blade
	])
	draw_colored_polygon(head, stamp_color)
	# Highlight stripe along the cutting edge for "bladed metal" read.
	draw_line(
		Vector2(CELL_SIZE * 0.60, CELL_SIZE * 0.20),
		Vector2(CELL_SIZE * 0.76, CELL_SIZE * 0.34),
		stamp_highlight, 1.4)
	# Handle — a thick line running from under the axe head to the
	# bottom-right corner of the cell.
	draw_line(
		Vector2(CELL_SIZE * 0.36, CELL_SIZE * 0.48),
		Vector2(CELL_SIZE * 0.88, CELL_SIZE * 0.92),
		stamp_color, CELL_SIZE * 0.10)
	# Subtle outline on the axe head so it stays crisp even when the
	# underlying face is a similarly dark wood kind.
	draw_polyline(head, Color(1, 1, 1, 0.25), 1.2)

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
	# Plank face.
	draw_rect(inner, face_color)
	# Beveled edges (lit top/left, shadowed bottom/right) — a carved wood block.
	var c_tl : Vector2 = inner.position
	var c_tr : Vector2 = Vector2(inner.end.x, inner.position.y)
	var c_bl : Vector2 = Vector2(inner.position.x, inner.end.y)
	var c_br : Vector2 = inner.end
	draw_line(c_tl, c_tr, face_color.lightened(0.22), 1.6)
	draw_line(c_tl, c_bl, face_color.lightened(0.13), 1.4)
	draw_line(c_bl, c_br, shadow_color.darkened(0.10), 1.6)
	draw_line(c_tr, c_br, shadow_color.darkened(0.04), 1.4)
	# Wood GRAIN — a few slightly wavy lines across the face (boards stacked flat).
	for k in GRAIN_STRIPE_COUNT:
		var gy : float = inner.position.y + inner.size.y * (0.28 + float(k) * 0.22)
		var pts : PackedVector2Array = PackedVector2Array()
		for j in 5:
			var tx : float = float(j) / 4.0
			var wob : float = sin(float(k) * 2.1 + tx * 5.0) * 1.4
			pts.append(Vector2(inner.position.x + 2.0 + (inner.size.x - 4.0) * tx, gy + wob))
		draw_polyline(pts, grain_color, GRAIN_STRIPE_WIDTH)
	# A faint lighter fleck near the top for figure.
	draw_line(
		Vector2(inner.position.x + inner.size.x * 0.20, inner.position.y + inner.size.y * 0.15),
		Vector2(inner.position.x + inner.size.x * 0.70, inner.position.y + inner.size.y * 0.15),
		face_color.lightened(0.10), 1.0)
	# Breaker variant — stamp a big dark AXE silhouette across the face
	# so the player can read "this is a breaker" at a single glance,
	# even at the bottom of a busy stack. The axe is a chunky
	# wedge-headed shape with a vertical handle, drawn in near-black so
	# it punches through any wood-kind color.
	if variant == Variant.BREAKER:
		_draw_axe_stamp()


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

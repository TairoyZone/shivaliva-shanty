## A single mineral tile on the Mining board — one of 5 rock kinds.
## This is the reskin of YPP Foraging's 5 landscape tiles (rock /
## foliage / wood / sand / soil). All five are mechanically identical;
## the color is purely a match identifier (a row/column of 3+ same-kind
## crumbles). The board owns position + grid state — this scene only
## knows how to draw itself given its kind. Per the scene-per-component
## principle it is a standalone .tscn so real art can swap in later
## without touching the board logic.
##
## See [[mining-spec]] for the full mechanical design.
@tool
class_name MiningRockTile
extends Node2D


## Five mineral kinds — fantasy strata for the floating-island universe.
## Mechanically identical; spread across the hue wheel (grey / blue /
## green / gold / red) so they read apart instantly at speed, the way
## Foraging's tile set does.
##   GRANITE   — cool grey, the plain bedrock
##   COBALT    — deep blue ore-bearing rock
##   MALACHITE — copper-green mineral
##   SULFUR    — bright golden-yellow crystal
##   GARNET    — crimson gem-rock
enum RockKind { GRANITE, COBALT, MALACHITE, SULFUR, GARNET }


## Cell size in pixels — also the board's grid step. MUST match
## MiningBoard.CELL. 44px reads chunky on an 8-wide board at 1080p.
const CELL_SIZE : float = 44.0
## Inner padding so a thin dark "grout" of the board backing shows
## between tiles — gives the grid a carved-rock-face read.
const CELL_PAD : float = 2.5


## Per-kind face / shadow / crack / facet colors. Saturated + high
## contrast — readability beats naturalism, same call as the lumber set.
const KIND_COLORS : Dictionary = {
	RockKind.GRANITE: {
		"face": Color(0.60, 0.63, 0.69, 1.0),
		"shadow": Color(0.38, 0.40, 0.46, 1.0),
		"crack": Color(0.24, 0.25, 0.30, 1.0),
		"facet": Color(0.84, 0.86, 0.92, 0.9),
	},
	RockKind.COBALT: {
		"face": Color(0.30, 0.52, 0.88, 1.0),
		"shadow": Color(0.15, 0.31, 0.60, 1.0),
		"crack": Color(0.06, 0.16, 0.38, 1.0),
		"facet": Color(0.66, 0.82, 1.00, 0.9),
	},
	RockKind.MALACHITE: {
		"face": Color(0.28, 0.72, 0.46, 1.0),
		"shadow": Color(0.14, 0.47, 0.28, 1.0),
		"crack": Color(0.05, 0.26, 0.15, 1.0),
		"facet": Color(0.68, 0.96, 0.78, 0.9),
	},
	RockKind.SULFUR: {
		"face": Color(0.96, 0.81, 0.26, 1.0),
		"shadow": Color(0.72, 0.56, 0.10, 1.0),
		"crack": Color(0.44, 0.33, 0.05, 1.0),
		"facet": Color(1.00, 0.96, 0.66, 0.9),
	},
	RockKind.GARNET: {
		"face": Color(0.86, 0.29, 0.31, 1.0),
		"shadow": Color(0.58, 0.13, 0.16, 1.0),
		"crack": Color(0.33, 0.05, 0.08, 1.0),
		"facet": Color(1.00, 0.70, 0.66, 0.9),
	},
}


@export var rock_kind : RockKind = RockKind.GRANITE :
	set(value):
		rock_kind = value
		queue_redraw()


func _draw() -> void:

	var palette : Dictionary = KIND_COLORS[rock_kind]
	var face_color : Color = palette["face"]
	var shadow_color : Color = palette["shadow"]
	var crack_color : Color = palette["crack"]
	var facet_color : Color = palette["facet"]
	# Inner rect leaves the grout pad on every side.
	var inner : Rect2 = Rect2(
		CELL_PAD, CELL_PAD,
		CELL_SIZE - 2.0 * CELL_PAD,
		CELL_SIZE - 2.0 * CELL_PAD)
	# Shadow base — a touch taller/offset down so the tile reads with a
	# little depth (a chunk of rock, not a flat sticker).
	var shadow_rect : Rect2 = inner
	shadow_rect.position.y += 2.0
	draw_rect(shadow_rect, shadow_color)
	# Face on top.
	draw_rect(inner, face_color)
	# Top-left facet highlight — a lit corner triangle so the rock catches
	# the light from the upper-left, like a faceted gem face.
	var facet : PackedVector2Array = PackedVector2Array([
		inner.position,
		Vector2(inner.position.x + inner.size.x * 0.55, inner.position.y),
		Vector2(inner.position.x, inner.position.y + inner.size.y * 0.55),
	])
	draw_colored_polygon(facet, facet_color)
	# A couple of crack lines so the face isn't a flat block — diagonal
	# fissures in the darkest kind tone.
	draw_line(
		Vector2(inner.position.x + inner.size.x * 0.30, inner.position.y + inner.size.y * 0.18),
		Vector2(inner.position.x + inner.size.x * 0.66, inner.end.y - inner.size.y * 0.12),
		crack_color, 1.6)
	draw_line(
		Vector2(inner.end.x - inner.size.x * 0.22, inner.position.y + inner.size.y * 0.40),
		Vector2(inner.end.x - inner.size.x * 0.06, inner.position.y + inner.size.y * 0.70),
		crack_color, 1.3)
	# Crisp dark outline so adjacent same-kind tiles still read as
	# separate cells (matters when a 3-run is about to crumble).
	draw_rect(inner, shadow_color.darkened(0.25), false, 1.5)
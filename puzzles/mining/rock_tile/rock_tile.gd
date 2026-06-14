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
	# Inner cell with grout pad.
	var inner : Rect2 = Rect2(
		CELL_PAD, CELL_PAD,
		CELL_SIZE - 2.0 * CELL_PAD,
		CELL_SIZE - 2.0 * CELL_PAD)
	# Carved socket recess so each gem reads as set INTO the rock face.
	draw_rect(inner, crack_color.darkened(0.35))
	# Octagon (cut-gem silhouette), inset a touch inside the socket.
	var g : Rect2 = inner.grow(-2.0)
	var c : float = minf(g.size.x, g.size.y) * 0.24
	var oct : PackedVector2Array = PackedVector2Array([
		Vector2(g.position.x + c, g.position.y),
		Vector2(g.end.x - c, g.position.y),
		Vector2(g.end.x, g.position.y + c),
		Vector2(g.end.x, g.end.y - c),
		Vector2(g.end.x - c, g.end.y),
		Vector2(g.position.x + c, g.end.y),
		Vector2(g.position.x, g.end.y - c),
		Vector2(g.position.x, g.position.y + c),
	])
	var centre : Vector2 = g.position + g.size * 0.5
	# Drop shadow under the gem (depth in the socket).
	var drop : PackedVector2Array = PackedVector2Array()
	for p in oct:
		drop.append(p + Vector2(0.0, 2.0))
	draw_colored_polygon(drop, Color(0.0, 0.0, 0.0, 0.45))
	# Radial CUT: 8 facets meeting at the centre, shaded by one up-left key
	# light so the gem reads as a faceted dome (bright top-left -> dark
	# bottom-right). The hue stays the kind's, only light->dark varies.
	var light_dir : Vector2 = Vector2(-0.45, -0.89)
	for i in 8:
		var a : Vector2 = oct[i]
		var b : Vector2 = oct[(i + 1) % 8]
		var n : Vector2 = ((a + b) * 0.5 - centre).normalized()
		var lit : float = clampf(n.dot(light_dir) * 0.5 + 0.5, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([a, b, centre]),
			shadow_color.lerp(facet_color, lit * lit))   # squared falloff = crisper facets
	# Centre table pip + a specular spark up-left.
	draw_circle(centre, g.size.x * 0.10, face_color.lightened(0.18))
	draw_circle(centre + light_dir * g.size.x * 0.26, g.size.x * 0.07, facet_color.lightened(0.30))
	# Beveled outline: a crisp dark rim (keeps adjacent same-kind gems
	# readable) with a brighter lit edge along the top-left.
	var rim : PackedVector2Array = oct.duplicate()
	rim.append(oct[0])
	draw_polyline(rim, crack_color, 1.4)
	draw_line(oct[7], oct[0], facet_color.lightened(0.25), 1.4)
	draw_line(oct[0], oct[1], facet_color.lightened(0.10), 1.2)
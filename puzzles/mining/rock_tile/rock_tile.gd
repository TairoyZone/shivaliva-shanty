## A single terrain tile on the Mining board — one of 5 MUNDANE materials
## (the reskin of YPP Foraging's 5 landscape tiles). All five are
## mechanically identical; the material is purely a match identifier (a
## row/column of 3+ of the same kind crumbles).
##
## DELIBERATELY humble + matte — these are common dirt and rock, NOT gems.
## The shiny faceted gems are reserved for the valuable ORE chunks, so the
## player can tell cheap terrain from treasure at a glance (Troy 2026-06-15:
## "make the common tiles stone/soil/gravel/sand, don't make everything a gem").
##
## The board owns position + grid state — this scene only knows how to draw
## itself given its kind. Standalone .tscn per the scene-per-component rule.
## See [[mining-spec]].
@tool
class_name MiningRockTile
extends Node2D


## Five common terrain materials — earthy, distinct hues so they still read
## apart at speed, but matte + mundane (no gem facets).
##   STONE  — neutral grey bedrock, pocked
##   SOIL   — dark brown earth, crumbly specks
##   SAND   — pale warm tan, fine grain + ripples
##   GRAVEL — cool blue-grey, angular chips
##   CLAY   — terracotta packed earth, hairline cracks
enum RockKind { STONE, SOIL, SAND, GRAVEL, CLAY }


## Cell size in pixels — also the board's grid step. MUST match
## MiningBoard.CELL.
const CELL_SIZE : float = 44.0
## Inner padding so a thin dark grout of the board backing shows between
## tiles — gives the grid a carved rock-face read.
const CELL_PAD : float = 2.5


## Base face color per material; the lit/shadow tones are derived from it.
const KIND_FACE : Dictionary = {
	RockKind.STONE: Color(0.64, 0.63, 0.60, 1.0),    # warm light grey
	RockKind.SOIL: Color(0.43, 0.31, 0.21, 1.0),
	RockKind.SAND: Color(0.82, 0.72, 0.47, 1.0),
	RockKind.GRAVEL: Color(0.36, 0.46, 0.62, 1.0),   # darker cool blue (clearly apart from stone)
	RockKind.CLAY: Color(0.72, 0.42, 0.33, 1.0),
}


@export var rock_kind : RockKind = RockKind.STONE :
	set(value):
		rock_kind = value
		queue_redraw()


func _draw() -> void:

	var face : Color = KIND_FACE[rock_kind]
	var inner : Rect2 = Rect2(CELL_PAD, CELL_PAD, CELL_SIZE - 2.0 * CELL_PAD, CELL_SIZE - 2.0 * CELL_PAD)
	# Matte material block with a soft beveled edge (lit top/left, shadowed
	# bottom/right) — no mid-tile seams, no facets.
	draw_rect(inner, face)
	var tl : Vector2 = inner.position
	var tr : Vector2 = Vector2(inner.end.x, inner.position.y)
	var bl : Vector2 = Vector2(inner.position.x, inner.end.y)
	var br : Vector2 = inner.end
	draw_line(tl, tr, face.lightened(0.20), 1.5)
	draw_line(tl, bl, face.lightened(0.12), 1.5)
	draw_line(bl, br, face.darkened(0.28), 1.5)
	draw_line(tr, br, face.darkened(0.18), 1.5)
	match rock_kind:
		RockKind.STONE:
			_tex_stone(inner, face)
		RockKind.SOIL:
			_tex_soil(inner, face)
		RockKind.SAND:
			_tex_sand(inner, face)
		RockKind.GRAVEL:
			_tex_gravel(inner, face)
		RockKind.CLAY:
			_tex_clay(inner, face)
	# Crisp dark outline so adjacent same-kind tiles still read as separate
	# cells (matters when a 3-run is about to crumble).
	draw_rect(inner, face.darkened(0.45), false, 1.5)


# STONE — smooth grey cobble with a few pock dents.
func _tex_stone(inner: Rect2, face: Color) -> void:

	var dark : Color = face.darkened(0.22)
	var lite : Color = face.lightened(0.12)
	draw_circle(inner.position + inner.size * Vector2(0.34, 0.42), 2.4, dark)
	draw_circle(inner.position + inner.size * Vector2(0.64, 0.60), 2.8, dark)
	draw_circle(inner.position + inner.size * Vector2(0.70, 0.30), 1.6, lite)
	draw_circle(inner.position + inner.size * Vector2(0.40, 0.72), 1.4, dark)


# SOIL — dark crumbly earth: scattered specks + a couple of lighter grains.
func _tex_soil(inner: Rect2, face: Color) -> void:

	var dark : Color = face.darkened(0.32)
	var grain : Color = face.lightened(0.24)
	for s in [Vector2(0.28, 0.30), Vector2(0.55, 0.40), Vector2(0.72, 0.62),
			Vector2(0.38, 0.66), Vector2(0.62, 0.24), Vector2(0.24, 0.54)]:
		draw_circle(inner.position + inner.size * s, 1.8, dark)
	for s in [Vector2(0.46, 0.52), Vector2(0.68, 0.44), Vector2(0.32, 0.78)]:
		draw_circle(inner.position + inner.size * s, 1.5, grain)


# SAND — pale fine grain: stipple dots + soft dune ripples.
func _tex_sand(inner: Rect2, face: Color) -> void:

	var dark : Color = face.darkened(0.14)
	var lite : Color = face.lightened(0.16)
	draw_line(inner.position + inner.size * Vector2(0.16, 0.46), inner.position + inner.size * Vector2(0.84, 0.40), dark, 1.0)
	draw_line(inner.position + inner.size * Vector2(0.18, 0.66), inner.position + inner.size * Vector2(0.82, 0.62), dark, 1.0)
	var dots : Array = [Vector2(0.30, 0.32), Vector2(0.52, 0.30), Vector2(0.70, 0.36),
		Vector2(0.40, 0.56), Vector2(0.62, 0.54), Vector2(0.34, 0.76), Vector2(0.66, 0.74)]
	for i in dots.size():
		draw_circle(inner.position + inner.size * dots[i], 1.0, lite if i % 2 == 0 else dark)


# GRAVEL — cool slate chips: a few angular pebbles in varied tones.
func _tex_gravel(inner: Rect2, face: Color) -> void:

	var tones : Array = [face.lightened(0.16), face.darkened(0.12), face.lightened(0.06), face.darkened(0.22)]
	var chips : Array = [
		[Vector2(0.24, 0.32), 7.0], [Vector2(0.58, 0.34), 6.0],
		[Vector2(0.40, 0.62), 7.5], [Vector2(0.72, 0.64), 5.5]]
	for i in chips.size():
		var c : Vector2 = inner.position + inner.size * chips[i][0]
		var r : float = chips[i][1]
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-r, -r * 0.5), c + Vector2(r * 0.6, -r),
			c + Vector2(r, r * 0.5), c + Vector2(-r * 0.4, r)]), tones[i % tones.size()])


# CLAY — packed terracotta with a couple of hairline cracks.
func _tex_clay(inner: Rect2, face: Color) -> void:

	var crack : Color = face.darkened(0.34)
	draw_line(inner.position + inner.size * Vector2(0.26, 0.22), inner.position + inner.size * Vector2(0.52, 0.62), crack, 1.2)
	draw_line(inner.position + inner.size * Vector2(0.52, 0.62), inner.position + inner.size * Vector2(0.74, 0.74), crack, 1.0)
	draw_line(inner.position + inner.size * Vector2(0.66, 0.28), inner.position + inner.size * Vector2(0.78, 0.46), crack, 0.9)

## An ore chunk on the Mining board — the reskin of YPP Foraging's
## containers (crate / basket / chest), and the ONLY thing that scores.
##
## A chunk enters from the top of the board and falls as a single rigid
## body. The player clears the rock UNDERNEATH it so it sinks; when its
## whole footprint reaches the floor it is EXTRACTED into the haul. Three
## sizes, richer ore the bigger they are:
##   NUGGET     1x1 — common metal
##   VEIN       2x2 — richer ore
##   GEM_POCKET 2x3 — rare gems / gold
##
## The board owns the chunk's grid placement (top_row / left_col); this
## scene only knows its footprint + how to draw itself. Standalone scene
## per the scene-per-component principle. See [[mining-spec]].
@tool
class_name OreChunk
extends Node2D


enum ChunkSize { NUGGET, VEIN, GEM_POCKET }


## MUST match MiningBoard.CELL / MiningRockTile.CELL_SIZE.
const CELL : float = 44.0
## Inset so the container sits just inside its cells and reads as a
## distinct object sitting in the shaft, not another tile.
const PAD : float = 3.0


## Footprint (w x h, in cells) + ore value per size. Bigger = rarer +
## much more ore (faithful to Foraging's crate/basket/chest value curve).
const SIZE_SPECS : Dictionary = {
	ChunkSize.NUGGET: { "w": 1, "h": 1, "ore": 1, "label": "Ore Nugget" },
	ChunkSize.VEIN: { "w": 2, "h": 2, "ore": 4, "label": "Ore Vein" },
	ChunkSize.GEM_POCKET: { "w": 2, "h": 3, "ore": 10, "label": "Gem Pocket" },
}


@export var chunk_size : ChunkSize = ChunkSize.NUGGET :
	set(value):
		chunk_size = value
		queue_redraw()


## Logical grid placement — the board reads/writes these as the chunk
## falls. top-left cell of the footprint.
var top_row : int = 0
var left_col : int = 0


func width() -> int:
	return SIZE_SPECS[chunk_size]["w"]


func height() -> int:
	return SIZE_SPECS[chunk_size]["h"]


func ore_value() -> int:
	return SIZE_SPECS[chunk_size]["ore"]


func label() -> String:
	return SIZE_SPECS[chunk_size]["label"]


func _draw() -> void:

	var w : float = width() * CELL
	var h : float = height() * CELL
	var box : Rect2 = Rect2(PAD, PAD, w - 2.0 * PAD, h - 2.0 * PAD)
	match chunk_size:
		ChunkSize.NUGGET:
			_draw_nugget(box)
		ChunkSize.VEIN:
			_draw_vein(box)
		ChunkSize.GEM_POCKET:
			_draw_gem_pocket(box)


# A single faceted gold nugget — the common 1x1 ore.
func _draw_nugget(box: Rect2) -> void:

	_draw_facet_gem(box.position + box.size * 0.5, box.size.x * 0.42, Color(0.93, 0.74, 0.28))


# A chunk of dark rock veined with ore, two cut gems embedded — the 2x2 vein.
func _draw_vein(box: Rect2) -> void:

	_draw_rock_body(box)
	# Bright ore veins threading the matrix.
	var gold : Color = Color(0.92, 0.74, 0.34, 0.85)
	draw_line(box.position + box.size * Vector2(0.12, 0.70), box.position + box.size * Vector2(0.52, 0.30), gold, 2.0)
	draw_line(box.position + box.size * Vector2(0.50, 0.78), box.position + box.size * Vector2(0.82, 0.46), gold, 1.6)
	# Two cut gems poking out of the rock.
	_draw_facet_gem(box.position + box.size * Vector2(0.34, 0.44), box.size.x * 0.20, Color(0.30, 0.74, 0.48))
	_draw_facet_gem(box.position + box.size * Vector2(0.66, 0.60), box.size.x * 0.17, Color(0.40, 0.58, 0.86))


# Cracked rock spilling a cluster of cut gems with a warm glow — the rare 2x3 pocket.
func _draw_gem_pocket(box: Rect2) -> void:

	_draw_rock_body(box)
	var centre : Vector2 = box.position + box.size * 0.5
	# Warm treasure glow behind the cluster.
	draw_circle(centre, box.size.x * 0.55, Color(1.0, 0.85, 0.42, 0.12))
	draw_circle(centre, box.size.x * 0.38, Color(1.0, 0.88, 0.50, 0.10))
	var gem_colors : Array = [
		Color(0.88, 0.30, 0.32), Color(0.40, 0.58, 0.86), Color(0.30, 0.74, 0.48),
		Color(0.96, 0.81, 0.30), Color(0.74, 0.44, 0.88),
	]
	var pts : Array = [
		Vector2(0.36, 0.32), Vector2(0.64, 0.28), Vector2(0.50, 0.50),
		Vector2(0.34, 0.68), Vector2(0.66, 0.66),
	]
	var h : float = box.size.x * 0.18
	for i in 5:
		_draw_facet_gem(box.position + box.size * pts[i], h * (1.0 if i < 3 else 0.85), gem_colors[i])


# Shared dark rock matrix the ore sits in — a mottled block with a top-lit face.
func _draw_rock_body(box: Rect2) -> void:

	var shadow : Rect2 = box
	shadow.position.y += 3.0
	draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.40))
	draw_rect(box, Color(0.25, 0.23, 0.28, 1.0))
	# Top-lit upper band for volume.
	draw_rect(Rect2(box.position, Vector2(box.size.x, box.size.y * 0.42)), Color(0.33, 0.31, 0.37, 1.0))
	# A few darker flecks so the rock isn't a flat block.
	draw_circle(box.position + box.size * Vector2(0.22, 0.30), 2.0, Color(0.16, 0.15, 0.19, 1.0))
	draw_circle(box.position + box.size * Vector2(0.78, 0.24), 1.6, Color(0.16, 0.15, 0.19, 1.0))
	draw_circle(box.position + box.size * Vector2(0.60, 0.82), 2.2, Color(0.16, 0.15, 0.19, 1.0))
	draw_rect(box, Color(0.11, 0.10, 0.13, 1.0), false, 2.0)


# A single cut gem (octagon, radial facets) — the same gemstone language as the
# board tiles, so the ore reads as the polished version of what you're mining.
func _draw_facet_gem(centre: Vector2, half: float, color: Color) -> void:

	var dark : Color = color.darkened(0.45)
	var lite : Color = color.lightened(0.50)
	var ch : float = half * 0.42
	var oct : PackedVector2Array = PackedVector2Array([
		centre + Vector2(-half + ch, -half),
		centre + Vector2(half - ch, -half),
		centre + Vector2(half, -half + ch),
		centre + Vector2(half, half - ch),
		centre + Vector2(half - ch, half),
		centre + Vector2(-half + ch, half),
		centre + Vector2(-half, half - ch),
		centre + Vector2(-half, -half + ch),
	])
	var drop : PackedVector2Array = PackedVector2Array()
	for p in oct:
		drop.append(p + Vector2(0.0, 2.0))
	draw_colored_polygon(drop, Color(0.0, 0.0, 0.0, 0.40))
	var light_dir : Vector2 = Vector2(-0.45, -0.89)
	for i in 8:
		var a : Vector2 = oct[i]
		var b : Vector2 = oct[(i + 1) % 8]
		var n : Vector2 = ((a + b) * 0.5 - centre).normalized()
		var lit : float = clampf(n.dot(light_dir) * 0.5 + 0.5, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([a, b, centre]), dark.lerp(lite, lit * lit))
	draw_circle(centre, half * 0.16, color.lightened(0.20))
	draw_circle(centre + light_dir * half * 0.40, half * 0.12, lite)
	var rim : PackedVector2Array = oct.duplicate()
	rim.append(oct[0])
	draw_polyline(rim, color.darkened(0.55), 1.4)
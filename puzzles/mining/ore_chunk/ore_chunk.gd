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


# A single rounded metal lump — common ore.
func _draw_nugget(box: Rect2) -> void:

	var base : Color = Color(0.74, 0.56, 0.26, 1.0)
	var hi : Color = Color(0.95, 0.82, 0.46, 1.0)
	var lo : Color = Color(0.42, 0.30, 0.12, 1.0)
	# Rounded lump (octagon-ish polygon centred in the cell).
	var cx : float = box.position.x + box.size.x * 0.5
	var cy : float = box.position.y + box.size.y * 0.5
	var rx : float = box.size.x * 0.42
	var ry : float = box.size.y * 0.42
	var lump : PackedVector2Array = PackedVector2Array([
		Vector2(cx - rx * 0.5, cy - ry),
		Vector2(cx + rx * 0.5, cy - ry),
		Vector2(cx + rx, cy - ry * 0.3),
		Vector2(cx + rx, cy + ry * 0.4),
		Vector2(cx + rx * 0.5, cy + ry),
		Vector2(cx - rx * 0.5, cy + ry),
		Vector2(cx - rx, cy + ry * 0.4),
		Vector2(cx - rx, cy - ry * 0.3),
	])
	draw_colored_polygon(lump, base)
	draw_polyline(lump + PackedVector2Array([lump[0]]), lo, 1.6)
	# Glint.
	draw_circle(Vector2(cx - rx * 0.3, cy - ry * 0.35), box.size.x * 0.12, hi)


# A timber crate framing raw ore crystals — medium value.
func _draw_vein(box: Rect2) -> void:

	_draw_crate_frame(box, Color(0.34, 0.22, 0.12, 1.0), Color(0.62, 0.44, 0.22, 1.0))
	# Ore crystals poking out the top — copper-green + a couple glints.
	var inner : Rect2 = box.grow(-box.size.x * 0.16)
	var crystal : Color = Color(0.32, 0.70, 0.48, 1.0)
	var crystal2 : Color = Color(0.40, 0.58, 0.82, 1.0)
	draw_rect(inner, Color(0.18, 0.13, 0.08, 1.0))
	_draw_shard(Vector2(inner.position.x + inner.size.x * 0.30, inner.position.y + inner.size.y * 0.45), inner.size.x * 0.18, crystal)
	_draw_shard(Vector2(inner.position.x + inner.size.x * 0.66, inner.position.y + inner.size.y * 0.55), inner.size.x * 0.16, crystal2)
	_draw_shard(Vector2(inner.position.x + inner.size.x * 0.50, inner.position.y + inner.size.y * 0.30), inner.size.x * 0.14, crystal)


# An ornate gold-trimmed chest spilling gems — the premium chunk.
func _draw_gem_pocket(box: Rect2) -> void:

	_draw_crate_frame(box, Color(0.26, 0.16, 0.08, 1.0), Color(0.86, 0.70, 0.30, 1.0))
	# Lid seam.
	var lid_y : float = box.position.y + box.size.y * 0.34
	draw_line(Vector2(box.position.x, lid_y), Vector2(box.end.x, lid_y), Color(0.86, 0.70, 0.30, 1.0), 3.0)
	# Lock.
	var lock : Rect2 = Rect2(box.position.x + box.size.x * 0.5 - 7.0, lid_y - 7.0, 14.0, 16.0)
	draw_rect(lock, Color(0.95, 0.82, 0.40, 1.0))
	# Gems spilling from the top.
	var gem_colors : Array = [
		Color(0.86, 0.29, 0.31, 1.0),
		Color(0.30, 0.52, 0.88, 1.0),
		Color(0.28, 0.72, 0.46, 1.0),
		Color(0.96, 0.81, 0.26, 1.0),
		Color(0.74, 0.42, 0.86, 1.0),
	]
	var gy : float = box.position.y + box.size.y * 0.16
	var spread : float = box.size.x * 0.7
	for i in 5:
		var t : float = i / 4.0
		var gx : float = box.position.x + box.size.x * 0.15 + spread * t
		_draw_gem(Vector2(gx, gy + (8.0 if i % 2 == 0 else 0.0)), box.size.x * 0.11, gem_colors[i])


# Shared beveled container frame (wood fill + metal trim border + studs).
func _draw_crate_frame(box: Rect2, wood: Color, trim: Color) -> void:

	# Shadow.
	var shadow : Rect2 = box
	shadow.position.y += 2.5
	draw_rect(shadow, wood.darkened(0.4))
	# Body.
	draw_rect(box, wood)
	# Plank lines (vertical).
	var planks : int = maxi(2, int(box.size.x / CELL) + 1)
	for i in range(1, planks):
		var x : float = box.position.x + box.size.x * (float(i) / planks)
		draw_line(Vector2(x, box.position.y), Vector2(x, box.end.y), wood.darkened(0.3), 1.4)
	# Metal trim border.
	draw_rect(box, trim, false, 3.0)
	# Corner studs.
	var s : float = 3.0
	for corner in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
		draw_circle(corner, s, trim.lightened(0.2))


func _draw_shard(centre: Vector2, size: float, color: Color) -> void:

	var shard : PackedVector2Array = PackedVector2Array([
		centre + Vector2(0, -size),
		centre + Vector2(size * 0.7, size * 0.5),
		centre + Vector2(-size * 0.7, size * 0.5),
	])
	draw_colored_polygon(shard, color)
	draw_line(centre + Vector2(0, -size), centre + Vector2(0, size * 0.5), color.lightened(0.4), 1.2)


func _draw_gem(centre: Vector2, size: float, color: Color) -> void:

	var gem : PackedVector2Array = PackedVector2Array([
		centre + Vector2(0, -size),
		centre + Vector2(size, 0),
		centre + Vector2(0, size),
		centre + Vector2(-size, 0),
	])
	draw_colored_polygon(gem, color)
	draw_line(centre + Vector2(0, -size), centre + Vector2(-size, 0), color.lightened(0.5), 1.2)
## A single board cell in the Lumberjacking puzzle — one of 4 PLANK kinds,
## either SOLID (lands and stays) or BREAKER (shatters connected same-kind
## solids on contact). Mirrors the YPP SwordFighting piece model, reskinned
## for wood.
##
## Minecraft-style PLANKS (Troy 2026-06-15): oak / birch / spruce / jungle.
## Each is a clean, self-contained plank face (a board grid + offset joints),
## NOTHING bleeds past the cell edge. When same-kind planks fuse into a 2x2+
## block, the board renders that group as a single LOG (see board.gd
## _draw_fused_block). All 4 are mechanically identical; the kind is purely a
## sorting/matching identity.
##
## The board owns position + state. Standalone .tscn per the scene-per-
## component principle. See [[lumberjacking-spec]].
@tool
class_name LogPiece
extends Node2D


## Four plank kinds (Minecraft palette): readable apart at speed AND believable
## as wood. OAK warm tan · BIRCH pale cream · SPRUCE dark brown · JUNGLE reddish.
enum WoodKind { OAK, BIRCH, SPRUCE, JUNGLE }

## SOLID = lands and remains. BREAKER = shatters on adjacent same-kind contact.
enum Variant { SOLID, BREAKER }


## Cell size in pixels — the board's grid step.
const CELL_SIZE : float = 36.0
## Inner padding so adjacent same-kind solids visibly TOUCH at their edges.
const CELL_PAD : float = 2.0


## Per-kind face + shadow + grain (seam) colors — the four Minecraft plank tones.
const KIND_COLORS : Dictionary = {
	WoodKind.OAK: {
		"face": Color(0.72, 0.57, 0.34, 1.0),
		"shadow": Color(0.50, 0.39, 0.22, 1.0),
		"grain": Color(0.40, 0.30, 0.16, 1.0),
	},
	WoodKind.BIRCH: {
		"face": Color(0.85, 0.78, 0.57, 1.0),
		"shadow": Color(0.64, 0.58, 0.40, 1.0),
		"grain": Color(0.50, 0.44, 0.29, 1.0),
	},
	WoodKind.SPRUCE: {
		"face": Color(0.42, 0.30, 0.18, 1.0),
		"shadow": Color(0.27, 0.19, 0.11, 1.0),
		"grain": Color(0.17, 0.11, 0.06, 1.0),
	},
	WoodKind.JUNGLE: {
		"face": Color(0.69, 0.45, 0.31, 1.0),
		"shadow": Color(0.47, 0.28, 0.18, 1.0),
		"grain": Color(0.34, 0.19, 0.12, 1.0),
	},
}


@export var wood_kind : WoodKind = WoodKind.OAK :
	set(value):
		wood_kind = value
		queue_redraw()
@export var variant : Variant = Variant.SOLID :
	set(value):
		variant = value
		queue_redraw()


## Stable per-piece seed so the joint offsets / birch flecks are varied but
## never shimmer (re-seeding off the changing fall position would). Set on _ready.
var _seed : int = 0


func _ready() -> void:

	_seed = randi()


func _draw() -> void:

	var palette : Dictionary = KIND_COLORS[wood_kind]
	var face : Color = palette["face"]
	var shadow : Color = palette["shadow"]
	var grain : Color = palette["grain"]
	var inner : Rect2 = Rect2(CELL_PAD, CELL_PAD, CELL_SIZE - 2.0 * CELL_PAD, CELL_SIZE - 2.0 * CELL_PAD)
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed
	# Drop shadow.
	var sh : Rect2 = inner
	sh.position.y += 1.5
	draw_rect(sh, shadow)
	# Plank face + a gentle top-lit / bottom-shaded wash (volume, all contained).
	draw_rect(inner, face)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.34)), face.lightened(0.07))
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - inner.size.y * 0.30), Vector2(inner.size.x, inner.size.y * 0.30)), face.darkened(0.07))
	# Horizontal plank boards with OFFSET vertical joints — the Minecraft grid.
	var boards : int = 3
	var bh : float = inner.size.y / float(boards)
	var seam : Color = Color(grain.r, grain.g, grain.b, 0.9)
	for b in boards:
		var by : float = inner.position.y + float(b) * bh
		if b > 0:
			draw_line(Vector2(inner.position.x, by), Vector2(inner.end.x, by), seam, 1.4)
			draw_line(Vector2(inner.position.x, by + 1.0), Vector2(inner.end.x, by + 1.0), face.lightened(0.12), 1.0)
		var jx : float = inner.position.x + inner.size.x * (0.62 if b % 2 == 0 else 0.34)
		draw_line(Vector2(jx, by + 2.0), Vector2(jx, by + bh - 2.0), seam, 1.2)
		draw_line(Vector2(jx + 1.0, by + 2.0), Vector2(jx + 1.0, by + bh - 2.0), face.lightened(0.10), 0.8)
		var gy : float = by + bh * 0.5
		draw_line(Vector2(inner.position.x + 3.0, gy), Vector2(inner.position.x + inner.size.x * 0.55, gy),
			Color(grain.r, grain.g, grain.b, 0.32), 1.0)
	# Beveled edge (lit top/left, shadowed bottom/right) — contained.
	var c_tl : Vector2 = inner.position
	var c_tr : Vector2 = Vector2(inner.end.x, inner.position.y)
	var c_bl : Vector2 = Vector2(inner.position.x, inner.end.y)
	var c_br : Vector2 = inner.end
	draw_line(c_tl, c_tr, face.lightened(0.26), 1.5)
	draw_line(c_tl, c_bl, face.lightened(0.18), 1.4)
	draw_line(c_bl, c_br, shadow.darkened(0.10), 1.6)
	draw_line(c_tr, c_br, shadow.darkened(0.04), 1.4)
	draw_circle(inner.position + Vector2(3.0, 3.0), 2.0, Color(1.0, 1.0, 1.0, 0.24))
	# Birch's dark flecks (its signature), tiny + contained.
	if wood_kind == WoodKind.BIRCH:
		for _i in 2:
			var fp : Vector2 = inner.position + inner.size * Vector2(rng.randf_range(0.20, 0.80), rng.randf_range(0.20, 0.80))
			draw_line(fp, fp + Vector2(rng.randf_range(2.0, 4.0), 0.0), Color(0.20, 0.16, 0.10, 0.7), 1.4)
	# Breaker variant — the axe stamp.
	if variant == Variant.BREAKER:
		_draw_axe_stamp()


# Big dark axe silhouette: triangular wedge-head at the TOP-LEFT (the blade),
# a thin handle to the bottom-right. Reads "breaker" on any plank color.
func _draw_axe_stamp() -> void:

	var stamp_color : Color = Color(0.06, 0.04, 0.02, 1.0)
	var stamp_highlight : Color = Color(0.92, 0.82, 0.55, 0.85)
	var head : PackedVector2Array = PackedVector2Array([
		Vector2(CELL_SIZE * 0.10, CELL_SIZE * 0.20),
		Vector2(CELL_SIZE * 0.62, CELL_SIZE * 0.16),
		Vector2(CELL_SIZE * 0.78, CELL_SIZE * 0.36),
		Vector2(CELL_SIZE * 0.46, CELL_SIZE * 0.48),
		Vector2(CELL_SIZE * 0.18, CELL_SIZE * 0.42),
	])
	draw_colored_polygon(head, stamp_color)
	draw_line(Vector2(CELL_SIZE * 0.60, CELL_SIZE * 0.20), Vector2(CELL_SIZE * 0.76, CELL_SIZE * 0.34), stamp_highlight, 1.4)
	draw_line(Vector2(CELL_SIZE * 0.36, CELL_SIZE * 0.48), Vector2(CELL_SIZE * 0.88, CELL_SIZE * 0.92), stamp_color, CELL_SIZE * 0.10)
	draw_polyline(head, Color(1, 1, 1, 0.25), 1.2)

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
		"face": Color(0.82, 0.59, 0.28, 1.0),     # saturated honey-tan
		"shadow": Color(0.56, 0.40, 0.17, 1.0),
		"grain": Color(0.40, 0.28, 0.12, 1.0),
	},
	WoodKind.BIRCH: {
		"face": Color(0.93, 0.85, 0.53, 1.0),     # bright pale cream
		"shadow": Color(0.70, 0.63, 0.37, 1.0),
		"grain": Color(0.52, 0.45, 0.26, 1.0),
	},
	WoodKind.SPRUCE: {
		"face": Color(0.47, 0.31, 0.15, 1.0),     # deep saturated brown
		"shadow": Color(0.30, 0.19, 0.09, 1.0),
		"grain": Color(0.17, 0.10, 0.05, 1.0),
	},
	WoodKind.JUNGLE: {
		"face": Color(0.80, 0.41, 0.22, 1.0),     # saturated red-orange (clearly apart from oak)
		"shadow": Color(0.54, 0.25, 0.12, 1.0),
		"grain": Color(0.35, 0.16, 0.08, 1.0),
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


## Bitmask of edges shared with a same-group fused neighbour. On a shared edge
## the tile extends to the cell boundary and SKIPS its bevel/seam, so a fused
## group reads as ONE continuous merged plank surface (the YPP "solidify" look),
## with no opaque overlay painted over other tiles (Troy 2026-06-15).
const _EDGE_N : int = 1
const _EDGE_E : int = 2
const _EDGE_S : int = 4
const _EDGE_W : int = 8
var fused_edges : int = 0 :
	set(value):
		if fused_edges == value:
			return
		fused_edges = value
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
	# BREAKER = a bare COLORED axe, NO plank backing (Troy 2026-06-15). The axe
	# wears the kind's own colour, so you read which planks it will shatter.
	if variant == Variant.BREAKER:
		_draw_axe(face, shadow)
		return
	# Extend to the cell boundary on edges shared with a same-group neighbour, so
	# fused planks MERGE into one continuous surface with no internal seam.
	var x0 : float = 0.0 if (fused_edges & _EDGE_W) else CELL_PAD
	var y0 : float = 0.0 if (fused_edges & _EDGE_N) else CELL_PAD
	var x1 : float = CELL_SIZE if (fused_edges & _EDGE_E) else CELL_SIZE - CELL_PAD
	var y1 : float = CELL_SIZE if (fused_edges & _EDGE_S) else CELL_SIZE - CELL_PAD
	var inner : Rect2 = Rect2(x0, y0, x1 - x0, y1 - y0)
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed
	# Drop shadow (skip on a fused south edge so no internal seam-shadow shows).
	if not (fused_edges & _EDGE_S):
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
	# Beveled edge — only on OUTER (non-fused) edges, so internal seams vanish and
	# the fused group reads as one merged plank surface.
	var c_tl : Vector2 = inner.position
	var c_tr : Vector2 = Vector2(inner.end.x, inner.position.y)
	var c_bl : Vector2 = Vector2(inner.position.x, inner.end.y)
	var c_br : Vector2 = inner.end
	if not (fused_edges & _EDGE_N):
		draw_line(c_tl, c_tr, face.lightened(0.26), 1.5)
	if not (fused_edges & _EDGE_W):
		draw_line(c_tl, c_bl, face.lightened(0.18), 1.4)
	if not (fused_edges & _EDGE_S):
		draw_line(c_bl, c_br, shadow.darkened(0.10), 1.6)
	if not (fused_edges & _EDGE_E):
		draw_line(c_tr, c_br, shadow.darkened(0.04), 1.4)
	if not (fused_edges & _EDGE_N) and not (fused_edges & _EDGE_W):
		draw_circle(inner.position + Vector2(3.0, 3.0), 2.0, Color(1.0, 1.0, 1.0, 0.24))
	# Birch's dark flecks (its signature), tiny + contained.
	if wood_kind == WoodKind.BIRCH:
		for _i in 2:
			var fp : Vector2 = inner.position + inner.size * Vector2(rng.randf_range(0.20, 0.80), rng.randf_range(0.20, 0.80))
			draw_line(fp, fp + Vector2(rng.randf_range(2.0, 4.0), 0.0), Color(0.20, 0.16, 0.10, 0.7), 1.4)


# A bold COLORED axe on a bare cell (no plank backing) — the breaker piece.
# Blade wears the kind's bright FACE colour (its identity), handle the darker
# SHADOW tone; a near-black outline + a bright cutting edge keep EVERY kind
# legible against the dark bin / preview panel (even dark spruce).
func _draw_axe(face: Color, shadow: Color) -> void:

	var outline : Color = Color(0.08, 0.05, 0.02, 1.0)
	var edge_hi : Color = face.lightened(0.5)
	# Blade wedge — cutting edge down the LEFT (points 0 -> 4), neck at the right.
	var head : PackedVector2Array = PackedVector2Array([
		Vector2(CELL_SIZE * 0.12, CELL_SIZE * 0.28),
		Vector2(CELL_SIZE * 0.60, CELL_SIZE * 0.16),
		Vector2(CELL_SIZE * 0.78, CELL_SIZE * 0.38),
		Vector2(CELL_SIZE * 0.44, CELL_SIZE * 0.52),
		Vector2(CELL_SIZE * 0.18, CELL_SIZE * 0.46),
	])
	var closed : PackedVector2Array = head + PackedVector2Array([head[0]])
	var handle_a : Vector2 = Vector2(CELL_SIZE * 0.54, CELL_SIZE * 0.40)
	var handle_b : Vector2 = Vector2(CELL_SIZE * 0.86, CELL_SIZE * 0.90)
	# Soft drop shadow so the axe sits in the cell against the dark bin.
	var soff : Vector2 = Vector2(1.5, 2.0)
	var head_sh : PackedVector2Array = PackedVector2Array()
	for p in head:
		head_sh.append(p + soff)
	draw_colored_polygon(head_sh, Color(0.0, 0.0, 0.0, 0.30))
	draw_line(handle_a + soff, handle_b + soff, Color(0.0, 0.0, 0.0, 0.30), CELL_SIZE * 0.15)
	# Handle (drawn first so the blade overlaps its neck): dark outline + body.
	draw_line(handle_a, handle_b, outline, CELL_SIZE * 0.17)
	draw_line(handle_a, handle_b, shadow, CELL_SIZE * 0.11)
	draw_line(handle_a + Vector2(-1.2, -1.0), handle_b + Vector2(-1.2, -1.0), shadow.lightened(0.22), 1.6)
	# Blade: outline, kind-colour fill, top facet, bright sharpened edge.
	draw_polyline(closed, outline, 2.4)
	draw_colored_polygon(head, face)
	draw_line(head[0], head[1], face.lightened(0.18), 1.6)        # top facet
	draw_line(head[2], head[3], shadow, 1.4)                       # lower facet shade
	draw_line(head[0], head[4], edge_hi, 2.6)                      # cutting edge (bright)

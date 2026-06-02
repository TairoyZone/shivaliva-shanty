## OrePile — the visible heap of ore in Cinder Troy's Forge. Grows as the
## player delivers ore at the [OreDropoff]. Pure visual feedback, no
## interaction. The Forge-side mirror of [LumberPile].
##
## Layout: a triangular heap of ore chunks (rounded rock with a metallic
## glint), widest at the bottom. [member STOCK_PER_CHUNK] sets how much
## delivered ore each visible chunk represents.
##
## Per the scene-per-component principle this lives in its own .tscn so
## art can swap without touching the delivery logic.
@tool
class_name OrePile
extends Node2D


# Origin (0, 0) is the front-center base of the heap on the ground.
const CHUNK_RADIUS : float = 11.0
const CHUNK_SPACING : float = 23.0
const ROW_HEIGHT : float = 17.0
## Each visible chunk represents this much delivered ore.
const STOCK_PER_CHUNK : int = 4
## Row-by-row max chunk counts bottom→top. Sum = 15 = visible cap.
const ROW_CAPS : Array = [5, 4, 3, 2, 1]

# --- Palette (cold stone with a warm metallic vein) ------------------
const COLOR_ROCK : Color = Color(0.42, 0.44, 0.50, 1.0)
const COLOR_ROCK_DARK : Color = Color(0.26, 0.28, 0.33, 1.0)
const COLOR_ROCK_LIGHT : Color = Color(0.62, 0.65, 0.72, 1.0)
const COLOR_VEIN : Color = Color(0.82, 0.62, 0.28, 1.0)   # gold/copper vein


func _ready() -> void:

	if Engine.is_editor_hint():
		return
	PlayerState.ore_stock_changed.connect(_on_ore_stock_changed)
	queue_redraw()


func _on_ore_stock_changed(_new_total: int) -> void:

	queue_redraw()


func _draw() -> void:

	var stock : int = (PlayerState.cinder_ore_stock
		if not Engine.is_editor_hint() else 32)
	if stock <= 0:
		return
	var max_visible : int = 0
	for cap in ROW_CAPS:
		max_visible += int(cap)
	@warning_ignore("integer_division")
	var visible_count : int = mini(stock / STOCK_PER_CHUNK, max_visible)
	if visible_count <= 0 and stock > 0:
		visible_count = 1
	var placed : int = 0
	for row_idx in range(ROW_CAPS.size()):
		if placed >= visible_count:
			break
		var cap : int = ROW_CAPS[row_idx]
		var in_row : int = mini(cap, visible_count - placed)
		var row_y : float = -CHUNK_RADIUS - row_idx * ROW_HEIGHT
		var first_x : float = -(in_row - 1) * CHUNK_SPACING * 0.5
		for col_idx in range(in_row):
			var cx : float = first_x + col_idx * CHUNK_SPACING
			_draw_chunk(Vector2(cx, row_y), (row_idx + col_idx) % 3 == 0)
		placed += in_row


# A rough ore chunk: dark rock base, lit face, and (on some) a gold vein.
func _draw_chunk(centre: Vector2, has_vein: bool) -> void:

	var rock : PackedVector2Array = PackedVector2Array([
		centre + Vector2(-CHUNK_RADIUS, CHUNK_RADIUS * 0.3),
		centre + Vector2(-CHUNK_RADIUS * 0.5, -CHUNK_RADIUS),
		centre + Vector2(CHUNK_RADIUS * 0.6, -CHUNK_RADIUS * 0.8),
		centre + Vector2(CHUNK_RADIUS, CHUNK_RADIUS * 0.2),
		centre + Vector2(CHUNK_RADIUS * 0.4, CHUNK_RADIUS),
		centre + Vector2(-CHUNK_RADIUS * 0.5, CHUNK_RADIUS),
	])
	draw_colored_polygon(rock, COLOR_ROCK)
	draw_polyline(rock + PackedVector2Array([rock[0]]), COLOR_ROCK_DARK, 1.4)
	# Lit top-left facet.
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-CHUNK_RADIUS * 0.5, -CHUNK_RADIUS),
		centre + Vector2(CHUNK_RADIUS * 0.1, -CHUNK_RADIUS * 0.85),
		centre + Vector2(-CHUNK_RADIUS * 0.3, -CHUNK_RADIUS * 0.1),
	]), COLOR_ROCK_LIGHT)
	if has_vein:
		draw_line(centre + Vector2(-CHUNK_RADIUS * 0.4, CHUNK_RADIUS * 0.2),
			centre + Vector2(CHUNK_RADIUS * 0.5, -CHUNK_RADIUS * 0.3), COLOR_VEIN, 2.0)
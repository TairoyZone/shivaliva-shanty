## LumberPile — the visible stack of cut wood in Cogwise Godfrey's
## Workshop. Grows as the player delivers lumber at the
## [WoodDropoff]. Pure visual feedback — no interaction.
##
## Layout: a triangular pile of log cross-sections (bark + sapwood +
## heartwood + rings, same family as the HUD wood icon). Logs are
## arranged in rows, widest at the bottom, narrowing toward the top.
## Row sizes are 5 / 4 / 3 / 2 / 1 (15 max visible logs), and
## [member STOCK_PER_LOG] sets how much delivered wood each visible
## log represents.
##
## See [[lumberjacking-spec]] for the wider loop. Per the
## scene-per-component principle, this lives in its own .tscn so art
## can swap without touching the gameplay-side delivery logic.
@tool
class_name LumberPile
extends Node2D


# --- Pile sizing -----------------------------------------------------
# Origin (0, 0) is the front-center base of the pile on the ground.

const LOG_RADIUS : float = 11.0
const LOG_SPACING : float = 23.0
const ROW_HEIGHT : float = 18.0
## Each visible log on the pile represents this much delivered wood.
## Tune so the pile fills naturally over a handful of decent runs.
const STOCK_PER_LOG : int = 4
## Row-by-row max log counts from bottom to top. Sum = 15 = visible cap.
const ROW_CAPS : Array = [5, 4, 3, 2, 1]

# --- Palette (matches the HUD wood_icon for visual consistency) ------

const COLOR_BARK : Color = Color(0.32, 0.20, 0.10, 1.0)
const COLOR_SAPWOOD : Color = Color(0.72, 0.52, 0.30, 1.0)
const COLOR_HEARTWOOD : Color = Color(0.55, 0.36, 0.18, 1.0)
const COLOR_RING : Color = Color(0.38, 0.24, 0.10, 1.0)
const COLOR_PITH : Color = Color(0.28, 0.16, 0.06, 1.0)
const COLOR_SHADOW : Color = Color(0, 0, 0, 0.35)


func _ready() -> void:

	if Engine.is_editor_hint():
		return
	PlayerState.lumber_stock_changed.connect(_on_lumber_stock_changed)
	queue_redraw()


func _on_lumber_stock_changed(_new_total: int) -> void:

	queue_redraw()


func _draw() -> void:

	var stock : int = (PlayerState.godfrey_lumber_stock
		if not Engine.is_editor_hint() else 32)
	if stock <= 0:
		return
	# Compute how many logs to actually draw, capped by ROW_CAPS sum.
	var max_visible : int = 0
	for cap in ROW_CAPS:
		max_visible += int(cap)
	@warning_ignore("integer_division")
	var visible_count : int = mini(stock / STOCK_PER_LOG, max_visible)
	if visible_count <= 0 and stock > 0:
		# Always show at least one log if there's ANY stock — otherwise
		# small deliveries feel like they vanished.
		visible_count = 1
	# Draw rows bottom-up.
	var placed : int = 0
	for row_idx in range(ROW_CAPS.size()):
		if placed >= visible_count:
			break
		var cap : int = ROW_CAPS[row_idx]
		var in_row : int = mini(cap, visible_count - placed)
		# Center the row horizontally.
		var row_y : float = -LOG_RADIUS - row_idx * ROW_HEIGHT
		var first_x : float = -(in_row - 1) * LOG_SPACING * 0.5
		for col_idx in range(in_row):
			var cx : float = first_x + col_idx * LOG_SPACING
			_draw_log(Vector2(cx, row_y))
		placed += in_row


# A single log cross-section: bark rim, sapwood ring, heartwood face,
# two growth rings, pith. Mirrors the HUD wood_icon so the visual
# language is consistent across the game.
func _draw_log(center: Vector2) -> void:

	draw_circle(center, LOG_RADIUS, COLOR_BARK)
	draw_circle(center, LOG_RADIUS * 0.86, COLOR_SAPWOOD)
	draw_circle(center, LOG_RADIUS * 0.74, COLOR_HEARTWOOD)
	var ring_w : float = maxf(1.0, LOG_RADIUS * 0.07)
	draw_arc(center, LOG_RADIUS * 0.55, 0.0, TAU, 22, COLOR_RING, ring_w)
	draw_arc(center, LOG_RADIUS * 0.34, 0.0, TAU, 18, COLOR_RING, ring_w)
	draw_circle(center, maxf(1.6, LOG_RADIUS * 0.12), COLOR_PITH)

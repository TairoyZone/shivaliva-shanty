## WoodDropoff — the crate inside Cogwise Godfrey's Workshop where the
## player drops off everything they've chopped at the Grove. Pressing E
## fires [method PlayerState.deliver_wood] for all carried wood, which:
##   1. zeros out [member PlayerState.total_wood],
##   2. grows [member PlayerState.godfrey_lumber_stock] (which the
##      LumberPile visualizes),
##   3. pays the player gold at the
##      [constant PlayerState.WOOD_TO_GOLD_RATE].
##
## Tooltip is state-aware:
##   - 0 wood carried → "No wood to deliver"
##   - N wood carried → "Deliver N wood for X gold   [Click]"
@tool
class_name WoodDropoff
extends Interactable


# --- Visual placeholder dimensions -----------------------------------
# Origin (0, 0) is the front-center-bottom of the crate.

const CRATE_HALF_WIDTH : float = 44.0
const CRATE_HEIGHT : float = 56.0
const CRATE_DEPTH : float = 18.0   # iso back-edge offset

# --- Palette ---------------------------------------------------------

const COLOR_FRONT_FILL : Color = Color(0.52, 0.32, 0.14, 1.0)
const COLOR_TOP_FILL : Color = Color(0.62, 0.42, 0.20, 1.0)
const COLOR_FRAME : Color = Color(0.18, 0.10, 0.04, 1.0)
const COLOR_PLANK_LINE : Color = Color(0.32, 0.18, 0.08, 0.85)
const COLOR_HOOP_DARK : Color = Color(0.22, 0.16, 0.10, 1.0)
const COLOR_HOOP_LIGHT : Color = Color(0.58, 0.42, 0.20, 1.0)


var _is_player_nearby : bool = false


func _ready() -> void:

	super._ready()
	if Engine.is_editor_hint():
		return
	PlayerState.wood_changed.connect(_on_wood_changed)


func interact() -> void:

	if Engine.is_editor_hint():
		return
	if PlayerState.total_wood <= 0:
		return
	PlayerState.deliver_wood(PlayerState.total_wood)
	# wood_changed fires → _refresh_tooltip_text updates the prompt.


func set_tooltip_visible(value: bool) -> void:

	if Engine.is_editor_hint():
		return
	_is_player_nearby = value
	if value:
		_refresh_tooltip_text()
	_tooltip.visible = value


# Dynamic tooltip — encodes the conversion the player's about to make,
# colored green when payout is positive, soft amber when there's
# nothing to deliver.
func _refresh_tooltip_text() -> void:

	if PlayerState.total_wood <= 0:
		_tooltip.text = "No wood to deliver"
		_tooltip.modulate = Color(0.85, 0.62, 0.42, 1.0)
		return
	var payout : int = int(round(
		PlayerState.total_wood * PlayerState.WOOD_TO_GOLD_RATE))
	_tooltip.text = "Deliver %d wood for %d gold   [Click]" % [
		PlayerState.total_wood, payout]
	_tooltip.modulate = Color(0.78, 1.0, 0.62, 1.0)


func _on_wood_changed(_new_total: int) -> void:

	if _is_player_nearby:
		_refresh_tooltip_text()


func _draw() -> void:

	# Iso crate placeholder — front face + tilted top diamond + dark
	# back-edge for depth.
	var front_bot_l : Vector2 = Vector2(-CRATE_HALF_WIDTH, 0.0)
	var front_bot_r : Vector2 = Vector2(CRATE_HALF_WIDTH, 0.0)
	var front_top_l : Vector2 = Vector2(-CRATE_HALF_WIDTH, -CRATE_HEIGHT)
	var front_top_r : Vector2 = Vector2(CRATE_HALF_WIDTH, -CRATE_HEIGHT)
	var back_top_l : Vector2 = front_top_l + Vector2(0.0, -CRATE_DEPTH)
	var back_top_r : Vector2 = front_top_r + Vector2(0.0, -CRATE_DEPTH)
	# Front face — the main visible side.
	draw_colored_polygon(
		PackedVector2Array([front_bot_l, front_bot_r, front_top_r, front_top_l]),
		COLOR_FRONT_FILL)
	# Vertical plank lines on the front face.
	for i in range(1, 4):
		var t : float = i / 4.0
		var x : float = lerpf(front_bot_l.x, front_bot_r.x, t)
		draw_line(Vector2(x, front_bot_l.y - 3.0),
			Vector2(x, front_top_l.y + 2.0),
			COLOR_PLANK_LINE, 1.4)
	# Top diamond (slight iso projection).
	draw_colored_polygon(
		PackedVector2Array([front_top_l, front_top_r, back_top_r, back_top_l]),
		COLOR_TOP_FILL)
	# Outline the whole crate silhouette.
	draw_polyline(
		PackedVector2Array([front_bot_l, front_bot_r, front_top_r,
			back_top_r, back_top_l, front_top_l, front_bot_l]),
		COLOR_FRAME, 1.6)
	draw_line(front_top_l, front_top_r, COLOR_FRAME, 1.2)
	# Iron hoops — two horizontal bands across the front face.
	var hoop_top_y : float = -CRATE_HEIGHT + 10.0
	var hoop_bot_y : float = -10.0
	var hoop_h : float = 5.0
	draw_rect(Rect2(front_top_l.x, hoop_top_y, CRATE_HALF_WIDTH * 2.0, hoop_h),
		COLOR_HOOP_DARK)
	draw_line(Vector2(front_top_l.x, hoop_top_y + 1.2),
		Vector2(front_top_r.x, hoop_top_y + 1.2), COLOR_HOOP_LIGHT, 1.0)
	draw_rect(Rect2(front_bot_l.x, hoop_bot_y, CRATE_HALF_WIDTH * 2.0, hoop_h),
		COLOR_HOOP_DARK)
	draw_line(Vector2(front_bot_l.x, hoop_bot_y + 1.2),
		Vector2(front_bot_r.x, hoop_bot_y + 1.2), COLOR_HOOP_LIGHT, 1.0)
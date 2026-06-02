## OreDropoff — the iron bin inside Cinder Troy's Forge where the player
## drops off everything mined at the Mine. Pressing E fires
## [method PlayerState.deliver_ore] for all carried ore, which:
##   1. zeros out [member PlayerState.total_ore],
##   2. grows [member PlayerState.cinder_ore_stock] (the OrePile visualizes it),
##   3. pays the player gold at [constant PlayerState.ORE_TO_GOLD_RATE].
##
## The Forge-side mirror of [WoodDropoff]. Tooltip is state-aware:
##   - 0 ore carried → "No ore to deliver"
##   - N ore carried → "Deliver N ore for X gold   [E]"
@tool
class_name OreDropoff
extends Interactable


# --- Visual placeholder dimensions -----------------------------------
# Origin (0, 0) is the front-center-bottom of the bin.

const BIN_HALF_WIDTH : float = 44.0
const BIN_HEIGHT : float = 52.0
const BIN_DEPTH : float = 18.0   # iso back-edge offset

# --- Palette (cold iron / stone, to read apart from the wood crate) --

const COLOR_FRONT_FILL : Color = Color(0.34, 0.35, 0.40, 1.0)
const COLOR_TOP_FILL : Color = Color(0.44, 0.46, 0.52, 1.0)
const COLOR_FRAME : Color = Color(0.12, 0.12, 0.15, 1.0)
const COLOR_RIVET : Color = Color(0.62, 0.64, 0.70, 1.0)
const COLOR_ORE_A : Color = Color(0.74, 0.56, 0.26, 1.0)   # copper-gold lump
const COLOR_ORE_B : Color = Color(0.55, 0.60, 0.68, 1.0)   # grey ore lump


var _is_player_nearby : bool = false


func _ready() -> void:

	super._ready()
	if Engine.is_editor_hint():
		return
	PlayerState.ore_changed.connect(_on_ore_changed)


func interact() -> void:

	if Engine.is_editor_hint():
		return
	if PlayerState.total_ore <= 0:
		return
	PlayerState.deliver_ore(PlayerState.total_ore)
	# ore_changed fires → _refresh_tooltip_text updates the prompt.


func set_tooltip_visible(value: bool) -> void:

	if Engine.is_editor_hint():
		return
	_is_player_nearby = value
	if value:
		_refresh_tooltip_text()
	_tooltip.visible = value


func _refresh_tooltip_text() -> void:

	if PlayerState.total_ore <= 0:
		_tooltip.text = "No ore to deliver"
		_tooltip.modulate = Color(0.85, 0.62, 0.42, 1.0)
		return
	var payout : int = int(round(
		PlayerState.total_ore * PlayerState.ORE_TO_GOLD_RATE))
	_tooltip.text = "Deliver %d ore for %d gold   [E]" % [PlayerState.total_ore, payout]
	_tooltip.modulate = Color(0.78, 1.0, 0.62, 1.0)


func _on_ore_changed(_new_total: int) -> void:

	if _is_player_nearby:
		_refresh_tooltip_text()


func _draw() -> void:

	# Iso bin placeholder — front face + tilted top diamond + dark back edge.
	var front_bot_l : Vector2 = Vector2(-BIN_HALF_WIDTH, 0.0)
	var front_bot_r : Vector2 = Vector2(BIN_HALF_WIDTH, 0.0)
	var front_top_l : Vector2 = Vector2(-BIN_HALF_WIDTH, -BIN_HEIGHT)
	var front_top_r : Vector2 = Vector2(BIN_HALF_WIDTH, -BIN_HEIGHT)
	var back_top_l : Vector2 = front_top_l + Vector2(0.0, -BIN_DEPTH)
	var back_top_r : Vector2 = front_top_r + Vector2(0.0, -BIN_DEPTH)
	# Front face.
	draw_colored_polygon(
		PackedVector2Array([front_bot_l, front_bot_r, front_top_r, front_top_l]),
		COLOR_FRONT_FILL)
	# Rivet rows on the front face.
	for ry in [-BIN_HEIGHT + 8.0, -8.0]:
		for i in range(5):
			var t : float = i / 4.0
			draw_circle(Vector2(lerpf(front_bot_l.x + 6.0, front_bot_r.x - 6.0, t), ry),
				1.8, COLOR_RIVET)
	# Top diamond.
	draw_colored_polygon(
		PackedVector2Array([front_top_l, front_top_r, back_top_r, back_top_l]),
		COLOR_TOP_FILL)
	# Ore lumps heaped on the open top.
	var top_centre : Vector2 = (front_top_l + front_top_r + back_top_r + back_top_l) * 0.25
	_draw_lump(top_centre + Vector2(-14.0, -2.0), 7.0, COLOR_ORE_B)
	_draw_lump(top_centre + Vector2(6.0, -6.0), 8.0, COLOR_ORE_A)
	_draw_lump(top_centre + Vector2(16.0, 2.0), 6.0, COLOR_ORE_B)
	_draw_lump(top_centre + Vector2(-2.0, 2.0), 6.5, COLOR_ORE_A)
	# Outline the silhouette.
	draw_polyline(
		PackedVector2Array([front_bot_l, front_bot_r, front_top_r,
			back_top_r, back_top_l, front_top_l, front_bot_l]),
		COLOR_FRAME, 1.6)
	draw_line(front_top_l, front_top_r, COLOR_FRAME, 1.2)


func _draw_lump(centre: Vector2, r: float, color: Color) -> void:

	draw_circle(centre, r, color)
	draw_circle(centre + Vector2(-r * 0.3, -r * 0.3), r * 0.3, color.lightened(0.4))
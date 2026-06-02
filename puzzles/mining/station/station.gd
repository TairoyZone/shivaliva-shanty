## The MiningSign — a sign post standing at the mouth of the Mine. The
## player walks up, presses E, and launches the Mining puzzle.
##
## Gated on [member PlayerState.hired_at_forge]: until the player has
## applied for the job at Cinder Troy's Forge HiringBoard, the sign just
## shows a hint to ask at the Forge first instead of launching.
##
## The Mining-side mirror of [WoodCuttingSign]. Inherits all proximity /
## tooltip / scene-change wiring from [Puzzle]; this script owns the
## hire-gate + the pickaxe-stamped visual. See [[mining-spec]].
@tool
class_name MiningSign
extends Puzzle


const POST_WIDTH : float = 9.0
const POST_HEIGHT : float = 92.0
const BASE_PEG_WIDTH : float = 26.0
const BASE_PEG_HEIGHT : float = 4.0
const BOARD_WIDTH : float = 104.0
const BOARD_HEIGHT : float = 60.0
const BOARD_TOP_OFFSET : float = 6.0
const NAIL_INSET : float = 6.0
const NAIL_RADIUS : float = 2.6

const COLOR_POST_FILL : Color = Color(0.34, 0.30, 0.28, 1.0)
const COLOR_POST_FRAME : Color = Color(0.14, 0.12, 0.12, 1.0)
const COLOR_BOARD_FILL : Color = Color(0.48, 0.50, 0.56, 1.0)
const COLOR_BOARD_FRAME : Color = Color(0.72, 0.74, 0.80, 1.0)
const COLOR_NAIL : Color = Color(0.78, 0.80, 0.86, 1.0)
const COLOR_PICK_HEAD : Color = Color(0.86, 0.88, 0.92, 1.0)
const COLOR_PICK_HANDLE : Color = Color(0.55, 0.36, 0.18, 1.0)


func interact() -> void:

	if Engine.is_editor_hint():
		return
	if not PlayerState.hired_at_forge:
		# Tooltip already explains — silently deny the launch.
		return
	if puzzle_scene.is_empty():
		return
	if play_cost > 0 and PlayerState.total_coins < play_cost:
		return
	if play_cost > 0:
		PlayerState.add_coins(-play_cost)
	PlayerState.request_spawn_at_anchor(name)
	get_tree().change_scene_to_file(puzzle_scene)


func _refresh_tooltip_text() -> void:

	if not PlayerState.hired_at_forge:
		_tooltip.text = "Ask Cinder Troy for work first"
		_tooltip.modulate = Color(0.98, 0.62, 0.42, 1.0)
		return
	super._refresh_tooltip_text()


func _draw() -> void:

	# Base pegs.
	var peg_rect : Rect2 = Rect2(
		-BASE_PEG_WIDTH * 0.5, -BASE_PEG_HEIGHT, BASE_PEG_WIDTH, BASE_PEG_HEIGHT)
	draw_rect(peg_rect, COLOR_POST_FILL)
	draw_rect(peg_rect, COLOR_POST_FRAME, false, 1.0)
	# Post.
	var post_rect : Rect2 = Rect2(
		-POST_WIDTH * 0.5, -POST_HEIGHT, POST_WIDTH, POST_HEIGHT)
	draw_rect(post_rect, COLOR_POST_FILL)
	draw_rect(post_rect, COLOR_POST_FRAME, false, 1.2)
	# Slate sign board.
	var board_y : float = -POST_HEIGHT + BOARD_TOP_OFFSET
	var board_rect : Rect2 = Rect2(
		-BOARD_WIDTH * 0.5, board_y, BOARD_WIDTH, BOARD_HEIGHT)
	draw_rect(board_rect, COLOR_BOARD_FILL)
	draw_rect(board_rect, COLOR_BOARD_FRAME, false, 2.0)
	# Corner nails.
	_draw_nail(board_rect.position + Vector2(NAIL_INSET, NAIL_INSET))
	_draw_nail(board_rect.position + Vector2(BOARD_WIDTH - NAIL_INSET, NAIL_INSET))
	_draw_nail(board_rect.position + Vector2(NAIL_INSET, BOARD_HEIGHT - NAIL_INSET))
	_draw_nail(board_rect.position + Vector2(BOARD_WIDTH - NAIL_INSET, BOARD_HEIGHT - NAIL_INSET))
	# Pickaxe stamp — reads as "the digging spot."
	_draw_pick_stamp(board_rect.position + board_rect.size * 0.5)


func _draw_nail(at: Vector2) -> void:

	draw_circle(at, NAIL_RADIUS, COLOR_NAIL)
	draw_circle(at, NAIL_RADIUS * 0.4, COLOR_POST_FRAME)


# A pickaxe: a curved double head with a diagonal handle.
func _draw_pick_stamp(center: Vector2) -> void:

	var head : PackedVector2Array = PackedVector2Array([
		center + Vector2(-24.0, 4.0),
		center + Vector2(-10.0, -12.0),
		center + Vector2(2.0, -15.0),
		center + Vector2(16.0, -12.0),
		center + Vector2(24.0, 2.0),
		center + Vector2(16.0, 4.0),
		center + Vector2(2.0, -6.0),
		center + Vector2(-12.0, -3.0),
	])
	draw_colored_polygon(head, COLOR_PICK_HEAD)
	draw_polyline(head, Color(0, 0, 0, 0.6), 1.2)
	# Handle running down to the lower-right.
	draw_line(center + Vector2(0.0, -6.0), center + Vector2(10.0, 20.0),
		COLOR_PICK_HANDLE, 3.4)
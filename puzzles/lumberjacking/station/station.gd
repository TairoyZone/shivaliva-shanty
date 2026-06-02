## The WoodCuttingSign — a wooden sign post standing at the edge of the
## Forest. The player walks up, presses E, and launches the Lumberjacking
## puzzle.
##
## Gated on [member PlayerState.hired_at_workshop]: until the player has
## applied for the job at Cogwise Godfrey's HiringBoard, the sign just
## shows a hint to ask at the Workshop first instead of launching.
##
## Inherits all proximity / tooltip / scene-change wiring from [Puzzle].
## This script only owns:
##   - the hire-gate check in [method interact] and [method _refresh_tooltip_text]
##   - the visual: a vertical post with a sign board nailed on, axe icon stamped
##
## See [[lumberjacking-spec]] for the surrounding loop (Apply → Forest →
## Chop → Drop-off → Gold).
@tool
class_name WoodCuttingSign
extends Puzzle


# --- Visual placeholder dimensions -----------------------------------
# Origin (0, 0) is the foot of the post on the ground.

const POST_WIDTH : float = 9.0
const POST_HEIGHT : float = 92.0
const BASE_PEG_WIDTH : float = 26.0
const BASE_PEG_HEIGHT : float = 4.0
const BOARD_WIDTH : float = 104.0
const BOARD_HEIGHT : float = 60.0
const BOARD_TOP_OFFSET : float = 6.0   # from the post's top
const NAIL_INSET : float = 6.0
const NAIL_RADIUS : float = 2.6

# --- Palette ---------------------------------------------------------

const COLOR_POST_FILL : Color = Color(0.42, 0.26, 0.10, 1.0)
const COLOR_POST_FRAME : Color = Color(0.18, 0.10, 0.04, 1.0)
const COLOR_BOARD_FILL : Color = Color(0.62, 0.42, 0.20, 1.0)
const COLOR_BOARD_FRAME : Color = Color(0.85, 0.65, 0.28, 1.0)
const COLOR_NAIL : Color = Color(0.92, 0.78, 0.36, 1.0)
const COLOR_AXE_BLADE : Color = Color(0.18, 0.16, 0.14, 1.0)
const COLOR_AXE_HIGHLIGHT : Color = Color(0.90, 0.86, 0.78, 0.85)


func interact() -> void:

	if Engine.is_editor_hint():
		return
	if not PlayerState.hired_at_workshop:
		# Tooltip already explains — silently deny the launch.
		return
	if puzzle_scene.is_empty():
		return
	if play_cost > 0 and PlayerState.total_coins < play_cost:
		return
	if play_cost > 0:
		PlayerState.add_coins(-play_cost)
	# When the puzzle exits, BaseLocation finds the node by our name and
	# uses position + spawn_offset to drop the player right beside us.
	PlayerState.request_spawn_at_anchor(name)
	get_tree().change_scene_to_file(puzzle_scene)


# Override the [Puzzle] tooltip to surface the hire-gate when the player
# hasn't applied yet. After applying, falls through to the normal cost/
# label tooltip.
func _refresh_tooltip_text() -> void:

	if not PlayerState.hired_at_workshop:
		_tooltip.text = "Ask Cogwise Godfrey for work first"
		_tooltip.modulate = Color(0.98, 0.62, 0.42, 1.0)
		return
	super._refresh_tooltip_text()


func _draw() -> void:

	# Base pegs — two small horizontal supports right at the ground line.
	var peg_y : float = -BASE_PEG_HEIGHT
	var peg_rect : Rect2 = Rect2(
		-BASE_PEG_WIDTH * 0.5, peg_y,
		BASE_PEG_WIDTH, BASE_PEG_HEIGHT)
	draw_rect(peg_rect, COLOR_POST_FILL)
	draw_rect(peg_rect, COLOR_POST_FRAME, false, 1.0)
	# Vertical post — main wooden upright.
	var post_rect : Rect2 = Rect2(
		-POST_WIDTH * 0.5, -POST_HEIGHT,
		POST_WIDTH, POST_HEIGHT)
	draw_rect(post_rect, COLOR_POST_FILL)
	draw_rect(post_rect, COLOR_POST_FRAME, false, 1.2)
	# Sign board nailed near the top of the post.
	var board_y : float = -POST_HEIGHT + BOARD_TOP_OFFSET
	var board_rect : Rect2 = Rect2(
		-BOARD_WIDTH * 0.5, board_y,
		BOARD_WIDTH, BOARD_HEIGHT)
	draw_rect(board_rect, COLOR_BOARD_FILL)
	draw_rect(board_rect, COLOR_BOARD_FRAME, false, 2.0)
	# Nails at the four corners of the board.
	_draw_nail(board_rect.position + Vector2(NAIL_INSET, NAIL_INSET))
	_draw_nail(board_rect.position + Vector2(BOARD_WIDTH - NAIL_INSET, NAIL_INSET))
	_draw_nail(board_rect.position + Vector2(NAIL_INSET, BOARD_HEIGHT - NAIL_INSET))
	_draw_nail(board_rect.position + Vector2(BOARD_WIDTH - NAIL_INSET, BOARD_HEIGHT - NAIL_INSET))
	# Axe icon stamped on the board — reads as "this is the chopping
	# spot" without needing literal text.
	_draw_axe_stamp(board_rect.position + board_rect.size * 0.5)


func _draw_nail(at: Vector2) -> void:

	draw_circle(at, NAIL_RADIUS, COLOR_NAIL)
	draw_circle(at, NAIL_RADIUS * 0.4, COLOR_POST_FRAME)


# Chunky axe head plus diagonal handle — same silhouette family as the
# breaker stamp on LogPiece so the player learns the icon vocabulary.
func _draw_axe_stamp(center: Vector2) -> void:

	var head_points : PackedVector2Array = PackedVector2Array([
		center + Vector2(-22.0, -10.0),
		center + Vector2(10.0, -16.0),
		center + Vector2(20.0, 2.0),
		center + Vector2(4.0, 8.0),
		center + Vector2(-18.0, 3.0),
	])
	draw_colored_polygon(head_points, COLOR_AXE_BLADE)
	draw_polyline(head_points, Color(0, 0, 0, 0.7), 1.4)
	# Cutting-edge highlight.
	draw_line(
		center + Vector2(8.0, -14.0),
		center + Vector2(19.0, 1.0),
		COLOR_AXE_HIGHLIGHT, 1.4)
	# Diagonal handle running to the bottom-right.
	draw_line(
		center + Vector2(-4.0, 6.0),
		center + Vector2(24.0, 22.0),
		COLOR_AXE_BLADE, 3.2)
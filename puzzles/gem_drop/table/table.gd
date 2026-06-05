## The Gem Drop board prop. Extends [ParlorTable] (which extends [Puzzle])
## for the lobby + NPC-hosting layer and the interaction logic (proximity,
## dynamic affordability tooltip, cost + scene change + return anchor).
## This script only owns the per-game config + the visual:
## a trapezoidal pegboard standing on two short legs, narrow at the
## top (where gems drop in) and wider at the base (the scoring slots).
@tool
class_name GemDropTable
extends ParlorTable


# --- Parlor config (see [ParlorTable]) --------------------------------
# Gem Drop: fixed 2 seats (you + 1 opponent); NO entry buy-in — the cost
# is billed at puzzle EXIT (a clean -5 toast), and a FREE table suppresses
# it entirely inside [GemDropScene]. So it charges nothing at launch.

func _game_id() -> String:
	return "gem_drop"

func _game_name() -> String:
	return "Gem Drop"

func _cash_cost() -> int:
	return 0

func _cash_note() -> String:
	return "win +10 gold, lose 5 on a loss"

func _charges_buy_in() -> bool:
	return false

func _badge_y() -> float:
	return -130.0


## Iso placeholder dimensions. Origin (0,0) is the FRONT-CENTER-BOTTOM
## of the table (matches building footprint convention). Table base is a
## small iso cube; the trapezoidal board stands UP from the top.
const TABLE_HW : float = 50.0       # half-width of table footprint
const TABLE_HH : float = 25.0       # half-height of table footprint (iso 2:1)
const TABLE_LEG_HEIGHT : float = 22.0
const BOARD_TOP_HW : float = 18.0
const BOARD_BOT_HW : float = 26.0
const BOARD_HEIGHT : float = 64.0
const BASE_STRIP_HEIGHT : float = 5.0

const PEG_ROWS : int = 4
const PEG_COLS : int = 3
const PEG_WIDTH : float = 1.6
const PEG_HEIGHT : float = 5.5

const COLOR_BOARD : Color = Color(0.96, 0.82, 0.22)
const COLOR_OUTLINE : Color = Color(0.20, 0.14, 0.04)
const COLOR_PEG : Color = Color(0.20, 0.14, 0.04)
const COLOR_LEG_DARK : Color = Color(0.42, 0.26, 0.12)
const COLOR_LEG_LIGHT : Color = Color(0.58, 0.38, 0.18)
const COLOR_LEG_TOP : Color = Color(0.68, 0.46, 0.22)
const COLOR_BASE_STRIP : Color = Color(0.85, 0.68, 0.18)


func _draw() -> void:

	# Iso table base — small cube with two visible faces + top diamond.
	var front : Vector2 = Vector2.ZERO
	var right : Vector2 = Vector2(TABLE_HW, -TABLE_HH)
	var back : Vector2 = Vector2(0.0, -2.0 * TABLE_HH)
	var left : Vector2 = Vector2(-TABLE_HW, -TABLE_HH)
	var t_front : Vector2 = front + Vector2(0.0, -TABLE_LEG_HEIGHT)
	var t_right : Vector2 = right + Vector2(0.0, -TABLE_LEG_HEIGHT)
	var t_back : Vector2 = back + Vector2(0.0, -TABLE_LEG_HEIGHT)
	var t_left : Vector2 = left + Vector2(0.0, -TABLE_LEG_HEIGHT)
	# Front-left face (shadow).
	draw_colored_polygon(
		PackedVector2Array([left, front, t_front, t_left]),
		COLOR_LEG_DARK)
	# Front-right face (sun-lit).
	draw_colored_polygon(
		PackedVector2Array([front, right, t_right, t_front]),
		COLOR_LEG_LIGHT)
	# Top diamond (table surface).
	draw_colored_polygon(
		PackedVector2Array([t_front, t_right, t_back, t_left]),
		COLOR_LEG_TOP)
	# Cube outlines.
	draw_polyline(
		PackedVector2Array([left, front, right, t_right, t_front, t_left, left]),
		COLOR_OUTLINE, 1.5)
	draw_line(front, t_front, COLOR_OUTLINE, 1.5)
	draw_polyline(
		PackedVector2Array([t_left, t_front, t_right, t_back, t_left]),
		COLOR_OUTLINE, 1.2)
	# Trapezoidal gem board standing UPRIGHT on the top diamond. The
	# board's "feet" sit at the center of the table top — at the back of
	# the diamond so the board has visual depth.
	var board_base_y : float = -TABLE_LEG_HEIGHT - TABLE_HH
	var corners : PackedVector2Array = PackedVector2Array([
		Vector2(-BOARD_BOT_HW, board_base_y),
		Vector2(BOARD_BOT_HW, board_base_y),
		Vector2(BOARD_TOP_HW, board_base_y - BOARD_HEIGHT),
		Vector2(-BOARD_TOP_HW, board_base_y - BOARD_HEIGHT),
	])
	draw_colored_polygon(corners, COLOR_BOARD)
	var board_outline : PackedVector2Array = corners.duplicate()
	board_outline.append(corners[0])
	draw_polyline(board_outline, COLOR_OUTLINE, 2.0)
	# Pegs (vertical dashes) on the board, staggered.
	for row in range(PEG_ROWS):
		var t : float = (row + 0.5) / float(PEG_ROWS)
		var y : float = board_base_y - BOARD_HEIGHT + BOARD_HEIGHT * t
		var half_width : float = lerp(BOARD_TOP_HW, BOARD_BOT_HW, t)
		var usable_half : float = half_width * 0.80
		var col_step : float = (usable_half * 2.0) / float(PEG_COLS)
		var x_offset : float = -usable_half + col_step * 0.5
		if row % 2 == 1:
			x_offset += col_step * 0.5
		for col in range(PEG_COLS):
			var x : float = x_offset + col_step * col
			if absf(x) > half_width - 2.0:
				continue
			draw_rect(Rect2(x - PEG_WIDTH * 0.5, y - PEG_HEIGHT * 0.5, PEG_WIDTH, PEG_HEIGHT), COLOR_PEG)
	# Bottom slot strip + dividers at the base of the board.
	var strip_y : float = board_base_y - BASE_STRIP_HEIGHT
	draw_rect(Rect2(-BOARD_BOT_HW, strip_y, BOARD_BOT_HW * 2.0, BASE_STRIP_HEIGHT), COLOR_BASE_STRIP)
	for i in range(1, 5):
		var sx : float = lerp(-BOARD_BOT_HW, BOARD_BOT_HW, i / 5.0)
		draw_line(Vector2(sx, strip_y), Vector2(sx, strip_y + BASE_STRIP_HEIGHT), COLOR_OUTLINE, 1.0)

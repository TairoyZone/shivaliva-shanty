## The Hold 'em Poker table prop. Sits in the tavern alongside the
## [GemDropTable]. Extends [ParlorTable] (which extends [Puzzle]) for the
## lobby + NPC-hosting layer and the interaction logic (proximity tooltip
## with affordability, gold buy-in deduction, scene change, return-spawn
## anchoring); this script only owns the per-game config + the visual — a
## flat iso table with a green felt top, brass rim, and a few chip stacks.
##
## Economy: nothing is charged on launch — the player chooses a VARIABLE buy-in at the table (the
## scene's "Buy into the game?" dialog), within the stake's 10×–100× range. The stack IS gold (1:1):
## cash out your final stack on exit, à la YPP's PoE. Bust = no refund. See [PokerConfig].
@tool
class_name PokerTable
extends ParlorTable


# Iso table dimensions. Origin (0,0) is the FRONT-CENTER-BOTTOM of the
# table — same convention as the gem-drop table + buildings.
const TABLE_HW : float = 58.0          # half-width of the footprint
const TABLE_HH : float = 29.0          # half-depth (2:1 iso ratio)
const LEG_HEIGHT : float = 24.0        # table lift above the floor
const FELT_INSET : float = 7.0         # brass-rim thickness around the felt

const COLOR_LEG_DARK : Color = Color(0.40, 0.25, 0.12, 1.0)
const COLOR_LEG_LIT : Color = Color(0.56, 0.37, 0.18, 1.0)
const COLOR_OUTLINE : Color = Color(0.18, 0.10, 0.04, 1.0)
const COLOR_RIM : Color = Color(0.78, 0.58, 0.24, 1.0)
const COLOR_FELT : Color = Color(0.14, 0.40, 0.24, 1.0)
const COLOR_FELT_SEAM : Color = Color(0.08, 0.26, 0.14, 1.0)
const COLOR_CHIP_RED : Color = Color(0.82, 0.24, 0.22, 1.0)
const COLOR_CHIP_BLUE : Color = Color(0.30, 0.55, 0.82, 1.0)
const COLOR_CHIP_CREAM : Color = Color(0.95, 0.93, 0.86, 1.0)


# --- Parlor config (see [ParlorTable]) --------------------------------
# Poker: 2-10 players; a VARIABLE buy-in chosen at the felt (the scene's "Buy into the game?"
# dialog), so nothing is charged on launch.

func _game_id() -> String:
	return "poker"

func _game_name() -> String:
	return "Poker"

func _max_seats() -> int:
	return 10   # YPP-style: up to 10 at the table (empty seats are fine — only the cast fills in)

func _cash_note() -> String:
	return "Texas Hold'em — pick a stake, buy in, cash out your stack"

# The buy-in is now VARIABLE and chosen at the table (the scene's "Buy into the game?" dialog), so
# nothing is charged on launch — unlike the old fixed play_cost. (Cf. Gem Drop, which bills at exit.)
func _charges_buy_in() -> bool:
	return false

func _badge_y() -> float:
	return -96.0


func _draw() -> void:

	# Iso table base — small cube with the front-left + front-right
	# faces visible, topped with a brass-rimmed green felt.
	var front : Vector2 = Vector2.ZERO
	var right : Vector2 = Vector2(TABLE_HW, -TABLE_HH)
	var back : Vector2 = Vector2(0.0, -2.0 * TABLE_HH)
	var left : Vector2 = Vector2(-TABLE_HW, -TABLE_HH)
	var t_front : Vector2 = front + Vector2(0.0, -LEG_HEIGHT)
	var t_right : Vector2 = right + Vector2(0.0, -LEG_HEIGHT)
	var t_back : Vector2 = back + Vector2(0.0, -LEG_HEIGHT)
	var t_left : Vector2 = left + Vector2(0.0, -LEG_HEIGHT)

	# Two visible leg faces.
	draw_colored_polygon(PackedVector2Array([left, front, t_front, t_left]), COLOR_LEG_DARK)
	draw_colored_polygon(PackedVector2Array([front, right, t_right, t_front]), COLOR_LEG_LIT)
	# Full top diamond — this is the brass rim.
	draw_colored_polygon(PackedVector2Array([t_front, t_right, t_back, t_left]), COLOR_RIM)
	# Green felt — inset diamond inside the rim. Inset proportional to
	# the table's footprint so the rim ring reads at a consistent thickness.
	var f_front : Vector2 = Vector2(0.0, t_front.y + FELT_INSET * 0.5)
	var f_right : Vector2 = Vector2(t_right.x - FELT_INSET, t_right.y)
	var f_back : Vector2 = Vector2(0.0, t_back.y - FELT_INSET * 0.5)
	var f_left : Vector2 = Vector2(t_left.x + FELT_INSET, t_left.y)
	draw_colored_polygon(PackedVector2Array([f_front, f_right, f_back, f_left]), COLOR_FELT)

	# A trio of chip stacks on the felt so the table reads as poker.
	var felt_center : Vector2 = (f_front + f_back) * 0.5
	_draw_chip_stack(felt_center + Vector2(-14.0, -2.0), COLOR_CHIP_RED, 3)
	_draw_chip_stack(felt_center + Vector2(8.0, -4.0), COLOR_CHIP_BLUE, 2)
	_draw_chip_stack(felt_center + Vector2(-2.0, 7.0), COLOR_CHIP_CREAM, 4)

	# Outlines (silhouette + crease + felt rim).
	draw_polyline(
		PackedVector2Array([left, front, right, t_right, t_front, t_left, left]),
		COLOR_OUTLINE, 1.5)
	draw_line(front, t_front, COLOR_OUTLINE, 1.5)
	draw_polyline(
		PackedVector2Array([t_left, t_front, t_right, t_back, t_left]),
		COLOR_OUTLINE, 1.2)
	draw_polyline(
		PackedVector2Array([f_left, f_front, f_right, f_back, f_left]),
		COLOR_FELT_SEAM, 1.0)


# Stylized "stack of chips" — `count` concentric circles offset upward
# slightly per layer. Tiny, no overlap with neighboring stacks.
func _draw_chip_stack(center: Vector2, color: Color, count: int) -> void:

	const RADIUS : float = 4.0
	const RIM_THICK : float = 0.9
	const LAYER_LIFT : float = 1.6
	for i in count:
		var pos : Vector2 = center + Vector2(0.0, -i * LAYER_LIFT)
		draw_circle(pos, RADIUS, color)
		draw_arc(pos, RADIUS, 0.0, TAU, 14, color.darkened(0.35), RIM_THICK)

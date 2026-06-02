## The selection cursor on the Mining board — the signature Foraging
## control. It normally frames a 2x2 of rock tiles (the four the player
## rotates). When it sits over a special tool it shrinks to a 1x1 frame
## (set span_cells = 1) to show the tool can be activated. The board owns
## where it sits + its span; this scene only draws the frame. Kept on a
## high z_index so it always sits above the pieces.
##
## See [[mining-spec]].
@tool
class_name MiningCursor
extends Node2D


## MUST match MiningBoard.CELL / MiningRockTile.CELL_SIZE.
const CELL : float = 44.0
## Frame line thickness.
const FRAME_WIDTH : float = 3.0


## 2 = the normal 2x2 selector, 1 = the 1x1 selector over a special.
@export var span_cells : int = 2 :
	set(value):
		span_cells = value
		queue_redraw()


func _draw() -> void:

	var span : float = CELL * float(span_cells)
	var rect : Rect2 = Rect2(0.0, 0.0, span, span)
	# A 1x1 (special) cursor reads in the tool's own warm tone; the 2x2
	# stays brass so the two modes are instantly distinguishable.
	var frame_color : Color = (Color(1.0, 0.78, 0.30, 0.98) if span_cells == 1
		else Color(1.0, 0.92, 0.55, 0.95))
	# Dark backing stroke first so the bright frame reads on any tile.
	draw_rect(rect.grow(1.0), Color(0.0, 0.0, 0.0, 0.55), false, FRAME_WIDTH + 2.0)
	draw_rect(rect, frame_color, false, FRAME_WIDTH)
	# Corner ticks.
	var tick : float = CELL * 0.34
	var accent : Color = Color(1.0, 0.98, 0.78, 1.0)
	draw_line(Vector2.ZERO, Vector2(tick, 0.0), accent, FRAME_WIDTH)
	draw_line(Vector2.ZERO, Vector2(0.0, tick), accent, FRAME_WIDTH)
	draw_line(Vector2(span, 0.0), Vector2(span - tick, 0.0), accent, FRAME_WIDTH)
	draw_line(Vector2(span, 0.0), Vector2(span, tick), accent, FRAME_WIDTH)
	draw_line(Vector2(0.0, span), Vector2(tick, span), accent, FRAME_WIDTH)
	draw_line(Vector2(0.0, span), Vector2(0.0, span - tick), accent, FRAME_WIDTH)
	draw_line(Vector2(span, span), Vector2(span - tick, span), accent, FRAME_WIDTH)
	draw_line(Vector2(span, span), Vector2(span, span - tick), accent, FRAME_WIDTH)
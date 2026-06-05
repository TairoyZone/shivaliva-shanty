## Renders a single Card from the shared poker spritesheet. Set `card`
## and `face_up` via the setters and the node re-draws.
##
## Spritesheet layout (cards.png — 944×385):
##   • 4 suit rows at y = 0, 64, 128, 192. Row order Hearts → Diamonds
##     → Spades → Clubs (matches [enum Card.Suit] indices).
##   • Each face cell is 48 wide × 64 tall; card art has ~3px transparent
##     padding on left + right inside the cell.
##   • Each row has 15 columns; cols 0..12 are ranks A..K, cols 13..14
##     are jokers / unused slots that we don't reference for poker.
##   • Bottom backs row at y = 256, same 48×64 cells, 8 colors.
@tool
class_name CardSprite
extends Node2D


const SPRITESHEET : Texture2D = preload("res://puzzles/poker/assets/cards.png")

const CELL_W : float = 48.0
const CELL_H : float = 64.0
## The source cells are a tiny 48×64 — render the card BIGGER so rank/suit read clearly at the table.
## Tunable: bump it for chunkier cards, drop it toward 1.0 for the original size.
const DRAW_SCALE : float = 1.45
const DRAW_W : float = CELL_W * DRAW_SCALE
const DRAW_H : float = CELL_H * DRAW_SCALE
## Y-coord of the top of each suit row, indexed by [enum Card.Suit].
const SUIT_ROW_Y : Array[float] = [0.0, 64.0, 128.0, 192.0]
const BACKS_ROW_Y : float = 256.0

var card : Card = null :
	set(value):
		card = value
		queue_redraw()
var face_up : bool = true :
	set(value):
		face_up = value
		queue_redraw()
## Which of the 8 card backs to draw when face_down.
@export_range(0, 7) var back_design : int = 0 :
	set(value):
		back_design = clampi(value, 0, 7)
		queue_redraw()
## When true, the card sits raised slightly with a brass glow border —
## used at showdown to flag the 5 cards that made the winning hand.
@export var highlighted : bool = false :
	set(value):
		highlighted = value
		queue_redraw()
## When true, the card is heavily darkened — paired with [member highlighted]
## at showdown so non-contributing cards visually recede.
@export var dimmed : bool = false :
	set(value):
		dimmed = value
		self_modulate = Color(0.40, 0.40, 0.40, 1.0) if dimmed else Color.WHITE


func _draw() -> void:

	if face_up:
		_draw_face()
	else:
		_draw_back()


# Source-rect math: rank 1..13 → cols 0..12, suit 0..3 → row Y from table.
func _draw_face() -> void:

	if card == null:
		return
	var lift : float = -8.0 if highlighted else 0.0
	var src : Rect2 = Rect2(
		(card.rank - 1) * CELL_W,
		SUIT_ROW_Y[card.suit],
		CELL_W, CELL_H)
	var dst : Rect2 = Rect2(-DRAW_W * 0.5, -DRAW_H * 0.5 + lift, DRAW_W, DRAW_H)
	draw_texture_rect_region(SPRITESHEET, dst, src)
	if highlighted:
		# Brass glow border around the lifted card.
		draw_rect(dst.grow(2.5), Color(1.0, 0.92, 0.42, 0.50), false, 4.0)
		draw_rect(dst, Color(1.0, 0.96, 0.55, 1.0), false, 2.0)


func _draw_back() -> void:

	var src : Rect2 = Rect2(
		back_design * CELL_W,
		BACKS_ROW_Y,
		CELL_W, CELL_H)
	var dst : Rect2 = Rect2(-DRAW_W * 0.5, -DRAW_H * 0.5, DRAW_W, DRAW_H)
	draw_texture_rect_region(SPRITESHEET, dst, src)


## Helper for code that builds a CardSprite at runtime.
func set_card(p_card: Card, p_face_up: bool = true) -> void:

	card = p_card
	face_up = p_face_up

## "NEXT" preview box for the Lumberjacking puzzle — shows the upcoming
## falling pair (A on top, B below, matching the PAIR_B_BELOW spawn
## orientation) so the player can plan ahead, exactly like the YPP
## SwordFight next-piece indicator.
##
## Driven by [signal LumberjackingBoard.next_pair_changed] via the scene
## controller calling [method set_pair]. Reuses the [LogPiece] scene for
## its visuals, so when the piece art is swapped the preview updates for
## free (per the scene-per-component principle).
##
## Reposition this node freely in the scene — it draws its own framed
## box relative to its origin (the top-left of the "NEXT" label).
@tool
class_name LumberNextPreview
extends Node2D


const LogPieceScene : PackedScene = preload("res://puzzles/lumberjacking/log_piece/log_piece.tscn")

const LABEL_HEIGHT : float = 24.0
const FRAME_PAD : float = 8.0
const COLOR_FRAME_BG : Color = Color(0.20, 0.13, 0.07, 0.92)
const COLOR_FRAME_BORDER : Color = Color(0.68, 0.46, 0.22, 1.0)
const COLOR_LABEL : Color = Color(0.95, 0.82, 0.55, 1.0)

var _piece_a : LogPiece
var _piece_b : LogPiece
var _label : Label


func _ready() -> void:

	# "NEXT" caption.
	_label = Label.new()
	_label.text = "NEXT"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", COLOR_LABEL)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(0.0, 0.0)
	_label.size = Vector2(LogPiece.CELL_SIZE, LABEL_HEIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	# The two stacked preview pieces — A above B (PAIR_B_BELOW order).
	_piece_a = LogPieceScene.instantiate()
	_piece_b = LogPieceScene.instantiate()
	_piece_a.position = Vector2(0.0, LABEL_HEIGHT)
	_piece_b.position = Vector2(0.0, LABEL_HEIGHT + LogPiece.CELL_SIZE)
	add_child(_piece_a)
	add_child(_piece_b)
	queue_redraw()


## Update the displayed pair. Called by the scene controller in response
## to [signal LumberjackingBoard.next_pair_changed].
func set_pair(a_kind: int, a_variant: int, b_kind: int, b_variant: int) -> void:

	if _piece_a == null or _piece_b == null:
		return
	_piece_a.wood_kind = a_kind as LogPiece.WoodKind
	_piece_a.variant = a_variant as LogPiece.Variant
	_piece_b.wood_kind = b_kind as LogPiece.WoodKind
	_piece_b.variant = b_variant as LogPiece.Variant


func _draw() -> void:

	# Framed box wrapping the label + the two stacked cells.
	var box_w : float = LogPiece.CELL_SIZE + FRAME_PAD * 2.0
	var box_h : float = LABEL_HEIGHT + LogPiece.CELL_SIZE * 2.0 + FRAME_PAD
	var rect : Rect2 = Rect2(-FRAME_PAD, -FRAME_PAD * 0.5, box_w, box_h)
	draw_rect(rect, COLOR_FRAME_BG, true)
	draw_rect(rect, COLOR_FRAME_BORDER, false, 2.0)
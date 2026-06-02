## Draws THE STARDUST tint + the 2-wide swap CURSOR on TOP of the breath-stones
## (a z-lifted child of [LoftBoard], since a node's own _draw renders BEHIND its
## children). The board paints into it via [method LoftBoard.paint_overlay]; `board`
## is left untyped to avoid a cyclic class reference.
class_name LoftOverlay
extends Node2D


var board   # the LoftBoard


func _draw() -> void:

	if board != null:
		board.paint_overlay(self)
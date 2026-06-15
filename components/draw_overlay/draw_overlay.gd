## A tiny on-top draw layer. A board adds one of these as a child with a high
## z_index and points [member draw_fn] at a method that paints whatever must
## sit ABOVE the board's piece nodes — e.g. the frame (so pieces stop bleeding
## over it) and YPP-style fused blocks (so a 2x2+ group reads as one solid
## tile). The method receives THIS node as its canvas, so it issues draw_*
## calls on the overlay, not on the board.
##
## Usage:
##   var ov := DrawOverlay.new()
##   ov.z_index = 50
##   ov.draw_fn = _paint_overlay        # func _paint_overlay(ci: CanvasItem) -> void
##   add_child(ov)
## then ov.queue_redraw() whenever the painted state changes.
class_name DrawOverlay
extends Node2D


var draw_fn : Callable = Callable()


func _draw() -> void:

	if draw_fn.is_valid():
		draw_fn.call(self)

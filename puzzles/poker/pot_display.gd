## Central pot display: stylized chip pile + numeric chip-count label.
## The pile size + color tier scales by decade (1, 10, 100, 1k, 10k,
## 100k) so a small pot looks like a few chips while a huge pot piles
## up multiple stacks of high-value chips. Uses the actual chip
## spritesheet at [code]puzzles/poker/assets/chips.png[/code] instead
## of drawing procedural circles.
##
## Origin sits at the BASE of the pile (the bottom-most chip). Label
## floats below the pile.
@tool
class_name PotDisplay
extends Node2D


const CHIPS_TEX : Texture2D = preload("res://puzzles/poker/assets/chips.png")
# Native pixel size of one chip cell in the spritesheet.
const CHIP_CELL_W : float = 46.0
const CHIP_CELL_H : float = 48.0

# Top-left atlas coords of the "single chip" (variant 0) for each color.
# Each color has 4 horizontal variants; we only use variant 0 and build
# stack height ourselves by drawing multiple sprites.
const CHIP_COORDS : Dictionary = {
	"red":     Vector2(0.0,   0.0),
	"blue":    Vector2(184.0, 0.0),
	"gray":    Vector2(0.0,   48.0),
	"purple":  Vector2(184.0, 48.0),
	"green":   Vector2(0.0,   96.0),
	"magenta": Vector2(184.0, 96.0),
	"black":   Vector2(0.0,   144.0),
	"yellow":  Vector2(184.0, 144.0),
}

# On-screen size each chip is drawn at (the source cells are bigger).
const CHIP_DISPLAY_W : float = 24.0
const CHIP_DISPLAY_H : float = 25.0
# Vertical pixels between consecutive chips in a stack.
const CHIP_STACK_LIFT : float = 4.5
# Horizontal pixels between adjacent stacks.
const STACK_X_SPREAD : float = 18.0

const COLOR_TEXT : Color = Color(0.97, 0.87, 0.55, 1.0)
const COLOR_OUTLINE : Color = Color(0, 0, 0, 0.85)
const COLOR_SHADOW : Color = Color(0.06, 0.04, 0.02, 0.55)


@export var amount : int = 0 :
	set(value):
		amount = maxi(0, value)
		queue_redraw()


func _draw() -> void:

	_draw_pile()
	_draw_label()


# Pick a color + stack shape from the amount's decade and draw it.
# Higher tiers = "richer" chip color + taller / wider piles.
#   tier   range       color    stacks × per_stack
#   0      1–9         red      1 × 1
#   1      10–99       red      1 × 4
#   2      100–999     blue     2 × 5
#   3      1k–9999     green    3 × 6
#   4      10k–99,999  black    4 × 7
#   5      100k+       black    5 × 9
func _draw_pile() -> void:

	if amount < 1:
		return
	var color_key : String
	var stacks : int
	var per_stack : int
	if amount < 10:
		color_key = "red"; stacks = 1; per_stack = 1
	elif amount < 100:
		color_key = "red"; stacks = 1; per_stack = 4
	elif amount < 1000:
		color_key = "blue"; stacks = 2; per_stack = 5
	elif amount < 10000:
		color_key = "green"; stacks = 3; per_stack = 6
	elif amount < 100000:
		color_key = "black"; stacks = 4; per_stack = 7
	else:
		color_key = "black"; stacks = 5; per_stack = 9

	var coord : Vector2 = CHIP_COORDS[color_key]
	var src : Rect2 = Rect2(coord, Vector2(CHIP_CELL_W, CHIP_CELL_H))

	var total_width : float = (stacks - 1) * STACK_X_SPREAD
	for s in stacks:
		var x : float = -total_width * 0.5 + s * STACK_X_SPREAD
		# Soft shadow beneath each stack.
		draw_circle(Vector2(x, 4.0), CHIP_DISPLAY_W * 0.5, COLOR_SHADOW)
		# Stack the chips upward.
		for c in per_stack:
			var y : float = -c * CHIP_STACK_LIFT
			var dst : Rect2 = Rect2(
				Vector2(x - CHIP_DISPLAY_W * 0.5, y - CHIP_DISPLAY_H * 0.5),
				Vector2(CHIP_DISPLAY_W, CHIP_DISPLAY_H))
			draw_texture_rect_region(CHIPS_TEX, dst, src)


func _draw_label() -> void:

	var font : Font = ThemeDB.fallback_font
	var text : String = "%d" % amount
	var size : int = 18
	var dim : Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var baseline : Vector2 = Vector2(-dim.x * 0.5, 36.0)
	font.draw_string_outline(get_canvas_item(), baseline, text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, size, 4, COLOR_OUTLINE)
	font.draw_string(get_canvas_item(), baseline, text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, size, COLOR_TEXT)

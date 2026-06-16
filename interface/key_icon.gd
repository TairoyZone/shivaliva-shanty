## Procedural KEY icon — a small Control drawn via [_draw], no texture. A classic key: a round bow (head)
## with a hole, a shaft, and a two-tooth bit. The [member key_tint] sets the metal hue so the three door
## keys (Mine / Grove / Jungle) read apart at a glance in the backpack. Used by [InventoryPanel] for any
## "key_*" item. Resize via [member custom_minimum_size]; the key fills the smallest dimension, centred.
@tool
class_name KeyIcon
extends Control

## The key's metal hue (set per key type by the inventory panel).
@export var key_tint : Color = Color(0.95, 0.82, 0.32, 1.0) :
	set(value):
		key_tint = value
		queue_redraw()


func _ready() -> void:

	custom_minimum_size = Vector2(36.0, 36.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _draw() -> void:

	var s : float = minf(size.x, size.y)
	var c : Vector2 = size * 0.5
	var metal : Color = key_tint
	var dark : Color = metal.darkened(0.5)

	# Bow (round head) near the top, with a hole.
	var bow : Vector2 = c + Vector2(0.0, -s * 0.24)
	draw_circle(bow, s * 0.20, metal)
	draw_circle(bow, s * 0.20, dark)  # rim is drawn over below; this seeds the outline feel
	draw_circle(bow, s * 0.17, metal)
	draw_circle(bow, s * 0.085, dark)  # the hole

	# Shaft — a thick vertical stem from the bow down past centre.
	var shaft_top : Vector2 = bow + Vector2(0.0, s * 0.10)
	var shaft_bot : Vector2 = c + Vector2(0.0, s * 0.36)
	var sw : float = maxf(2.5, s * 0.11)
	draw_line(shaft_top, shaft_bot, metal, sw)

	# Bit (teeth) — two notches stepping off the bottom-right of the shaft.
	var tx : float = shaft_bot.x + sw * 0.4
	draw_rect(Rect2(tx, shaft_bot.y - s * 0.06, s * 0.16, s * 0.06), metal)
	draw_rect(Rect2(tx, shaft_bot.y - s * 0.17, s * 0.11, s * 0.06), metal)

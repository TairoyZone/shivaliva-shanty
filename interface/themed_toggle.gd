## ThemedToggle — a drawn on/off switch that follows the central HUD theme. Godot's built-in CheckButton draws
## its switch with engine-default textures that can't be recoloured, so this is a procedural _draw replacement:
## a labelled pill (accent when on, recessed when off) with a sliding knob — click anywhere on the row to flip.
## Drop-in via setup(text, on, on_toggle). Reusable anywhere a toggle is needed. (Troy 2026-06-17.)
class_name ThemedToggle
extends Control


signal toggled(on: bool)

const ROW_H : float = 34.0
const SW : float = 54.0   # switch width
const SH : float = 28.0   # switch height
const FONT_SIZE : int = 21

var label_text : String = ""
var pressed : bool = false


func _ready() -> void:

	custom_minimum_size = Vector2(0.0, ROW_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP


## Wire it up: label, initial state, and the setter called with the new value on each flip.
func setup(text: String, on: bool, on_toggle: Callable) -> void:

	label_text = text
	pressed = on
	if on_toggle.is_valid():
		toggled.connect(func(v: bool) -> void: on_toggle.call(v))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:

	if event is InputEventMouseButton:
		var mb : InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed = not pressed
			toggled.emit(pressed)
			queue_redraw()
			accept_event()


func _draw() -> void:

	var font : Font = get_theme_default_font()
	if font != null:
		draw_string(font, Vector2(0.0, size.y * 0.5 + FONT_SIZE * 0.34), label_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, Palette.TEXT_PRIMARY)
	# The switch, right-aligned.
	var sx : float = size.x - SW
	var sy : float = (size.y - SH) * 0.5
	var track : StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Palette.ACCENT if pressed else Palette.SLOT_BG
	track.border_color = Palette.ACCENT if pressed else Palette.BORDER
	track.set_border_width_all(2)
	track.set_corner_radius_all(int(SH * 0.5))
	track.draw(get_canvas_item(), Rect2(sx, sy, SW, SH))
	# Knob — light on the accent track (on), dark on the recessed track (off): contrast either way.
	var kr : float = SH * 0.5 - 4.0
	var kx : float = (sx + SW - kr - 5.0) if pressed else (sx + kr + 5.0)
	draw_circle(Vector2(kx, sy + SH * 0.5), kr, Palette.CARD_LIGHT if pressed else Palette.TEXT_MUTED)

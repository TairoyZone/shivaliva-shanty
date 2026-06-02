## Bottom-of-screen overlay card for NPC dialog and LoreObject reveals.
## Autoloaded — any script can call:
##
##   Overlay.show_dialog(speaker, lines_array)   # NPCs
##   Overlay.show_lore(title, body)               # LoreObjects, Springs
##
## Same panel container, two styles: dark-with-gold-trim for dialog,
## parchment-with-brown-trim for lore. Press E / Space / left-click to
## advance a dialog line; the last line dismisses on next advance. Lore
## is single-page, dismisses on any advance input.
##
## While `is_active` is true the [Player] freezes its movement input —
## that's how the world knows to pause while the player reads.
extends CanvasLayer


const DIALOG_PANEL_COLOR : Color = Color(0.08, 0.06, 0.12, 0.92)
const DIALOG_BORDER : Color = Color(0.85, 0.66, 0.28, 1.0)
const DIALOG_TEXT_COLOR : Color = Color(0.98, 0.96, 0.88, 1.0)
const DIALOG_SPEAKER_COLOR : Color = Color(0.98, 0.85, 0.40, 1.0)

const LORE_PANEL_COLOR : Color = Color(0.92, 0.85, 0.62, 0.96)
const LORE_BORDER : Color = Color(0.45, 0.30, 0.10, 1.0)
const LORE_TEXT_COLOR : Color = Color(0.22, 0.15, 0.08, 1.0)
const LORE_TITLE_COLOR : Color = Color(0.45, 0.20, 0.08, 1.0)

@onready var _panel : PanelContainer = $Panel
@onready var _title_label : Label = $Panel/Margin/VBox/TitleLabel
@onready var _body_label : Label = $Panel/Margin/VBox/BodyLabel
@onready var _hint_label : Label = $Panel/Margin/VBox/HintLabel

var is_active : bool = false

var _panel_style : StyleBoxFlat
var _pending_lines : Array[String] = []


func _ready() -> void:

	_panel.visible = false
	_panel_style = StyleBoxFlat.new()
	_panel_style.border_width_left = 3
	_panel_style.border_width_right = 3
	_panel_style.border_width_top = 3
	_panel_style.border_width_bottom = 3
	_panel_style.corner_radius_top_left = 14
	_panel_style.corner_radius_top_right = 14
	_panel_style.corner_radius_bottom_right = 14
	_panel_style.corner_radius_bottom_left = 14
	_panel_style.content_margin_left = 28
	_panel_style.content_margin_right = 28
	_panel_style.content_margin_top = 18
	_panel_style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", _panel_style)


func show_dialog(speaker: String, lines: Array[String]) -> void:

	if lines.is_empty():
		return
	_apply_dialog_style()
	_title_label.text = speaker
	_hint_label.text = "[E] / [Space] to continue"
	_pending_lines = lines.duplicate()
	_show_next_line()
	is_active = true


func show_lore(title: String, body: String) -> void:

	if body.is_empty() and title.is_empty():
		return
	_apply_lore_style()
	_title_label.text = title
	_body_label.text = body
	_hint_label.text = "[E] to close"
	_pending_lines.clear()
	_panel.visible = true
	is_active = true


func _input(event: InputEvent) -> void:

	if not is_active:
		return
	var advance : bool = false
	if event.is_action_pressed("interact"):
		advance = true
	elif event.is_action_pressed("ui_accept"):
		advance = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _pending_lines.is_empty():
		_close()
	else:
		_show_next_line()


func _show_next_line() -> void:

	if _pending_lines.is_empty():
		_close()
		return
	_body_label.text = _pending_lines.pop_front()
	_panel.visible = true


func _close() -> void:

	_panel.visible = false
	is_active = false
	_pending_lines.clear()


func _apply_dialog_style() -> void:

	_panel_style.bg_color = DIALOG_PANEL_COLOR
	_panel_style.border_color = DIALOG_BORDER
	_title_label.modulate = DIALOG_SPEAKER_COLOR
	_body_label.modulate = DIALOG_TEXT_COLOR
	_hint_label.modulate = DIALOG_TEXT_COLOR


func _apply_lore_style() -> void:

	_panel_style.bg_color = LORE_PANEL_COLOR
	_panel_style.border_color = LORE_BORDER
	_title_label.modulate = LORE_TITLE_COLOR
	_body_label.modulate = LORE_TEXT_COLOR
	_hint_label.modulate = LORE_TEXT_COLOR

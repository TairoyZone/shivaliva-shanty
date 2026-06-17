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
## Optional callback fired ONCE when the current dialog closes — lets a caller chain something after the lines
## (e.g. the gym intro hands off to the power-type picker). Captured + cleared on close so it never double-fires.
var _on_done : Callable = Callable()
## The typewriter (borrow #4): each line/body reveals char-by-char; an advance press first completes the
## reveal, then the next press advances. See [[godot-borrow-todo]].
const CHAR_TIME : float = 0.018
var _type_tween : Tween
var _typing : bool = false


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
	# Overlay is a PERSISTENT autoload that toggles a CHILD panel (not its own visibility), so pass an
	# is_open check (is_active) — else ESC would be swallowed in every scene. See [[esc-closes-every-window]].
	add_child(EscToClose.new(_close, func() -> bool: return is_active))


func show_dialog(speaker: String, lines: Array[String], on_done: Callable = Callable()) -> void:

	if lines.is_empty():
		if on_done.is_valid():
			on_done.call()   # nothing to say, but still fire the chain (e.g. straight to the picker)
		return
	_apply_dialog_style()
	_on_done = on_done
	_title_label.text = speaker
	_hint_label.text = "Tap to continue" if TouchEnv.is_touch() else "[E] / [Space] to continue"
	_pending_lines = lines.duplicate()
	_show_next_line()
	is_active = true


func show_lore(title: String, body: String) -> void:

	if body.is_empty() and title.is_empty():
		return
	_apply_lore_style()
	_title_label.text = title
	_hint_label.text = "Tap to close" if TouchEnv.is_touch() else "[E] to close"
	_pending_lines.clear()
	_on_done = Callable()   # lore never chains — clear any stale dialog callback
	_panel.visible = true
	is_active = true
	_type_line(body)


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
	if _typing:
		_finish_typing()   # first press completes the reveal; the next one advances/closes
		return
	if _pending_lines.is_empty():
		_close()
	else:
		_show_next_line()


func _show_next_line() -> void:

	if _pending_lines.is_empty():
		_close()
		return
	var line : String = _pending_lines.pop_front()
	# On the FINAL line E closes rather than continues — mirror show_lore's "[E] to close" hint.
	if _pending_lines.is_empty():
		_hint_label.text = "Tap to close" if TouchEnv.is_touch() else "[E] to close"
	_panel.visible = true
	_type_line(line)


## Reveal [param text] character-by-character (the typewriter). Stores the tween so an advance press can
## skip the reveal to full via [method _finish_typing].
func _type_line(text: String) -> void:

	Audio.play_sfx("voice", -3.0)   # a soft talk-synth blip per revealed line (borrowed lib)
	_body_label.text = text
	_body_label.visible_ratio = 0.0
	_typing = true
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	var dur : float = clampf(float(text.length()) * CHAR_TIME, 0.15, 2.5)
	_type_tween = create_tween()
	_type_tween.tween_property(_body_label, "visible_ratio", 1.0, dur)
	_type_tween.finished.connect(func() -> void: _typing = false)


## Snap the current reveal fully open (an advance press while still typing).
func _finish_typing() -> void:

	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_body_label.visible_ratio = 1.0
	_typing = false


func _close() -> void:

	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_typing = false
	_panel.visible = false
	is_active = false
	_pending_lines.clear()
	# Fire the one-shot completion callback (captured + cleared first, so a re-entrant show_dialog from it works).
	var done : Callable = _on_done
	_on_done = Callable()
	if done.is_valid():
		done.call()


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

## Modal — the reusable base for every centered pop-up modal (dim + centered panel + content + ESC + ModalFx
## pop-in/out + tree-pause capture/restore). Extracted 2026-06-09 (Operation Marie Kondo) from ~6 hand-rolled
## modals that each cloned this exact scaffolding — the inheritance-over-duplication law applied to UI.
##
## To make a modal: `extends Modal`, override `_build_content(content)` (build your UI into `_content`), and
## optionally the config hooks below. You get for free: the dim (LEFT-click to dismiss), the centered panel,
## ESC-to-close, the pop-in/out animation, and the pause. Close from anywhere via `_close()`; subclasses can
## listen to the `closed` signal. Set a unique `_modal_group()` to make the modal non-stacking (the subclass's
## own `static open(host)` then guards on it).
class_name Modal
extends CanvasLayer


signal closed

var _panel : PanelContainer
var _dim : ColorRect
var _content : VBoxContainer
var _was_paused : bool = false


# --- config hooks (override in the subclass) -------------------------

func _modal_layer() -> int:
	return 36

## A unique group name makes the modal non-stacking (paired with the subclass's static open() guard). "" = none.
func _modal_group() -> StringName:
	return &""

func _modal_dim_alpha() -> float:
	return 0.55

## The panel's full width × height (centered on screen).
func _modal_size() -> Vector2:
	return Vector2(460.0, 420.0)

func _modal_content_separation() -> int:
	return 10

## true → a vertical ScrollContainer (h-scroll off) wraps the content, for tall modals.
func _modal_scrollable() -> bool:
	return false

## false → the modal manages its OWN ESC (skip the standard EscToClose) — e.g. PauseMenu, which guards the
## Options sub-panel stacked over it.
func _modal_esc_to_close() -> bool:
	return true

func _modal_panel_style() -> StyleBoxFlat:
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.97)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(22)
	return s

## Build the modal's UI into [member _content]. Called once, after the scaffolding is up.
func _build_content() -> void:
	pass


# --- scaffolding (shared by every modal) -----------------------------

func _ready() -> void:

	layer = _modal_layer()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var g : StringName = _modal_group()
	if g != &"":
		add_to_group(g)
	_was_paused = get_tree().paused
	get_tree().paused = true

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, _modal_dim_alpha())
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)   # LEFT-click off the panel dismisses (a wheel notch must NOT)
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _modal_panel_style())
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sz : Vector2 = _modal_size()
	_panel.offset_left = -sz.x * 0.5
	_panel.offset_top = -sz.y * 0.5
	_panel.offset_right = sz.x * 0.5
	_panel.offset_bottom = sz.y * 0.5
	add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", _modal_content_separation())
	if _modal_scrollable():
		var scroll : ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_panel.add_child(scroll)
		var pad : MarginContainer = MarginContainer.new()   # keep the content clear of the vertical scrollbar
		pad.add_theme_constant_override("margin_right", 14)
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(pad)
		_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.add_child(_content)
	else:
		_panel.add_child(_content)

	if _modal_esc_to_close():
		add_child(EscToClose.new(_close))
	_build_content()
	ModalFx.appear(_panel, _dim)


func _on_dim_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_close()


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = _was_paused   # frees → restore the pause state we found


func _close() -> void:

	ModalFx.dismiss(self, _panel, _dim, _do_close)


func _do_close() -> void:

	closed.emit()
	queue_free()

## OptionsPanel — a small SETTINGS modal: toggle Music + Sound effects on/off. The toggles drive the Audio
## autoload (Audio.set_music_enabled / set_sfx_enabled), which applies them live AND persists to
## user://settings.cfg — so they're remembered next launch. Self-contained + self-freeing, on a high
## CanvasLayer + process-always so it works over the title OR an in-game/paused state. Open it with
## OptionsPanel.open(some_node). Won't stack. See the Audio autoload + [[godot-borrow-todo]].
class_name OptionsPanel
extends CanvasLayer

const GOLD : Color = Color(0.96, 0.86, 0.5, 1.0)
const GROUP : StringName = &"options_panel"


## Open the panel (added to the tree root). No-op if one is already showing.
static func open(host: Node) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	host.get_tree().root.add_child(OptionsPanel.new())


func _ready() -> void:

	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)

	# Dim backdrop — a click anywhere outside the panel closes.
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# Centred panel.
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -210.0
	panel.offset_top = -150.0
	panel.offset_right = 210.0
	panel.offset_bottom = 150.0
	add_child(panel)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title : Label = Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_toggle("Music", Audio.music_enabled, Audio.set_music_enabled))
	vbox.add_child(_make_toggle("Sound effects", Audio.sfx_enabled, Audio.set_sfx_enabled))
	vbox.add_child(_make_toggle("Show chat", ChatBox.chat_visible, ChatBox.set_chat_visible))

	var spacer : Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 10.0)
	vbox.add_child(spacer)

	var close : Button = Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 20)
	close.add_theme_color_override("font_color", GOLD)
	close.pressed.connect(_close)
	vbox.add_child(close)

	add_child(EscToClose.new(_close))


func _make_toggle(text: String, on: bool, setter: Callable) -> CheckButton:

	var cb : CheckButton = CheckButton.new()
	cb.text = text
	cb.button_pressed = on
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_size_override("font_size", 21)
	cb.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78, 1.0))
	cb.toggled.connect(func(pressed: bool) -> void: setter.call(pressed))
	return cb


func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.11, 0.06, 0.98)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(28)
	return s


func _on_dim_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:

	queue_free()

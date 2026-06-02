## The Journal — a Stardew-style quest log. Opened from the HUD journal
## button (or the J key); lists the player's current quests (from
## [method PlayerState.current_quests]) on a parchment panel, each with a
## status marker + detail. Pauses the tree while open (so the player can't
## wander off) and owns its own close input, mirroring the IntroOverlay /
## HiringBoard modal pattern.
##
## Lives as a hidden child of the [HUD]; toggle() shows/hides it and
## rebuilds the list from current progress each time it opens.
class_name JournalPanel
extends Control


## Parchment palette (matches the HiringBoard poster).
const COLOR_PARCHMENT : Color = Color(0.95, 0.88, 0.66, 1.0)
const COLOR_CARD : Color = Color(0.99, 0.94, 0.78, 1.0)
const COLOR_CARD_DONE : Color = Color(0.86, 0.82, 0.68, 1.0)
const COLOR_INK : Color = Color(0.30, 0.20, 0.08, 1.0)
const COLOR_INK_SOFT : Color = Color(0.42, 0.32, 0.18, 1.0)
const COLOR_INK_DONE : Color = Color(0.52, 0.47, 0.36, 1.0)
const COLOR_FRAME : Color = Color(0.52, 0.36, 0.16, 1.0)

var _list : VBoxContainer
var _open : bool = false


func _ready() -> void:

	# Cover the whole screen; eat clicks behind the panel; stay live while
	# the tree is paused so the buttons + close input still work.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_chrome()


func is_open() -> bool:

	return _open


func toggle() -> void:

	if _open:
		close()
	else:
		open()


func open() -> void:

	if _open:
		return
	_rebuild_list()
	visible = true
	_open = true
	get_tree().paused = true


func close() -> void:

	if not _open:
		return
	visible = false
	_open = false
	get_tree().paused = false


## Rebuild the list in place if the journal is currently open — lets the
## HUD reflect live gold/lumber progress while the player reads it.
func refresh_if_open() -> void:

	if _open:
		_rebuild_list()


func _unhandled_input(event: InputEvent) -> void:

	if not _open:
		return
	if event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J):
		close()
		get_viewport().set_input_as_handled()


# --- UI construction -------------------------------------------------

func _build_chrome() -> void:

	# Dimmer behind the panel.
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# Centered parchment panel.
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _parchment_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330.0
	panel.offset_top = -250.0
	panel.offset_right = 330.0
	panel.offset_bottom = 250.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Header row: title + close button.
	var header : HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)
	var title : Label = Label.new()
	title.text = "Objectives"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COLOR_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var close_btn : Button = _make_close_button()
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# Divider.
	var rule : ColorRect = ColorRect.new()
	rule.color = COLOR_FRAME
	rule.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(rule)

	# Scrollable quest list.
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func _rebuild_list() -> void:

	for child in _list.get_children():
		child.queue_free()
	var shown : int = 0
	for quest in PlayerState.current_quests():
		# Finished objectives drop off the log — show only what's still open.
		if bool(quest.get("done", false)):
			continue
		_list.add_child(_make_quest_card(quest))
		shown += 1
	if shown == 0:
		_list.add_child(_make_empty_notice())


# Shown when there's nothing open — keeps the panel from reading as broken
# and nudges the player toward the cozy side-content.
func _make_empty_notice() -> Control:

	var label : Label = Label.new()
	label.text = "All caught up!\n\nWander Cradle Rock and talk to the folk — some may ask a small favour."
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", COLOR_INK_SOFT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


func _make_quest_card(quest: Dictionary) -> Control:

	var done : bool = bool(quest.get("done", false))
	var card : PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(done))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	# Status marker.
	var marker : Label = Label.new()
	marker.text = "v" if done else "!"
	marker.add_theme_font_size_override("font_size", 24)
	marker.add_theme_color_override("font_color",
		Color(0.34, 0.62, 0.30, 1.0) if done else Color(0.86, 0.56, 0.14, 1.0))
	marker.custom_minimum_size = Vector2(26, 0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(marker)

	# Title + detail.
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title : Label = Label.new()
	title.text = String(quest.get("title", ""))
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", COLOR_INK_DONE if done else COLOR_INK)
	col.add_child(title)
	var detail : Label = Label.new()
	detail.text = String(quest.get("detail", ""))
	detail.add_theme_font_size_override("font_size", 15)
	detail.add_theme_color_override("font_color", COLOR_INK_DONE if done else COLOR_INK_SOFT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(detail)
	return card


func _parchment_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = COLOR_PARCHMENT
	s.border_color = COLOR_FRAME
	s.border_width_left = 4
	s.border_width_top = 4
	s.border_width_right = 4
	s.border_width_bottom = 4
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_right = 12
	s.corner_radius_bottom_left = 12
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 16
	s.content_margin_bottom = 18
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 10
	return s


func _card_style(done: bool) -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = COLOR_CARD_DONE if done else COLOR_CARD
	s.border_color = COLOR_FRAME
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_right = 8
	s.corner_radius_bottom_left = 8
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _make_close_button() -> Button:

	var btn : Button = Button.new()
	btn.text = "X"
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(40, 40)
	for state in ["normal", "hover", "pressed"]:
		var sb : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.74, 0.28, 0.20, 1.0)
		if state == "hover":
			bg = bg.lightened(0.12)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		sb.bg_color = bg
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_right = 8
		sb.corner_radius_bottom_left = 8
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color(1, 0.95, 0.9, 1))
	return btn
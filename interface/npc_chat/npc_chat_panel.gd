## NpcChatPanel — the free-form CHAT window with a cast member (THE unique hook). Opened from the NPC
## radial menu's "Chat" option. The player types; the NPC answers in character via [NpcBrain] (Claude
## Haiku, through the proxy). A scrolling transcript + a text input + Send / Leave; pauses the world while
## open and closes on ESC. On any chat failure it gracefully drops in one of the NPC's canned lines so the
## conversation never dead-ends. Built in code (placeholder-first, our convention); warm-brass styling to
## match the NPC menu. Mirrors the GodotNPCAI course's DialogueBox. See [NpcBrain] / [[chatbox-comms-reference]].
class_name NpcChatPanel
extends CanvasLayer

const GROUP : StringName = &"npc_chat"

var _persona : NpcPersonality = null
var _fallback_lines : Array = []

var _transcript : RichTextLabel
var _status : Label
var _input : LineEdit
var _send_btn : Button
var _panel : PanelContainer
var _dim : ColorRect


## Open the chat with [param persona]; [param fallback_lines] are the NPC's canned lines, used if a request
## fails so the NPC always says SOMETHING. No-op if a chat is already open or persona is null.
static func open(host: Node, persona: NpcPersonality, fallback_lines: Array = []) -> void:

	if host == null or host.get_tree() == null or persona == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	var p : NpcChatPanel = NpcChatPanel.new()
	p._persona = persona
	p._fallback_lines = fallback_lines
	host.get_tree().root.add_child(p)


func _ready() -> void:

	layer = 86   # above the NPC menu (85)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_build()
	get_tree().paused = true
	# Drive the conversation through the shared brain.
	NpcBrain.npc_replied.connect(_on_npc_replied)
	NpcBrain.chat_failed.connect(_on_chat_failed)
	NpcBrain.thinking_started.connect(_on_thinking)
	NpcBrain.enter_chat(_persona)
	NpcBrain.request_opening()
	add_child(EscToClose.new(_leave))
	ModalFx.appear(_panel, _dim)


func _build() -> void:

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -320.0
	_panel.offset_top = -230.0
	_panel.offset_right = 320.0
	_panel.offset_bottom = 230.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Header: a portrait disc + the NPC's name.
	var header : HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)
	var disc : Panel = Panel.new()
	var ds : StyleBoxFlat = StyleBoxFlat.new()
	ds.bg_color = _persona.portrait_color
	ds.border_color = Color(1, 1, 1, 0.85)
	ds.set_border_width_all(2)
	ds.set_corner_radius_all(20)
	disc.add_theme_stylebox_override("panel", ds)
	disc.custom_minimum_size = Vector2(40.0, 40.0)
	header.add_child(disc)
	var name_l : Label = Label.new()
	name_l.text = _persona.npc_name
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", Palette.GOLD_TEXT)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_l.add_theme_constant_override("outline_size", 4)
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name_l)

	# Transcript — a scrolling, word-wrapped log (player gold, NPC parchment).
	_transcript = RichTextLabel.new()
	_transcript.bbcode_enabled = true
	_transcript.scroll_following = true
	_transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transcript.custom_minimum_size = Vector2(600.0, 320.0)
	_transcript.add_theme_color_override("default_color", Palette.PARCHMENT)
	_transcript.add_theme_constant_override("line_separation", 3)
	var ts : StyleBoxFlat = StyleBoxFlat.new()
	ts.bg_color = Color(0.10, 0.07, 0.04, 0.55)
	ts.set_corner_radius_all(8)
	ts.set_content_margin_all(12)
	_transcript.add_theme_stylebox_override("normal", ts)
	vbox.add_child(_transcript)

	# A small status line ("… is thinking", or a hint).
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Palette.PARCHMENT_DIM)
	vbox.add_child(_status)

	# Input row: text field + Send + Leave.
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	_input = LineEdit.new()
	_input.placeholder_text = "Say something…"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_size_override("font_size", 16)
	_input.max_length = 280   # keep player input (and cost) bounded
	_input.text_submitted.connect(_on_submit)
	row.add_child(_input)
	_send_btn = _make_button("Send", Color(0.80, 1.0, 0.66, 1.0))
	_send_btn.pressed.connect(func() -> void: _on_submit(_input.text))
	row.add_child(_send_btn)
	var leave_btn : Button = _make_button("Leave", Color(0.95, 0.84, 0.56, 1.0))
	leave_btn.pressed.connect(_leave)
	row.add_child(leave_btn)

	_set_busy(true)   # the opening line is on its way


func _on_submit(text: String) -> void:

	var t : String = text.strip_edges()
	if t.is_empty() or NpcBrain.is_busy():
		return
	_append("You", t, Palette.GOLD_TEXT)
	_input.clear()
	NpcBrain.send(t)


func _on_thinking() -> void:

	_set_busy(true)
	_status.text = "%s is thinking…" % _short_name()


func _on_npc_replied(reply: String) -> void:

	_status.text = ""
	_append(_short_name(), reply, _persona.portrait_color.lightened(0.35))
	_set_busy(false)


# A request failed — keep the conversation alive with one of the NPC's canned lines (or a soft default),
# so the player never hits a dead end. (The proxy may be down / unconfigured.)
func _on_chat_failed(_reason: String) -> void:

	var line : String = "..."
	if not _fallback_lines.is_empty():
		line = String(_fallback_lines[randi() % _fallback_lines.size()])
	_append(_short_name(), line, _persona.portrait_color.lightened(0.35))
	_status.text = ""
	_set_busy(false)


func _append(speaker: String, text: String, color: Color) -> void:

	_transcript.append_text("[color=#%s][b]%s[/b][/color]  %s\n\n" % [color.to_html(false), speaker, text])


func _set_busy(busy: bool) -> void:

	if _send_btn != null:
		_send_btn.disabled = busy
	if _input != null:
		_input.editable = not busy
		if not busy:
			_input.grab_focus()


func _short_name() -> String:

	var parts : PackedStringArray = _persona.npc_name.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else _persona.npc_name


func _on_dim_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed:
		_leave()


func _leave() -> void:

	NpcBrain.end_chat()
	ModalFx.dismiss(self, _panel, _dim, _do_close)


func _do_close() -> void:

	if get_tree() != null:
		get_tree().paused = false
	queue_free()


func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.11, 0.06, 0.98)
	s.border_color = Palette.BRASS_FRAME
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(20)
	return s


func _make_button(text: String, fg: Color) -> Button:

	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	b.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.24, 0.16, 0.09, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		elif state == "disabled":
			bg = bg.darkened(0.30)
		sb.bg_color = bg
		sb.border_color = Palette.BRASS_FRAME if state != "disabled" else Color(0.5, 0.42, 0.3, 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		b.add_theme_stylebox_override(state, sb)
	return b

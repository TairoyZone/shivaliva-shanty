## THE CHAT BOX — a YPP-style speech bar + a persistent chat/event LOG (see [[chatbox-comms-reference]]).
## Autoloaded; shown in the walkable overworld (mirrors the HUD's visibility). You type at the bottom and
## your pirate SPEAKS (a floating [SpeechBubble]); every line — your chat AND game events (gold, plunder,
## holes, rank-ups: everything on [signal PlayerState.event_logged]) — is kept in a scrollable LOG you can
## toggle open ("logs are stored"). The transient [EventFeed] still streams the live one-liners; this is the
## stored history + the input. Single-player for now: modes = Speak / Emote / Think; the directed modes
## (Tell / Crew / Vessel) arrive with co-op (see [[multiplayer-direction]]) — build co-op-ready.
extends CanvasLayer

const SETTINGS_PATH : String = "user://settings.cfg"
const MAX_LOG_LINES : int = 120
const MODES : Array[String] = ["Speak", "Emote", "Think"]
const CHAT_COLOR : Color = Color(0.92, 0.95, 1.0, 1.0)

## User setting (persisted) — whether the chat bar + log show at all.
var chat_visible : bool = true

var _input : LineEdit
var _mode_btn : Button
var _log_panel : PanelContainer
var _log_box : VBoxContainer
var _log_scroll : ScrollContainer
var _mode : int = 0
var _log_open : bool = false


func _ready() -> void:

	layer = 12   # above the world, below the HUD (10? no — HUD is 10); sits with gameplay, hides in puzzles
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_settings()
	_build_ui()
	visible = false   # the _process mirror turns it on once a HUD-bearing scene is up
	PlayerState.event_logged.connect(_on_event_logged)


## True while the player is typing in the chat bar — game input (movement, click-to-interact, E/Esc)
## checks this and stands down so keystrokes go to the chat, not the world.
func is_typing() -> bool:

	return _input != null and _input.has_focus()


## Release the chat bar's focus — called when a HUD panel opens via a mouse click (which bypasses the
## keyboard is_typing() guards), so we never get stuck typing behind a modal with the world frozen.
func drop_focus() -> void:

	if _input != null and _input.has_focus():
		_input.release_focus()


func set_chat_visible(on: bool) -> void:

	chat_visible = on
	_save_settings()


# --- build ------------------------------------------------------------

func _build_ui() -> void:

	# The speech bar across the bottom: [mode] [ input ] [Send] [Log].
	var bar : PanelContainer = PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_top = -46.0
	bar.offset_bottom = -8.0
	bar.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.09, 0.13, 0.82)))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE   # the empty bar background must not eat world clicks
	add_child(bar)
	var hb : HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE   # only the actual controls (LineEdit/buttons) catch clicks
	bar.add_child(hb)

	_mode_btn = Button.new()
	_mode_btn.custom_minimum_size = Vector2(88.0, 0.0)
	_mode_btn.focus_mode = Control.FOCUS_NONE
	_mode_btn.text = MODES[_mode]
	_mode_btn.tooltip_text = "Chat mode — Speak / Emote / Think"
	_mode_btn.pressed.connect(_cycle_mode)
	hb.add_child(_mode_btn)

	_input = LineEdit.new()
	_input.placeholder_text = "Say something…   (Enter)"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.max_length = 200
	_input.text_submitted.connect(_on_submit)
	_input.gui_input.connect(_on_input_gui)
	hb.add_child(_input)

	var send : Button = Button.new()
	send.text = "Send"
	send.focus_mode = Control.FOCUS_NONE
	send.pressed.connect(_send_current)
	hb.add_child(send)

	var log_btn : Button = Button.new()
	log_btn.text = "Log"
	log_btn.custom_minimum_size = Vector2(50.0, 0.0)
	log_btn.focus_mode = Control.FOCUS_NONE
	log_btn.tooltip_text = "Toggle the chat + event history"
	log_btn.pressed.connect(_toggle_log)
	hb.add_child(log_btn)

	# The history panel, just above the bar (hidden until you open it).
	_log_panel = PanelContainer.new()
	_log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_panel.offset_left = 12.0
	_log_panel.offset_right = 12.0 + 444.0
	_log_panel.offset_top = -52.0 - 264.0
	_log_panel.offset_bottom = -52.0
	_log_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.07, 0.11, 0.9)))
	_log_panel.visible = false
	add_child(_log_panel)
	_log_scroll = ScrollContainer.new()
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_panel.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_constant_override("separation", 2)
	_log_scroll.add_child(_log_box)


func _panel_style(bg: Color) -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(0.62, 0.46, 0.20, 0.7)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s


# --- input ------------------------------------------------------------

# Enter (when not already typing) drops focus into the chat bar — but never over an open dialog/backpack.
func _unhandled_input(event: InputEvent) -> void:

	if not visible or is_typing():
		return
	if Overlay.is_active or (HUD != null and HUD.is_inventory_open()):
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if _input != null:
			_input.grab_focus()
		get_viewport().set_input_as_handled()


# Escape while typing bows out of the bar (without opening the backpack).
func _on_input_gui(event: InputEvent) -> void:

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _input != null:
			_input.release_focus()
		get_viewport().set_input_as_handled()


func _on_submit(text: String) -> void:

	_send(text)


func _send_current() -> void:

	if _input != null:
		_send(_input.text)


func _send(raw: String) -> void:

	var text : String = raw.strip_edges()
	if _input != null:
		_input.clear()
	if text.is_empty():
		return
	var bubble : String = text
	var line : String = ""
	match MODES[_mode]:
		"Emote":
			line = "You %s" % text
		"Think":
			bubble = "(%s)" % text
			line = "You think: %s" % text
		_:
			line = "You: %s" % text
	# Your pirate speaks it aloud (a floating bubble) when there's a player in the scene.
	var player : Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("speak"):
		player.speak(bubble)
	_append_log(line, CHAT_COLOR)
	if _input != null:
		_input.release_focus()   # back to the game so WASD moves again


func _cycle_mode() -> void:

	_mode = (_mode + 1) % MODES.size()
	if _mode_btn != null:
		_mode_btn.text = MODES[_mode]


func _toggle_log() -> void:

	_log_open = not _log_open
	if _log_panel != null:
		_log_panel.visible = _log_open
	if _log_open:
		_autoscroll()


# --- log --------------------------------------------------------------

func _on_event_logged(text: String, color: Color) -> void:

	_append_log(text, color)


func _append_log(text: String, color: Color) -> void:

	if _log_box == null:
		return
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_child(l)
	while _log_box.get_child_count() > MAX_LOG_LINES:
		var oldest : Node = _log_box.get_child(0)
		_log_box.remove_child(oldest)
		oldest.queue_free()
	_autoscroll()


func _autoscroll() -> void:

	if not _log_open or _log_scroll == null:
		return
	await get_tree().process_frame
	if is_instance_valid(_log_scroll):
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


# --- visibility + settings -------------------------------------------

# Mirror the HUD: chat shows in the walkable overworld, hides on the title + inside puzzles/voyage legs
# (the EventFeed still streams the live events there). Releasing focus when hidden frees game input.
func _process(_delta: float) -> void:

	var should : bool = chat_visible and HUD != null and HUD.visible
	if should != visible:
		visible = should
		if not visible and is_typing():
			_input.release_focus()
	# The open log shows the same lines as the transient EventFeed + shares the lower-left corner, so hide
	# the feed while the log is open (avoids the same line rendering twice).
	var feed_visible : bool = not (visible and _log_open)
	if EventFeed != null and EventFeed.visible != feed_visible:
		EventFeed.visible = feed_visible


func _load_settings() -> void:

	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		chat_visible = bool(cfg.get_value("chat", "visible", true))


func _save_settings() -> void:

	var cfg : ConfigFile = ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep the [audio] section Audio owns
	cfg.set_value("chat", "visible", chat_visible)
	cfg.save(SETTINGS_PATH)

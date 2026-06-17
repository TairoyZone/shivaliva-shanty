## THE CHAT BOX — a YPP-style speech bar + a persistent chat/event LOG (see [[chatbox-comms-reference]]).
## Autoloaded; shown in the walkable overworld (mirrors the HUD's visibility). You type at the bottom and
## your pirate SPEAKS (a floating [SpeechBubble]); every line — your chat AND game events (gold, plunder,
## holes, rank-ups: everything on [signal PlayerState.event_logged]) — is kept in a scrollable LOG you can
## toggle open. The transient [EventFeed] still streams the live one-liners; this is the stored history + input.
##
## PRIVATE NPC CHAT (the unique hook): an NPC's "Chat" routes a free-form, in-character AI conversation
## THROUGH this bar ([method start_private_chat]) — no separate window. While private, your typing goes to
## that NPC via [NpcBrain] (DeepSeek/Claude) and their replies log here + float above them; click the target
## chip to step away. (The old Speak/Emote/Think "chat mode" was removed — Troy 2026-06-07; no use for it.)
extends CanvasLayer

const SETTINGS_PATH : String = "user://settings.cfg"
const MAX_LOG_LINES : int = 120
const CHAT_COLOR : Color = Color(0.92, 0.95, 1.0, 1.0)         # your public speech
const PRIVATE_YOU_COLOR : Color = Color(0.78, 0.90, 1.0, 1.0)  # your line while privately chatting an NPC
const SYSTEM_LINE_COLOR : Color = Color(0.72, 0.75, 0.82, 1.0) # "— you begin / step away —" framing lines
## Chat segregation (Troy 2026-06-14): ONE colour for every NPC's speech (was per-NPC portrait colours = a
## rainbow), so the cast reads as one voice-class. The player's lines keep the cool blues above; the announcer
## (system / table events) keeps the gold log default. Warm coral — distinct from both the cool player + gold.
const NPC_CHAT_COLOR : Color = Color(0.99, 0.76, 0.64, 1.0)
## Suit inks for the Log's parchment: hearts/diamonds RED, spades/clubs near-BLACK. Now that the Log panel is
## light, black actually reads (it couldn't on the old dark walnut) — real playing-card colours (Troy 2026-06-14).
const SUIT_RED_HEX : String = "c4181b"
const SUIT_BLACK_HEX : String = "18181d"

## User setting (persisted) — whether the chat bar + log show at all.
var chat_visible : bool = true

var _input : LineEdit
var _scope_btn : Button        # the LEFT-side scope selector — "All" (the room) or "→ Name" (private)
var _scope_targets : Dictionary = {}   # scope-menu item id → the present Npc node
var _log_panel : PanelContainer
var _log_box : VBoxContainer
var _log_scroll : ScrollContainer
var _log_open : bool = false
var _bar : PanelContainer       # the summoned input bar — HIDDEN by default; Enter reveals it (the Minecraft /
var _bar_open : bool = false    # Valorant / Stardew model — Troy 2026-06-10). The fading idle log = the EventFeed.
var _chat_btn : Button = null   # touch only: a visible "Chat" button that summons the bar (no Enter key on a phone)

# Private NPC chat state (one conversation at a time; routed through this bar).
var _in_private : bool = false
var _private_persona : NpcPersonality = null
var _private_npc : Node = null          # the Npc node, for floating reply bubbles (may go invalid on scene change)
var _private_fallback : Array = []      # the NPC's canned lines — used if a request fails
var _npc_signals_connected : bool = false
var _last_scene : Node = null           # to end a private chat when the scene changes (the NPC node is freed)
var _has_npc_cached : bool = false       # is there an addressable NPC in THIS scene — computed once per scene (the
                                         # cast is static), not via a get_nodes_in_group query every frame (perf)


func _ready() -> void:

	layer = 22   # ON TOP of the HUD (10) + the puzzle Leave button (20) so the summoned bar is never hidden
	             # behind them (Troy 2026-06-10); still below tree-pausing modals (36+), which suppress the summon
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_settings()
	_build_ui()
	visible = false   # the _process mirror turns it on once a HUD-bearing scene is up
	PlayerState.event_logged.connect(_on_event_logged)


## True while the player is typing in the chat bar — game input (movement, click-to-interact, E/Esc)
## checks this and stands down so keystrokes go to the chat, not the world.
func is_typing() -> bool:

	return _input != null and _input.has_focus()


## True while the summoned chat bar (with its log) is up — so ESC dismisses it (and the HUD stands down on
## ESC rather than opening the backpack; see hud.gd).
func is_log_open() -> bool:

	return _bar_open


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
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)   # bottom-LEFT, same width as the log box (aligned)
	bar.offset_left = 14.0
	bar.offset_right = 634.0     # 620 wide — matches the log panel
	bar.offset_top = -58.0       # 48 tall — enough for the controls (was cramped at 38)
	bar.offset_bottom = -10.0
	bar.add_theme_stylebox_override("panel", _panel_style(Color(0.90, 0.84, 0.69, 0.95)))   # warm parchment (light: colored suits read)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE   # the empty bar background must not eat world clicks
	add_child(bar)
	_bar = bar
	bar.visible = false   # HIDDEN by default — Enter summons it (see _open_bar)
	_build_touch_chat_button()   # on touch, a visible button stands in for Enter-to-open (no keyboard on a phone)
	var hb : HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE   # only the actual controls (LineEdit/buttons) catch clicks
	bar.add_child(hb)

	# Scope selector (Valorant-style) on the LEFT: "All" = speak to the room, "→ Name" = a private word with an
	# NPC. Click it to pick who you're talking to (the room, or anyone present).
	_scope_btn = Button.new()
	_scope_btn.focus_mode = Control.FOCUS_NONE
	_scope_btn.custom_minimum_size = Vector2(80.0, 0.0)
	_scope_btn.tooltip_text = "Who you're talking to — All (the room) or a private word"
	_scope_btn.pressed.connect(_open_scope_menu)
	_style_chat_button(_scope_btn)
	hb.add_child(_scope_btn)
	_update_scope_chip()

	_input = LineEdit.new()
	# (Enter) is a keyboard hint — on touch you tap Send / tap outside to close, so drop it.
	_input.placeholder_text = "Say something…" if TouchEnv.is_touch() else "Say something…   (Enter)"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.max_length = 200
	_input.text_submitted.connect(_on_submit)
	_input.gui_input.connect(_on_input_gui)
	_style_chat_input(_input)
	hb.add_child(_input)

	var send : Button = Button.new()
	send.text = "Send"
	send.focus_mode = Control.FOCUS_NONE
	send.pressed.connect(_send_current)
	_style_chat_button(send)
	hb.add_child(send)

	var log_btn : Button = Button.new()
	log_btn.text = "Log"
	log_btn.custom_minimum_size = Vector2(50.0, 0.0)
	log_btn.focus_mode = Control.FOCUS_NONE
	log_btn.tooltip_text = "Toggle the chat + event history"
	log_btn.pressed.connect(_toggle_log)
	_style_chat_button(log_btn)
	hb.add_child(log_btn)

	# The history panel, just above the bar (hidden until you open it).
	_log_panel = PanelContainer.new()
	_log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_panel.offset_left = 14.0
	_log_panel.offset_right = 634.0           # match the bar's width
	_log_panel.offset_top = -62.0 - 260.0     # 260 tall, sitting just above the bar
	_log_panel.offset_bottom = -62.0
	_log_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.92, 0.86, 0.72, 0.97)))   # warm parchment
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
	s.border_color = _brass(0.6)   # lowkey brass rim (matches the NPC chat panel / menu family)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s


# Brass (the menu-family rim) at [param a] alpha — kept subtle so the persistent chat chrome stays lowkey.
func _brass(a: float) -> Color:

	return Color(Palette.BRASS_FRAME.r, Palette.BRASS_FRAME.g, Palette.BRASS_FRAME.b, a)


# Touch screens shrink the whole 1280×720 canvas to fit a phone, so chat text reads TINY. Bump every chat font
# (and the field/bar) on touch only — desktop stays exactly as tuned (Troy 2026-06-13).
func _chat_font(desktop: int, touch: int) -> int:

	return touch if TouchEnv.is_touch() else desktop


# A small warm-brass button (Send / Log / the private-chat target chip) — matches the NPC chat panel.
func _style_chat_button(btn: Button) -> void:

	btn.add_theme_font_size_override("font_size", _chat_font(14, 18))
	btn.add_theme_color_override("font_color", Color(0.95, 0.86, 0.58, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	btn.add_theme_constant_override("outline_size", 2)
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.22, 0.15, 0.08, 0.92)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		s.bg_color = bg
		s.border_color = _brass(0.7)
		s.set_border_width_all(1)
		s.set_corner_radius_all(7)
		s.content_margin_left = 10.0
		s.content_margin_right = 10.0
		s.content_margin_top = 4.0
		s.content_margin_bottom = 4.0
		btn.add_theme_stylebox_override(state, s)


# A subtly warm input field — dark walnut trough, faint brass rim that brightens on focus.
func _style_chat_input(le: LineEdit) -> void:

	le.add_theme_font_size_override("font_size", _chat_font(15, 23))
	if TouchEnv.is_touch():
		le.custom_minimum_size = Vector2(0.0, 40.0)   # a taller, tappable field for the bigger touch font
	le.add_theme_color_override("font_color", Color(0.20, 0.13, 0.06, 1.0))           # dark ink on parchment
	le.add_theme_color_override("font_placeholder_color", Color(0.42, 0.35, 0.24, 0.7))
	# A clear blinking insertion caret so you can see exactly where you're editing + fix typos (Troy 2026-06-14,
	# standard chat-field behaviour). Dark warm caret to read on the light parchment field.
	le.add_theme_color_override("caret_color", Color(0.32, 0.20, 0.08, 1.0))
	le.caret_blink = true
	le.caret_blink_interval = 0.5
	var normal : StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.83, 0.74, 0.57, 0.6)   # a slightly-inset lighter trough on the parchment bar
	normal.set_corner_radius_all(7)
	normal.set_border_width_all(1)
	normal.border_color = _brass(0.3)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	le.add_theme_stylebox_override("normal", normal)
	var focused : StyleBoxFlat = normal.duplicate()
	focused.border_color = _brass(0.75)
	le.add_theme_stylebox_override("focus", focused)


# --- input ------------------------------------------------------------

# Enter (when not already typing) drops focus into the chat bar — but never over an open dialog/backpack.
func _unhandled_input(event: InputEvent) -> void:

	# A click / tap OUTSIDE the open chat bar dismisses it — mobile has no Esc, and it's expected on desktop too
	# (Troy 2026-06-12). Checked BEFORE the is_typing early-return so it fires while the input is focused.
	if _bar_open and _is_outside_press(event):
		_close_bar()
		var vp0 : Viewport = get_viewport()
		if vp0 != null:
			vp0.set_input_as_handled()
		return
	if not visible or is_typing():
		return
	if Overlay.is_active or (HUD != null and HUD.is_inventory_open()):
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_open_bar()
		var vp : Viewport = get_viewport()
		if vp != null:
			vp.set_input_as_handled()


# A left-click / tap landing OUTSIDE the open bar + its log panel (clicking the world / the felt closes the chat).
func _is_outside_press(event: InputEvent) -> bool:

	var pos : Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	else:
		return false
	if _bar != null and _bar.visible and _bar.get_global_rect().has_point(pos):
		return false
	if _log_panel != null and _log_panel.visible and _log_panel.get_global_rect().has_point(pos):
		return false
	return true


# On a touch device there's no Enter key, so a visible "Chat" button summons the bar (Troy 2026-06-12). Shown
# only when the bar is closed (managed in _process); bottom-right, clear of the overworld joystick (bottom-left).
func _build_touch_chat_button() -> void:

	if not TouchEnv.is_touch():
		return
	_chat_btn = Button.new()
	_chat_btn.text = "Chat"
	_chat_btn.focus_mode = Control.FOCUS_NONE
	_chat_btn.custom_minimum_size = Vector2(96.0, 64.0)
	_chat_btn.add_theme_font_size_override("font_size", 22)
	# The standalone Chat button floats over the WORLD (not on the parchment bar), so it wears the central HUD
	# theme like the clock/rail — adapts light/dark. (The in-bar Send/Log keep _style_chat_button.)
	UiStyle.style_button(_chat_btn, Palette.ACCENT, Palette.CARD_BG, Palette.BORDER)
	_chat_btn.anchor_left = 1.0
	_chat_btn.anchor_right = 1.0
	_chat_btn.anchor_top = 1.0
	_chat_btn.anchor_bottom = 1.0
	_chat_btn.offset_right = -70.0
	_chat_btn.offset_left = -70.0 - 96.0
	_chat_btn.offset_bottom = -22.0
	_chat_btn.offset_top = -22.0 - 64.0
	_chat_btn.pressed.connect(_open_bar)
	_chat_btn.visible = false
	add_child(_chat_btn)


# Place the touch Chat button. A touch action puzzle whose HUD we moved to the bottom -> TOP-right corner (beside
# the score/status it vacated). An action puzzle that HASN'T swapped -> TOP-centre (clear of its top-corner HUD,
# beside Leave). Everything else -> flush BOTTOM-right corner (Troy 2026-06-12).
func _place_chat_button(action_puzzle: bool, swapped: bool) -> void:

	if _chat_btn == null:
		return
	if swapped:
		_chat_btn.anchor_left = 1.0
		_chat_btn.anchor_right = 1.0
		_chat_btn.anchor_top = 0.0
		_chat_btn.anchor_bottom = 0.0
		_chat_btn.offset_left = -18.0 - 96.0
		_chat_btn.offset_right = -18.0
		_chat_btn.offset_top = 16.0
		_chat_btn.offset_bottom = 16.0 + 64.0
	elif action_puzzle:
		# Un-swapped action puzzle -> Chat sits just RIGHT of centre and GROWS right, so it never meets the Leave
		# button on the left of centre (24px clear gap at the centre line), Troy 2026-06-13.
		_chat_btn.anchor_left = 0.5
		_chat_btn.anchor_right = 0.5
		_chat_btn.grow_horizontal = Control.GROW_DIRECTION_END
		_chat_btn.anchor_top = 0.0
		_chat_btn.anchor_bottom = 0.0
		_chat_btn.offset_left = 12.0
		_chat_btn.offset_right = 12.0 + 96.0
		_chat_btn.offset_top = 16.0
		_chat_btn.offset_bottom = 16.0 + 64.0
	else:
		_chat_btn.anchor_left = 1.0
		_chat_btn.anchor_right = 1.0
		_chat_btn.anchor_top = 1.0
		_chat_btn.anchor_bottom = 1.0
		_chat_btn.offset_left = -18.0 - 96.0
		_chat_btn.offset_right = -18.0
		_chat_btn.offset_top = -18.0 - 64.0
		_chat_btn.offset_bottom = -18.0


# Pin the Chat button to a named CORNER (a puzzle that overrides chat_button_corner()). Fixed 96x64 box, 18px
# inset from the chosen corner — independent of the action-puzzle/swap logic above.
func _place_chat_button_corner(corner: String) -> void:

	if _chat_btn == null:
		return
	const W : float = 96.0
	const H : float = 64.0
	const M : float = 18.0
	_chat_btn.grow_horizontal = Control.GROW_DIRECTION_END
	var left : bool = corner.ends_with("left")
	var top : bool = corner.begins_with("top")
	_chat_btn.anchor_left = 0.0 if left else 1.0
	_chat_btn.anchor_right = 0.0 if left else 1.0
	_chat_btn.anchor_top = 0.0 if top else 1.0
	_chat_btn.anchor_bottom = 0.0 if top else 1.0
	_chat_btn.offset_left = M if left else -M - W
	_chat_btn.offset_right = M + W if left else -M
	_chat_btn.offset_top = M if top else -M - H
	_chat_btn.offset_bottom = M + H if top else -M


# Summon the input bar + the recent log (Enter, or the start of a private chat). Focuses the field so you can
# type straight away.
func _open_bar() -> void:

	_bar_open = true
	if _bar != null:
		_bar.visible = true
	if not _log_open:
		_toggle_log()          # show the recent history alongside the input (the "Enter shows the log" beat)
	if TouchEnv.is_touch():
		_apply_kbd_layout(true)   # float the chat into the TOP half so the phone keyboard doesn't bury it
	if _input != null:
		_input.grab_focus()


# Dismiss the bar + the log back to the idle state (the fading EventFeed takes over). Send + Esc call this.
func _close_bar() -> void:

	_bar_open = false
	if _input != null:
		_input.release_focus()   # back to the game / puzzle
	if _log_open:
		_toggle_log()
	if _bar != null:
		_bar.visible = false
	if TouchEnv.is_touch():
		_apply_kbd_layout(false)   # back to the bottom-left


# TOUCH: while you're typing, the phone's virtual keyboard fills the bottom of the screen — so float the whole
# chat into the TOP half (log up top, input bar just above the keyboard line) instead of leaving it buried at the
# bottom where the keyboard hides it. Restored to the bottom-left when the bar closes (Troy 2026-06-13).
func _apply_kbd_layout(on: bool) -> void:

	if _bar == null or _log_panel == null:
		return
	if on:
		# This branch runs only on touch (gated in _open_bar): a TALLER full-width bar in the top half so the
		# bigger touch font + tappable field fit, with the log filling the space above it.
		_bar.anchor_left = 0.0
		_bar.anchor_right = 1.0
		_bar.anchor_top = 0.5
		_bar.anchor_bottom = 0.5
		_bar.offset_left = 14.0
		_bar.offset_right = -14.0
		_bar.offset_top = -84.0
		_bar.offset_bottom = -10.0
		_log_panel.anchor_left = 0.0
		_log_panel.anchor_right = 1.0
		_log_panel.anchor_top = 0.0
		_log_panel.anchor_bottom = 0.5
		_log_panel.offset_left = 14.0
		_log_panel.offset_right = -14.0
		_log_panel.offset_top = 14.0
		_log_panel.offset_bottom = -90.0
	else:
		_bar.anchor_left = 0.0
		_bar.anchor_right = 0.0
		_bar.anchor_top = 1.0
		_bar.anchor_bottom = 1.0
		_bar.offset_left = 14.0
		_bar.offset_right = 634.0
		_bar.offset_top = -58.0
		_bar.offset_bottom = -10.0
		_log_panel.anchor_left = 0.0
		_log_panel.anchor_right = 0.0
		_log_panel.anchor_top = 1.0
		_log_panel.anchor_bottom = 1.0
		_log_panel.offset_left = 14.0
		_log_panel.offset_right = 634.0
		_log_panel.offset_top = -322.0
		_log_panel.offset_bottom = -62.0


# Escape while typing dismisses the bar (without opening the backpack).
func _on_input_gui(event: InputEvent) -> void:

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_bar()
		var vp : Viewport = get_viewport()
		if vp != null:
			vp.set_input_as_handled()


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
	# DEV slash-commands (debug builds only): typed in the chat box — /crew, /gold, /holes, /mend, /wreck, /help.
	if text.begins_with("/") and OS.is_debug_build():
		DevCheats.run_command(text)
		_close_bar()
		return
	if _in_private:
		_send_private(text)
		return
	# Public speech — your pirate says it aloud (a floating bubble) + it lands in the feed + stored log
	# (same pipe as game events).
	var player : Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("speak"):
		player.speak(text)
	PlayerState.log_event("You: %s" % text, CHAT_COLOR)
	RoomChat.hear(text)   # ambient: NPCs present in the room may pipe up (the private path never reaches here)
	_close_bar()          # one public line sent → tuck the bar away (the line fades in the corner via EventFeed)


# --- private NPC chat (routed through this bar; see [NpcBrain]) --------

## Start a free-form AI conversation with [param persona], driven through this chat bar — the player's
## "Chat" option on an NPC calls this. [param npc] is the Npc node (for floating reply bubbles);
## [param fallback_lines] are its canned lines, used if a request fails. No-op off the walkable overworld.
func start_private_chat(persona: NpcPersonality, npc: Node = null, fallback_lines: Array = []) -> void:

	if persona == null or not visible:
		return
	_connect_npc_signals()
	_in_private = true
	_private_persona = persona
	_private_npc = npc
	_private_fallback = fallback_lines
	NpcBrain.enter_chat(persona)
	_update_scope_chip()
	# "again" once they remember you (saved history) — the persistence is felt right from the opening line.
	var verb : String = "pick your talk back up with" if NpcBrain.has_history() else "begin talking with"
	PlayerState.log_event("— You %s %s  (%s) —" % [verb, persona.npc_name,
		PlayerState.affinity_tier(persona.npc_name)], SYSTEM_LINE_COLOR)
	_open_bar()                    # summon the bar + show the conversation thread
	_set_thinking(true)
	NpcBrain.request_opening()


func _send_private(text: String) -> void:

	if NpcBrain.is_busy():
		return                     # still waiting on the last reply
	PlayerState.log_event("You → %s: %s" % [_short_name(), text], PRIVATE_YOU_COLOR)
	_set_thinking(true)
	NpcBrain.send(text)            # bar stays focused for the conversation


# Step out of the private chat, back to plain public speech.
func _exit_private() -> void:

	if not _in_private:
		return
	var who : String = _short_name()
	NpcBrain.end_chat()
	_in_private = false
	_private_persona = null
	_private_npc = null
	_private_fallback = []
	_update_scope_chip()
	if _input != null:
		_input.placeholder_text = "Say something…   (Enter)"
		_input.release_focus()
	PlayerState.log_event("— You step away from %s —" % who, SYSTEM_LINE_COLOR)


# --- scope selector (All the room / a private word with someone) -----

func _update_scope_chip() -> void:

	if _scope_btn == null:
		return
	if _in_private:
		_scope_btn.text = "→ %s  ▾" % _short_name()
		var col : Color = _private_persona.portrait_color.lightened(0.4) if _private_persona != null else Color(0.95, 0.86, 0.58, 1.0)
		_scope_btn.add_theme_color_override("font_color", col)
	else:
		_scope_btn.text = "All  ▾"
		_scope_btn.add_theme_color_override("font_color", Color(0.80, 0.95, 1.0, 1.0))   # cool = speak to the room


# Pop a small list ABOVE the chip: "All" (the room) + everyone present (a private word).
func _open_scope_menu() -> void:

	var menu : PopupMenu = PopupMenu.new()
	_style_popup(menu)
	menu.add_item("All — speak to the room", 0)
	_scope_targets = {}
	var idx : int = 1
	for n in get_tree().get_nodes_in_group("npc"):
		if not is_instance_valid(n) or not ("npc_name" in n):
			continue
		menu.add_item("→ %s   (private)" % String(n.npc_name), idx)
		_scope_targets[idx] = n
		idx += 1
	if idx == 1:
		menu.add_item("(no one nearby to whisper)", 99)
		menu.set_item_disabled(menu.get_item_index(99), true)
	menu.id_pressed.connect(_on_scope_picked)
	add_child(menu)
	# The bar sits at the screen bottom, so pop the menu ABOVE the chip (Godot clamps it on-screen anyway).
	var gp : Rect2 = _scope_btn.get_global_rect()
	var est_h : int = menu.get_item_count() * 30 + 14
	menu.position = Vector2i(int(gp.position.x), int(gp.position.y) - est_h)
	menu.popup()
	menu.popup_hide.connect(menu.queue_free)


func _on_scope_picked(id: int) -> void:

	if id == 0:
		_exit_private()   # back to All (the room)
		return
	var npc : Node = _scope_targets.get(id, null)
	if not is_instance_valid(npc):
		return
	if _in_private:
		_exit_private()   # leave the current conversation before opening a new one
	if npc.has_method("open_chat"):
		npc.open_chat()


func _style_popup(menu: PopupMenu) -> void:

	menu.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.11, 0.06, 0.97)))
	menu.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78, 1.0))
	menu.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1.0))
	menu.add_theme_color_override("font_disabled_color", Color(0.70, 0.66, 0.58, 0.7))
	menu.add_theme_font_size_override("font_size", _chat_font(15, 20))


func _connect_npc_signals() -> void:

	if _npc_signals_connected:
		return
	_npc_signals_connected = true
	NpcBrain.npc_replied.connect(_on_npc_replied)
	NpcBrain.chat_failed.connect(_on_npc_chat_failed)
	NpcBrain.thinking_started.connect(_on_npc_thinking)


func _on_npc_replied(reply: String) -> void:

	if not _in_private:
		return
	PlayerState.log_event("%s: %s" % [_short_name(), reply], NPC_CHAT_COLOR)
	if is_instance_valid(_private_npc):
		SpeechBubble.say(_private_npc, reply)
	_set_thinking(false)


# A request failed — keep the conversation alive with one of the NPC's canned lines so it never dead-ends.
func _on_npc_chat_failed(_reason: String) -> void:

	if not _in_private:
		return
	var line : String = String(_private_fallback[randi() % _private_fallback.size()]) if not _private_fallback.is_empty() else "..."
	PlayerState.log_event("%s: %s" % [_short_name(), line], NPC_CHAT_COLOR)
	if is_instance_valid(_private_npc):
		SpeechBubble.say(_private_npc, line)
	_set_thinking(false)


func _on_npc_thinking() -> void:

	if _in_private:
		_set_thinking(true)


func _set_thinking(thinking: bool) -> void:

	if _input == null:
		return
	_input.placeholder_text = ("%s is thinking…" % _short_name()) if thinking else ("Message %s…   (Enter)" % _short_name())


func _short_name() -> String:

	if _private_persona == null:
		return "them"
	var parts : PackedStringArray = _private_persona.npc_name.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else _private_persona.npc_name


func _toggle_log() -> void:

	_log_open = not _log_open
	if _log_panel != null:
		_log_panel.visible = _log_open
	if _log_open:
		_autoscroll()


## Dismiss the chat bar if up (ESC from the HUD calls this before falling through to the pause menu).
func close_log() -> void:

	if _bar_open:
		_close_bar()


# --- log --------------------------------------------------------------

func _on_event_logged(text: String, color: Color) -> void:

	_append_log(text, color)


func _append_log(text: String, color: Color) -> void:

	if _log_box == null:
		return
	# RichTextLabel (not a plain Label) so suit glyphs get real card colours within the line (Troy 2026-06-14).
	# The line's ink is a DARK, hue-preserving version of the event colour — readable on the parchment Log, while
	# the over-game EventFeed keeps the original light colour (the two are decoupled).
	var l : RichTextLabel = RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("normal_font_size", _chat_font(14, 19))
	l.text = _log_bbcode(text, _parchment_ink(color))
	_log_box.add_child(l)
	while _log_box.get_child_count() > MAX_LOG_LINES:
		var oldest : Node = _log_box.get_child(0)
		_log_box.remove_child(oldest)
		oldest.queue_free()
	_autoscroll()


# Hand-tuned dark inks per speaker bucket — readable AND clearly distinct on the parchment Log. (Deriving from the
# near-white player colour came out muddy, so map the known buckets to explicit inks; anything else = announcer.)
func _parchment_ink(c: Color) -> Color:

	if _ink_near(c, CHAT_COLOR) or _ink_near(c, PRIVATE_YOU_COLOR):
		return Color(0.13, 0.31, 0.66)   # YOU — deep blue (cool, clearly "you")
	if _ink_near(c, NPC_CHAT_COLOR):
		return Color(0.63, 0.26, 0.08)   # NPCs — warm sienna (the cast)
	if _ink_near(c, SYSTEM_LINE_COLOR):
		return Color(0.45, 0.41, 0.33)   # framing lines — muted brown-grey
	return Color(0.42, 0.33, 0.13)       # announcer / system events — dark olive-bronze


func _ink_near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.10


# Wrap a Log line in BBCode: the whole line in its ink, with suit glyphs overridden to real card colours
# (hearts/diamonds red, spades/clubs near-black). Literal "[" is escaped so stray brackets can't break parsing.
func _log_bbcode(text: String, ink: Color) -> String:

	var t : String = text.replace("[", "[lb]")
	t = t.replace("♥", "[color=#%s]♥[/color]" % SUIT_RED_HEX).replace("♦", "[color=#%s]♦[/color]" % SUIT_RED_HEX)
	t = t.replace("♠", "[color=#%s]♠[/color]" % SUIT_BLACK_HEX).replace("♣", "[color=#%s]♣[/color]" % SUIT_BLACK_HEX)
	return "[color=#%s]%s[/color]" % [ink.to_html(false), t]


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

	# Shows in the walkable overworld (mirrors the HUD) AND in any scene that opts in via the "chat_scene"
	# group (e.g. the poker table — a PuzzleScene where the HUD is hidden but we still want table banter).
	var sc : Node = get_tree().current_scene if get_tree() != null else null
	# Handle a scene change FIRST so the per-scene state (the addressable-NPC cache + the chat-button placement) is
	# fresh before we decide visibility. End a private chat on ANY scene change — the NPC node (e.g. a poker seat)
	# is freed by the swap, so the conversation can't continue (covers poker → overworld).
	if sc != _last_scene:
		_last_scene = sc
		_has_npc_cached = _has_addressable_npc()   # the cast is STATIC per scene — query once here, not every frame
		if _in_private:
			_exit_private()
		# Chat by scene: a touch action puzzle whose HUD we centred at the top -> TOP-right corner; an action
		# puzzle that hasn't swapped yet -> top-centre; else the flush bottom-right corner (Troy 2026-06-12).
		var action_puzzle : bool = sc is PuzzleScene and sc.has_method("_has_touch_bar") and bool(sc.call("_has_touch_bar"))
		var hud_swapped : bool = sc is PuzzleScene and sc.has_method("touch_hud_swapped") and bool(sc.call("touch_hud_swapped"))
		# A puzzle may FORCE the Chat button into a specific corner (Patchworks wants bottom-left, Troy 2026-06-17);
		# otherwise fall back to the action-puzzle/swapped placement above.
		var forced_corner : String = String(sc.call("chat_button_corner")) if (sc is PuzzleScene and sc.has_method("chat_button_corner")) else ""
		if forced_corner != "":
			_place_chat_button_corner(forced_corner)
		else:
			_place_chat_button(action_puzzle, hud_swapped)
	# UNIVERSAL now: chat is available in EVERY gameplay scene — the overworld AND every puzzle/voyage — hidden
	# by default; only the title has no chat (Troy 2026-06-10, the Minecraft/Stardew/Valorant model).
	# On TOUCH the Chat button rides EVERY non-title scene (so it's always one tap away — and ready for co-op
	# chat later, even where no NPC stands), Troy 2026-06-12. On desktop it stays NPC-gated (no dead bar).
	# Order the cheap, cached TouchEnv.is_touch() BEFORE the cached NPC check (both O(1) now).
	var should : bool = chat_visible and sc != null and not _is_title(sc) and (_in_private or TouchEnv.is_touch() or _has_npc_cached)
	if should != visible:
		visible = should
		if not visible:
			_close_bar()   # left for the title — tuck everything away
	if _in_private and not visible:
		_exit_private()
	# The fading idle LOG is the EventFeed (shows everywhere, lingers ~8s then fades — the Minecraft/Stardew
	# corner). Hide it only while the bar's OPEN (the scrollable history shows the same lines then).
	var feed_visible : bool = not _bar_open
	if EventFeed != null and EventFeed.visible != feed_visible:
		EventFeed.visible = feed_visible
	if _chat_btn != null:
		_chat_btn.visible = not _bar_open   # the touch "Chat" button shows whenever the bar is tucked away


# Is there anyone in the scene to actually talk to? Keeps the chat bar from showing a dead "speak" affordance
# in the empty outdoor overworld (shore/forest/mine/Driftspar) where no Npc is placed (Troy 2026-06-12).
func _has_addressable_npc() -> bool:

	if get_tree() == null:
		return false
	for n in get_tree().get_nodes_in_group("npc"):
		if is_instance_valid(n) and ("npc_name" in n):
			return true
	return false


# The title screen (main.tscn) is the one scene with no chat — everything else is gameplay.
func _is_title(sc: Node) -> bool:

	return sc != null and sc.scene_file_path.ends_with("main.tscn")


func _load_settings() -> void:

	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		chat_visible = bool(cfg.get_value("chat", "visible", true))


func _save_settings() -> void:

	var cfg : ConfigFile = ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep the [audio] section Audio owns
	cfg.set_value("chat", "visible", chat_visible)
	cfg.save(SETTINGS_PATH)

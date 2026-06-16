## Title screen + main menu. Offers Continue (only when a saved session
## exists), New Game (confirms before overwriting a save), and Quit. The
## HUD is hidden here — it belongs to gameplay (BaseLocation re-shows it).
extends Control


## First scene of a fresh game — the player's shanty (shows the one-time
## IntroOverlay there).
const FIRST_SCENE : String = "res://levels/player_shanty_interior/player_shanty_interior.tscn"

@onready var _title : Label = $Title
@onready var _subtitle : Label = $Subtitle

## The overwrite-confirm / name-prompt overlay while it's up (guards against stacking).
var _confirm : CanvasLayer = null
## The New Game name field (lives inside the name-prompt overlay).
var _name_edit : LineEdit = null
## The "Set sail" button — disabled until the name is valid (required + not already taken).
var _set_sail_btn : Button = null
## A small validation line under the name field (e.g. "that name's taken").
var _name_hint : Label = null
## The New Game gender pick ("Male" / "Female" / "Other"), chosen beside the name (identity now; cosmetics post-MVP).
var _chosen_gender : String = "Other"


func _ready() -> void:

	# The HUD is a gameplay element — keep it off the title.
	if HUD:
		HUD.visible = false
	Audio.play_music_track("title", -16.0)   # the chiptune title theme (Juhani Junkala, CC0) — toned down (Troy: too loud)
	# Living procedural sky behind the menu (drifting isles + stardust). Sits over the flat
	# fallback bg, beneath the title/buttons.
	var backdrop : MenuBackdrop = MenuBackdrop.new()
	add_child(backdrop)
	move_child(backdrop, 1)
	_style_title()
	_build_menu()


func _style_title() -> void:

	_title.text = "Shivaliva Shanty"
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.95))
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 5)

	_subtitle.text = "Sail the Stardust, sing your shanty, make your name."
	_subtitle.add_theme_font_size_override("font_size", 21)
	_subtitle.add_theme_color_override("font_color", Color(0.74, 0.82, 0.96, 0.95))
	_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_subtitle.add_theme_constant_override("outline_size", 3)


func _build_menu() -> void:

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -150.0
	vbox.offset_top = 18.0
	vbox.offset_right = 150.0
	vbox.offset_bottom = 280.0
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(vbox)

	# Continue — only when there's a restorable session.
	if PlayerState.has_resumable_session():
		var cont : Button = _make_button("Continue", Color(0.80, 1.0, 0.64, 1.0))
		cont.pressed.connect(_on_continue)
		vbox.add_child(cont)

	var new_game : Button = _make_button("New Game", Color(0.96, 0.86, 0.5, 1.0))
	new_game.pressed.connect(_on_new_game)
	vbox.add_child(new_game)

	var options : Button = _make_button("Options", Color(0.74, 0.82, 0.96, 1.0))
	options.pressed.connect(func() -> void: OptionsPanel.open(self))
	vbox.add_child(options)

	var quit : Button = _make_button("Quit", Color(0.92, 0.72, 0.62, 1.0))
	quit.pressed.connect(_on_quit)
	quit.visible = not OS.has_feature("web")   # a browser tab can't quit itself — hide it on web
	vbox.add_child(quit)


func _on_continue() -> void:

	# The ship deck is NEVER a valid resume target: voyage state is transient (never saved), so resuming
	# onto the deck would fabricate a phantom demo voyage (the deck's standalone seeder). Close-the-app
	# mid-voyage makes this reachable — fall back to the home shore, fresh-spawned. (Troy 2026-06-10 review.)
	var scene : String = PlayerState.last_scene
	# Fall back to the home shore when there's no valid resume target: empty, the transient ship deck (see
	# above), OR a scene that no longer exists (e.g. renamed/removed since the save — never crash Continue).
	if scene.is_empty() or scene.find("ship_deck") != -1 or not ResourceLoader.exists(scene):
		get_tree().change_scene_to_file("res://levels/shore/shore.tscn")
		return
	PlayerState.request_spawn_at_position(PlayerState.last_position)
	get_tree().change_scene_to_file(scene)


func _on_new_game() -> void:

	# A fresh start wipes the existing save — confirm first if there is one.
	if PlayerState.has_resumable_session():
		_show_overwrite_confirm()
	else:
		_start_new_game()


func _start_new_game() -> void:

	# Name yourself first — the cast remembers it for the whole game (Troy 2026-06-10).
	_close_confirm()           # drop the overwrite confirm if that's the path here
	_show_name_prompt()


# Pop the "what do they call you?" field, then begin the named game.
func _show_name_prompt() -> void:

	if is_instance_valid(_confirm):
		return
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 40
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -120.0
	panel.offset_right = 280.0
	panel.offset_bottom = 120.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	var msg : Label = Label.new()
	msg.text = "What do they call you?"
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", Color(0.98, 0.90, 0.6, 1.0))
	msg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	msg.add_theme_constant_override("outline_size", 3)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)
	var sub : Label = Label.new()
	sub.text = "The folk of Cradle Rock will remember your name."
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.82, 0.74, 0.56, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(sub)
	var edit : LineEdit = LineEdit.new()
	edit.placeholder_text = "your name…"
	edit.max_length = 20
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_size_override("font_size", 22)
	edit.custom_minimum_size = Vector2(0, 46)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(_t: String) -> void: _begin_from_edit())   # Enter submits
	edit.text_changed.connect(func(_t: String) -> void: _refresh_name_validity())
	# Field + a dice button to roll a random UNUSED name (for players who'd rather not type one).
	var name_row : HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(edit)
	var dice : Button = _make_button("", Color(0.92, 0.86, 0.66, 1.0))
	dice.custom_minimum_size = Vector2(56, 46)
	dice.tooltip_text = "Roll a random name"
	dice.pressed.connect(_roll_name)
	var die_icon : DieIcon = DieIcon.new()   # procedural die face (the font has no die glyph)
	die_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	die_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice.add_child(die_icon)
	name_row.add_child(dice)
	vbox.add_child(name_row)
	_name_edit = edit
	# Validation line (a name is REQUIRED + must be unused — empty/taken disables "Set sail").
	var hint : Label = Label.new()
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.96, 0.62, 0.5, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(hint)
	_name_hint = hint
	# Gender pick (identity now; full character cosmetics post-MVP). A 3-way radio — defaults to Other so there's
	# always a value, and any romanceable NPC is open to any player regardless (orientation-agnostic).
	var glabel : Label = Label.new()
	glabel.text = "And you are…"
	glabel.add_theme_font_size_override("font_size", 15)
	glabel.add_theme_color_override("font_color", Color(0.82, 0.74, 0.56, 1.0))
	glabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(glabel)
	var grow : HBoxContainer = HBoxContainer.new()
	grow.alignment = BoxContainer.ALIGNMENT_CENTER
	grow.add_theme_constant_override("separation", 10)
	var ggroup : ButtonGroup = ButtonGroup.new()
	for g in ["Male", "Female", "Other"]:
		var gb : Button = _make_button(g, Color(0.92, 0.86, 0.66, 1.0))
		gb.toggle_mode = true
		gb.button_group = ggroup
		gb.button_pressed = (g == _chosen_gender)
		gb.toggled.connect(_on_gender_toggled.bind(g))
		grow.add_child(gb)
	vbox.add_child(grow)
	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)
	var go : Button = _make_button("Set sail", Color(0.80, 1.0, 0.66, 1.0))
	go.pressed.connect(_begin_from_edit)
	row.add_child(go)
	_set_sail_btn = go
	_confirm = layer
	add_child(layer)
	_refresh_name_validity()   # start disabled — a name is required before you can sail
	edit.grab_focus()


# Names already claimed in the shared world — the single source the dice + the validator both read. The NPC cast
# now; once online/co-op lands, the server's registered player names fold into THIS list so cross-player
# uniqueness is enforced through the same path (Troy 2026-06-13: names must be unique for online/co-op).
func _taken_names() -> Array:

	var taken : Array = []
	for p in NpcRegistry.all():
		taken.append(p.npc_name)
	return taken


# Roll a random unused name into the field (excluding the cast + the current entry, so a re-roll always changes).
func _roll_name() -> void:

	if not is_instance_valid(_name_edit):
		return
	var taken : Array = _taken_names()
	if not _name_edit.text.strip_edges().is_empty():
		taken.append(_name_edit.text)
	_name_edit.text = RandomName.roll(taken)
	_refresh_name_validity()


# A name is REQUIRED and must be unused: enable "Set sail" only when valid, and explain when it isn't.
func _refresh_name_validity() -> void:

	if not is_instance_valid(_name_edit) or not is_instance_valid(_set_sail_btn):
		return
	var raw : String = _name_edit.text.strip_edges()
	var valid : bool = RandomName.is_available(raw, _taken_names())
	_set_sail_btn.disabled = not valid
	_set_sail_btn.modulate = Color(1, 1, 1, 1) if valid else Color(1, 1, 1, 0.45)
	if is_instance_valid(_name_hint):
		if raw.is_empty():
			_name_hint.text = ""
		elif not valid:
			_name_hint.text = "That name's already taken — pick another or roll one."
		else:
			_name_hint.text = ""


func _begin_from_edit() -> void:

	if not is_instance_valid(_name_edit):
		return
	var entered : String = _name_edit.text.strip_edges()
	# A name is REQUIRED + must be unused. If not, stay on the prompt and say why (covers Enter, which
	# bypasses the disabled button).
	if not RandomName.is_available(entered, _taken_names()):
		_refresh_name_validity()
		_name_edit.grab_focus()
		return
	_begin_named_game(entered)


func _on_gender_toggled(toggled_on: bool, g: String) -> void:

	if toggled_on:
		_chosen_gender = g


func _begin_named_game(chosen_name: String) -> void:

	_close_confirm()
	_name_edit = null
	PlayerState.clear_save()
	PlayerState.set_player_name(chosen_name)   # persisted — the cast remembers it all game
	PlayerState.set_player_gender(_chosen_gender)
	get_tree().change_scene_to_file(FIRST_SCENE)


func _on_quit() -> void:

	if OS.has_feature("web"):
		return   # no-op on web (button is hidden there); get_tree().quit() just freezes the canvas
	get_tree().quit()


# --- Overwrite confirm -----------------------------------------------

func _show_overwrite_confirm() -> void:

	if is_instance_valid(_confirm):
		return
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 40
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260.0
	panel.offset_top = -110.0
	panel.offset_right = 260.0
	panel.offset_bottom = 110.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	var msg : Label = Label.new()
	msg.text = "Start a new game?\nThis erases your current saved progress."
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(0.95, 0.86, 0.6, 1.0))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(msg)
	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	vbox.add_child(row)
	var confirm_btn : Button = _make_button("Start Over", Color(1.0, 0.7, 0.5, 1.0))
	confirm_btn.pressed.connect(_start_new_game)
	row.add_child(confirm_btn)
	var cancel_btn : Button = _make_button("Cancel", Color(0.95, 0.86, 0.56, 1.0))
	cancel_btn.pressed.connect(_close_confirm)
	row.add_child(cancel_btn)
	_confirm = layer
	add_child(layer)


func _close_confirm() -> void:

	if is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = null
	_name_edit = null
	_set_sail_btn = null
	_name_hint = null


# --- Styling ---------------------------------------------------------

func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.97)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 24
	s.content_margin_bottom = 24
	return s


func _make_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(260, 0)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed"]:
		var sb : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.20, 0.13, 0.07, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		sb.bg_color = bg
		sb.border_color = Color(0.78, 0.58, 0.24, 1.0)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_right = 10
		sb.corner_radius_bottom_left = 10
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override(state, sb)
	return btn

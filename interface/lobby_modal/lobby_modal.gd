## The parlor LOBBY modal — opened by a parlor table when the player
## interacts, BEFORE the puzzle scene loads. Two modes:
##  • HOST ("host") — the player hosts: pick table size + Free/Cash, and
##    the cast fills in (rapport-weighted, see [method NpcRegistry.pick_for_lobby]).
##  • JOIN ("join") — an NPC is already hosting a game here; the player can
##    take the open seat (gated by rapport with the host) or "Start your own"
##    (which flips this modal to host mode — never a dead end).
## On confirm it emits [signal confirmed] with the seated NPCs' resource
## paths + the free flag; the table stashes those in [PlayerState] and
## launches. Styling clones the [HiringBoard] modal. See [[parlor-social-system]].
class_name LobbyModal
extends CanvasLayer


## Emitted on Sit/Join. seated_paths = chosen NPC profile paths; free_table = toggle.
signal confirmed(seated_paths: Array, free_table: bool)
## Emitted on Leave / backing out.
signal cancelled


# Host config.
var _game_name : String = "Game"
var _min_seats : int = 2
var _max_seats : int = 2
var _seats : int = 2
var _affinity_of : Callable = Callable()
var _cash_cost : int = 0
var _cash_note : String = ""
var _exclude : Array[NpcPersonality] = []
# Join config.
var _mode : String = "host"
var _host_name : String = ""
var _host_color : Color = Color(0.95, 0.84, 0.56, 1.0)
var _join_profiles : Array[NpcPersonality] = []
var _can_join : bool = true

var _free : bool = false
var _cash_locked_out : bool = false
var _seated : Array[NpcPersonality] = []
## Manual-invite (Mode B) host sub-state: invite specific NPCs who accept
## or decline by rapport, instead of letting folks auto-join.
var _invite_only : bool = false
var _invited : Array[NpcPersonality] = []
var _picker_msg : String = ""

var _content : VBoxContainer
var _chip_row : HBoxContainer
var _seats_label : Label
var _stake_label : Label


static func create(config: Dictionary) -> LobbyModal:

	var modal : LobbyModal = LobbyModal.new()
	modal._mode = String(config.get("mode", "host"))
	modal._game_name = String(config.get("game_name", "Game"))
	modal._min_seats = int(config.get("min_seats", 2))
	modal._max_seats = int(config.get("max_seats", 2))
	modal._seats = clampi(int(config.get("default_seats", modal._max_seats)),
		modal._min_seats, modal._max_seats)
	modal._affinity_of = config.get("affinity_of", Callable())
	modal._cash_cost = int(config.get("cash_cost", 0))
	modal._cash_note = String(config.get("cash_note", ""))
	modal._exclude = _typed_profiles(config.get("exclude", []))
	modal._host_name = String(config.get("host_name", ""))
	modal._host_color = config.get("host_color", Color(0.95, 0.84, 0.56, 1.0))
	modal._join_profiles = _typed_profiles(config.get("join_profiles", []))
	modal._can_join = bool(config.get("can_join", true))
	return modal


## Load NPC profiles from a list of resource paths (e.g.
## [member PlayerState.lobby_seated_paths]). Shared by the table props
## (exclude list) and the parlor scenes (seating). Skips unloadable paths.
static func profiles_from_paths(paths: Array) -> Array[NpcPersonality]:

	var out : Array[NpcPersonality] = []
	for p in paths:
		var prof : NpcPersonality = load(String(p)) as NpcPersonality
		if prof != null:
			out.append(prof)
	return out


static func _typed_profiles(arr: Array) -> Array[NpcPersonality]:

	var out : Array[NpcPersonality] = []
	for e in arr:
		if e is NpcPersonality:
			out.append(e)
	return out


func _ready() -> void:

	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _cash_cost > 0 and PlayerState.total_coins < _cash_cost:
		_free = true
		_cash_locked_out = true
	_build_chrome()
	_render()
	get_tree().paused = true


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false


# --- Build -------------------------------------------------------------

# Dimmer + walnut panel + the (rebuildable) content vbox — built ONCE.
func _build_chrome() -> void:

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -310.0
	panel.offset_top = -220.0
	panel.offset_right = 310.0
	panel.offset_bottom = 220.0
	add_child(panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	panel.add_child(_content)


# (Re)build the panel content for the current mode. Called on open AND when
# "Start your own" flips a join lobby to host mode IN PLACE — so the modal
# is never freed+reopened, and the paused tree never changes hands.
func _render() -> void:

	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	# Cached refs point at the just-freed nodes — drop them so a mode that
	# doesn't rebuild one (e.g. the picker has no stake label) can't touch it.
	_chip_row = null
	_seats_label = null
	_stake_label = null
	if _mode == "join":
		_seated = _join_profiles
		_build_join_ui()
	elif _mode == "picker":
		_build_picker_ui()
	else:
		_build_host_ui()
		if not _invite_only:
			_roll_seats()
	_refresh_stake_label()


func _build_host_ui() -> void:

	var vbox : VBoxContainer = _content
	vbox.add_child(_make_title("%s — HOST A TABLE" % _game_name.to_upper()))
	vbox.add_child(_make_caption("Your guest list" if _invite_only else "Joining you"))
	_chip_row = _make_chip_row()
	vbox.add_child(_chip_row)
	if _invite_only:
		_refresh_invite_slots()
	# Open ↔ Invite-only.
	var toggle_btn : Button = _make_walnut_button(
		"Let folks join instead" if _invite_only else "Invite only  ▸",
		Color(0.82, 0.88, 1.0, 1.0))
	toggle_btn.pressed.connect(_on_toggle_invite)
	vbox.add_child(toggle_btn)
	# Seats stepper — Open mode only (invite-only fills up to the max).
	if not _invite_only and _max_seats > _min_seats:
		var seat_row : HBoxContainer = HBoxContainer.new()
		seat_row.add_theme_constant_override("separation", 14)
		seat_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(seat_row)
		var minus : Button = _make_walnut_button("–", Color(0.95, 0.84, 0.56, 1.0))
		minus.pressed.connect(_on_seats_delta.bind(-1))
		seat_row.add_child(minus)
		_seats_label = Label.new()
		_seats_label.add_theme_font_size_override("font_size", 20)
		_seats_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66, 1.0))
		_seats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_seats_label.custom_minimum_size = Vector2(150.0, 0.0)
		seat_row.add_child(_seats_label)
		var plus : Button = _make_walnut_button("+", Color(0.95, 0.84, 0.56, 1.0))
		plus.pressed.connect(_on_seats_delta.bind(1))
		seat_row.add_child(plus)
		_refresh_seats_label()
	_add_stake_toggle(vbox)
	var hbox : HBoxContainer = _make_button_row()
	vbox.add_child(hbox)
	var sit_btn : Button = _make_walnut_button("Sit down  ▸", Color(0.78, 1.0, 0.62, 1.0))
	sit_btn.disabled = _invite_only and _invited.is_empty()
	sit_btn.pressed.connect(_on_sit)
	hbox.add_child(sit_btn)
	var leave_btn : Button = _make_walnut_button("Leave", Color(0.95, 0.84, 0.56, 1.0))
	leave_btn.pressed.connect(_on_cancel)
	hbox.add_child(leave_btn)


# Invite-only chip row: a chip per accepted guest + a "+ Invite" button for
# each still-empty seat (up to max_seats - 1 opponents).
func _refresh_invite_slots() -> void:

	if _chip_row == null:
		return
	for child in _chip_row.get_children():
		_chip_row.remove_child(child)
		child.queue_free()
	var slots : int = maxi(_max_seats - 1, 1)
	for i in slots:
		if i < _invited.size():
			_chip_row.add_child(_make_chip(_invited[i]))
		else:
			var inv : Button = _make_walnut_button("+ Invite", Color(0.82, 0.92, 1.0, 1.0))
			inv.pressed.connect(_on_invite_slot)
			_chip_row.add_child(inv)


# The pirate picker — list the cast (minus those already invited) with their
# rapport tier; picking one rolls accept/decline by rapport.
func _build_picker_ui() -> void:

	var vbox : VBoxContainer = _content
	vbox.add_child(_make_title("INVITE A PIRATE"))
	if not _picker_msg.is_empty():
		var msg : Label = _make_caption(_picker_msg)
		msg.add_theme_color_override("font_color", Color(1.0, 0.72, 0.55, 1.0))
		vbox.add_child(msg)
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 230.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list : VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for profile in NpcRegistry.all():
		if profile in _invited:
			continue
		var tier : String = PlayerState.affinity_tier(profile.npc_name)
		var btn : Button = _make_walnut_button("%s   ·   %s" % [profile.npc_name, tier],
			profile.portrait_color.lightened(0.30))
		btn.pressed.connect(_on_pick_npc.bind(profile))
		list.add_child(btn)
	var back : Button = _make_walnut_button("Back", Color(0.95, 0.84, 0.56, 1.0))
	back.pressed.connect(_on_picker_back)
	vbox.add_child(back)


func _build_join_ui() -> void:

	var vbox : VBoxContainer = _content
	var title : Label = _make_title("%s'S TABLE" % _host_name.to_upper())
	title.add_theme_color_override("font_color", _host_color.lightened(0.30))
	vbox.add_child(title)
	vbox.add_child(_make_caption("Already playing"))
	_chip_row = _make_chip_row()
	vbox.add_child(_chip_row)
	_refresh_chips()
	var note : Label = _make_caption("")
	if _can_join:
		note.text = "There's an open seat — pull up a chair."
	else:
		note.text = ("Regulars only for now — they don't know you well enough yet.\n"
			+ "Share a few games or do a favour, then try again.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(note)
	_add_stake_toggle(vbox)
	var hbox : HBoxContainer = _make_button_row()
	vbox.add_child(hbox)
	if _can_join:
		var join_btn : Button = _make_walnut_button("Join the table  ▸", Color(0.78, 1.0, 0.62, 1.0))
		join_btn.pressed.connect(_on_join)
		hbox.add_child(join_btn)
	var own_btn : Button = _make_walnut_button("Start your own", Color(0.95, 0.84, 0.56, 1.0))
	own_btn.pressed.connect(_on_start_own)
	hbox.add_child(own_btn)
	var leave_btn : Button = _make_walnut_button("Leave", Color(0.88, 0.80, 0.70, 1.0))
	leave_btn.pressed.connect(_on_cancel)
	hbox.add_child(leave_btn)


func _add_stake_toggle(vbox: VBoxContainer) -> void:

	var free_check : CheckButton = CheckButton.new()
	free_check.text = "Free table (just for fun)"
	free_check.button_pressed = _free
	free_check.disabled = _cash_locked_out
	free_check.focus_mode = Control.FOCUS_NONE
	free_check.add_theme_font_size_override("font_size", 18)
	free_check.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66, 1.0))
	free_check.toggled.connect(_on_free_toggled)
	vbox.add_child(free_check)
	_stake_label = Label.new()
	_stake_label.add_theme_font_size_override("font_size", 15)
	_stake_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.70, 1.0))
	_stake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stake_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_stake_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_stake_label)


func _make_title(text: String) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_caption(text: String) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.74, 0.80, 0.92, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_chip_row() -> HBoxContainer:

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0.0, 56.0)
	return row


func _make_button_row() -> HBoxContainer:

	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	return hbox


# --- Roll / refresh ----------------------------------------------------

func _roll_seats() -> void:

	var opponents : int = maxi(_seats - 1, 0)
	_seated = NpcRegistry.pick_for_lobby(opponents, _affinity_of, _exclude)
	_refresh_chips()


func _refresh_chips() -> void:

	if _chip_row == null:
		return
	for child in _chip_row.get_children():
		child.queue_free()
	if _seated.is_empty():
		var lonely : Label = Label.new()
		lonely.text = "(an empty table)"
		lonely.add_theme_font_size_override("font_size", 16)
		lonely.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72, 1.0))
		_chip_row.add_child(lonely)
		return
	for profile in _seated:
		_chip_row.add_child(_make_chip(profile))


func _refresh_seats_label() -> void:

	if _seats_label != null:
		_seats_label.text = "Players: %d" % _seats


func _refresh_stake_label() -> void:

	if _stake_label == null:
		return
	if _free:
		if _cash_locked_out:
			_stake_label.text = "No gold to spare for a cash table — playing free. No gold won or lost, just rapport."
		else:
			_stake_label.text = "Free table — no gold won or lost, just rapport."
	else:
		var note : String = _cash_note if not _cash_note.is_empty() else "the usual stakes"
		_stake_label.text = "Cash table — %s." % note


# --- Handlers ----------------------------------------------------------

func _on_seats_delta(delta: int) -> void:

	_seats = clampi(_seats + delta, _min_seats, _max_seats)
	_refresh_seats_label()
	_roll_seats()


func _on_free_toggled(pressed: bool) -> void:

	if _cash_locked_out:
		return
	_free = pressed
	_refresh_stake_label()


func _on_toggle_invite() -> void:

	_invite_only = not _invite_only
	_invited.clear()
	_render()


func _on_invite_slot() -> void:

	_picker_msg = ""
	_mode = "picker"
	_render()


func _on_pick_npc(profile: NpcPersonality) -> void:

	# Accept chance scales with rapport (a friend almost always says yes, a
	# stranger often declines) — but a decline is never a wall.
	var aff : float = float(_affinity_of.call(profile.npc_name))
	var p_accept : float = clampf(0.35 + aff / 100.0 * 0.6, 0.35, 0.95)
	if randf() <= p_accept:
		_invited.append(profile)
		_mode = "host"
		_render()
	else:
		_picker_msg = "%s: \"Maybe next time, friend.\"" % _short_name(profile)
		_render()


func _on_picker_back() -> void:

	_mode = "host"
	_render()


func _on_sit() -> void:

	if get_tree() != null:
		get_tree().paused = false
	confirmed.emit(_seated_paths(), _free)
	queue_free()


func _on_join() -> void:

	if get_tree() != null:
		get_tree().paused = false
	confirmed.emit(_seated_paths(), _free)
	queue_free()


func _on_start_own() -> void:

	# Flip this join lobby to a HOST lobby in place — no free/reopen, so the
	# paused tree never changes hands. Don't re-seat the very NPCs whose
	# table we just declined.
	_mode = "host"
	for p in _join_profiles:
		if not (p in _exclude):
			_exclude.append(p)
	_render()


func _on_cancel() -> void:

	if get_tree() != null:
		get_tree().paused = false
	cancelled.emit()
	queue_free()


# Who actually sits: the manually-invited guest list in invite-only mode,
# else whoever auto-joined (host) / was already playing (join).
func _effective_seated() -> Array[NpcPersonality]:

	return _invited if _invite_only else _seated


func _seated_paths() -> Array:

	var paths : Array = []
	for profile in _effective_seated():
		if profile != null and not String(profile.resource_path).is_empty():
			paths.append(profile.resource_path)
	return paths


# --- Styling (cloned from HiringBoard so the modals match) -------------

func _make_chip(profile: NpcPersonality) -> Control:

	var chip : PanelContainer = PanelContainer.new()
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.08, 0.95)
	var accent : Color = profile.portrait_color if profile != null else Color(0.78, 0.58, 0.24, 1.0)
	style.border_color = accent
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	chip.add_theme_stylebox_override("panel", style)
	var label : Label = Label.new()
	label.text = _short_name(profile)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", accent.lightened(0.35))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	chip.add_child(label)
	return chip


func _short_name(profile: NpcPersonality) -> String:

	if profile == null:
		return "Rival"
	var parts : PackedStringArray = profile.npc_name.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else profile.npc_name


func _build_panel_style() -> StyleBoxFlat:

	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.11, 0.06, 0.96)
	style.border_color = Color(0.78, 0.58, 0.24, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	return style


func _make_walnut_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.22, 0.14, 0.08, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		elif state == "disabled":
			bg = bg.darkened(0.30)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0) if state != "disabled" else Color(0.5, 0.42, 0.3, 1.0)
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 2
		s.corner_radius_top_left = 8
		s.corner_radius_top_right = 8
		s.corner_radius_bottom_right = 8
		s.corner_radius_bottom_left = 8
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		btn.add_theme_stylebox_override(state, s)
	return btn
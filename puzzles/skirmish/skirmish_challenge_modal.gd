## The Cradle Gym LADDER board — opened by the Spar post ([SkirmishSign]) in the gym. Lists the cast in
## difficulty order as a LADDER: beaten rungs are checked off, the next-up is the only one you can
## CHALLENGE, the rest are locked until you climb to them (master Ellison last). On a pick it emits
## [signal challenged] so the prop seats the foe + launches a FRIENDLY duel. Beat the top for the Gym
## Champion trophy. A pause-tree CanvasLayer; chrome cloned from [LobbyModal]. See [[cradle-gym-jungle-ordeal]].
class_name SkirmishChallengeModal
extends CanvasLayer


## Emitted when the player chooses an opponent.
signal challenged(profile: NpcPersonality)
## Emitted on backing out.
signal cancelled


func _ready() -> void:

	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	add_child(EscToClose.new(_on_cancel))   # ESC backs out, like every window (esc-closes-every-window rule)
	get_tree().paused = true


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false


func _build() -> void:

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -230.0
	panel.offset_right = 300.0
	panel.offset_bottom = 230.0
	add_child(panel)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	vbox.add_child(_make_title("THE GYM LADDER"))
	# No fighting style yet → the WHOLE ladder is locked; the master (Ellison) is the only one who can set you on a
	# path (choosing a style is HIS doing, not this sign's).
	var no_style : bool = not PlayerState.has_power_type()
	if no_style:
		vbox.add_child(_make_caption("Hollow Ellison bars the way. \"Choose your fighting style with me first — no one climbs my ladder 'til they know who they are.\""))
	else:
		vbox.add_child(_make_caption("Climb the ladder — beat each fighter to unlock the next, up to the master."))

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 280.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list : VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	# The LADDER: the cast in difficulty order (master last). Beaten rungs are checked off, the next-up is
	# the only CHALLENGE-able one, the rest are locked. (Roster is PlayerState's single source of truth.)
	var roster : Array = PlayerState.ladder_roster()
	var next_up : String = PlayerState.ladder_next()
	for profile in roster:
		var who : String = String(profile.npc_name)
		var diff : String = _difficulty_tier(profile.skirmish_skill)
		var btn : Button
		if no_style:
			# Everything LOCKED until you've chosen a style with Ellison.
			btn = _make_walnut_button("🔒   %s   ·   %s" % [who, diff], Palette.TEXT_MUTED)
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.4)
		elif PlayerState.ladder_beaten(who):
			btn = _make_walnut_button("✓   %s   ·   bested" % who, Palette.POSITIVE)
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.6)
		elif who == next_up:
			btn = _make_walnut_button("%s   ·   %s   —   CHALLENGE" % [who, diff], Palette.ACCENT)
			btn.pressed.connect(_on_pick.bind(profile))
		else:
			btn = _make_walnut_button("🔒   %s   ·   %s" % [who, diff], Palette.TEXT_MUTED)
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.45)
		list.add_child(btn)

	var foot : String = "Friendly bouts — lose and just try again. Win to climb the next rung."
	if no_style:
		foot = "Talk to Hollow Ellison to choose your fighting style — then come back and climb."
	elif PlayerState.ladder_complete():
		foot = "You've topped the ladder — Gym Champion! Drop in for a rematch any time."
	vbox.add_child(_make_caption(foot))
	var back : Button = _make_walnut_button("Never mind", Palette.ACCENT)
	back.pressed.connect(_on_cancel)
	vbox.add_child(back)


# Player-facing difficulty from the foe's FISTS skill (skirmish_skill, 0..1).
func _difficulty_tier(skill: float) -> String:

	if skill < 0.34:
		return "Novice"
	if skill < 0.62:
		return "Regular"
	return "Expert"


func _on_pick(profile: NpcPersonality) -> void:

	if get_tree() != null:
		get_tree().paused = false
	challenged.emit(profile)
	queue_free()


func _on_cancel() -> void:

	if get_tree() != null:
		get_tree().paused = false
	cancelled.emit()
	queue_free()




# --- Styling (cloned from LobbyModal so the modals match) -------------

func _make_title(text: String) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	UiStyle.apply_title(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_caption(text: String) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	UiStyle.apply_muted(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# WRAP within the panel's inner width (600 wide - 30 margins each side) so a long line never widens the modal
	# off-screen — keeps the window its normal size no matter the caption length.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(540.0, 0.0)
	return label


func _panel_style() -> StyleBoxFlat:

	var style : StyleBoxFlat = UiStyle.panel(true)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	return style


func _make_walnut_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 19)
	UiStyle.style_button(btn, font_color)
	return btn
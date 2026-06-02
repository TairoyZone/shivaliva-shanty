## A Voyage — the skyfaring core loop (see [[voyage-loop-research]]). Launched from
## the Skydock's [SkyHelm]. The loop, as a screen flow that re-enters itself off
## [member PlayerState.voyage_phase] each time a station/fight puzzle returns here:
##
##   CAST OFF  → MAKE WAY (THE LOFT: clear the Stardust, bank LIFT to keep her aloft)
##             → ENCOUNTER (a sky-brigand swings in)
##             → BOARDING (the SKIRMISH duel — your Loft lift SEEDS the foe's board)
##             → LOOT (win → booty scaled by your sailing + a new isle; lose → limp home)
##
## The Loft + Skirmish are real [PuzzleScene]s launched via change_scene; they write
## their results to transient PlayerState fields (last_loft_lift / last_skirmish_won)
## which this scene reads on re-entry — robust to the scene-swap (live state would die).
extends Control


const LOFT_SCENE : String = "res://puzzles/loft/loft.tscn"
const SKIRMISH_SCENE : String = "res://puzzles/skirmish/skirmish_duel.tscn"
const VOYAGE_SCENE : String = "res://voyages/voyage.tscn"
const FRONTIER_SCENE : String = "res://levels/frontier_isle/frontier_isle.tscn"
const FALLBACK_HOME : String = "res://levels/shore/shore.tscn"

## Booty for a won voyage: a base + a slice of your Loft lift (sailing well pays).
const BOOTY_BASE : int = 40
const BOOTY_PER_LIFT_DIV : int = 6      # +1 gold per this much lift
const BOOTY_LIFT_BONUS_CAP : int = 100
## Arrival footing: how much Loft lift pre-buries the foe's board by one clump.
const SEED_PER_LIFT_DIV : int = 150
const SEED_CAP : int = 3


func _ready() -> void:

	# A voyage is its own screen — hide the overworld HUD (a destination
	# BaseLocation re-shows it, and any booty gold flushes onto the purse then).
	if HUD:
		HUD.visible = false
	# Defensive: we're a Control pass-through, not a BaseLocation, so a queued
	# resume-position must not leak into the location we hand off to.
	PlayerState.consume_position()
	match PlayerState.voyage_phase:
		1:
			_show_encounter()    # back from the Loft
		2:
			_show_result()       # back from the boarding fight
		_:
			_show_castoff()      # fresh sail


# --- Phase 0: cast off → the LOFT station ----------------------------

func _show_castoff() -> void:

	_build_screen(
		"INTO THE VOID",
		"Your craft slips its mooring and rises through the clouds.\n\n"
		+ "But a sky-rock wants to FALL — get to the Loft and sing the breath-stones "
		+ "alight to keep her aloft as you make way through the Stardust.",
		[{"label": "Man the Loft", "color": Color(0.78, 1.0, 0.62, 1.0),
			"action": _start_loft}])


func _start_loft() -> void:

	PlayerState.last_loft_lift = 0
	PlayerState.voyage_phase = 1
	# Return HERE when the Loft ends — via the one-shot override, NOT last_scene
	# (which stays the real home scene, so quitting mid-voyage resumes at the dock).
	PlayerState.puzzle_return_scene = VOYAGE_SCENE
	get_tree().change_scene_to_file(LOFT_SCENE)


# --- Phase 1: encounter → the BOARDING fight -------------------------

func _show_encounter() -> void:

	var lift : int = PlayerState.last_loft_lift
	_build_screen(
		"BRIGAND OFF THE BOW",
		"You held her aloft and made good way (lift banked:  %d).\n\n" % lift
		+ "But you're barely clear of the clouds when a sky-brigand swings in off the "
		+ "wind, hungry for your cargo. Board them and bury them under your deck!",
		[{"label": "Board them!", "color": Color(1.0, 0.84, 0.5, 1.0),
			"action": _start_fight}])


func _start_fight() -> void:

	PlayerState.last_skirmish_won = false
	PlayerState.voyage_phase = 2
	# Arrival footing: a strong Loft run starts the brigand pre-buried (capped, so
	# it never auto-wins). Random cast brigand (flavour only — the bot's the same).
	@warning_ignore("integer_division")
	var boarding_seed : int = clampi(PlayerState.last_loft_lift / SEED_PER_LIFT_DIV, 0, SEED_CAP)
	PlayerState.voyage_boarding_seed = boarding_seed
	PlayerState.skirmish_opponent = ""
	PlayerState.puzzle_return_scene = VOYAGE_SCENE
	get_tree().change_scene_to_file(SKIRMISH_SCENE)


# --- Phase 2: resolve the loot ---------------------------------------

func _show_result() -> void:

	var won : bool = PlayerState.last_skirmish_won
	var lift : int = PlayerState.last_loft_lift
	PlayerState.voyage_phase = 0   # resolved — don't re-grant on any re-entry
	if won:
		@warning_ignore("integer_division")
		var lift_bonus : int = clampi(lift / BOOTY_PER_LIFT_DIV, 0, BOOTY_LIFT_BONUS_CAP)
		var booty : int = BOOTY_BASE + lift_bonus
		PlayerState.add_coins(booty)
		PlayerState.frontier_unlocked = true
		_build_screen(
			"BRIGAND ROUTED!",
			"You buried them under your deck and took their hold for your own.\n\n"
			+ "Booty:  +%d gold.\n\n" % booty
			+ "As the clouds thin, a lone rock drifts into view — Driftspar, "
			+ "untouched and waiting.",
			[
				{"label": "Disembark at Driftspar", "color": Color(0.80, 1.0, 0.66, 1.0),
					"action": _disembark},
				{"label": "Sail home", "color": Color(0.95, 0.86, 0.56, 1.0),
					"action": _sail_home},
			])
	else:
		_build_screen(
			"THEY GOT AWAY",
			"The brigand topped your deck out and slipped your grasp, fleeing into the "
			+ "murk with the wind at their back.\n\nNo booty this time — wheel about "
			+ "and try the skies again.",
			[{"label": "Sail home", "color": Color(0.95, 0.86, 0.56, 1.0),
				"action": _sail_home}])


func _disembark() -> void:

	get_tree().change_scene_to_file(FRONTIER_SCENE)


func _sail_home() -> void:

	var home : String = PlayerState.voyage_home_scene
	if home.is_empty():
		home = FALLBACK_HOME
	get_tree().change_scene_to_file(home)


# --- Screen building -------------------------------------------------

func _build_screen(title_text: String, body_text: String, buttons: Array) -> void:

	for child in get_children():
		child.queue_free()

	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360.0
	panel.offset_top = -220.0
	panel.offset_right = 360.0
	panel.offset_bottom = 220.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title : Label = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var body : Label = Label.new()
	body.text = body_text
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color(0.90, 0.86, 0.72, 1.0))
	body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	body.add_theme_constant_override("outline_size", 2)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vbox.add_child(row)
	for spec in buttons:
		var btn : Button = _make_button(String(spec["label"]), spec["color"])
		btn.pressed.connect(spec["action"])
		row.add_child(btn)


func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.10, 0.16, 0.97)
	s.border_color = Color(0.5, 0.6, 0.82, 1.0)
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 26
	s.content_margin_bottom = 26
	return s


func _make_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed"]:
		var sb : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.20, 0.16, 0.26, 0.96)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		sb.bg_color = bg
		sb.border_color = Color(0.5, 0.6, 0.82, 1.0)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_right = 10
		sb.corner_radius_bottom_left = 10
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override(state, sb)
	return btn

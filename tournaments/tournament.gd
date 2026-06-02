## A Gem Drop TOURNAMENT — an occasional 4-player single-elimination bracket
## (you + 3 of the cast). Entered from the [TournamentBoard] in the Inn for a
## Gold fee; this scene runs the bracket, launching the Gem Drop puzzle for
## each of YOUR matches (the parallel semifinal auto-resolves by NPC strength)
## and branching on [PlayerState] tournament state in _ready to tell "show the
## bracket" from "back from a match". The champion takes the pot. Mirrors the
## [Voyage] multi-scene pattern. See [[parlor-social-system]] (Slice 3c).
extends Control


const GEM_DROP_SCENE : String = "res://puzzles/gem_drop/gem_drop.tscn"
const TOURNAMENT_SCENE : String = "res://tournaments/tournament.tscn"
const FALLBACK_HOME : String = "res://levels/tavern/tavern.tscn"


func _ready() -> void:

	# A tournament is its own screen — hide the overworld HUD (the home
	# BaseLocation re-shows it, and any pot gold flushes onto the purse then).
	if HUD:
		HUD.visible = false
	# We're a Control pass-through, not a BaseLocation — drain any queued
	# resume position so it can't leak into the home scene we hand off to.
	PlayerState.consume_position()
	if PlayerState.tournament_awaiting:
		_resolve_match()
	_show()


# --- Bracket logic -----------------------------------------------------

# Score the match the player just played and advance the bracket.
func _resolve_match() -> void:

	PlayerState.tournament_awaiting = false
	var won : bool = PlayerState.last_gem_drop_won
	if PlayerState.tournament_round >= 2:
		# The final.
		if won:
			PlayerState.tournament_outcome = PlayerState.TournamentOutcome.CHAMPION
			PlayerState.add_coins(PlayerState.tournament_pot)
			PlayerState.record_tournament_win()
		else:
			PlayerState.tournament_outcome = PlayerState.TournamentOutcome.KNOCKED_OUT
	else:
		# The semifinal — winning advances you to the final vs the winner of
		# the parallel (NPC-vs-NPC) semifinal.
		if won:
			PlayerState.tournament_finalist = _resolve_other_semi()
			PlayerState.tournament_round = 2
		else:
			PlayerState.tournament_outcome = PlayerState.TournamentOutcome.KNOCKED_OUT


# The parallel semifinal (field[1] vs field[2]) resolves on its own — the
# stronger NPC (deeper minimax search + a touch of aggression) wins more often.
func _resolve_other_semi() -> String:

	var field : Array = PlayerState.tournament_field
	if field.size() < 3:
		return String(field[field.size() - 1]) if not field.is_empty() else ""
	var a : String = String(field[1])
	var b : String = String(field[2])
	var sa : float = _strength_of(a)
	var sb : float = _strength_of(b)
	var total : float = sa + sb
	if total <= 0.0:
		return a if randf() < 0.5 else b
	return a if randf() < (sa / total) else b


func _strength_of(path: String) -> float:

	var prof : NpcPersonality = load(path) as NpcPersonality
	if prof == null:
		return 1.0
	return float(prof.search_depth) + prof.aggression


# --- Screens -----------------------------------------------------------

func _show() -> void:

	match PlayerState.tournament_outcome:
		PlayerState.TournamentOutcome.CHAMPION:
			_show_champion()
		PlayerState.TournamentOutcome.KNOCKED_OUT:
			_show_knocked_out()
		_:
			_show_bracket()


func _show_bracket() -> void:

	var you_vs : String = _name_of(PlayerState.tournament_opponent())
	var body : String
	var btn_label : String
	if PlayerState.tournament_round >= 2:
		body = ("You won your semifinal!\n\nThe FINAL:   you   vs   %s\n\n"
			+ "Win this and the %d-gold pot is yours.") % [you_vs, PlayerState.tournament_pot]
		btn_label = "Play the final  ▸"
	else:
		var field : Array = PlayerState.tournament_field
		var other_a : String = _name_of(String(field[1])) if field.size() > 1 else "?"
		var other_b : String = _name_of(String(field[2])) if field.size() > 2 else "?"
		body = ("SEMIFINALS\n\nYour match:    you   vs   %s\nOther match:   %s   vs   %s\n\n"
			+ "Win two matches to take the %d-gold pot.") % [you_vs, other_a, other_b, PlayerState.tournament_pot]
		btn_label = "Play your match  ▸"
	_build_screen("GEM DROP TOURNAMENT", body, [
		{"label": btn_label, "color": Color(0.78, 1.0, 0.62, 1.0), "action": _start_match},
		{"label": "Withdraw", "color": Color(0.90, 0.80, 0.70, 1.0), "action": _leave},
	])


func _show_champion() -> void:

	_build_screen("TOURNAMENT CHAMPION!",
		"You took the whole bracket — last pirate standing.\n\nPrize:   +%d gold."
		% PlayerState.tournament_pot,
		[{"label": "Collect your winnings", "color": Color(0.80, 1.0, 0.66, 1.0), "action": _leave}])


func _show_knocked_out() -> void:

	_build_screen("KNOCKED OUT",
		"%s got the better of you this round.\n\n" % _name_of(PlayerState.tournament_opponent())
		+ "The pot slips away — but there's always the next tournament.",
		[{"label": "Head out", "color": Color(0.95, 0.86, 0.56, 1.0), "action": _leave}])


# --- Flow --------------------------------------------------------------

func _start_match() -> void:

	# Seat the bracket opponent, play it as a no-stakes graded match, and come
	# back HERE to score it (puzzle_return_scene, not last_scene).
	PlayerState.lobby_seated_paths = [PlayerState.tournament_opponent()]
	PlayerState.free_table = true
	PlayerState.puzzle_return_scene = TOURNAMENT_SCENE
	PlayerState.tournament_awaiting = true
	get_tree().change_scene_to_file(GEM_DROP_SCENE)


func _leave() -> void:

	var home : String = PlayerState.tournament_home
	if home.is_empty():
		home = FALLBACK_HOME
	PlayerState.end_tournament()
	get_tree().change_scene_to_file(home)


func _name_of(path: String) -> String:

	if path.is_empty():
		return "?"
	var prof : NpcPersonality = load(path) as NpcPersonality
	if prof == null:
		return "?"
	return prof.npc_name


# --- Screen building (clone of the Voyage screen) ----------------------

func _build_screen(title_text: String, body_text: String, buttons: Array) -> void:

	for child in get_children():
		child.queue_free()

	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10, 1.0)
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
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	s.bg_color = Color(0.13, 0.11, 0.08, 0.97)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
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
		var bg : Color = Color(0.24, 0.16, 0.09, 0.96)
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
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override(state, sb)
	return btn
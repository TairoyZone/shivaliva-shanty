## THE LOFT — the playable LIFT puzzle (SLICE 1). Inherits HUD-hiding, the Leave button
## + click-to-dismiss from [PuzzleScene]; binds the [LoftBoard]'s signals to a small HUD
## (lift banked, swaps left, a LIFT gauge reading how far she's sunk into THE STARDUST),
## flashes the COMBO banners (Arrr!/Bingo!/Vegas!), and on round-end records 'loft'
## mastery + shows the result. Standalone for now; voyage integration is later.
## See [[loft-spec]] + [[bilging-research]] (the mechanical template we reskinned).
extends PuzzleScene


## When manning the Loft AS a voyage leg, the crossing plays out HERE (the cockpit): the ship
## sails the chart, and her arrival at a stop ends the leg right over the board — a fight boards
## 'em, a calm stop posts the duty report — so you never get yanked out to the deck. See
## [[voyage-loop-research]].
const SELF_SCENE : String = "res://puzzles/loft/loft.tscn"
const SKIRMISH_SCENE : String = "res://puzzles/skirmish/skirmish_boarding.tscn"
const SHIP_DECK_SCENE : String = "res://levels/ship_deck/ship_deck.tscn"

@onready var _board : LoftBoard = $Board

var _banked_label : Label
var _moves_label : Label
var _gauge_label : Label
var _ui : CanvasLayer

var _voyage_chart : VoyageChart   # the in-sync voyage ribbon while manning the Loft mid-pillage
var _current_lift : int = 0       # live CUMULATIVE lift (the whole crossing in continuous mode)
var _current_swaps : int = 0      # live CUMULATIVE swaps — per-leg deltas come off the leg baseline
var _voyage_busy : bool = false   # a voyage transition (stop/fight/report/bail) underway — fire once
var _fight_done_this_leg : bool = false   # this fight leg's boarding is fought — resolve at the node, don't re-board
var _restore_pending : bool = false   # post-fight board restore not done yet — hold leg resolution until it is


func _ready() -> void:

	super._ready()
	_board.lift_changed.connect(_on_Board_lift_changed)
	_board.moves_changed.connect(_on_Board_moves_changed)
	_board.stardust_changed.connect(_on_Board_stardust_changed)
	_board.combo_scored.connect(_on_Board_combo_scored)
	_board.session_ended.connect(_on_Board_session_ended)
	_center_board()
	_build_ui()
	if PlayerState.voyage_active:
		_board.set_voyage_mode(true)   # one CONTINUOUS station for the whole crossing
		# Couple the Loft to the ACTIVE ship's condition: more open holes ⇒ faster Stardust rise.
		_push_effective_rise()
		if PlayerState.pillage_phase == 2:
			# Back from a boarding → RESTORE the same board + sail on to the node, where this fight
			# leg resolves (the outcome folds in there). Mark the fight DONE + restore PENDING now
			# (synchronously) so a stray reached_stop can't re-board OR resolve a 0/0 leg before the
			# restore runs; the restore itself is deferred (UI/board built).
			_fight_done_this_leg = true
			_restore_pending = true
			call_deferred("_resume_after_fight")
		else:
			# First time at the Loft this voyage (a fresh board) → seed the starting Stardust from the
			# ship's condition (perfect hull = baseline/aloft), then open this leg's measurement window.
			_board.set_stardust_start(PlayerState.ship_stardust_start())
			_board.set_can_sink(_is_voyage_fight_leg())   # only a FIGHT leg can sink her
			PlayerState.voyage_leg_lift0 = 0
			PlayerState.voyage_leg_swaps0 = 0


func _center_board() -> void:

	var board_size : Vector2 = Vector2(LoftBoard.COLS * LoftBoard.CELL, LoftBoard.ROWS * LoftBoard.CELL)
	_board.position = ((get_viewport().get_visible_rect().size - board_size) * 0.5).round()


# --- HUD --------------------------------------------------------------

func _build_ui() -> void:

	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)

	var bar : HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_top = 18.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui.add_child(bar)

	_banked_label = _make_label("BANKED  0", Color(0.97, 0.88, 0.50, 1.0))
	_moves_label = _make_label("SWAPS  %d" % LoftBoard.MOVES_PER_ROUND, Color(0.82, 0.90, 1.0, 1.0))
	_gauge_label = _make_label("LIFT  ALOFT", Color(0.55, 0.92, 0.95, 1.0))
	bar.add_child(_wrap(_banked_label))
	bar.add_child(_wrap(_moves_label))
	bar.add_child(_wrap(_gauge_label))

	set_help_text("THE LOFT — keep the falling rock aloft.\n\n"
		+ "• Move the cursor with the MOUSE or ARROW KEYS.\n"
		+ "• Aim at the seam between two side-by-side stones and CLICK or press SPACE to swap them.\n"
		+ "• Line up 3+ of a hue in a row or column to ignite them.\n"
		+ "• Clear MORE THAN ONE line in a SINGLE swap (a combo: Arrr! / Bingo! / Vegas!) for big LIFT.\n"
		+ "• Clear stones to climb away from THE STARDUST rising below; dawdle on weak clears and it creeps up to swallow her.\n"
		+ "• A heavy BALLAST drifts in from above — you can't swap or match it, but clear BENEATH it to sink it into THE STARDUST (or let the Stardust rise to it) and it sloughs for big LIFT.")

	# Manning the Loft mid-pillage? Keep the voyage chart in view (top-left, clear of the centre
	# gauge bar and the Leave/? buttons) — and let her SAIL in real time while you work, in sync
	# with the deck (both charts share PlayerState.voyage_ship_t). Manning a station = a crossing.
	if PlayerState.voyage_active:
		_voyage_chart = VoyageChart.new()
		_voyage_chart.place_at(_ui, true)
		_voyage_chart.refresh_from_state(true)   # manning a station IS a crossing — she sails
		# Each stop/encounter she makes advances the leg right here over the board. Connected ALWAYS
		# — a post-fight Loft sails ON to the node too, where the fought leg resolves.
		_voyage_chart.reached_stop.connect(_on_voyage_reached_stop)
		_voyage_chart.reached_encounter.connect(_on_voyage_reached_encounter)


func _make_label(text: String, color: Color) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _wrap(label: Label) -> PanelContainer:

	var panel : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.11, 0.10, 0.16, 0.92)
	s.border_color = Color(0.4, 0.5, 0.72, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", s)
	panel.custom_minimum_size = Vector2(150.0, 0.0)
	panel.add_child(label)
	return panel


func _on_Board_lift_changed(total_lift: int) -> void:

	_current_lift = total_lift
	if _banked_label != null:
		_banked_label.text = "BANKED  %d" % total_lift


func _on_Board_moves_changed(remaining: int, total: int) -> void:

	# Standalone: (remaining, cap) — counts DOWN. Voyage continuous: (swaps MADE, -1) — counts UP, no
	# cap. Label them distinctly so "SWAPS 7" can't mean both "7 left" and "7 spent".
	_current_swaps = remaining if total < 0 else (total - remaining)
	if _moves_label != null:
		_moves_label.text = ("SWAPS USED  %d" % remaining) if total < 0 else ("SWAPS  %d" % remaining)


# The LIFT gauge reads the Stardust: low = aloft (clear sky), mid = steady, high = sinking.
func _on_Board_stardust_changed(level: float) -> void:

	if _gauge_label == null:
		return
	var text : String = "STEADY"
	var color : Color = Color(0.96, 0.86, 0.40, 1.0)
	if level <= 4.0:
		text = "ALOFT"
		color = Color(0.50, 0.92, 0.96, 1.0)
	elif level >= 7.5:
		text = "SINKING"
		color = Color(1.0, 0.55, 0.42, 1.0)
	_gauge_label.text = "LIFT  %s" % text
	_gauge_label.add_theme_color_override("font_color", color)


# The named combo flashes center-board (Arrr!/Bingo!/Vegas!/…).
func _on_Board_combo_scored(combo_name: String, lift_gained: int) -> void:

	var label : Label = Label.new()
	label.text = "%s\n+%d" % [combo_name, lift_gained]
	label.add_theme_font_size_override("font_size", 30 + mini(lift_gained, 40))
	label.add_theme_color_override("font_color", _combo_color(lift_gained))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(520.0, 140.0)
	var vp : Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2(vp.x * 0.5 - 260.0, vp.y * 0.32)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.5, 0.5)
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	layer.add_child(label)
	var tw : Tween = create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_property(label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(layer.queue_free)


func _combo_color(lift: int) -> Color:

	if lift >= 40:
		return Color(1.0, 0.62, 0.30, 1.0)   # orange — Bingo/Vegas
	if lift >= 16:
		return Color(0.62, 0.96, 0.72, 1.0)  # green — doubles
	return Color(0.70, 0.90, 1.0, 1.0)       # blue — Good/Great


# --- Round end --------------------------------------------------------

func _on_Board_session_ended(total_lift: int, sank: bool) -> void:

	# Mid-pillage the Loft round running out (or a sink) just ends THIS leg — resolve it here.
	if PlayerState.voyage_active:
		_current_lift = total_lift
		if sank:
			_on_voyage_sunk()   # the Stardust took her on a fight leg → LOST IN THE STARDUST
			return
		_on_voyage_reached_stop()
		return
	# Standalone: report the lift, record mastery, show the result. A SINK ends early → lower lift.
	PlayerState.last_loft_lift = total_lift
	var mastery : Dictionary = PlayerState.record_puzzle_result("loft", total_lift)
	_show_results(total_lift, mastery, sank)
	if mastery["ranked_up"]:
		add_child(MasteryToast.create(String(mastery["tier_name"])))
	_set_awaiting_dismiss(true)


# --- Voyage cockpit: the crossing ENDS over the board, never out on the deck ----------

# The sloop made this leg's NODE — resolve the leg HERE (over the board) + post the duty report:
# a calm leg just reports; a fight leg reports with the boarding outcome folded in (we fought it
# mid-leg). If a fight leg reached the node WITHOUT meeting the foe (no swords), board 'em now.
func _on_voyage_reached_stop() -> void:

	if _restore_pending:
		return   # post-fight board not restored yet — _resume_after_fight will drive the resolve
	if _is_voyage_fight_leg():
		if _fight_done_this_leg:
			_resolve_and_report(true, PlayerState.last_skirmish_won, _leg_lift(), _leg_swaps())
		else:
			_trigger_voyage_skirmish()
	else:
		_resolve_and_report(false, true, _leg_lift(), _leg_swaps())


# The sloop reached this leg's swords (the random mid-leg spot) — board 'em right there.
func _on_voyage_reached_encounter() -> void:

	if _is_voyage_fight_leg() and not _fight_done_this_leg:
		_trigger_voyage_skirmish()


func _is_voyage_fight_leg() -> bool:

	var enc : Array = PlayerState.pillage_encounters
	var i : int = PlayerState.pillage_leg
	return i >= 0 and i < enc.size() and String(enc[i]) != ""


# Push the hole-scaled per-move rise into the board from the ACTIVE ship's CURRENT holes. Called at
# embark AND at each new leg so a fight's fresh holes bite the very next leg (not a leg late, since
# holes are only opened when the leg resolves — after _ready already ran). See [[ship-condition-research]].
func _push_effective_rise() -> void:

	_board.set_effective_rise(LoftBoard.RISE_BASE + LoftBoard.HOLE_RISE_PER_HOLE * float(PlayerState.ship_open_holes()))


# This leg's lift / swaps — the DELTA off the leg's start baseline (the board's running totals are
# cumulative across the whole continuous crossing, so each leg rates only ITS own stretch).
func _leg_lift() -> int:

	return maxi(0, _current_lift - PlayerState.voyage_leg_lift0)


func _leg_swaps() -> int:

	return maxi(0, _current_swaps - PlayerState.voyage_leg_swaps0)


# Back from a boarding → RESTORE the same board (continue the station) and sail on to the node, where
# this fight leg resolves with the remembered outcome. No re-deal, no re-fight.
func _resume_after_fight() -> void:

	if not is_inside_tree():
		return
	if not PlayerState.loft_board_state.is_empty():
		_board.restore(PlayerState.loft_board_state)
		PlayerState.loft_board_state = {}
	if _voyage_chart != null:
		_voyage_chart.mark_encounter_fired()   # don't let the resumed chart re-signal this fought leg
	_restore_pending = false
	_voyage_busy = false
	_board.set_can_sink(false)   # the fight's done — sailing on to the resolve node can't sink her
	# If the boarding fired AT the node (the swords-missed fallback), the chart is already at its goal
	# and reached_stop won't re-fire — resolve the leg right now (mirrors the deck's zero-distance guard).
	if _voyage_chart != null and not _voyage_chart.needs_sail():
		_on_voyage_reached_stop()


# Resolve the leg via the shared logic + show the DUTY REPORT as an overlay OVER the board (you
# stay at your station, the board keeps its state). On dismiss: open the next leg or disembark.
func _resolve_and_report(is_fight: bool, won: bool, lift: int, swaps: int) -> void:

	if _voyage_busy:
		return
	_voyage_busy = true
	if _voyage_chart != null:
		_voyage_chart.snap_to_goal()   # she's at the node — pin her there for the report
	var r : Dictionary = PlayerState.resolve_voyage_leg(is_fight, won, lift, swaps)
	var panel : DutyReportPanel = DutyReportPanel.create(PlayerState.last_duty_report)
	panel.closed.connect(_on_report_closed.bind(bool(r["arrived"])))
	add_child(panel)


func _on_report_closed(arrived: bool) -> void:

	if arrived:
		# Voyage's end → the booty DIVVY (pool × your overall duty), then step ashore.
		var card : VoyageHaulCard = VoyageHaulCard.create(PlayerState.pillage_destination)
		card.closed.connect(_on_haul_card_closed)
		add_child(card)
	else:
		_begin_next_leg()   # in-place — no reload, the chart keeps sailing (no black flash)


# Open the NEXT leg WITHOUT touching the board — CONTINUOUS crossing: the stones, lift + Stardust
# carry straight through; we just start a fresh measurement window and sail the chart on. (The
# chart signals are wired once in _build_ui and stay connected the whole voyage.)
func _begin_next_leg() -> void:

	_fight_done_this_leg = false
	_board.set_can_sink(_is_voyage_fight_leg())      # arm the sink only if the NEW leg is a fight
	_push_effective_rise()                           # refresh the rise — the last fight may have opened holes
	PlayerState.voyage_leg_lift0 = _current_lift     # this leg's baseline (cumulative so far)
	PlayerState.voyage_leg_swaps0 = _current_swaps
	if _voyage_chart != null:
		_voyage_chart.refresh_from_state(true)       # sail on toward the next stop
	_voyage_busy = false


# The Stardust took her on a fight leg — LOST IN THE STARDUST. Apply the consequence (forfeit the
# booty pool + tow toll + mend the hull, keep the deed), show the card, then limp home on dismiss.
func _on_voyage_sunk() -> void:

	_voyage_busy = true   # OWN the transition — block any concurrent reached_stop / boarding from firing too
	var r : Dictionary = PlayerState.sink_voyage()
	var card : VoyageSinkCard = VoyageSinkCard.create(int(r["forfeited"]), int(r["toll"]))
	card.closed.connect(_on_sunk_card_closed.bind(String(r["home"])))
	add_child(card)


func _on_sunk_card_closed(home: String) -> void:

	if get_tree() != null:
		get_tree().change_scene_to_file(home)


func _on_haul_card_closed() -> void:

	var dest : String = PlayerState.pillage_destination_scene
	PlayerState.cash_out_voyage()   # pay the pooled booty as one cut
	PlayerState.clear_voyage()
	if dest.is_empty():
		dest = SHIP_DECK_SCENE
	get_tree().change_scene_to_file(dest)


# Met the foe mid-leg → park at the swords, SNAPSHOT the board (to carry across the boarding), then
# board 'em. The Skirmish returns to a fresh Loft (_resume_after_fight restores this board + sails
# ON to the node, where the leg resolves). The fight footing is seeded from THIS leg's form so far.
func _trigger_voyage_skirmish() -> void:

	if _voyage_busy:
		return
	_voyage_busy = true
	if _voyage_chart != null:
		_voyage_chart.freeze()   # PARK her at the swords for the boarding — don't sail on to the node
	_board.lock_input(true)      # no stray swap during the cry / before we snapshot
	# A "Sail ho!" beat so the boarding never reads as a teleport (animate-everything).
	var cry : Tween = _flash_alarm("Sail ho!   Board 'em!")
	# Let the current swap's cascade settle so we snapshot a STABLE board, then carry it across the
	# boarding. Cap the wait so a stuck resolve can't hang the cry.
	var guard : int = 0
	while _board.is_resolving() and guard < 120:
		await get_tree().process_frame
		if not is_instance_valid(self) or not is_inside_tree():
			return
		guard += 1
	# A cascade that settled during the wait may have SUNK her (fight leg + Stardust hit SINK_LEVEL) →
	# _on_voyage_sunk already cleared the voyage and owns the transition. Abort the boarding so we don't
	# double-fire a scene change over the sink card.
	if not PlayerState.voyage_active:
		return
	PlayerState.loft_board_state = _board.serialize()
	# Footing = how well you flew INTO the fight (this leg's form so far); banked for the deck path too.
	PlayerState.last_loft_lift = _leg_lift()
	PlayerState.last_loft_swaps = _leg_swaps()
	PlayerState.last_skirmish_won = false
	PlayerState.voyage_boarding_seed = PlayerState.voyage_seed_from_lift(_leg_lift())
	PlayerState.skirmish_opponent = ""
	PlayerState.pillage_phase = 2
	PlayerState.puzzle_return_scene = SELF_SCENE
	# Swap right as the cry ENDS — never cut it off (fast resolve) nor leave a dead locked frame
	# after it (slow resolve already outlasted it → the tween is done → await returns at once).
	if cry != null and cry.is_valid():
		await cry.finished
	if not is_instance_valid(self) or not is_inside_tree() or not PlayerState.voyage_active:
		return
	get_tree().change_scene_to_file(SKIRMISH_SCENE)


# A big centred cry over the board (reused for the boarding alarm). Returns its Tween so the caller
# can await the cry finishing before swapping scenes.
func _flash_alarm(text: String) -> Tween:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.40, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(640.0, 110.0)
	var vp : Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2(vp.x * 0.5 - 320.0, vp.y * 0.34)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.6, 0.6)
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	layer.add_child(label)
	var tw : Tween = create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.5)
	tw.chain().tween_property(label, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(layer.queue_free)
	return tw


# The persistent Leave button → bail back to the deck, banking this leg's form (the deck resumes the
# crossing on its side). Bailing ABANDONS the continuous station — drop the snapshot so nothing
# stale restores. Standalone Lofts use the base behaviour.
func _return_to_launching_scene() -> void:

	if PlayerState.voyage_active:
		if _voyage_busy:
			return
		_voyage_busy = true
		PlayerState.last_loft_lift = _leg_lift()
		PlayerState.last_loft_swaps = _leg_swaps()
		PlayerState.loft_board_state = {}
		get_tree().change_scene_to_file(SHIP_DECK_SCENE)
		return
	super._return_to_launching_scene()


func _show_results(total_lift: int, mastery: Dictionary, sank: bool) -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var panel : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.10, 0.16, 0.97)
	s.border_color = Color(0.85, 0.35, 0.38, 1.0) if sank else Color(0.4, 0.6, 0.85, 1.0)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.content_margin_left = 40
	s.content_margin_right = 40
	s.content_margin_top = 28
	s.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", s)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	if sank:
		_add_label(vbox, "LOST IN THE STARDUST", 38, Color(1.0, 0.5, 0.5, 1.0))
		_add_label(vbox, "Sank before the run was done — sing harder next time.",
			16, Color(0.92, 0.74, 0.74, 1.0))
	else:
		_add_label(vbox, "THE SHIP IS ALOFT", 38, Color(0.7, 0.9, 1.0, 1.0))
	_add_label(vbox, "Lift banked:  %d" % total_lift, 26, Color(0.97, 0.86, 0.46, 1.0))
	_add_label(vbox, "%s  ·  best  %d" % [String(mastery["tier_name"]), int(mastery["best"])],
		18, Color(0.78, 0.84, 0.96, 1.0))
	_add_label(vbox, "Click anywhere to head back", 15, Color(0.6, 0.66, 0.78, 1.0))


func _add_label(parent: VBoxContainer, text: String, size: int, color: Color) -> void:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
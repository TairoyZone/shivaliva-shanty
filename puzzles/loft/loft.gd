## THE LOFT — the playable LIFT puzzle (SLICE 1). Inherits HUD-hiding, the Leave button
## + click-to-dismiss from [PuzzleScene]; binds the [LoftBoard]'s signals to a small HUD
## (lift banked, swaps left, a LIFT gauge reading how far she's sunk into THE STARDUST),
## flashes the COMBO banners (Arrr!/Bingo!/Vegas!), and on round-end records 'loft'
## mastery + shows the result. Standalone for now; voyage integration is later.
## See [[loft-spec]] + [[bilging-research]] (the mechanical template we reskinned).
extends VoyageStationScene


## When manning the Loft AS a voyage station, the WHOLE crossing plays out here (the cockpit, CONTINUOUS):
## the ship sails the chart, each stop resolves a leg over the board (a fight boards 'em, then the duty
## report posts), and the NEXT leg opens right here — the Stardust + stones + lift carry straight through,
## no dismount to the deck. You man ONE station per pillage (the Loft to fly, or the Patchworks to patch);
## the AI crew covers the rest. Arrival → the haul card; a sink → LOST IN THE STARDUST. See [[voyage-loop-research]].
const SELF_SCENE : String = "res://puzzles/loft/loft.tscn"   # SKIRMISH/SHIP_DECK scenes live in the base

@onready var _board : LoftBoard = $Board

var _banked_label : Label
var _moves_label : Label
var _stardust_bar : MeterBar    # LIFT/Stardust as a real meter (was the LIFT text gauge)
var _hull_bar : MeterBar        # voyage-only HULL meter (was the HULL text label)
var _ui : CanvasLayer

var _current_lift : int = 0       # live CUMULATIVE lift this leg (the board's running total)
var _current_swaps : int = 0      # live CUMULATIVE swaps — the leg delta comes off the leg baseline
# (_voyage_chart + the busy/fight/restore flags now live in VoyageStationScene, the shared base.)


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
		_board.set_voyage_mode(true)   # a continuous station session for this leg
		# Couple the Loft to the ACTIVE ship's condition: more open holes ⇒ faster Stardust rise.
		_push_effective_rise()
		_enter_voyage_station()        # VoyageStationScene: build+sail the chart, then resume-after-fight or fresh leg


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
	bar.add_child(_make_station_pill(_banked_label))
	bar.add_child(_make_station_pill(_moves_label))
	# LIFT/Stardust as a real meter BAR (same component as the ship deck) — it FILLS as the Stardust
	# rises (calm-blue → red past the bite tick), so you SEE her sinking. Caption = ALOFT/STEADY/SINKING.
	_stardust_bar = _make_station_meter("STARDUST", "stardust")
	_stardust_bar.rising_palette = true
	_stardust_bar.danger_tick = 0.8   # STARDUST_DANGER(8) / SINK(10)
	_stardust_bar.hard_line = 1.0     # the SINK line
	_stardust_bar.set_caption("ALOFT")
	bar.add_child(_stardust_bar)

	var help : String = ("THE LOFT — keep the falling rock aloft.\n\n"
		+ "• Move the cursor with the MOUSE or ARROW KEYS.\n"
		+ "• Aim at the seam between two side-by-side stones and CLICK or press SPACE to swap them.\n"
		+ "• Line up 3+ of a hue in a row or column to ignite them.\n"
		+ "• Clear MORE THAN ONE line in a SINGLE swap (a combo: Arrr! / Bingo! / Vegas!) for big LIFT.\n"
		+ "• Clear stones to climb away from THE STARDUST rising below; dawdle on weak clears and it creeps up to swallow her.\n"
		+ "• A heavy BALLAST drifts in from above — you can't swap or match it, but clear BENEATH it to sink it into THE STARDUST (or let the Stardust rise to it) and it sloughs for big LIFT.")
	if PlayerState.voyage_active:
		help += ("\n\nFLYING A LEG — you're manning the Loft on a pillage. The ship SAILS the chart while you "
			+ "play; keep her ALOFT to crawl toward the next stop. More open HULL holes flood the Stardust "
			+ "faster, so a battered hull sinks you sooner. Meet a foe mid-leg and the crossing pauses for a "
			+ "BOARDING — then you're right back at the Loft for the next leg.")
	set_help_text(help)

	# Manning the Loft mid-pillage? Keep the voyage chart in view (top-left, clear of the centre
	# gauge bar and the Leave/? buttons) — and let her SAIL in real time while you work, in sync
	# with the deck (both charts share PlayerState.voyage_ship_t). Manning a station = a crossing.
	if PlayerState.voyage_active:
		# A HULL meter beside the gauges — the PILLAGE ship's holes (shows WHY the Stardust floods fast).
		# Same bar as the deck (green→amber→red, one notch per hole). The voyage CHART + leg-resolution are
		# built by the base (_enter_voyage_station).
		_hull_bar = _make_station_meter("HULL", "hull")
		_hull_bar.warn_frac = 0.25   # 1 hole → amber, 3+ → red
		_hull_bar.bad_frac = 0.75
		bar.add_child(_hull_bar)
		_update_hull_label()


func _make_label(text: String, color: Color) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _on_Board_lift_changed(total_lift: int) -> void:

	_current_lift = total_lift
	if _banked_label != null:
		_banked_label.text = "BANKED  %d" % total_lift


func _on_Board_moves_changed(remaining: int, total: int) -> void:

	# Standalone: (remaining, cap) — counts DOWN ("SWAPS 7" = 7 left). Voyage continuous: (swaps MADE,
	# -1) — counts UP, no cap; read it as "flown" so it can't be misread as a dwindling limit.
	_current_swaps = remaining if total < 0 else (total - remaining)
	if _moves_label != null:
		_moves_label.text = ("SWAPS  %d flown" % remaining) if total < 0 else ("SWAPS  %d" % remaining)


# The STARDUST meter reads the live level: low = aloft (clear sky), mid = steady, high = sinking. The bar
# fills + reddens as it climbs (animate-everything); the caption gives the lift reading.
func _on_Board_stardust_changed(level: float) -> void:

	if _stardust_bar == null:
		return
	var text : String = "STEADY"
	if level <= 4.0:
		text = "ALOFT"
	elif level >= 7.5:
		text = "SINKING"
	_stardust_bar.set_value(level, LoftBoard.SINK_LEVEL)
	_stardust_bar.set_caption(text)


# The named combo flashes center-board (Arrr!/Bingo!/Vegas!/…).
func _on_Board_combo_scored(combo_name: String, lift_gained: int) -> void:

	Audio.play_sfx("bop")
	if lift_gained >= 7:   # a notable combo punches the screen (borrow #5)
		get_tree().root.add_child(ScreenFlash.make(_combo_color(lift_gained), clampf(float(lift_gained) * 0.02, 0.12, 0.4)))
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


# --- Voyage station hooks (the shared leg flow lives in [VoyageStationScene]) ----------

# Open a fresh leg: seed the Stardust from ship condition (perfect hull = aloft) + arm the sink only on
# a FIGHT leg. The base then sails the chart.
func _setup_fresh_voyage_leg() -> void:

	_board.set_stardust_start(PlayerState.ship_stardust_start())
	_board.set_can_sink(_is_voyage_fight_leg())


# Continue the crossing (the board carries — Stardust + stones + lift roll through): re-baseline the
# leg's lift/swaps to the cumulative so far, re-arm the sink for the new leg, re-push the hole rise.
func _open_next_leg() -> void:

	PlayerState.voyage_leg_lift0 = _current_lift
	PlayerState.voyage_leg_swaps0 = _current_swaps
	_board.set_can_sink(_is_voyage_fight_leg())
	_push_effective_rise()


# This leg's lift / swaps — the DELTA off the leg baseline (the board's running totals are cumulative).
func _leg_performance() -> Dictionary:

	return {"lift": maxi(0, _current_lift - PlayerState.voyage_leg_lift0),
		"swaps": maxi(0, _current_swaps - PlayerState.voyage_leg_swaps0)}


func _snapshot_voyage_state() -> Dictionary:

	return _board.serialize()


func _restore_voyage_state(state: Dictionary) -> void:

	_board.restore(state)


func _disarm_sink() -> void:

	_board.set_can_sink(false)


func _voyage_chart_placement(layer: CanvasLayer) -> void:

	_voyage_chart.place_at(layer, true)
	# Nudge DOWN clear of the centred gauge bar: the voyage bar is FOUR pills (BANKED / SWAPS / LIFT /
	# HULL), wide enough that its left edge slid under this top-left chart and hid BANKED. Drop it below.
	_voyage_chart.offset_top += 80.0
	_voyage_chart.offset_bottom += 80.0


func _self_scene() -> String:

	return SELF_SCENE


func _lock_station_input(on: bool) -> void:

	_board.lock_input(on)


func _station_is_resolving() -> bool:

	return _board.is_resolving()


# Push the hole-scaled per-move rise into the board from the ACTIVE ship's CURRENT holes. Called at
# embark AND at each new leg so a fight's fresh holes bite the very next leg (not a leg late, since
# holes are only opened when the leg resolves — after _ready already ran). See [[ship-condition-research]].
func _push_effective_rise() -> void:

	_board.set_effective_rise(LoftBoard.RISE_BASE + LoftBoard.HOLE_RISE_PER_HOLE * float(PlayerState.ship_open_holes()))
	_update_hull_label()


# Refresh the voyage HULL meter from the active ship's open holes — the shared station refresher (so the
# Loft + Patchworks + deck all read the hull the same way).
func _update_hull_label() -> void:

	_refresh_hull_meter(_hull_bar)


# (The shared voyage-leg flow — board / resume / resolve / report / sink / haul / the "Sail ho!" cry —
# now lives in [VoyageStationScene]; the Loft only supplies the hooks above.)


# (The voyage-bail Leave handler lives in [VoyageStationScene]; the standalone Loft uses PuzzleScene's.)


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
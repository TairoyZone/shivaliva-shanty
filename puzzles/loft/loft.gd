## THE LOFT — the playable LIFT puzzle (SLICE 1). Inherits HUD-hiding, the Leave button
## + click-to-dismiss from [PuzzleScene]; binds the [LoftBoard]'s signals to a small HUD
## (lift banked, swaps left, a LIFT gauge reading how far she's sunk into THE STARDUST),
## flashes the COMBO banners (Arrr!/Bingo!/Vegas!), and on round-end records 'loft'
## mastery + shows the result. Standalone for now; voyage integration is later.
## See [[loft-spec]] + [[bilging-research]] (the mechanical template we reskinned).
extends PuzzleScene


@onready var _board : LoftBoard = $Board

var _banked_label : Label
var _moves_label : Label
var _gauge_label : Label
var _ui : CanvasLayer


func _ready() -> void:

	super._ready()
	_board.lift_changed.connect(_on_Board_lift_changed)
	_board.moves_changed.connect(_on_Board_moves_changed)
	_board.stardust_changed.connect(_on_Board_stardust_changed)
	_board.combo_scored.connect(_on_Board_combo_scored)
	_board.session_ended.connect(_on_Board_session_ended)
	_center_board()
	_build_ui()


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

	# Manning the Loft mid-pillage? Keep the voyage chart in view (top-left, clear of the
	# centre gauge bar and the Leave/? buttons) so you can see where the ship's bound.
	if PlayerState.voyage_active:
		var chart : VoyageChart = VoyageChart.new()
		chart.place_at(_ui, true)
		chart.refresh_from_state(false)


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

	if _banked_label != null:
		_banked_label.text = "BANKED  %d" % total_lift


func _on_Board_moves_changed(remaining: int, _total: int) -> void:

	if _moves_label != null:
		_moves_label.text = "SWAPS  %d" % remaining


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

	# Report the lift so a Voyage MAKE-WAY phase can read it (booty + fight footing).
	# A SINK ends the round early, so total_lift is naturally lower → worse footing.
	PlayerState.last_loft_lift = total_lift
	var mastery : Dictionary = PlayerState.record_puzzle_result("loft", total_lift)
	_show_results(total_lift, mastery, sank)
	if mastery["ranked_up"]:
		add_child(MasteryToast.create(String(mastery["tier_name"])))
	_set_awaiting_dismiss(true)


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
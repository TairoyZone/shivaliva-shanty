## Mining — the playable job-puzzle (a reskin of YPP Foraging). Inherits
## HUD-hiding, the persistent Leave button and click-to-dismiss from
## [PuzzleScene]; this script binds the puzzle's UI (ore haul, the
## progress meter, combo banners, the results screen) to the board's
## signals.
##
## PHASE 2 (this build): ore chunks fall in from the top, you dig them to
## the floor to extract them, and the haul + combos are scored. The
## session runs until the chunk target is met. The ore does not yet flow
## to the backpack / pay out — that wiring (plus the Mine work-site and
## Forge hire) is phase 4. See [[mining-spec]].
extends PuzzleScene


# TOUCH controls (mobile web): a d-pad moves the 2x2 cursor (held); the rotate buttons crumble (C/X keys). See [[touch-input-foundation]].
func _touch_spec() -> Array:
	return [
		{"label": "◄", "action": "ui_left", "hold": true, "side": "left"},
		{"label": "►", "action": "ui_right", "hold": true, "side": "left"},
		{"label": "▲", "action": "ui_up", "hold": true, "side": "left"},
		{"label": "▼", "action": "ui_down", "hold": true, "side": "left"},
		{"label": "↺", "key": KEY_X},
		{"label": "↻", "key": KEY_C},
	]


## Combo step names by chunk-count (index = chunks dug in one move).
const COMBO_NAMES : Array = [
	"", "", "DOUBLE HAUL", "TRIPLE HAUL", "MOTHERLODE", "MOTHERLODE",
]


@onready var _board : MiningBoard = $Board
@onready var _ore_label : Label = $UI/TopBar/OrePanel/OreLabel
@onready var _dug_label : Label = $UI/TopBar/DugPanel/DugLabel
@onready var _ui : CanvasLayer = $UI


## Progress-meter pips (top = first to deplete as you dig).
var _pips : Array = []

## Running ore total mirrored from the board, committed to the backpack on
## session end / leave.
var _running_ore : int = 0
## Idempotency guard so the haul is granted exactly once across the
## natural session-end path, the click-through dismiss, AND a mid-session
## Leave.
var _ore_committed : bool = false
## Ore the backpack couldn't hold when the haul was committed (bag full).
var _overflow_lost : int = 0
var _meter_count : Label = null


func _ready() -> void:

	super._ready()
	set_help_text("How to mine\n\n"
		+ "• Move the 2x2 cursor with the arrow keys or the mouse\n"
		+ "• Rotate it: C / right-click = clockwise,  X / left-click = counter-clockwise\n"
		+ "• Line up 3+ of the same color to crumble that rock\n"
		+ "• Clear the rock UNDER an ore chunk to dig it down to the floor — chunks are the only thing that scores\n"
		+ "• Dig several chunks in one move for a combo bonus\n"
		+ "• Big clears drop a TOOL — frame it (the cursor shrinks to 1x1) and click to use it\n"
		+ "• Fill the 'TO GET' meter beside the board (one pip per chunk you dig) to finish the shift")
	_board.ore_changed.connect(_on_ore_changed)
	_board.progress_changed.connect(_on_progress_changed)
	_board.combo_landed.connect(_on_combo_landed)
	_board.session_ended.connect(_on_session_ended)
	_build_progress_meter(MiningBoard.CHUNK_TARGET)
	_refresh_ore(0)
	_refresh_dug(0)


func _on_ore_changed(total_ore: int) -> void:

	_running_ore = total_ore
	_refresh_ore(total_ore)


func _refresh_ore(value: int) -> void:

	_ore_label.text = "ORE MINED:  %d" % value


func _refresh_dug(extracted: int) -> void:

	_dug_label.text = "CHUNKS:  %d / %d" % [extracted, MiningBoard.CHUNK_TARGET]


func _on_progress_changed(remaining: int, target: int) -> void:

	var extracted : int = target - remaining
	_refresh_dug(extracted)
	for i in _pips.size():
		var lit : bool = i >= target - extracted   # FILL from the bottom up as chunks are dug (was: drained)
		var pip : ColorRect = _pips[i]
		pip.color = (Color(0.96, 0.78, 0.32, 1.0) if lit
			else Color(0.22, 0.20, 0.16, 1.0))
	if _meter_count != null:
		_meter_count.text = "%d / %d" % [extracted, target]


# --- Progress meter (the "banana column" reskin) ---------------------

func _build_progress_meter(target: int) -> void:

	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _meter_style())
	# Sit the meter RIGHT BESIDE the board so it reads as the board's own goal tracker (the Board node is at
	# x=464 and is COLS*CELL = 352 wide → its right edge is 816; +16 gap). Was floating at the screen edge,
	# unclear + overlapping the panel rail.
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 832.0
	panel.offset_right = 924.0
	panel.offset_top = -180.0
	panel.offset_bottom = 180.0
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(panel)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	var title : Label = Label.new()
	title.text = "TO GET"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.82, 0.88, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)
	_pips.clear()
	for i in target:
		var pip : ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(44.0, 30.0)
		pip.color = Color(0.22, 0.20, 0.16, 1.0)   # starts EMPTY — fills in as you dig chunks out
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(pip)
		_pips.append(pip)
	# A plain count under the pips so the meter is unmistakable: chunks dug so far, out of the target.
	_meter_count = Label.new()
	_meter_count.text = "0 / %d" % target
	_meter_count.add_theme_font_size_override("font_size", 15)
	_meter_count.add_theme_color_override("font_color", Color(0.96, 0.86, 0.5, 1.0))
	_meter_count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_meter_count.add_theme_constant_override("outline_size", 3)
	_meter_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meter_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_meter_count)


func _meter_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.09, 0.13, 0.92)
	s.border_color = Color(0.4, 0.45, 0.58, 1.0)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_right = 10
	s.corner_radius_bottom_left = 10
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


# --- Combo banner ----------------------------------------------------

func _on_combo_landed(count: int, ore_gained: int) -> void:

	if count < 2:
		return
	Audio.play_sfx("hit")
	var combo_name : String = (COMBO_NAMES[count] if count < COMBO_NAMES.size()
		else "HAUL x%d" % count)
	var label : Label = Label.new()
	label.text = "%s\n+%d ORE" % [combo_name, ore_gained]
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", _combo_color(count))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(640.0, 160.0)
	var vp_size : Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2(vp_size.x * 0.5 - 320.0, vp_size.y * 0.30 - 80.0)
	label.scale = Vector2(0.4, 0.4)
	label.pivot_offset = label.size * 0.5
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	layer.add_child(label)
	var tw : Tween = create_tween().set_parallel(false)
	tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)


func _combo_color(count: int) -> Color:

	match count:
		2:
			return Color(0.62, 0.86, 1.00, 1.0)
		3:
			return Color(0.58, 0.96, 0.72, 1.0)
		4:
			return Color(1.00, 0.92, 0.42, 1.0)
	return Color(1.00, 0.62, 0.24, 1.0)


# --- Session end -----------------------------------------------------

func _on_session_ended(total_ore: int, chunks_extracted: int) -> void:

	_running_ore = total_ore
	_commit_ore_once()
	# Mastery: ore mined this session is the score; pop the flourish on a tier-up.
	var mastery : Dictionary = PlayerState.record_puzzle_result("mining", total_ore)
	_show_results_panel(total_ore - _overflow_lost, _overflow_lost, chunks_extracted)
	if mastery["ranked_up"]:
		add_child(MasteryToast.create(String(mastery["tier_name"])))
	_set_awaiting_dismiss(true)


# Idempotent — runs add_ore exactly once across every exit path (natural
# end, click-through dismiss, mid-session Leave). add_ore returns the
# overflow (ore the backpack couldn't hold), surfaced in the results.
func _commit_ore_once() -> void:

	if _ore_committed:
		return
	_ore_committed = true
	if _running_ore > 0:
		_overflow_lost = PlayerState.add_ore(_running_ore)


# If the player taps Leave mid-session, bank what they've dug before the
# base class navigates away.
func _return_to_launching_scene() -> void:

	_commit_ore_once()
	super._return_to_launching_scene()


func _show_results_panel(ore_kept: int, overflow: int, chunks_extracted: int) -> void:

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
	panel.add_theme_stylebox_override("panel", _results_style())
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
	_add_result_label(vbox, "SHIFT COMPLETE", 40, Color(0.7, 0.9, 1.0, 1.0))
	_add_result_label(vbox, "You dug out all %d chunks." % chunks_extracted, 18,
		Color(0.85, 0.9, 1.0, 1.0))
	_add_result_label(vbox, "Ore mined:  %d  (added to your backpack)" % ore_kept,
		24, Color(0.96, 0.82, 0.4, 1.0))
	if overflow > 0:
		_add_result_label(vbox, "Bag was full — %d left behind" % overflow,
			16, Color(1.0, 0.62, 0.42, 1.0))
	_add_result_label(vbox, "Deliver it to Cinder Troy at the Forge for gold",
		15, Color(0.6, 0.66, 0.78, 1.0))
	_add_result_label(vbox, "Click anywhere to head back", 15, Color(0.6, 0.66, 0.78, 1.0))


func _add_result_label(parent: VBoxContainer, text: String, size: int, color: Color) -> void:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _results_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.10, 0.16, 0.97)
	s.border_color = Color(0.4, 0.6, 0.85, 1.0)
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	s.content_margin_left = 40
	s.content_margin_right = 40
	s.content_margin_top = 28
	s.content_margin_bottom = 28
	return s
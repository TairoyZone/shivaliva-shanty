## SKIRMISH — the playable scene wrapping [SkirmishBoard]. Inherits HUD
## hiding, the persistent Leave button and click-to-dismiss from
## [PuzzleScene]; this script forwards input to the board, shows the
## score/level/lines read-out, and on top-out records mastery + the
## results screen.
##
## This is the SINGLE-PLAYER core (prove the falling-block engine is fun).
## The versus duel (2nd board + AI + garbage attacks), the cancel window,
## and the 3 weapon classes are the next build layers. See
## [[combat-puzzle-direction]].
extends PuzzleScene


# TOUCH controls (mobile web): move + soft-drop are held, rotate is a tap. See [[touch-input-foundation]].
func _touch_spec() -> Array:
	return [
		{"label": "◄", "action": "ui_left", "hold": true, "side": "left"},
		{"label": "►", "action": "ui_right", "hold": true, "side": "left"},
		{"label": "↻", "action": "ui_up"},
		{"label": "▼", "action": "ui_down", "hold": true},
	]


const DAS_DELAY : float = 0.16     # hold time before auto-shift kicks in
const DAS_REPEAT : float = 0.04    # auto-shift step interval

@onready var _board : SkirmishBoard = $Board

var _score_label : Label
var _level_label : Label
var _lines_label : Label

var _das_dir : int = 0
var _das_timer : float = 0.0
var _das_charged : bool = false


func _ready() -> void:

	super._ready()
	# Centre the field (+ its next-piece box) on screen.
	var vp : Vector2 = get_viewport().get_visible_rect().size
	var field_w : int = SkirmishBoard.COLS * SkirmishBoard.CELL
	var field_h : int = SkirmishBoard.ROWS * SkirmishBoard.CELL
	var preview_w : int = SkirmishBoard.CELL * 4 + 16 + 22
	_board.position = Vector2(
		round((vp.x - float(field_w + preview_w)) * 0.5),
		round((vp.y - float(field_h)) * 0.5))
	_board.score_changed.connect(_on_score_changed)
	_board.lines_changed.connect(_on_lines_changed)
	_board.level_changed.connect(_on_level_changed)
	_board.game_over.connect(_on_game_over)
	_build_ui()


func _process(delta: float) -> void:

	if _board == null or _board.is_over():
		return
	# Soft drop on ↓ OR Space — hold to fall faster. NO instant hard-drop
	# (Troy: the piece must never teleport to the floor).
	_board.set_soft_drop(Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_accept"))
	var dir : int = 0
	if Input.is_action_pressed("ui_right"):
		dir += 1
	if Input.is_action_pressed("ui_left"):
		dir -= 1
	if dir == 0:
		_das_dir = 0
		return
	if dir != _das_dir:
		# Fresh press — move once immediately, then arm the auto-shift.
		_das_dir = dir
		_das_timer = 0.0
		_das_charged = false
		_board.move(dir)
		return
	_das_timer += delta
	if not _das_charged:
		if _das_timer >= DAS_DELAY:
			_das_charged = true
			_das_timer = 0.0
			_board.move(dir)
	else:
		while _das_timer >= DAS_REPEAT:
			_das_timer -= DAS_REPEAT
			_board.move(dir)


func _unhandled_input(event: InputEvent) -> void:

	if _board != null and not _board.is_over():
		if event.is_action_pressed("ui_up"):
			_board.rotate_cw()
			get_viewport().set_input_as_handled()
			return
		# NOTE: Space is a SOFT drop (polled in _process), NOT a hard drop —
		# we never teleport the piece to the floor.
	# Defer to PuzzleScene for the click-to-dismiss after game over.
	super._unhandled_input(event)


# --- UI ---------------------------------------------------------------

func _build_ui() -> void:

	var ui : CanvasLayer = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var stats : VBoxContainer = VBoxContainer.new()
	stats.position = Vector2(48.0, 120.0)
	stats.add_theme_constant_override("separation", 20)
	ui.add_child(stats)
	_score_label = _add_stat(stats, "SCORE")
	_level_label = _add_stat(stats, "LEVEL")
	_lines_label = _add_stat(stats, "LINES")
	_score_label.text = "0"
	_level_label.text = "1"
	_lines_label.text = "0"
	# Controls hint, bottom-centre.
	var hint : Label = Label.new()
	hint.text = "←  →  move        ↑  rotate        ↓ / Space  soft drop"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.7, 0.76, 0.92, 0.9))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint.add_theme_constant_override("outline_size", 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -44.0
	hint.offset_bottom = -16.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hint)


func _add_stat(parent: VBoxContainer, title: String) -> Label:

	var block : VBoxContainer = VBoxContainer.new()
	parent.add_child(block)
	var t : Label = Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", Color(0.62, 0.68, 0.85, 1.0))
	block.add_child(t)
	var v : Label = Label.new()
	v.add_theme_font_size_override("font_size", 30)
	v.add_theme_color_override("font_color", Color(0.96, 0.92, 0.70, 1.0))
	v.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	v.add_theme_constant_override("outline_size", 4)
	block.add_child(v)
	return v


func _on_score_changed(s: int) -> void:
	if _score_label != null:
		_score_label.text = _commafy(s)


func _on_lines_changed(total: int) -> void:
	if _lines_label != null:
		_lines_label.text = str(total)


func _on_level_changed(lvl: int) -> void:
	if _level_label != null:
		_level_label.text = str(lvl)


func _commafy(n: int) -> String:

	var s : String = str(absi(n))
	var out : String = ""
	var c : int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c == 3 and i > 0:
			out = "," + out
			c = 0
	return out


# --- Game over --------------------------------------------------------

func _on_game_over(final_score: int) -> void:

	var mastery : Dictionary = PlayerState.record_puzzle_result("skirmish", final_score)
	_show_results(final_score, bool(mastery["is_new_best"]))
	if mastery["ranked_up"]:
		add_child(MasteryToast.create(String(mastery["tier_name"])))
	_set_awaiting_dismiss(true)


func _show_results(final_score: int, is_new_best: bool) -> void:

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
	panel.add_child(vbox)
	_add_result_label(vbox, "TOPPED OUT", 40, Color(0.86, 0.62, 0.92, 1.0))
	_add_result_label(vbox, "Score:  %s" % _commafy(final_score), 26, Color(0.96, 0.92, 0.6, 1.0))
	_add_result_label(vbox, "Lines:  %d" % _board.lines_total(), 20, Color(0.85, 0.9, 1.0, 1.0))
	if is_new_best:
		_add_result_label(vbox, "A new best!", 17, Color(0.7, 1.0, 0.7, 1.0))
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
	s.border_color = Color(0.5, 0.55, 0.82, 1.0)
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	s.content_margin_left = 44
	s.content_margin_right = 44
	s.content_margin_top = 28
	s.content_margin_bottom = 28
	return s
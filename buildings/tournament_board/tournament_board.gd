## The Tournament Board in the Inn. Tournaments are OCCASIONAL, not always
## on — on each visit the board rolls whether a bout is currently being held
## (a stand-in for a real seasonal calendar until a day-cycle exists). When
## one's on, interacting offers entry for a Gold fee, which launches the
## [code]res://tournaments/tournament.tscn[/code] bracket. See
## [[parlor-social-system]] (Slice 3c). Drawn procedurally: a post + a
## parchment board with a brass cup, matching the [HiringBoard] family.
@tool
class_name TournamentBoard
extends Interactable


const ENTRY_FEE : int = 30
const FIELD_SIZE : int = 3
## Per-Inn-visit chance a tournament is currently being held. Occasional —
## you won't always find one running (tunable).
const TOURNAMENT_CHANCE : float = 0.35
const TOURNAMENT_SCENE : String = "res://tournaments/tournament.tscn"

const POST_WIDTH : float = 9.0
const POST_HEIGHT : float = 102.0
const BOARD_WIDTH : float = 120.0
const BOARD_HEIGHT : float = 90.0
const BOARD_TOP_OFFSET : float = 4.0
const BASE_PEG_WIDTH : float = 26.0
const BASE_PEG_HEIGHT : float = 4.0

const COLOR_POST_FILL : Color = Color(0.42, 0.26, 0.10, 1.0)
const COLOR_POST_FRAME : Color = Color(0.18, 0.10, 0.04, 1.0)
const COLOR_BOARD_FILL : Color = Color(0.94, 0.86, 0.62, 1.0)
const COLOR_BOARD_FRAME : Color = Color(0.52, 0.36, 0.18, 1.0)
const COLOR_HEADER_BAR : Color = Color(0.36, 0.22, 0.42, 1.0)
const COLOR_CUP : Color = Color(0.86, 0.66, 0.28, 1.0)
const COLOR_CUP_DARK : Color = Color(0.54, 0.38, 0.14, 1.0)
const COLOR_NAIL : Color = Color(0.46, 0.30, 0.14, 1.0)

var _in_session : bool = false
var _modal : CanvasLayer = null


func _ready() -> void:

	super._ready()
	if Engine.is_editor_hint():
		return
	# Roll the "season" — occasional, re-rolled each Inn visit.
	_in_session = randf() < TOURNAMENT_CHANCE
	marker_label = "A Gem Drop tournament is on!" if _in_session else "Tournament board"
	var tip : Label = get_node_or_null("Tooltip") as Label
	if tip != null:
		tip.text = "%s   [E]" % marker_label


func _exit_tree() -> void:

	if is_instance_valid(_modal):
		get_tree().paused = false
		_modal.queue_free()
		_modal = null


func interact() -> void:

	if Engine.is_editor_hint():
		return
	_show_modal()


func _show_modal() -> void:

	if is_instance_valid(_modal):
		return
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -180.0
	panel.offset_right = 300.0
	panel.offset_bottom = 180.0
	layer.add_child(panel)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	# Title.
	var title : Label = Label.new()
	title.text = "GEM DROP TOURNAMENT" if _in_session else "TOURNAMENT BOARD"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	# Body.
	var can_afford : bool = PlayerState.total_coins >= ENTRY_FEE
	var body : Label = Label.new()
	if _in_session:
		body.text = ("A bout is on! Four pirates, single elimination — winner takes "
			+ "the pot.\n\nEntry:  %d gold.        Pot:  %d gold.") % [ENTRY_FEE, ENTRY_FEE * 4]
		if not can_afford:
			body.text += "\n\nYou need %d gold to enter." % ENTRY_FEE
	else:
		body.text = ("No tournament running just now. They're called now and then — "
			+ "swing by another time and try your luck for the pot.")
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58, 1.0))
	body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	body.add_theme_constant_override("outline_size", 2)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)
	# Buttons.
	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	if _in_session and can_afford:
		var enter_btn : Button = _make_walnut_button("Enter  (%d gold)" % ENTRY_FEE,
			Color(0.78, 1.0, 0.62, 1.0))
		enter_btn.pressed.connect(_on_enter_pressed)
		hbox.add_child(enter_btn)
	var close_btn : Button = _make_walnut_button("Close", Color(0.95, 0.84, 0.56, 1.0))
	close_btn.pressed.connect(_close_modal)
	hbox.add_child(close_btn)
	_modal = layer
	add_child(layer)
	get_tree().paused = true


func _on_enter_pressed() -> void:

	if PlayerState.total_coins < ENTRY_FEE:
		return
	PlayerState.add_coins(-ENTRY_FEE, "Tournament entry")
	var field_paths : Array = []
	for prof in NpcRegistry.pick_random(FIELD_SIZE):
		field_paths.append(prof.resource_path)
	var home : String = ""
	if get_tree().current_scene != null:
		home = get_tree().current_scene.scene_file_path
	PlayerState.start_tournament(field_paths, ENTRY_FEE * 4, home)
	get_tree().paused = false
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	get_tree().change_scene_to_file(TOURNAMENT_SCENE)


func _close_modal() -> void:

	get_tree().paused = false
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null


# --- Styling (matches the HiringBoard modal) ---------------------------

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
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style


func _make_walnut_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.22, 0.14, 0.08, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0)
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


# --- Visual: post + parchment board with a brass cup -------------------

func _draw() -> void:

	# Base pegs.
	var peg_rect : Rect2 = Rect2(-BASE_PEG_WIDTH * 0.5, -BASE_PEG_HEIGHT,
		BASE_PEG_WIDTH, BASE_PEG_HEIGHT)
	draw_rect(peg_rect, COLOR_POST_FILL)
	draw_rect(peg_rect, COLOR_POST_FRAME, false, 1.0)
	# Post.
	var post_rect : Rect2 = Rect2(-POST_WIDTH * 0.5, -POST_HEIGHT, POST_WIDTH, POST_HEIGHT)
	draw_rect(post_rect, COLOR_POST_FILL)
	draw_rect(post_rect, COLOR_POST_FRAME, false, 1.2)
	# Parchment board.
	var board_y : float = -POST_HEIGHT + BOARD_TOP_OFFSET
	var board_rect : Rect2 = Rect2(-BOARD_WIDTH * 0.5, board_y, BOARD_WIDTH, BOARD_HEIGHT)
	draw_rect(board_rect, COLOR_BOARD_FILL)
	draw_rect(board_rect, COLOR_BOARD_FRAME, false, 2.4)
	# Header bar.
	var header_h : float = 16.0
	draw_rect(Rect2(board_rect.position.x, board_rect.position.y, BOARD_WIDTH, header_h),
		COLOR_HEADER_BAR)
	# Brass cup, centered under the header.
	var cx : float = 0.0
	var cup_top : float = board_rect.position.y + header_h + 14.0
	var cup_w : float = 30.0
	var cup_h : float = 30.0
	# Bowl (trapezoid, wider at the top).
	var bowl : PackedVector2Array = PackedVector2Array([
		Vector2(cx - cup_w * 0.5, cup_top),
		Vector2(cx + cup_w * 0.5, cup_top),
		Vector2(cx + cup_w * 0.28, cup_top + cup_h * 0.62),
		Vector2(cx - cup_w * 0.28, cup_top + cup_h * 0.62),
	])
	draw_colored_polygon(bowl, COLOR_CUP)
	draw_polyline(bowl + PackedVector2Array([bowl[0]]), COLOR_CUP_DARK, 1.4)
	# Handles (side arcs).
	draw_arc(Vector2(cx - cup_w * 0.5, cup_top + 6.0), 7.0, -PI * 0.5, PI * 0.5, 10, COLOR_CUP_DARK, 2.0)
	draw_arc(Vector2(cx + cup_w * 0.5, cup_top + 6.0), 7.0, PI * 0.5, PI * 1.5, 10, COLOR_CUP_DARK, 2.0)
	# Stem + base.
	draw_rect(Rect2(cx - 2.0, cup_top + cup_h * 0.62, 4.0, cup_h * 0.22), COLOR_CUP)
	draw_rect(Rect2(cx - 9.0, cup_top + cup_h * 0.84, 18.0, 4.0), COLOR_CUP)
	draw_rect(Rect2(cx - 9.0, cup_top + cup_h * 0.84, 18.0, 4.0), COLOR_CUP_DARK, false, 1.0)
	# Corner nails.
	var nail_inset : float = 6.0
	draw_circle(board_rect.position + Vector2(nail_inset, nail_inset), 2.8, COLOR_NAIL)
	draw_circle(board_rect.position + Vector2(BOARD_WIDTH - nail_inset, nail_inset), 2.8, COLOR_NAIL)
	draw_circle(board_rect.position + Vector2(nail_inset, BOARD_HEIGHT - nail_inset), 2.8, COLOR_NAIL)
	draw_circle(board_rect.position + Vector2(BOARD_WIDTH - nail_inset, BOARD_HEIGHT - nail_inset), 2.8, COLOR_NAIL)
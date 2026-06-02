## HiringBoard — the Wanted poster pinned up at Cogwise Godfrey's
## Workshop where the player applies for the lumberjacking job.
## Interacting opens a modal:
##   - Before applying: title is WANTED LUMBERJACKS, body explains the
##     wage, an [Apply for the job] button sets
##     [member PlayerState.hired_at_workshop] = true.
##   - After applying: title is WORKSHOP JOB, body says you're hired
##     and reminds you of the loop (chop at the Grove, deliver here),
##     Apply button is hidden — just a [Close] button.
##
## The board itself is a parchment poster nailed to a wooden post,
## drawn procedurally with three placeholder "text lines" so it reads
## as a poster at a glance.
@tool
class_name HiringBoard
extends Interactable


## Which job this board hires for. WORKSHOP = Cogwise Godfrey's
## lumberjacking (default, so existing instances are unchanged); FORGE =
## Cinder Troy's mining. Drives which PlayerState "hired" flag is
## read/written and the poster's wording.
enum Job { WORKSHOP, FORGE }

@export var job : Job = Job.WORKSHOP


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
const COLOR_HEADER_BAR : Color = Color(0.42, 0.24, 0.10, 1.0)
const COLOR_TEXT_LINE : Color = Color(0.30, 0.18, 0.06, 0.78)
const COLOR_NAIL : Color = Color(0.46, 0.30, 0.14, 1.0)

## The open modal, or null. Guards against stacking (re-pressing E while
## it's already up) and lets [method _exit_tree] tear it down if the
## scene changes out from under it.
var _modal : CanvasLayer = null


func interact() -> void:

	if Engine.is_editor_hint():
		return
	_show_modal()


# Free the modal + unpause if the board leaves the tree while it's open
# (backstop — pausing the tree already prevents a scene change while
# open, but this keeps cleanup honest).
func _exit_tree() -> void:

	if is_instance_valid(_modal):
		get_tree().paused = false
		_modal.queue_free()
		_modal = null


func _show_modal() -> void:

	# Open-guard: never stack a second modal over a live one.
	if is_instance_valid(_modal):
		return
	var is_hired : bool = _is_hired()
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 30
	# Process while paused so the buttons still work after we pause the
	# tree to freeze the world (and the player) behind the modal.
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	# Dimmer behind the panel — eats input so the player can't click
	# through onto other interactables while the modal is open.
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	# Walnut/brass panel — matches the Leave-button styling.
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -200.0
	panel.offset_right = 300.0
	panel.offset_bottom = 200.0
	layer.add_child(panel)
	# Stack inside the panel: title, body, button row.
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	# Title.
	var title : Label = Label.new()
	if job == Job.FORGE:
		title.text = ("FORGE JOB" if is_hired else "WANTED:  MINERS")
	else:
		title.text = ("WORKSHOP JOB" if is_hired else "WANTED:  LUMBERJACKS")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	# Body text — different per job + state.
	var body : Label = Label.new()
	if job == Job.FORGE:
		if is_hired:
			body.text = ("You're on Cinder Troy's books.\n\n"
				+ "Mine at the Mine (its entrance is out on Cradle Rock). "
				+ "Bring the ore back here and drop it at the ore bin. "
				+ "Wages: 2 gold per ore delivered.")
		else:
			body.text = ("Cinder Troy needs ore for the forge.\n\n"
				+ "Apply to take the job. Wages: 2 gold per ore delivered. "
				+ "Dig at the Mine out on Cradle Rock, then bring the ore back "
				+ "to the bin here at the Forge.")
	elif is_hired:
		body.text = ("You're on Cogwise Godfrey's lumber payroll.\n\n"
			+ "Chop at the Grove (east of the Workshop). "
			+ "Bring the wood back here and drop it at the lumber pile. "
			+ "Wages: 1 gold per wood delivered.")
	else:
		body.text = ("Cogwise Godfrey needs lumber for a spacecraft hull.\n\n"
			+ "Apply to take the job. Wages: 1 gold per wood delivered. "
			+ "Chop at the Grove east of here, then bring the lumber back "
			+ "to the drop-off in this shop.")
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58, 1.0))
	body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	body.add_theme_constant_override("outline_size", 2)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)
	# Button row.
	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	if not is_hired:
		var apply_btn : Button = _make_walnut_button(
			"Apply for the job", Color(0.78, 1.0, 0.62, 1.0))
		apply_btn.pressed.connect(_on_apply_pressed)
		hbox.add_child(apply_btn)
	var close_btn : Button = _make_walnut_button(
		"Close", Color(0.95, 0.84, 0.56, 1.0))
	close_btn.pressed.connect(_on_close_pressed)
	hbox.add_child(close_btn)
	# Parent to THIS node (in the scene), not get_tree().root — so the
	# modal dies with the scene instead of orphaning on root. Then pause
	# the tree: freezes the player + world behind the modal and makes it
	# impossible to trigger a scene change while it's open.
	_modal = layer
	add_child(layer)
	get_tree().paused = true


func _on_apply_pressed() -> void:

	_set_hired()
	_close_modal()


# Read/write the right PlayerState hire flag for this board's job.
func _is_hired() -> bool:

	if job == Job.FORGE:
		return PlayerState.hired_at_forge
	return PlayerState.hired_at_workshop


func _set_hired() -> void:

	if job == Job.FORGE:
		PlayerState.hired_at_forge = true
	else:
		PlayerState.hired_at_workshop = true


func _on_close_pressed() -> void:

	_close_modal()


func _close_modal() -> void:

	get_tree().paused = false
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null


# Walnut + brass panel style — matches the tavern Leave button.
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


# Walnut/brass button — same family as the Leave button. Adds the
# subtle hover/pressed state tints.
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


func _draw() -> void:

	# Base pegs.
	var peg_y : float = -BASE_PEG_HEIGHT
	var peg_rect : Rect2 = Rect2(
		-BASE_PEG_WIDTH * 0.5, peg_y,
		BASE_PEG_WIDTH, BASE_PEG_HEIGHT)
	draw_rect(peg_rect, COLOR_POST_FILL)
	draw_rect(peg_rect, COLOR_POST_FRAME, false, 1.0)
	# Post.
	var post_rect : Rect2 = Rect2(
		-POST_WIDTH * 0.5, -POST_HEIGHT,
		POST_WIDTH, POST_HEIGHT)
	draw_rect(post_rect, COLOR_POST_FILL)
	draw_rect(post_rect, COLOR_POST_FRAME, false, 1.2)
	# Parchment board.
	var board_y : float = -POST_HEIGHT + BOARD_TOP_OFFSET
	var board_rect : Rect2 = Rect2(
		-BOARD_WIDTH * 0.5, board_y,
		BOARD_WIDTH, BOARD_HEIGHT)
	draw_rect(board_rect, COLOR_BOARD_FILL)
	draw_rect(board_rect, COLOR_BOARD_FRAME, false, 2.4)
	# Dark header bar across the top of the parchment.
	var header_h : float = 16.0
	draw_rect(
		Rect2(board_rect.position.x, board_rect.position.y, BOARD_WIDTH, header_h),
		COLOR_HEADER_BAR)
	# Placeholder text lines under the header — 4 thin horizontal
	# strips, last one shorter so it reads as "end of paragraph."
	var body_y0 : float = board_rect.position.y + header_h + 12.0
	var line_left : float = board_rect.position.x + 10.0
	var line_right : float = board_rect.end.x - 10.0
	var line_h : float = 3.0
	var line_spacing : float = 12.0
	for i in range(4):
		var y : float = body_y0 + i * line_spacing
		var line_w : float = line_right - line_left
		if i == 3:
			line_w *= 0.62
		draw_rect(Rect2(line_left, y, line_w, line_h), COLOR_TEXT_LINE)
	# Corner nails.
	var nail_radius : float = 2.8
	var nail_inset : float = 6.0
	draw_circle(board_rect.position + Vector2(nail_inset, nail_inset),
		nail_radius, COLOR_NAIL)
	draw_circle(board_rect.position + Vector2(BOARD_WIDTH - nail_inset, nail_inset),
		nail_radius, COLOR_NAIL)
	draw_circle(board_rect.position + Vector2(nail_inset, BOARD_HEIGHT - nail_inset),
		nail_radius, COLOR_NAIL)
	draw_circle(board_rect.position + Vector2(BOARD_WIDTH - nail_inset, BOARD_HEIGHT - nail_inset),
		nail_radius, COLOR_NAIL)
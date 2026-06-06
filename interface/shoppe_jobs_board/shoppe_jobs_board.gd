## ShoppeJobsBoard — a YPP "Shoppe Jobs"-style notice board listing the labour puzzles you can take on
## (Mining + Woodcutting). Each row shows the trade + its wage and a "Go" that launches the puzzle —
## gated by being hired at that work-site (apply at the Forge / Workshop first). A self-freeing modal
## CanvasLayer; opened from the HUD quick menu. Modelled on [VoyagesBoard]. See [[ypp-template]].
class_name ShoppeJobsBoard
extends CanvasLayer

const GROUP : StringName = &"shoppe_jobs_board"

## The labour jobs surfaced here. `hired` = the PlayerState flag gating it; `site` = where to apply.
const JOBS : Array = [
	{"title": "Mining", "scene": "res://puzzles/mining/mining.tscn",
		"wage": "2 gold per ore", "hired": "hired_at_forge", "site": "the Forge"},
	{"title": "Woodcutting", "scene": "res://puzzles/lumberjacking/lumberjacking.tscn",
		"wage": "1 gold per wood", "hired": "hired_at_workshop", "site": "the Workshop"},
]


static func open(host: Node) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	host.get_tree().root.add_child(ShoppeJobsBoard.new())


func _ready() -> void:

	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_build()
	get_tree().paused = true


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false


func _build() -> void:

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -175.0
	panel.offset_right = 300.0
	panel.offset_bottom = 175.0
	add_child(panel)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	vbox.add_child(_make_title("Shoppe Jobs"))
	vbox.add_child(_make_caption("Honest work for honest gold — pick a trade and get to it."))
	for job in JOBS:
		vbox.add_child(_make_job_row(job as Dictionary))
	var spacer : Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	vbox.add_child(spacer)
	var back : Button = _make_button("Never mind", Color(0.95, 0.84, 0.56, 1.0))
	back.pressed.connect(_close)
	vbox.add_child(back)


func _make_job_row(job: Dictionary) -> PanelContainer:

	var hired : bool = bool(PlayerState.get(String(job["hired"])))
	var row_panel : PanelContainer = PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _row_style())
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row_panel.add_child(row)

	var info : Label = Label.new()
	var sub : String = String(job["wage"]) if hired else "Get hired at %s first" % String(job["site"])
	info.text = "%s\n%s" % [String(job["title"]), sub]
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color(0.95, 0.9, 0.74, 1.0) if hired else Color(0.72, 0.66, 0.52, 1.0))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var go : Button = _make_button("Go" if hired else "Locked", Color(0.80, 1.0, 0.66, 1.0) if hired else Color(0.7, 0.64, 0.5, 1.0))
	go.disabled = not hired
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if hired:
		go.pressed.connect(_on_go.bind(job))
	row.add_child(go)
	return row_panel


func _on_go(job: Dictionary) -> void:

	# Launched from a board, not a world prop — so return the player to where they stood (the spawn
	# resolver falls back to this when there's no anchor). Then unpause + change scene like a Puzzle does.
	var player : Node = get_tree().get_first_node_in_group("player")
	if player is Node2D:
		PlayerState.request_spawn_at_position((player as Node2D).global_position)
	if get_tree() != null:
		get_tree().paused = false
	Audio.play_sfx("whoosh")
	get_tree().change_scene_to_file(String(job["scene"]))


func _on_dim_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:

	queue_free()


# --- styling (matches VoyagesBoard's walnut/brass) -------------------

func _make_title(text: String) -> Label:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_caption(text: String) -> Label:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.82, 0.74, 0.56, 1.0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_color_disabled", Color(0.6, 0.55, 0.44, 0.8))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.24, 0.16, 0.09, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		elif state == "disabled":
			bg = Color(0.15, 0.11, 0.07, 0.55)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0) if state != "disabled" else Color(0.42, 0.32, 0.2, 0.6)
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 18.0
		s.content_margin_right = 18.0
		s.content_margin_top = 7.0
		s.content_margin_bottom = 7.0
		btn.add_theme_stylebox_override(state, s)
	return btn


func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.97)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(26)
	return s


func _row_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.14, 0.08, 0.92)
	s.border_color = Color(0.5, 0.4, 0.22, 1.0)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(12)
	return s

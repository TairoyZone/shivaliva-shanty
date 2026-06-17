## ShoppeJobsBoard — a YPP "Shoppe Jobs"-style notice board listing the labour puzzles you can take on
## (Mining + Woodcutting). Each row shows the trade + its wage and a "Go" that takes you TO the work-site
## (the Mine / the Forest), dropped next to the sign — you walk up + click it to start. A self-freeing modal
## CanvasLayer; opened from the InventoryPanel Jobs tab (part of the Sunshine Widget user panel).
## Modelled on [VoyagesBoard]. See [[ypp-template]].
class_name ShoppeJobsBoard
extends CanvasLayer

const GROUP : StringName = &"shoppe_jobs_board"

var _panel : PanelContainer   # pop-in / dismiss target
var _dim : ColorRect

## The labour jobs surfaced here. `hired` = the PlayerState flag gating it; `site` = where to apply.
const JOBS : Array = [
	{"title": "Mining", "location": "res://levels/mine/mine.tscn", "anchor": "MiningSign",
		"wage": "2 gold per ore", "hired": "hired_at_forge", "site": "the Forge"},
	{"title": "Woodcutting", "location": "res://levels/forest/forest.tscn", "anchor": "WoodCuttingSign",
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
	_dim = dim

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
	_panel = panel

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
	var back : Button = _make_button("Never mind", Palette.ACCENT)
	back.pressed.connect(_close)
	vbox.add_child(back)
	# ESC closes the board — the ONE reusable primitive (standing rule), not a hand-rolled _unhandled_input.
	add_child(EscToClose.new(_close))
	ModalFx.appear(_panel, _dim)   # fade + pop in (animate-everything)


func _make_job_row(job: Dictionary) -> PanelContainer:

	var hired : bool = bool(PlayerState.get(String(job["hired"])))
	var row_panel : PanelContainer = PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _row_style())
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row_panel.add_child(row)

	var info : Label = Label.new()
	var sub : String = String(job["wage"])
	if not hired:
		sub += "   ·   get hired at %s first" % String(job["site"])
	info.text = "%s\n%s" % [String(job["title"]), sub]
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	# "Go" always takes you to the work-site (head there to apply / look even before you're hired).
	var go : Button = _make_button("Go", Palette.POSITIVE)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_on_go.bind(job))
	row.add_child(go)
	return row_panel


func _on_go(job: Dictionary) -> void:

	# Take the player TO the work-site (the Mine / the Forest), spawned next to the sign — they walk up +
	# click it to start the puzzle (which gates on being hired). Not straight into the puzzle.
	PlayerState.request_spawn_at_anchor(String(job["anchor"]))
	if get_tree() != null:
		get_tree().paused = false
	Audio.play_sfx("whoosh")
	get_tree().change_scene_to_file(String(job["location"]))


func _on_dim_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:

	ModalFx.dismiss(self, _panel, _dim, _do_close)   # scale + fade out, THEN free (_exit_tree unpauses)


func _do_close() -> void:

	queue_free()


# --- styling (matches VoyagesBoard's walnut/brass) -------------------

func _make_title(text: String) -> Label:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	UiStyle.apply_title(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_caption(text: String) -> Label:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	UiStyle.apply_muted(l)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 18)
	UiStyle.style_button(btn, font_color)
	return btn


func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = UiStyle.panel(true)
	s.set_content_margin_all(26)
	return s


func _row_style() -> StyleBoxFlat:

	return UiStyle.card()

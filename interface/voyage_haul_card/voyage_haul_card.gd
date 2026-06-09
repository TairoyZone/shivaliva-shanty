## THE BOOTY DIVVY — shown at a voyage's END (the YPP "ye received X PoE" beat). The whole
## pillage's plunder is POOLED and paid as one cut here, not per stop. Tree-pausing modal;
## emits `closed` so the caller can cash out + step onto the isle. Placeholder-first _draw-free
## (styled labels), gold-accented.
class_name VoyageHaulCard
extends CanvasLayer


signal closed

static func create(destination: String) -> VoyageHaulCard:

	var c : VoyageHaulCard = VoyageHaulCard.new()
	c._dest = destination
	return c


var _dest : String = ""
var _closed : bool = false


func _ready() -> void:

	layer = 52
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var panel : PanelContainer = PanelContainer.new()
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.05, 0.98)
	sb.border_color = Color(0.96, 0.78, 0.34, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(30)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	# The divvy: a flat pool from the battles, then YOUR share scaled by how you flew the crossing.
	var pool : int = PlayerState.voyage_total_gold()
	var rating_idx : int = PlayerState.voyage_duty_rating_index()
	var mult : float = PlayerState.voyage_duty_multiplier()
	var final_cut : int = PlayerState.voyage_final_cut()

	_add(col, "VOYAGE'S END", 30, Color(0.98, 0.90, 0.55, 1.0), 3)
	if not _dest.is_empty():
		_add(col, "Made port at %s" % _dest, 17, Color(0.80, 0.88, 0.98, 1.0), 2)
	col.add_child(_spacer(10))
	_add(col, "BOOTY DIVVY", 14, Color(0.70, 0.78, 0.92, 1.0), 2)
	if pool > 0:
		_add(col, "Plunder pool:  %d gold" % pool, 15, Color(0.80, 0.84, 0.92, 1.0), 2)
		if rating_idx < 0:   # a pure passenger — manned nothing all run; a par cut, not a botch
			_add(col, "Crew duty:  off duty   ×%.1f" % mult, 16, Color(0.62, 0.66, 0.74, 1.0), 2)
		else:
			_add(col, "Crew duty:  %s   ×%.1f" % [DutyReport.rating_name(rating_idx), mult], 16,
				DutyReport.rating_color(rating_idx), 2)
		col.add_child(_spacer(4))
	_add(col, "%d gold" % final_cut, 40, Color(0.99, 0.84, 0.36, 1.0), 4)
	_add(col, "your cut of the plunder" if final_cut > 0 else "no plunder this run", 14,
		Color(0.74, 0.80, 0.92, 1.0), 2)
	col.add_child(_spacer(12))

	var btn : Button = Button.new()
	btn.text = "Step ashore"
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(_close)
	col.add_child(btn)

	add_child(EscToClose.new(_close))


func _add(parent: VBoxContainer, text: String, size: int, color: Color, outline: int) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)


func _spacer(h: float) -> Control:

	var c : Control = Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c


func _on_dim_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:

	if get_tree() != null:
		get_tree().paused = false
	if not _closed:
		_closed = true
		closed.emit()
	queue_free()


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false
	if not _closed:
		_closed = true
		closed.emit()

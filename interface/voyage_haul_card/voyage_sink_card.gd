## LOST IN THE STARDUST — shown when the ship SINKS on a fight leg (the Stardust reached SINK_LEVEL).
## The whole booty pool is FORFEIT and she's towed home + dry-docked (a gold toll), but the DEED is
## kept and the hull comes back mended — she limps home, no death spiral. Tree-pausing modal; emits
## `closed` so the Loft can relocate home. Mirrors [VoyageHaulCard]. See [[ship-condition-research]].
class_name VoyageSinkCard
extends CanvasLayer


signal closed

static func create(forfeited: int, toll: int) -> VoyageSinkCard:

	var c : VoyageSinkCard = VoyageSinkCard.new()
	c._forfeited = forfeited
	c._toll = toll
	return c


var _forfeited : int = 0
var _toll : int = 0
var _closed : bool = false


func _ready() -> void:

	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.06, 0.72)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var panel : PanelContainer = PanelContainer.new()
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.06, 0.12, 0.98)
	sb.border_color = Color(0.85, 0.40, 0.45, 0.95)
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

	_add(col, "LOST IN THE STARDUST", 30, Color(1.0, 0.55, 0.55), 3)
	_add(col, "The Stardust swallowed the deck — she went under.", 16, Color(0.86, 0.82, 0.92), 2)
	col.add_child(_spacer(10))
	if _forfeited > 0:
		_add(col, "Booty forfeited:  %d gold" % _forfeited, 15, Color(0.92, 0.78, 0.5), 2)
	_add(col, "Towed home + dry-docked:  -%d gold" % _toll, 15, Color(1.0, 0.7, 0.6), 2)
	_add(col, "She's patched and afloat — the hull's mended.", 14, Color(0.7, 0.86, 0.78), 2)
	col.add_child(_spacer(12))

	var btn : Button = Button.new()
	btn.text = "Limp home"
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

## THE DUTY REPORT PANEL — the YPP-style "how'd the crew do last leg" sheet, opened from
## the [ShipDeck]. Lists each hand · their duty · their rating (Booched..Incredible, coloured
## by [DutyReport]). YOUR row (the Loft) is highlighted. Click the dim or Dismiss to close.
## Placeholder-first: a colour swatch stands in for each crewmate's portrait.
class_name DutyReportPanel
extends CanvasLayer


signal closed   # dismissed — the Loft uses this to continue the voyage (next leg / disembark)

# Build a panel for a given report snapshot (PlayerState.last_duty_report). Add it to the tree.
static func create(report: Array) -> DutyReportPanel:

	var p : DutyReportPanel = DutyReportPanel.new()
	p._report = report
	return p


var _report : Array = []
var _closed : bool = false   # emit `closed` exactly once


func _ready() -> void:

	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS   # stays live while the tree is paused
	add_to_group("duty_report")               # so the deck never stacks two at once
	# Pause the deck while the report's up (matches VoyagesBoard) so E can't fire
	# man-the-Loft / board / disembark behind the panel and orphan it.
	get_tree().paused = true

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var panel : PanelContainer = PanelContainer.new()
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.12, 0.20, 0.98)
	sb.border_color = Color(0.62, 0.70, 0.40, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(20)
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
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var title : Label = Label.new()
	title.text = "DUTY REPORT"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.98, 0.90, 0.55, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sub : Label = Label.new()
	sub.text = "— how the crew fared last leg —"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.72, 0.80, 0.92, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	col.add_child(_spacer(6))

	if _report.is_empty():
		var none : Label = Label.new()
		none.text = "No leg sailed yet — man the Loft to log a report."
		none.add_theme_font_size_override("font_size", 16)
		none.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 1.0))
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(none)
	else:
		var grid : GridContainer = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 8)
		col.add_child(grid)
		_header(grid, "")
		_header(grid, "DUTY")
		_header(grid, "HAND")
		_header(grid, "RATING")
		for entry in _report:
			_row(grid, entry)

	col.add_child(_spacer(8))

	var dismiss : Button = Button.new()
	dismiss.text = "Dismiss"
	dismiss.add_theme_font_size_override("font_size", 16)
	dismiss.pressed.connect(_close)
	col.add_child(dismiss)


# One report line: [swatch] [duty] [name] [rating]. Player row brightened.
func _row(grid: GridContainer, entry: Dictionary) -> void:

	var is_player : bool = bool(entry.get("is_player", false))
	var tint : Color = entry.get("tint", Color.WHITE)

	var swatch : ColorRect = ColorRect.new()
	swatch.color = tint
	swatch.custom_minimum_size = Vector2(18.0, 18.0)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(swatch)

	var duty : Label = Label.new()
	duty.text = String(entry.get("duty", ""))
	duty.add_theme_font_size_override("font_size", 17)
	duty.add_theme_color_override("font_color", Color(0.74, 0.82, 0.96, 1.0))
	grid.add_child(duty)

	var nm : Label = Label.new()
	nm.text = ("%s  (you)" % String(entry.get("name", ""))) if is_player else String(entry.get("name", ""))
	nm.add_theme_font_size_override("font_size", 17)
	nm.add_theme_color_override("font_color",
		Color(1.0, 0.94, 0.66, 1.0) if is_player else Color(0.90, 0.92, 0.98, 1.0))
	grid.add_child(nm)

	var idx : int = int(entry.get("rating_idx", 0))
	var rate : Label = Label.new()
	rate.text = DutyReport.rating_name(idx)
	rate.add_theme_font_size_override("font_size", 17)
	rate.add_theme_color_override("font_color", DutyReport.rating_color(idx))
	rate.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	rate.add_theme_constant_override("outline_size", 2)
	grid.add_child(rate)


func _header(grid: GridContainer, text: String) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.58, 0.66, 0.80, 1.0))
	grid.add_child(l)


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

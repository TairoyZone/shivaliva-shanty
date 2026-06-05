## A floating badge shown above a parlor table when an NPC is already
## hosting a game there: the host's name + "open seat", tinted in their
## colour, with a small coloured pip per seated patron. Purely cosmetic —
## it's what makes the parlor read as alive before you walk up. The join
## flow lives in [ParlorBrowser] (the table rows). See [[parlor-social-system]].
class_name ParlorHostBadge
extends Node2D


var _host_name : String = ""
var _host_color : Color = Color.WHITE
var _patron_colors : Array[Color] = []


static func create(host_name: String, host_color: Color, patron_colors: Array[Color], y_offset: float) -> ParlorHostBadge:

	var badge : ParlorHostBadge = ParlorHostBadge.new()
	badge._host_name = host_name
	badge._host_color = host_color
	badge._patron_colors = patron_colors.duplicate()
	badge.position = Vector2(0.0, y_offset)
	return badge


func _ready() -> void:

	# Float above the table regardless of Y-sort depth.
	z_index = 60
	var label : Label = Label.new()
	label.text = "%s's table  ·  open seat" % _host_name
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", _host_color.lightened(0.35))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(240.0, 20.0)
	label.position = Vector2(-120.0, -26.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	queue_redraw()


# Draw a row of small tinted pips (one per seated patron) just under the
# label, so you can read at a glance how full the table is.
func _draw() -> void:

	var n : int = _patron_colors.size()
	if n == 0:
		return
	const SPACING : float = 13.0
	const RADIUS : float = 4.0
	var start_x : float = -(n - 1) * SPACING * 0.5
	for i in n:
		var c : Color = _patron_colors[i]
		var p : Vector2 = Vector2(start_x + i * SPACING, 0.0)
		draw_circle(p, RADIUS, c)
		draw_arc(p, RADIUS, 0.0, TAU, 14, c.darkened(0.45), 1.2)
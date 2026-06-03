## Cogwise Godfrey's ship shop — a drafting desk in the Workshop the
## player interacts with to ORDER a spacecraft. Mirrors the
## [HiringBoard] modal formula (walnut/brass panel, paused tree, open
## guard, _exit_tree cleanup) — just with a catalog of ships to buy.
##
## Buying a ship spends gold AND consumes that much of Godfrey's
## delivered lumber stock ([member PlayerState.godfrey_lumber_stock]) —
## he builds the hull from the wood you chopped + delivered, closing the
## Lumberjacking loop. Ownership is vanity for now; the travel/sailing
## arc that USES the ships is far-future (see [[gameplay-design]]).
@tool
class_name ShipShop
extends Interactable


## The catalog — small → large. The starter Driftpod is GOLD-ONLY (the MVP goal); bigger
## hulls also want lumber delivered to Godfrey. ids persist in owned_ships; keep them stable.
const SHIPS : Array = [
	{
		"id": "driftpod", "name": "Driftpod",
		"gold": 750, "lumber": 0,
		"blurb": "A one-seat skiff for short hops between nearby rocks.",
	},
	{
		"id": "cloudcutter", "name": "Cloud Cutter",
		"gold": 3000, "lumber": 220,
		"blurb": "A nimble cutter — room for a small crew and some cargo.",
	},
	{
		"id": "skygalleon", "name": "Sky Galleon",
		"gold": 10000, "lumber": 550,
		"blurb": "A great hull built for long voyages across the void.",
	},
]

# --- Visual placeholder (a drafting desk with a ship blueprint) -------
const DESK_HALF_WIDTH : float = 46.0
const DESK_HEIGHT : float = 30.0
const DESK_LEG_HEIGHT : float = 26.0
const BLUEPRINT_W : float = 60.0
const BLUEPRINT_H : float = 40.0

const COLOR_DESK_TOP : Color = Color(0.50, 0.32, 0.14, 1.0)
const COLOR_DESK_LEG : Color = Color(0.34, 0.20, 0.09, 1.0)
const COLOR_FRAME : Color = Color(0.18, 0.10, 0.04, 1.0)
const COLOR_BLUEPRINT : Color = Color(0.20, 0.42, 0.62, 1.0)
const COLOR_BLUEPRINT_LINE : Color = Color(0.80, 0.90, 1.0, 0.85)

## The open modal (null when closed). Guards against stacking.
var _modal : CanvasLayer = null
## Re-render rows live when a purchase lands.
var _rows_vbox : VBoxContainer = null


func interact() -> void:

	if Engine.is_editor_hint():
		return
	_show_modal()


func _exit_tree() -> void:

	if is_instance_valid(_modal):
		get_tree().paused = false
		_modal.queue_free()
		_modal = null


func _show_modal() -> void:

	if is_instance_valid(_modal):
		return
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	# Dimmer.
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	# Panel.
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	# Title.
	var title : Label = Label.new()
	title.text = "SHIPWRIGHT — ORDER A SPACECRAFT"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	# Hint line — how purchases are paid.
	var hint : Label = Label.new()
	hint.text = "Paid in gold — bigger hulls also want lumber delivered to Godfrey."
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.82, 0.7, 0.45, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	# Ship rows.
	_rows_vbox = VBoxContainer.new()
	_rows_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(_rows_vbox)
	_rebuild_rows()
	# Close button.
	var close_btn : Button = _make_walnut_button("Close", Color(0.95, 0.84, 0.56, 1.0))
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)
	_modal = layer
	add_child(layer)
	get_tree().paused = true
	# Live-refresh the rows when a purchase changes ownership / stock.
	PlayerState.ships_changed.connect(_rebuild_rows)


# Build (or rebuild) one row per ship. Re-run after a purchase so the
# bought ship flips to "Owned" and others re-evaluate affordability.
func _rebuild_rows() -> void:

	if _rows_vbox == null:
		return
	for child in _rows_vbox.get_children():
		child.queue_free()
	for ship in SHIPS:
		_rows_vbox.add_child(_make_ship_row(ship))


func _make_ship_row(ship: Dictionary) -> Control:

	var row : PanelContainer = PanelContainer.new()
	row.add_theme_stylebox_override("panel", _build_row_style())
	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)
	# Left: name + blurb + cost.
	var info : VBoxContainer = VBoxContainer.new()
	info.custom_minimum_size = Vector2(360.0, 0.0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)
	_add_label(info, String(ship["name"]), 20, Color(0.98, 0.88, 0.5, 1.0))
	_add_label(info, String(ship["blurb"]), 14, Color(0.86, 0.78, 0.6, 1.0))
	var cost_text : String = "%d gold" % int(ship["gold"])
	if int(ship["lumber"]) > 0:
		cost_text += "  +  %d lumber" % int(ship["lumber"])
	_add_label(info, cost_text, 15, Color(0.80, 0.92, 1.0, 1.0))
	# Right: Buy / Owned / can't-afford button.
	var owned : bool = PlayerState.owns_ship(String(ship["id"]))
	var can_buy : bool = PlayerState.can_buy_ship(
		String(ship["id"]), int(ship["gold"]), int(ship["lumber"]))
	var btn : Button
	if owned:
		btn = _make_walnut_button("Owned", Color(0.7, 0.9, 0.7, 1.0))
		btn.disabled = true
	elif can_buy:
		btn = _make_walnut_button("Buy", Color(0.78, 1.0, 0.62, 1.0))
		btn.pressed.connect(_on_buy_pressed.bind(ship))
	else:
		btn = _make_walnut_button("Can't afford", Color(0.9, 0.6, 0.5, 1.0))
		btn.disabled = true
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn)
	return row


func _on_buy_pressed(ship: Dictionary) -> void:

	PlayerState.buy_ship(
		String(ship["id"]), int(ship["gold"]), int(ship["lumber"]))
	# ships_changed fires → _rebuild_rows updates the buttons.


func _on_close_pressed() -> void:

	get_tree().paused = false
	if PlayerState.ships_changed.is_connected(_rebuild_rows):
		PlayerState.ships_changed.disconnect(_rebuild_rows)
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_rows_vbox = null


func _add_label(parent: VBoxContainer, text: String, size: int, color: Color) -> void:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(label)


func _build_panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.98)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 24
	s.content_margin_bottom = 24
	return s


func _build_row_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.08, 0.04, 0.9)
	s.border_color = Color(0.5, 0.36, 0.18, 1.0)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_right = 8
	s.corner_radius_bottom_left = 8
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _make_walnut_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.22, 0.14, 0.08, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		elif state == "disabled":
			bg = bg.darkened(0.30)
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

	# Drafting desk — a top slab on two short legs, with a blueprint
	# sheet propped on it showing a tiny ship silhouette.
	var top_y : float = -DESK_LEG_HEIGHT
	# Legs.
	draw_rect(Rect2(-DESK_HALF_WIDTH + 4.0, top_y, 6.0, DESK_LEG_HEIGHT), COLOR_DESK_LEG)
	draw_rect(Rect2(DESK_HALF_WIDTH - 10.0, top_y, 6.0, DESK_LEG_HEIGHT), COLOR_DESK_LEG)
	# Desk top.
	var top_rect : Rect2 = Rect2(-DESK_HALF_WIDTH, top_y - DESK_HEIGHT, DESK_HALF_WIDTH * 2.0, DESK_HEIGHT)
	draw_rect(top_rect, COLOR_DESK_TOP)
	draw_rect(top_rect, COLOR_FRAME, false, 1.5)
	# Blueprint sheet propped on the desk.
	var bp : Rect2 = Rect2(-BLUEPRINT_W * 0.5, top_y - DESK_HEIGHT - BLUEPRINT_H + 4.0, BLUEPRINT_W, BLUEPRINT_H)
	draw_rect(bp, COLOR_BLUEPRINT)
	draw_rect(bp, COLOR_FRAME, false, 2.0)
	# Tiny ship silhouette on the blueprint (a hull + mast).
	var cx : float = bp.position.x + BLUEPRINT_W * 0.5
	var hull_y : float = bp.position.y + BLUEPRINT_H * 0.62
	var hull : PackedVector2Array = PackedVector2Array([
		Vector2(cx - 18.0, hull_y),
		Vector2(cx + 18.0, hull_y),
		Vector2(cx + 11.0, hull_y + 9.0),
		Vector2(cx - 11.0, hull_y + 9.0),
	])
	draw_colored_polygon(hull, COLOR_BLUEPRINT_LINE)
	draw_line(Vector2(cx, hull_y), Vector2(cx, hull_y - 16.0), COLOR_BLUEPRINT_LINE, 1.6)
	draw_line(Vector2(cx, hull_y - 16.0), Vector2(cx + 12.0, hull_y - 6.0), COLOR_BLUEPRINT_LINE, 1.4)
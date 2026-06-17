## Cogwise Godfrey's ship shop — a drafting desk in the Workshop the
## player interacts with to ORDER a spacecraft. Mirrors the
## [HiringBoard] modal formula (walnut/brass panel, paused tree, open
## guard, _exit_tree cleanup) — just with a catalog of ships to buy.
##
## Ships are bought with GOLD ONLY — the single earned currency, earn-and-keep
## (no second resource gate). Ownership unlocks the voyage loop (the Skydock helm).
@tool
class_name ShipShop
extends Interactable


# The catalog lives in ShipClasses.DEFS (components/ships/ — the single source of truth for
# prices, blurbs AND the per-class stats), so the shop can never drift from the mechanics.

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

	if Engine.is_editor_hint():
		return   # @tool: autoloads don't exist at edit time — closing the scene tab must not touch PlayerState
	# Mirror _on_close_pressed's cleanup in case the shop is freed (scene change) with the modal still open.
	if PlayerState.ships_changed.is_connected(_rebuild_rows):
		PlayerState.ships_changed.disconnect(_rebuild_rows)
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
	UiStyle.apply_title(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	# Hint line — how purchases are paid.
	var hint : Label = Label.new()
	hint.text = "Paid in gold — what you've earned is yours to spend."
	hint.add_theme_font_size_override("font_size", 15)
	UiStyle.apply_muted(hint)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	# Ship rows.
	_rows_vbox = VBoxContainer.new()
	_rows_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(_rows_vbox)
	_rebuild_rows()
	# Close button.
	var close_btn : Button = _make_walnut_button("Close", Palette.ACCENT)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)
	_modal = layer
	add_child(layer)
	layer.add_child(EscToClose.new(_on_close_pressed))   # ESC closes the shop (standing rule — on the MODAL, not the post)
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
	for ship_id in ShipClasses.DEFS:
		_rows_vbox.add_child(_make_ship_row(String(ship_id)))


func _make_ship_row(ship_id: String) -> Control:

	var def : Dictionary = ShipClasses.get_def(ship_id)
	var row : PanelContainer = PanelContainer.new()
	row.add_theme_stylebox_override("panel", _build_row_style())
	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)
	# Left: name + blurb + the class STATS (why a bigger hull costs more) + cost.
	var info : VBoxContainer = VBoxContainer.new()
	info.custom_minimum_size = Vector2(360.0, 0.0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)
	var owned : bool = PlayerState.owns_ship(ship_id)
	var shown_name : String = String(def["display"])
	if owned and PlayerState.ship_name(ship_id) != shown_name:
		shown_name += "  —  the %s" % PlayerState.ship_name(ship_id)   # her christened name, proudly
	_add_label(info, shown_name, 20, Palette.ACCENT)
	_add_label(info, String(def["blurb"]), 14, Palette.TEXT_MUTED)
	_add_label(info, ShipClasses.stat_line(ship_id), 13, Palette.TEXT_MUTED)
	_add_label(info, "%d gold" % int(def["gold"]), 15, Palette.TEXT_PRIMARY)
	# Right: Buy / Owned / can't-afford button.
	var can_buy : bool = PlayerState.can_buy_ship(ship_id, int(def["gold"]))
	var btn : Button
	if owned:
		btn = _make_walnut_button("Owned", Palette.POSITIVE)
		btn.disabled = true
	elif can_buy:
		btn = _make_walnut_button("Buy", Palette.POSITIVE)
		btn.pressed.connect(_on_buy_pressed.bind(ship_id))
	else:
		btn = _make_walnut_button("Can't afford", Palette.DANGER)
		btn.disabled = true
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn)
	return row


func _on_buy_pressed(ship_id: String) -> void:

	if not PlayerState.buy_ship(ship_id, ShipClasses.gold_cost(ship_id)):
		return
	Audio.play_sfx("powerup")   # the biggest purchase in the game lands with a fanfare
	# ships_changed fires → _rebuild_rows updates the buttons. Then the christening beat:
	# she's YOURS — name her (skippable; she keeps the class name until christened).
	ShipChristening.open(self, ship_id)


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
	# Light schemes (dark text on a light page) want NO outline — a black halo just muddies dark ink.
	if Palette.IS_DARK:
		label.add_theme_color_override("font_outline_color", Palette.OUTLINE_HARD)
		label.add_theme_constant_override("outline_size", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(label)


# Themed modal panel from the central UiStyle factory (adapts to the active scheme, light or dark).
func _build_panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = UiStyle.panel(true)
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 24
	s.content_margin_bottom = 24
	return s


# Themed list-row (dark-token raised card — text on it uses TEXT_PRIMARY / TEXT_MUTED).
func _build_row_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = UiStyle.card()
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


# Themed button — routed through UiStyle.style_button. [param font_color] carries the SEMANTIC
# label hue (POSITIVE for buy/owned, DANGER for can't-afford, ACCENT for neutral).
func _make_walnut_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 18)
	UiStyle.style_button(btn, font_color)
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
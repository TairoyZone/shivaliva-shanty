## Cinder Troy's weapon rack — an anvil-side stand in the Forge the player interacts
## with to BUY a Skirmish weapon (the Sword / Long Shot) for gold; it's appended to
## [member PlayerState.owned_weapons], then equipped in the inventory (Backpack tab).
## Fists is free (you always have it), so it's not for sale. Mirrors [ShipShop]'s modal
## formula (walnut/brass panel, paused tree, open-guard, _exit_tree cleanup) — gold-only.
## See [SkirmishWeapon] / [[combat-puzzle-direction]].
@tool
class_name WeaponShop
extends Interactable


## The catalog — the buyable weapons (Fists is free, never listed). Prices tunable.
## ids match [constant SkirmishWeapon.ALL]; names/blurbs come from SkirmishWeapon.
const WEAPONS_FOR_SALE : Array = [
	{"id": "sword", "gold": 150},
	{"id": "long_range", "gold": 250},
]

# --- Visual placeholder (an anvil with a blade resting on it) ---------
const COLOR_ANVIL : Color = Color(0.22, 0.23, 0.27, 1.0)
const COLOR_ANVIL_DK : Color = Color(0.14, 0.15, 0.18, 1.0)
const COLOR_BASE : Color = Color(0.34, 0.20, 0.09, 1.0)
const COLOR_STEEL : Color = Color(0.80, 0.82, 0.88, 1.0)
const COLOR_GOLD : Color = Color(0.86, 0.68, 0.30, 1.0)

var _modal : CanvasLayer = null
var _rows_vbox : VBoxContainer = null


func interact() -> void:

	if Engine.is_editor_hint():
		return
	_show_modal()


func _exit_tree() -> void:

	# Mirror _on_close_pressed's cleanup in case the shop is freed (scene change) with the modal still open.
	if PlayerState.weapons_changed.is_connected(_rebuild_rows):
		PlayerState.weapons_changed.disconnect(_rebuild_rows)
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
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	var title : Label = Label.new()
	title.text = "CINDER TROY'S FORGE — ARM YERSELF"
	title.add_theme_font_size_override("font_size", 28)
	UiStyle.apply_title(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var hint : Label = Label.new()
	hint.text = "Forged in good steel — equip what ye buy in yer Backpack."
	hint.add_theme_font_size_override("font_size", 15)
	UiStyle.apply_muted(hint)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	_rows_vbox = VBoxContainer.new()
	_rows_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(_rows_vbox)
	_rebuild_rows()
	var close_btn : Button = _make_walnut_button("Close", Palette.ACCENT)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)
	_modal = layer
	add_child(layer)
	layer.add_child(EscToClose.new(_on_close_pressed))   # ESC closes the shop (standing rule — on the MODAL, not the post)
	get_tree().paused = true
	PlayerState.weapons_changed.connect(_rebuild_rows)


func _rebuild_rows() -> void:

	if _rows_vbox == null:
		return
	for child in _rows_vbox.get_children():
		child.queue_free()
	for entry in WEAPONS_FOR_SALE:
		_rows_vbox.add_child(_make_weapon_row(entry))


func _make_weapon_row(entry: Dictionary) -> Control:

	var wid : String = String(entry["id"])
	var gold : int = int(entry["gold"])
	var row : PanelContainer = PanelContainer.new()
	row.add_theme_stylebox_override("panel", _build_row_style())
	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)
	# Procedural weapon icon.
	var icon : WeaponIcon = WeaponIcon.new()
	icon.weapon_id = wid
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)
	# Name + blurb + cost.
	var info : VBoxContainer = VBoxContainer.new()
	info.custom_minimum_size = Vector2(360.0, 0.0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)
	_add_label(info, SkirmishWeapon.display_name(wid), 20, Palette.ACCENT)
	_add_label(info, String(SkirmishWeapon.DESCRIPTIONS.get(wid, "")), 14, Palette.TEXT_MUTED)
	_add_label(info, "%d gold" % gold, 15, Palette.TEXT_PRIMARY)
	# Buy / Owned / can't-afford.
	var btn : Button
	if PlayerState.owns_weapon(wid):
		btn = _make_walnut_button("Owned", Palette.POSITIVE)
		btn.disabled = true
	elif PlayerState.can_buy_weapon(wid, gold):
		btn = _make_walnut_button("Buy", Palette.POSITIVE)
		btn.pressed.connect(_on_buy_pressed.bind(entry))
	else:
		btn = _make_walnut_button("Can't afford", Palette.DANGER)
		btn.disabled = true
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn)
	return row


func _on_buy_pressed(entry: Dictionary) -> void:

	if PlayerState.buy_weapon(String(entry["id"]), int(entry["gold"])):
		Audio.play_sfx("pickup")   # forged steel in hand — distinct from the generic backpack thunk
	# weapons_changed fires → _rebuild_rows updates the buttons.


func _on_close_pressed() -> void:

	get_tree().paused = false
	if PlayerState.weapons_changed.is_connected(_rebuild_rows):
		PlayerState.weapons_changed.disconnect(_rebuild_rows)
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

	# An anvil on a wooden base, a blade resting across its face.
	# Base.
	draw_rect(Rect2(-20.0, -16.0, 40.0, 16.0), COLOR_BASE)
	draw_rect(Rect2(-20.0, -16.0, 40.0, 16.0), COLOR_ANVIL_DK, false, 1.5)
	# Anvil body (waist) + top face + horn.
	draw_rect(Rect2(-9.0, -34.0, 18.0, 18.0), COLOR_ANVIL)
	var top : PackedVector2Array = PackedVector2Array([
		Vector2(-22.0, -34.0), Vector2(20.0, -34.0),
		Vector2(30.0, -40.0), Vector2(20.0, -44.0),
		Vector2(-18.0, -44.0), Vector2(-22.0, -40.0)])
	draw_colored_polygon(top, COLOR_ANVIL)
	draw_polyline(top + PackedVector2Array([top[0]]), COLOR_ANVIL_DK, 1.5)
	# A blade resting across the anvil face (steel + gold guard).
	draw_rect(Rect2(-26.0, -49.0, 44.0, 4.0), COLOR_STEEL)
	draw_rect(Rect2(14.0, -52.0, 4.0, 10.0), COLOR_GOLD)
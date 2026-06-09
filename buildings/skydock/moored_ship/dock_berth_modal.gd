## DockBerthModal — YOUR BERTH at the Skydock: the ship-management hub opened by clicking the moored
## ship. Lists every owned hull — christened name, class, stat line, live condition — with per-ship
## actions: SAIL HER (makes her active + sets out, the old direct-board flow), RENAME (re-christen),
## and SELL (half the catalog price back, two-click confirm so a misclick can't sell your galleon).
## The ★ row is the ACTIVE ship (the one berthed/drawn at the dock). A warm walnut [Modal].
class_name DockBerthModal
extends Modal


const GROUP : StringName = &"dock_berth_modal"

## The id armed for a sale confirm ("" = none) — the Sell button flips to "Sure?" first.
var _confirm_sell : String = ""


static func open(host: Node) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	host.get_tree().root.add_child(DockBerthModal.new())


# --- Modal config -----------------------------------------------------

func _modal_group() -> StringName:
	return GROUP

func _modal_size() -> Vector2:
	return Vector2(560.0, 150.0 + 118.0 * float(maxi(PlayerState.owned_ships.size(), 1)))


func _build_content() -> void:

	PlayerState.ships_changed.connect(_render)
	_render()


func _render() -> void:

	if PlayerState.owned_ships.is_empty():   # sold the last hull from this very panel
		_close()
		return
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

	var title : Label = Label.new()
	title.text = "YOUR BERTH"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	var sub : Label = Label.new()
	sub.text = "— the ★ ship is berthed here, ready to sail —"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.82, 0.74, 0.56, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(sub)

	for sid in PlayerState.owned_ships:
		_content.add_child(_ship_card(String(sid)))

	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close : Button = _btn("Close", 15)
	close.pressed.connect(_close)
	row.add_child(close)
	_content.add_child(row)


func _ship_card(sid: String) -> Control:

	var active : bool = sid == PlayerState.active_ship_id()
	var card : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.08, 0.04, 0.92)
	s.border_color = Color(0.95, 0.80, 0.40, 1.0) if active else Color(0.5, 0.36, 0.18, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", s)

	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var info : VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	hbox.add_child(info)
	var holes : int = PlayerState.ship_holes_of(sid)
	var cond : String = "hull sound" if holes <= 0 else ("%d hole%s open" % [holes, "" if holes == 1 else "s"])
	var name_l : Label = Label.new()
	name_l.text = "%s%s   (%s)" % ["★ " if active else "", PlayerState.ship_name(sid), ShipClasses.display(sid)]
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", Color(0.98, 0.90, 0.55, 1.0) if active else Color(0.90, 0.84, 0.70, 1.0))
	info.add_child(name_l)
	_small(info, ShipClasses.stat_line(sid), Color(0.72, 0.86, 0.72, 1.0))
	_small(info, cond, Color(0.70, 0.92, 0.74, 1.0) if holes <= 0 else Color(0.96, 0.68, 0.5, 1.0))

	var btns : VBoxContainer = VBoxContainer.new()
	btns.add_theme_constant_override("separation", 4)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btns)
	var sail : Button = _btn("Sail her" if active else "Sail her (make ★)", 14)
	sail.pressed.connect(_on_sail.bind(sid))
	btns.add_child(sail)
	var sub_row : HBoxContainer = HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 4)
	btns.add_child(sub_row)
	var rename : Button = _btn("Rename", 12)
	rename.pressed.connect(_on_rename.bind(sid))
	sub_row.add_child(rename)
	var price : int = ShipClasses.sell_price(sid)
	var sell : Button = _btn(("Sure? +%dg" % price) if _confirm_sell == sid else ("Sell %dg" % price), 12)
	if _confirm_sell == sid:
		sell.add_theme_color_override("font_color", Color(1.0, 0.62, 0.5, 1.0))
	sell.pressed.connect(_on_sell.bind(sid))
	sub_row.add_child(sell)
	return card


func _on_sail(sid: String) -> void:

	PlayerState.set_active_ship(sid)   # no-op when she's already the ★
	var tree : SceneTree = get_tree()
	if tree.current_scene != null:
		PlayerState.voyage_home_scene = tree.current_scene.scene_file_path   # where to step off on disembark
	var scene : String = PlayerState.captain_own_voyage()
	if scene.is_empty():
		return
	tree.paused = false
	tree.change_scene_to_file(scene)
	queue_free()


func _on_rename(sid: String) -> void:

	ShipChristening.open(self, sid)
	# ships_changed on christen → _render refreshes her name here.


func _on_sell(sid: String) -> void:

	if _confirm_sell != sid:   # first click only ARMS the sale
		_confirm_sell = sid
		_render()
		return
	_confirm_sell = ""
	PlayerState.sell_ship(sid)   # ships_changed → _render (or _close when the berth empties)


func _small(parent: VBoxContainer, text: String, color: Color) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)


func _btn(text: String, font_size: int) -> Button:

	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	return b

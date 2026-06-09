## CrewDutyPanel — assign your recruited crew to the voyage's three duty STATIONS (Sailing→the Loft,
## Repair→the Patchworks, Combat→boarding). You man one station live each leg; the crew you post to the OTHER
## two carry them by their CrewSkills rating. Opened from the deck's "Crew Duty" button. A cool deck-themed
## [Modal] (the dim + panel + ESC + ModalFx + pause come from the base). Writes PlayerState.voyage_stations.
class_name CrewDutyPanel
extends Modal


const GROUP : StringName = &"crew_duty_panel"
const INK : Color = Color(0.88, 0.93, 1.0, 1.0)
const INK_SOFT : Color = Color(0.68, 0.76, 0.90, 1.0)
const HEADER : Color = Color(0.62, 0.82, 1.0, 1.0)
const FRAME : Color = Color(0.42, 0.58, 0.82, 1.0)


static func open(host: Node) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	host.get_tree().root.add_child(CrewDutyPanel.new())


# --- Modal config -----------------------------------------------------

func _modal_group() -> StringName:
	return GROUP

func _modal_size() -> Vector2:
	return Vector2(500.0, 420.0)

func _modal_panel_style() -> StyleBoxFlat:
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.13, 0.21, 0.97)
	s.border_color = FRAME
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(20)
	return s


func _build_content(content: VBoxContainer) -> void:

	PlayerState.voyage_stations_changed.connect(_render)   # re-render when an assignment changes (single source)
	_render()


# --- render -----------------------------------------------------------

func _render() -> void:

	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

	var title : Label = Label.new()
	title.text = "Crew Duty"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var sub : Label = Label.new()
	sub.text = "Post a hand to each station — they carry it by their skill while you man another."
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content.add_child(sub)
	_content.add_child(_rule())

	if PlayerState.crew.is_empty():
		var none : Label = Label.new()
		none.text = "No crew yet.\nRecruit a Confidant from their Profile, then post them here."
		none.add_theme_font_size_override("font_size", 14)
		none.add_theme_color_override("font_color", INK_SOFT)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.autowrap_mode = TextServer.AUTOWRAP_WORD
		_content.add_child(none)
	else:
		for station in CrewSkills.STATIONS:
			_content.add_child(_station_row(station))

	_content.add_child(_rule())
	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close : Button = _btn("Done")
	close.pressed.connect(_close)
	row.add_child(close)
	_content.add_child(row)


func _station_row(station: String) -> Control:

	var card : PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	# Station + post label.
	var lab : VBoxContainer = VBoxContainer.new()
	lab.add_theme_constant_override("separation", 0)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l : Label = Label.new()
	name_l.text = station
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", HEADER)
	lab.add_child(name_l)
	var post_l : Label = Label.new()
	post_l.text = String(CrewSkills.STATION_POST.get(station, ""))
	post_l.add_theme_font_size_override("font_size", 12)
	post_l.add_theme_color_override("font_color", INK_SOFT)
	lab.add_child(post_l)
	row.add_child(lab)

	# Crew picker — "— unmanned —" + each recruited hand with their rating for THIS station.
	var pick : OptionButton = OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size = Vector2(212, 34)
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pick.add_theme_font_size_override("font_size", 14)
	pick.add_theme_color_override("font_color", INK)
	_style_option(pick)
	pick.add_item("—  unmanned")
	pick.set_item_metadata(0, "")
	var assigned : String = PlayerState.voyage_station_npc(station)
	var sel : int = 0
	var names : Array = PlayerState.crew.keys()
	for i in names.size():
		var who : String = String(names[i])
		pick.add_item("%s   %s" % [_given(who), CrewSkills.stars(CrewSkills.rating(who, station))])
		pick.set_item_metadata(i + 1, who)
		if who == assigned:
			sel = i + 1
	pick.select(sel)
	pick.item_selected.connect(func(idx: int) -> void: _on_pick(station, String(pick.get_item_metadata(idx))))
	row.add_child(pick)
	return card


func _on_pick(station: String, npc_name: String) -> void:

	# Emits voyage_stations_changed → _render (a hand can only hold one post, so assigning may have cleared
	# another row — the signal rebuilds every row).
	PlayerState.set_voyage_station(station, npc_name)


# --- small builders ---------------------------------------------------

func _given(npc_name: String) -> String:
	var parts : PackedStringArray = npc_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else npc_name


func _rule() -> Control:
	var r : ColorRect = ColorRect.new()
	r.color = Color(FRAME.r, FRAME.g, FRAME.b, 0.5)
	r.custom_minimum_size = Vector2(0, 2)
	return r


func _card_style() -> StyleBoxFlat:
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.18, 0.28, 0.95)
	s.border_color = Color(FRAME.r, FRAME.g, FRAME.b, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _style_option(o: OptionButton) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.16, 0.22, 0.34, 0.96)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.10)
		s.bg_color = bg
		s.border_color = FRAME
		s.set_border_width_all(1)
		s.set_corner_radius_all(7)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		o.add_theme_stylebox_override(state, s)


func _btn(text: String) -> Button:
	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	b.add_theme_constant_override("outline_size", 2)
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.14, 0.20, 0.32, 0.96)
		if state == "hover":
			bg = bg.lightened(0.12)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		s.bg_color = bg
		s.border_color = FRAME
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(state, s)
	return b

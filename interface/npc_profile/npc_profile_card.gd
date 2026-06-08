## NpcProfileCard — a character page for any NPC (the mirror of the player's ★ Profile), opened from the NPC
## radial menu's "Profile". SINGLE-COLUMN (header → crew → standing → about → favour) so it can't overflow.
## The CREW section is the foundation for "start a crew": recruit a CONFIDANT, then promote / demote / dismiss
## them (all via PlayerState's crew model). Modal family (dim + panel + ESC + ModalFx). Built 2026-06-08.
class_name NpcProfileCard
extends CanvasLayer


signal closed

const GROUP : StringName = &"npc_profile_card"
const INK : Color = Color(0.95, 0.88, 0.66, 1.0)
const INK_SOFT : Color = Color(0.78, 0.72, 0.56, 1.0)
const HEADER : Color = Color(0.66, 0.74, 0.62, 1.0)

## What each cast member does — shown under their name. Data-driven; falls back to a generic role.
const ROLES : Dictionary = {
	"Flint Kerr": "Bladesmith", "Cinder Troy": "Blacksmith", "Hearty Brian": "Innkeeper",
	"Merry Geneva": "Inn hostess", "Spritely Mia": "Whittler", "Mossy Jade": "Herbalist",
	"Cogwise Godfrey": "Tinker", "Stormy Jericho": "Skydock master", "Hollow Ellison": "Old storyteller",
}
## Where each is usually found (for the "About" line).
const HAUNTS : Dictionary = {
	"Flint Kerr": "the Forge", "Cinder Troy": "the Forge", "Hearty Brian": "the Inn",
	"Merry Geneva": "the Inn", "Spritely Mia": "the Inn", "Mossy Jade": "the Healer's Hut",
	"Cogwise Godfrey": "the Workshop", "Stormy Jericho": "the Skydock", "Hollow Ellison": "the Inn",
}

var _npc_name : String = ""
var _color : Color = Color(0.6, 0.6, 0.7, 1.0)
var _bio : String = ""
var _locale : String = ""
var _favor : Dictionary = {}

var _panel : PanelContainer
var _dim : ColorRect
var _content : VBoxContainer


static func open(host: Node, config: Dictionary) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	var c : NpcProfileCard = NpcProfileCard.new()
	c._npc_name = String(config.get("npc_name", "Stranger"))
	c._color = config.get("npc_color", Color(0.6, 0.6, 0.7, 1.0))
	c._bio = String(config.get("bio", ""))
	c._locale = String(config.get("locale", ""))
	c._favor = (config.get("favor", {}) as Dictionary).duplicate()
	host.get_tree().root.add_child(c)


func _ready() -> void:

	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	get_tree().paused = true

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e: InputEvent) -> void: if e is InputEventMouseButton and e.pressed: _close())
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_left = -230.0
	_panel.offset_top = -252.0
	_panel.offset_right = 230.0
	_panel.offset_bottom = 252.0
	add_child(_panel)

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	add_child(EscToClose.new(_close))
	_render()
	ModalFx.appear(_panel, _dim)


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false


# --- render -----------------------------------------------------------

func _render() -> void:

	for c in _content.get_children():
		c.queue_free()

	_content.add_child(_header())
	_content.add_child(_rule())
	_content.add_child(_crew_section())
	_content.add_child(_rule())

	# Your standing with them.
	_content.add_child(_section("Standing"))
	_content.add_child(_kv("Rapport", PlayerState.affinity_tier(_npc_name)))
	_content.add_child(_hearts_bar())
	var done : int = int(PlayerState.npc_favor_done.get(_npc_name, 0))
	if done > 0:
		_content.add_child(_muted("Favours done for them: %d" % done))

	# About.
	var haunt : String = String(HAUNTS.get(_npc_name, ""))
	if not _bio.is_empty() or not haunt.is_empty():
		_content.add_child(_rule())
		_content.add_child(_section("About"))
		if not _bio.is_empty():
			_content.add_child(_body(_bio))
		if not haunt.is_empty():
			_content.add_child(_muted("Usually found at %s." % haunt))

	# Their standing favour.
	if not _favor.is_empty():
		_content.add_child(_rule())
		_content.add_child(_section("Could use a hand"))
		_content.add_child(_body("Wants %d %s — drop by for a Favour to help." % [int(_favor["amount"]), _item_name()]))

	_content.add_child(_gap(6))
	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close : Button = _btn("Close", INK)
	close.pressed.connect(_close)
	row.add_child(close)
	_content.add_child(row)


func _header() -> Control:

	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	# Portrait disc (colour + initial), centred.
	var disc_row : HBoxContainer = HBoxContainer.new()
	disc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var disc : Panel = Panel.new()
	var ds : StyleBoxFlat = StyleBoxFlat.new()
	ds.bg_color = _color
	ds.border_color = Color(1, 1, 1, 0.85)
	ds.set_border_width_all(3)
	ds.set_corner_radius_all(48)
	disc.add_theme_stylebox_override("panel", ds)
	disc.custom_minimum_size = Vector2(86.0, 86.0)
	var initial : Label = Label.new()
	initial.text = _short().substr(0, 1).to_upper()
	initial.add_theme_font_size_override("font_size", 38)
	initial.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	initial.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	initial.add_theme_constant_override("outline_size", 4)
	initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(initial)
	disc_row.add_child(disc)
	box.add_child(disc_row)

	var name_l : Label = Label.new()
	name_l.text = _npc_name
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_l.add_theme_constant_override("outline_size", 3)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_l)
	var role_l : Label = Label.new()
	role_l.text = String(ROLES.get(_npc_name, "Cradle Rock local"))
	role_l.add_theme_font_size_override("font_size", 15)
	role_l.add_theme_color_override("font_color", INK_SOFT)
	role_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(role_l)
	return box


# The CREW section — recruit / rank / dismiss (the foundation for "start a crew").
func _crew_section() -> Control:

	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_section("Crew"))
	if PlayerState.is_in_crew(_npc_name):
		_content_note(box, "Aboard your crew  ·  %s" % PlayerState.crew_rank(_npc_name), INK)
		var row : HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		var up : Button = _btn("Promote ▲", Color(0.82, 1.0, 0.66, 1.0))
		up.pressed.connect(_promote)
		row.add_child(up)
		var down : Button = _btn("Demote ▼", Color(0.95, 0.84, 0.56, 1.0))
		down.pressed.connect(_demote)
		row.add_child(down)
		var off : Button = _btn("Dismiss", Color(0.95, 0.72, 0.6, 1.0))
		off.pressed.connect(_dismiss)
		row.add_child(off)
		box.add_child(row)
	elif PlayerState.can_recruit(_npc_name):
		_content_note(box, "They'd sail with you.", INK_SOFT)
		var row : HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var hire : Button = _btn("Hire to crew  ▸", Color(0.82, 1.0, 0.66, 1.0))
		hire.pressed.connect(_hire)
		row.add_child(hire)
		box.add_child(row)
	else:
		_content_note(box, "Earn their trust to recruit — become their Confidant.  (rapport %d / %d)" % [
			PlayerState.get_affinity(_npc_name), PlayerState.RECRUIT_MIN_AFFINITY], INK_SOFT)
	return box


# --- actions ----------------------------------------------------------

func _hire() -> void:
	PlayerState.hire_crew(_npc_name)
	_render()

func _dismiss() -> void:
	PlayerState.dismiss_crew(_npc_name)
	_render()

func _promote() -> void:
	PlayerState.cycle_crew_rank(_npc_name, 1)
	_render()

func _demote() -> void:
	PlayerState.cycle_crew_rank(_npc_name, -1)
	_render()


# --- small builders ----------------------------------------------------

func _hearts_bar() -> Control:

	var bar : ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(PlayerState.MAX_AFFINITY)
	bar.value = float(PlayerState.get_affinity(_npc_name))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg : StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.24, 0.20, 0.16, 1.0)
	bg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	var fill : StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.90, 0.34, 0.40, 1.0)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _section(text: String) -> Label:
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", HEADER)
	return l


func _kv(key: String, value: String) -> Label:
	var l : Label = Label.new()
	l.text = "%s:  %s" % [key, value]
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", INK)
	return l


func _body(text: String) -> Label:
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


func _muted(text: String) -> Label:
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


func _content_note(box: VBoxContainer, text: String, color: Color) -> void:
	var l : Label = _body(text)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)


func _rule() -> Control:
	var r : ColorRect = ColorRect.new()
	r.color = Color(0.52, 0.36, 0.16, 1.0)
	r.custom_minimum_size = Vector2(0, 2)
	return r


func _gap(h: float) -> Control:
	var c : Control = Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _item_name() -> String:
	var id : String = String(_favor.get("item", ""))
	return String((PlayerState.ITEM_DEFS.get(id, {}) as Dictionary).get("name", id.capitalize()))


func _short() -> String:
	var parts : PackedStringArray = _npc_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else _npc_name


func _close() -> void:
	ModalFx.dismiss(self, _panel, _dim, _do_close)


func _do_close() -> void:
	if get_tree() != null:
		get_tree().paused = false
	closed.emit()
	queue_free()


func _panel_style() -> StyleBoxFlat:
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.97)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(22)
	return s


func _btn(text: String, font_color: Color) -> Button:
	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", font_color)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 2)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.22, 0.14, 0.08, 0.95)
		if st == "hover":
			bg = bg.lightened(0.10)
		elif st == "pressed":
			bg = bg.darkened(0.12)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0)
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 13
		s.content_margin_right = 13
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(st, s)
	return b

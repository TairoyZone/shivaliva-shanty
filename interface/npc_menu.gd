## NpcMenu — a RADIAL click-menu around an NPC (YPP-style, see [[Official:Communications]]): a circular
## portrait in the centre + a ring of option buttons. Replaces the old dialogue-box-on-click — the favour
## is now just ONE option here, never demanded in a dialogue. Built by Npc.interact() from the NPC's
## available options: NpcMenu.open(host, screen_pos, name, colour, [{label, action: Callable}, ...]).
## Self-contained + self-freeing; click outside to close. Won't stack. See [[godot-borrow-todo]].
class_name NpcMenu
extends CanvasLayer

const RING_RADIUS_BASE : float = 98.0
const BTN_SIZE_BASE : float = 78.0
const PORTRAIT_SIZE_BASE : float = 82.0
# Bigger touch targets on a phone (gated on TouchEnv so the desktop menu is unchanged — Troy 2026-06-12).
@onready var RING_RADIUS : float = RING_RADIUS_BASE * (1.22 if TouchEnv.is_touch() else 1.0)
@onready var BTN_SIZE : float = BTN_SIZE_BASE * (1.22 if TouchEnv.is_touch() else 1.0)
@onready var PORTRAIT_SIZE : float = PORTRAIT_SIZE_BASE * (1.18 if TouchEnv.is_touch() else 1.0)
const GROUP : StringName = &"npc_menu"

var _center : Vector2 = Vector2.ZERO
var _npc_name : String = ""
var _color : Color = Color(0.6, 0.6, 0.7, 1.0)
var _options : Array = []


static func open(host: Node, screen_pos: Vector2, npc_name: String, color: Color, options: Array) -> void:

	if host == null or host.get_tree() == null or options.is_empty():
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	var m : NpcMenu = NpcMenu.new()
	m._center = screen_pos
	m._npc_name = npc_name
	m._color = color
	m._options = options
	host.get_tree().root.add_child(m)


func _ready() -> void:

	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	# Keep the whole ring on-screen.
	var vp : Vector2 = get_viewport().get_visible_rect().size
	var pad : float = RING_RADIUS + BTN_SIZE
	_center.x = clampf(_center.x, pad, vp.x - pad)
	_center.y = clampf(_center.y, pad, vp.y - pad - 24.0)

	# Backdrop — a click anywhere outside the buttons closes.
	var dim : Control = Control.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# Centre portrait: a coloured disc + the NPC's initial, with the name beneath.
	var portrait : Panel = Panel.new()
	var ps : StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = _color
	ps.border_color = Color(1, 1, 1, 0.85)
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(int(PORTRAIT_SIZE * 0.5))
	portrait.add_theme_stylebox_override("panel", ps)
	portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.position = _center - portrait.size * 0.5
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	var initial : Label = Label.new()
	initial.text = _initial()
	initial.add_theme_font_size_override("font_size", 34)
	initial.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	initial.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	initial.add_theme_constant_override("outline_size", 4)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(initial)
	var name_l : Label = Label.new()
	name_l.text = _npc_name
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", Color(0.98, 0.9, 0.6, 1.0))
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_l.add_theme_constant_override("outline_size", 3)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.size = Vector2(220.0, 0.0)
	name_l.position = Vector2(_center.x - 110.0, _center.y + PORTRAIT_SIZE * 0.5 + 6.0)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_l)

	# Ring of option buttons (first one at the top, going clockwise).
	var n : int = _options.size()
	for i in n:
		var ang : float = -PI * 0.5 + float(i) * TAU / float(n)
		var p : Vector2 = _center + Vector2(cos(ang), sin(ang)) * RING_RADIUS
		var btn : Button = _make_option(_options[i] as Dictionary)
		btn.position = p - Vector2(BTN_SIZE, BTN_SIZE) * 0.5
		add_child(btn)

	add_child(EscToClose.new(_close))


func _make_option(opt: Dictionary) -> Button:

	var b : Button = Button.new()
	b.text = String(opt.get("label", "?"))
	b.size = Vector2(BTN_SIZE, BTN_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.97, 0.9, 0.7, 1.0))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	b.add_theme_constant_override("outline_size", 2)
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.18, 0.12, 0.07, 0.97)
		if state == "hover":
			bg = bg.lightened(0.12)
		elif state == "pressed":
			bg = bg.darkened(0.1)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0)
		s.set_border_width_all(2)
		s.set_corner_radius_all(int(BTN_SIZE * 0.5))
		b.add_theme_stylebox_override(state, s)
	var act : Callable = opt.get("action", Callable())
	b.pressed.connect(_on_option.bind(act))
	return b


func _on_option(act: Callable) -> void:

	_close()
	if act.is_valid():
		act.call()


func _initial() -> String:

	if _npc_name.is_empty():
		return "?"
	return _npc_name.substr(_npc_name.rfind(" ") + 1, 1).to_upper()


func _on_dim_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:

	queue_free()

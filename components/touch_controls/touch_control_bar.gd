## TouchControlBar — a data-driven row of large touch buttons a puzzle declares via [PuzzleScene._touch_spec].
## Each spec entry is a Dictionary:
##   {"label": String, "hold": bool, and ONE of "action": StringName | "callable": Callable}
##   HOLD + action  -> presses/releases the InputMap action on touch-down/up, so the puzzle's EXISTING polled DAS
##                     auto-repeat works unchanged (move left/right, soft-drop). A finger sliding off releases it.
##   TAP + callable -> calls the method once on press — the reliable path for rotate / flip / toss.
##   TAP + action   -> a momentary press for puzzles that poll is_action_just_pressed.
## Built ONLY on touch (PuzzleScene gates it on TouchEnv). One bar, one place — every action puzzle just declares
## its buttons (inheritance over duplication). Anchored bottom-right, >=72px targets, placeholder styling.
class_name TouchControlBar
extends HBoxContainer

const BTN_SIZE : float = 72.0

var _spec : Array = []
var _held : Dictionary = {}   # Button -> the StringName action it is holding


func setup(spec: Array) -> void:
	_spec = spec


func _ready() -> void:

	add_theme_constant_override("separation", 14)
	for entry in _spec:
		add_child(_make_button(entry))
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)


func _make_button(entry: Dictionary) -> Button:

	var btn : Button = Button.new()
	btn.text = String(entry.get("label", "?"))
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	btn.add_theme_font_size_override("font_size", 30)
	_style_button(btn)
	var hold : bool = bool(entry.get("hold", false))
	if entry.has("action"):
		var action : StringName = StringName(entry["action"])
		if hold:
			btn.button_down.connect(_press.bind(btn, action))
			btn.button_up.connect(_release.bind(btn))
			btn.mouse_exited.connect(_release.bind(btn))   # finger slid off the button -> release the held action
		else:
			btn.pressed.connect(_tap_action.bind(action))
	elif entry.has("callable"):
		btn.pressed.connect(entry["callable"] as Callable)
	return btn


func _press(btn: Button, action: StringName) -> void:

	if _held.has(btn):
		return
	_held[btn] = action
	Input.action_press(action)


func _release(btn: Button) -> void:

	if not _held.has(btn):
		return
	Input.action_release(_held[btn])
	_held.erase(btn)


func _tap_action(action: StringName) -> void:

	# A momentary press so a polled is_action_just_pressed fires; released next idle frame.
	Input.action_press(action)
	_release_action_deferred.call_deferred(action)


func _release_action_deferred(action: StringName) -> void:
	Input.action_release(action)


func _style_button(btn: Button) -> void:

	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = Color(0.30, 0.20, 0.10, 0.96) if state == "pressed" else Color(0.18, 0.11, 0.06, 0.92)
		s.set_border_width_all(2)
		s.border_color = Color(0.78, 0.58, 0.24, 1.0)
		s.set_corner_radius_all(12)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color(0.97, 0.87, 0.55, 1.0))


# Release any held action if the bar is freed mid-press (scene change / leave) so nothing sticks down.
func _exit_tree() -> void:

	for btn in _held.keys():
		Input.action_release(_held[btn])
	_held.clear()

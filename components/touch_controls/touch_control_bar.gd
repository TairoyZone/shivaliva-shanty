## TouchControlBar — a data-driven set of large touch buttons a puzzle declares via [PuzzleScene._touch_spec].
## Each spec entry:
##   {"label": String, "hold": bool, "side": "left" | "right" (default "right"), and ONE of
##    "action": StringName | "key": int (a KEY_* code) | "callable": Callable}
## Buttons split into a BOTTOM-LEFT group and a BOTTOM-RIGHT group by `side`, gamepad-style — movement under the
## left thumb, rotate/drop under the right — instead of all bunching in one corner over the chat/leave buttons
## (Troy 2026-06-12, the Skirmish overlap). HOLD presses on touch-down / releases on up (held DAS inputs); TAP
## fires once. An "action" synthesizes BOTH the polled state + an InputEventAction, a "key" an InputEventKey
## (so it works whether the puzzle polls or reads events); a "callable" calls a method. Built ONLY on touch.
class_name TouchControlBar
extends Control

const BTN_SIZE : float = 80.0

var _spec : Array = []
var _held : Dictionary = {}   # Button -> the {kind, value} it is holding down
var _left : HBoxContainer      # the bottom-LEFT button group (movement)
var _right : HBoxContainer     # the bottom-RIGHT button group (rotate / drop)


func setup(spec: Array) -> void:
	_spec = spec


func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE   # only the buttons catch taps; everything else passes to the board
	_left = _new_row()
	_right = _new_row()
	for entry in _spec:
		var btn : Button = _make_button(entry)
		if String(entry.get("side", "right")) == "left":
			_left.add_child(btn)
		else:
			_right.add_child(btn)
	add_child(_left)
	add_child(_right)
	# A Control .new()'d under a CanvasLayer is NOT auto-laid-out to the viewport (see InventoryPanel._fit_viewport)
	# — it stays (0,0), so the bottom-corner groups anchor to nothing and VANISH. Force the size + re-fit on resize
	# (Troy 2026-06-12, the disappeared Skirmish controls).
	_fit()
	var vp : Viewport = get_viewport()
	if vp != null:
		vp.size_changed.connect(_fit)


func _fit() -> void:

	var vp : Viewport = get_viewport()
	if vp == null:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = vp.get_visible_rect().size
	_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	_right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)


func _new_row() -> HBoxContainer:

	var h : HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	return h


func _make_button(entry: Dictionary) -> Button:

	var btn : Button = Button.new()
	btn.text = String(entry.get("label", "?"))
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	btn.add_theme_font_size_override("font_size", 32)
	_style_button(btn)
	var hold : bool = bool(entry.get("hold", false))
	var what : Dictionary = {}
	if entry.has("action"):
		what = {"kind": "action", "value": StringName(entry["action"])}
	elif entry.has("key"):
		what = {"kind": "key", "value": int(entry["key"])}
	elif entry.has("callable"):
		btn.pressed.connect(entry["callable"] as Callable)
		return btn
	if hold:
		btn.button_down.connect(_press.bind(btn, what))
		btn.button_up.connect(_release.bind(btn))
		btn.mouse_exited.connect(_release.bind(btn))   # finger slid off the button -> release the held input
	else:
		btn.pressed.connect(_tap.bind(what))
	return btn


func _press(btn: Button, what: Dictionary) -> void:

	if _held.has(btn):
		return
	_held[btn] = what
	_set_down(what, true)


func _release(btn: Button) -> void:

	if not _held.has(btn):
		return
	var what : Dictionary = _held[btn]
	_held.erase(btn)
	_set_down(what, false)


func _tap(what: Dictionary) -> void:

	_set_down(what, true)
	_set_down_deferred.call_deferred(what, false)   # release next idle frame (one clean press)


func _set_down_deferred(what: Dictionary, down: bool) -> void:
	_set_down(what, down)


# Drive the input down/up, covering BOTH polled (Input.action_press) and event-based (parse_input_event) readers.
func _set_down(what: Dictionary, down: bool) -> void:

	if what.get("kind", "") == "action":
		var a : StringName = what["value"]
		if down:
			Input.action_press(a)
		else:
			Input.action_release(a)
		Input.parse_input_event(_action_event(a, down))
	elif what.get("kind", "") == "key":
		var k : int = int(what["value"])
		var ev : InputEventKey = InputEventKey.new()
		ev.keycode = k as Key
		ev.physical_keycode = k as Key
		ev.pressed = down
		Input.parse_input_event(ev)


# Build the EVENT to deliver for an action button. Prefer a COPY of the action's real KEY binding so it looks
# exactly like a keyboard press — INCLUDING an `echo` property. A bare InputEventAction has NO `echo`, which
# crashes the standard "ignore key-repeat" guard `if event.is_action_pressed(...) and not event.echo`
# (Troy 2026-06-12). Falls back to InputEventAction only if the action has no key binding.
func _action_event(action: StringName, down: bool) -> InputEvent:

	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				var k : InputEventKey = (e as InputEventKey).duplicate()
				k.pressed = down
				k.echo = false
				return k
	var a : InputEventAction = InputEventAction.new()
	a.action = action
	a.pressed = down
	return a


func _style_button(btn: Button) -> void:

	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = Color(0.30, 0.20, 0.10, 0.96) if state == "pressed" else Color(0.18, 0.11, 0.06, 0.92)
		s.set_border_width_all(2)
		s.border_color = Color(0.78, 0.58, 0.24, 1.0)
		s.set_corner_radius_all(12)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color(0.97, 0.87, 0.55, 1.0))


# Release anything held if the bar is freed mid-press (scene change / leave) so no input sticks down.
func _exit_tree() -> void:

	for btn in _held.keys():
		_set_down(_held[btn], false)
	_held.clear()

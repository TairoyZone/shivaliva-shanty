## VirtualJoystick — an 8-direction touch stick for the overworld. It drives the SAME move_* input actions the
## player already polls ([code]Input.get_vector("move_left","move_right","move_up","move_down")[/code] in
## player.gd), via Input.action_press/release — so player.gd needs ZERO changes; spawn it (gated on TouchEnv) and
## movement works. It snaps the thumb to one of 8 SCREEN directions and presses the action pair that produces that
## screen direction under the player's ISO map (up on screen = right+up, right = right+down, …) so dragging the
## thumb a way moves the character that way. Placeholder _draw art; lives on a high CanvasLayer (the spawner's job).
class_name VirtualJoystick
extends Control

const RADIUS : float = 78.0
const KNOB_RADIUS : float = 32.0
const DEADZONE_FRAC : float = 0.30        # below this fraction of RADIUS, no movement fires
const _MOUSE : int = -2                    # sentinel "touch index" for desktop mouse (force-touch testing)

# SCREEN octant (0 = N/up, then clockwise NE, E, SE, S, SW, W, NW) -> the move_* actions that produce that SCREEN
# direction under the player's iso INPUT_TO_DIRECTION map.
const _OCTANT_ACTIONS : Array = [
	["move_right", "move_up"],      # 0 N  (up)
	["move_right"],                 # 1 NE
	["move_right", "move_down"],    # 2 E  (right)
	["move_down"],                  # 3 SE
	["move_left", "move_down"],     # 4 S  (down)
	["move_left"],                  # 5 SW
	["move_left", "move_up"],       # 6 W  (left)
	["move_up"],                    # 7 NW
]

var _touch_index : int = -1               # the finger (or _MOUSE) currently driving the stick (-1 = none)
var _knob : Vector2 = Vector2.ZERO        # knob offset from centre
var _held : Array = []                    # actions we are currently holding, so we release exactly those


func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_STOP   # capture touches in the stick zone; the rest reach the world
	var zone : float = RADIUS * 2.0 + 56.0
	custom_minimum_size = Vector2(zone, zone)
	size = Vector2(zone, zone)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, 24)


func _gui_input(event: InputEvent) -> void:

	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_update(event.position)
		elif not event.pressed and event.index == _touch_index:
			_release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _touch_index == -1:
			_touch_index = _MOUSE
			_update(event.position)
		elif not event.pressed and _touch_index == _MOUSE:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _touch_index == _MOUSE:
		_update(event.position)
		accept_event()


func _update(pos: Vector2) -> void:

	var v : Vector2 = pos - size * 0.5
	_knob = v.limit_length(RADIUS)
	queue_redraw()
	if v.length() < RADIUS * DEADZONE_FRAC:
		_set_actions([])
		return
	_set_actions(_actions_for(v))


## The input actions to HOLD for a thumb offset `v` (past the deadzone). Overworld default: snap to 8 SCREEN
## octants and press the move_* pair that yields that screen direction under the iso map. Subclasses (e.g.
## [PuzzleJoystick]) override this to drive different actions — the touch/hold/cleanup plumbing is shared.
func _actions_for(v: Vector2) -> Array:

	# Angle measured from "up" (screen north), clockwise. y is down, so up = (0,-1).
	var ang : float = atan2(v.x, -v.y)
	if ang < 0.0:
		ang += TAU
	var oct : int = int(round(ang / (TAU / 8.0))) % 8
	return _OCTANT_ACTIONS[oct]


func _release() -> void:

	_touch_index = -1
	_knob = Vector2.ZERO
	_set_actions([])
	queue_redraw()


# Hold exactly the desired actions: release any we hold that aren't wanted, press any wanted we don't hold.
func _set_actions(desired: Array) -> void:

	for a in _held:
		if not desired.has(a):
			Input.action_release(a)
	for a in desired:
		if not _held.has(a):
			Input.action_press(a)
	_held = desired.duplicate()


func _draw() -> void:

	var c : Vector2 = size * 0.5
	draw_circle(c, RADIUS, Color(0.10, 0.10, 0.16, 0.32))
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(0.90, 0.90, 0.98, 0.40), 3.0)
	draw_circle(c + _knob, KNOB_RADIUS, Color(0.95, 0.95, 1.0, 0.55))
	draw_arc(c + _knob, KNOB_RADIUS, 0.0, TAU, 32, Color(0.70, 0.75, 0.90, 0.75), 2.0)


# Never leave an action stuck pressed if the stick is freed mid-drag (a scene change while moving).
func _exit_tree() -> void:

	for a in _held:
		Input.action_release(a)
	_held = []

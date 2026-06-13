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

## The finger index the stick currently OWNS, mirrored to a STATIC so PinchZoom can see it WITHOUT a node lookup
## (-1 = the stick is idle). This is the Mobile-Legends move-vs-look split: while the stick owns a finger, the
## camera's PinchZoom skips that finger entirely AND refuses to pinch-zoom, so moving the stick can never pan or
## zoom the view, and a SECOND finger reads as a clean look-around pan (never a two-finger pinch). One stick at a
## time in a scene, so a static is safe. (Troy 2026-06-14: "i dont want it to zoom in that state combination.")
static var active_index : int = -1


func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE   # we route input ourselves in _input (own the finger globally)
	var zone : float = RADIUS * 2.0 + 56.0
	custom_minimum_size = Vector2(zone, zone)
	size = Vector2(zone, zone)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, 24)


# The stick's screen rect — a press must START here to claim the finger; after that the finger is OWNED and
# tracked ANYWHERE on screen (Mobile-Legends style), so dragging the thumb past the rim never drops it.
func _zone() -> Rect2:
	return Rect2(global_position, size)


# Handled in _input (not _gui_input) so we OWN the claimed finger across the whole screen and CONSUME its events
# before they reach the camera pan in _unhandled_input — that's what keeps move + swipe-pan from fighting each
# other (Troy 2026-06-14, the "glitch when moving + panning" fix). event.position is screen-space here, so we
# convert to the control's local space for _update.
func _input(event: InputEvent) -> void:

	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _zone().has_point(event.position):
				_touch_index = event.index
				active_index = event.index   # claim it globally so PinchZoom ignores this finger + won't zoom
				_update(event.position - global_position)
				_consume()
		elif event.index == _touch_index:
			_release()
			_consume()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update(event.position - global_position)
		_consume()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _touch_index == -1 and _zone().has_point(event.position):
				_touch_index = _MOUSE
				active_index = _MOUSE
				_update(event.position - global_position)
				_consume()
		elif _touch_index == _MOUSE:
			_release()
			_consume()
	elif event is InputEventMouseMotion and _touch_index == _MOUSE:
		_update(event.position - global_position)
		_consume()


# Consume the event so the camera pan (PinchZoom, in _unhandled_input) never sees this finger. Viewport-null-safe
# for headless tests.
func _consume() -> void:

	var vp : Viewport = get_viewport()
	if vp != null:
		vp.set_input_as_handled()


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
	active_index = -1   # the stick is idle again → PinchZoom resumes normal pan + pinch-zoom
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
	active_index = -1   # freed mid-drag (a scene change while moving) — don't leave the static stuck "engaged"

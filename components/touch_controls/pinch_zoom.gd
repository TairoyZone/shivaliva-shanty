## PinchZoom — two-finger pinch-to-zoom + one-finger swipe-to-pan for a [Camera2D], TOUCH ONLY. The 1280×720
## canvas shrinks to fit a phone, so the world/tables read small. Spread two fingers to zoom IN (clamped), drag
## ONE finger to pan the view any direction (clamped), and pinch fully back out to re-centre. The zoom level
## PERSISTS across scenes (see [member shared_zoom]) so it survives every screen change. Desktop is never affected
## (gated on [method TouchEnv.is_touch]).
##
## Add it as a child of a scene and call [method setup] with the camera + a `extra_pan` look-around allowance:
##   • Overworld (the camera rides the player) → `pz.setup(cam, 1.0, 2.6, Vector2(240, 160))` — a fixed
##     look-around so you can swipe to peer about even at the default zoom.
##   • A puzzle table (static camera at the screen centre) → `pz.setup(cam, 1.0, 2.8, Vector2.ZERO)` — pan only as
##     far as the board edges (no fixed extra).
## See [[touch-input-foundation]] (Troy 2026-06-13).
class_name PinchZoom
extends Node

## A one-finger drag must travel this far (px) before it counts as a PAN — below it the touch is a tap, left for
## the board/world to handle.
const PAN_THRESHOLD : float = 12.0

## The zoom level, SHARED across every scene's PinchZoom so a zoom set on one screen PERSISTS to the next
## (Troy 2026-06-13). Reset to 1.0 only by pinching fully out.
static var shared_zoom : float = 1.0

var _camera : Camera2D
var _min : float = 1.0
var _max : float = 3.0
var _extra_pan : Vector2 = Vector2.ZERO     # fixed look-around slack added to the zoom-based edge clamp

var _base_pos : Vector2 = Vector2.ZERO      # the camera's resting position (re-centred here on full zoom-out)
var _touches : Dictionary = {}              # active finger index -> last screen position
var _last_dist : float = -1.0               # finger separation last frame (-1 = no active pinch)
var _last_mid : Vector2 = Vector2.ZERO      # midpoint between the two fingers last frame
var _pan_start : Vector2 = Vector2.ZERO     # where a one-finger touch began (to tell a pan from a tap)
var _panning : bool = false                 # this one-finger gesture has passed PAN_THRESHOLD


func setup(camera: Camera2D, min_z: float = 1.0, max_z: float = 3.0, extra_pan: Vector2 = Vector2.ZERO) -> void:

	_camera = camera
	_min = min_z
	_max = max_z
	_extra_pan = extra_pan


func _ready() -> void:

	if _camera != null:
		_base_pos = _camera.position
		# Restore the persisted zoom (clamped to this scene's range); pan resets to the framed centre each scene.
		var z : float = clampf(shared_zoom, _min, _max)
		_camera.zoom = Vector2(z, z)


func _unhandled_input(event: InputEvent) -> void:

	if not TouchEnv.is_touch() or _camera == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_pan_start = event.position
				_panning = false
		else:
			_touches.erase(event.index)
			if _touches.size() < 2:
				_last_dist = -1.0   # pinch ended
			if _touches.is_empty():
				_panning = false
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			_touches[event.index] = event.position
		if _touches.size() >= 2:
			_pinch()
			get_viewport().set_input_as_handled()   # a 2-finger gesture is ours
		elif _touches.size() == 1:
			_one_finger_pan(event)


# Drag ONE finger to pan, once it's moved past PAN_THRESHOLD (so a tap still reaches the board/world).
func _one_finger_pan(event: InputEventScreenDrag) -> void:

	if not _panning and _pan_start.distance_to(event.position) < PAN_THRESHOLD:
		return
	_panning = true
	var vp : Vector2 = _viewport_size()
	# Move the camera OPPOSITE the finger so the content tracks the finger (world units = screen / zoom).
	var want : Vector2 = _camera.position - event.relative / _camera.zoom.x
	_camera.position = _clamp_pan(want, _camera.zoom.x, vp)
	var vp_node : Viewport = get_viewport()
	if vp_node != null:
		vp_node.set_input_as_handled()


func _pinch() -> void:

	var ks : Array = _touches.keys()
	var p0 : Vector2 = _touches[ks[0]]
	var p1 : Vector2 = _touches[ks[1]]
	var dist : float = p0.distance_to(p1)
	var mid : Vector2 = (p0 + p1) * 0.5
	# First frame of a pinch: just record the baseline (no jump).
	if _last_dist <= 0.0 or dist <= 0.0:
		_last_dist = dist
		_last_mid = mid
		return
	var old_zoom : float = _camera.zoom.x
	var new_zoom : float = clampf(old_zoom * (dist / _last_dist), _min, _max)
	var vp : Vector2 = _viewport_size()
	# Keep the world point the fingers grabbed anchored under the CURRENT midpoint — folds zoom-toward-the-pinch
	# AND pan-with-the-fingers together (DRAG_CENTER anchor).
	var grabbed : Vector2 = _camera.position + (_last_mid - vp * 0.5) / old_zoom
	_camera.zoom = Vector2(new_zoom, new_zoom)
	if new_zoom <= _min + 0.001:
		_camera.position = _base_pos   # pinched all the way out → snap back to the framed default
	else:
		var want : Vector2 = grabbed - (mid - vp * 0.5) / new_zoom
		_camera.position = _clamp_pan(want, new_zoom, vp)
	shared_zoom = new_zoom             # PERSIST the zoom across scenes
	_last_dist = dist
	_last_mid = mid


# The live viewport size, or the design resolution if there's no viewport yet (headless tests / pre-tree).
func _viewport_size() -> Vector2:

	var vp_node : Viewport = get_viewport()
	return vp_node.get_visible_rect().size if vp_node != null else Vector2(1280.0, 720.0)


# Clamp the view: the board-edge slack (more the further you're zoomed in) plus any fixed look-around (overworld).
func _clamp_pan(pos: Vector2, zoom: float, vp: Vector2) -> Vector2:

	var slack : Vector2 = vp * 0.5 * maxf(0.0, 1.0 - 1.0 / zoom) + _extra_pan
	return Vector2(
		clampf(pos.x, _base_pos.x - slack.x, _base_pos.x + slack.x),
		clampf(pos.y, _base_pos.y - slack.y, _base_pos.y + slack.y))

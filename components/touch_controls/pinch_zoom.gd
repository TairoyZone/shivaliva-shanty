## PinchZoom — the standard two-finger pinch-to-zoom (+ optional two-finger pan) for a [Camera2D], TOUCH ONLY.
## The 1280×720 canvas shrinks to fit a phone, so the world/tables read small; this lets the player spread two
## fingers to zoom IN (clamped) and, with pan on, slide both fingers to move the view. Pinching fully back out
## re-centers. Desktop is never affected (every path is gated on [method TouchEnv.is_touch]).
##
## Add it as a child of a scene and call [method setup] with the camera:
##   • Overworld (the camera RIDES the player) → zoom-only: `pz.setup(cam, 1.0, 2.6, false)`.
##   • A puzzle table (a static camera at the screen centre) → zoom + pan: `pz.setup(cam, 1.0, 2.8, true)`.
## See [[touch-input-foundation]]. Built 2026-06-13 (the "everything looks small on mobile" fix).
class_name PinchZoom
extends Node


var _camera : Camera2D
var _min : float = 1.0
var _max : float = 3.0
var _pan : bool = false

var _base_pos : Vector2 = Vector2.ZERO      # the camera's resting position (re-centred to here on full zoom-out)
var _touches : Dictionary = {}              # active finger index -> last screen position
var _last_dist : float = -1.0               # finger separation last frame (-1 = no active pinch)
var _last_mid : Vector2 = Vector2.ZERO      # midpoint between the two fingers last frame


## camera = the Camera2D to drive; min_z/max_z = zoom clamp (1.0 = the default view, never smaller); allow_pan =
## true for a static puzzle camera (slide to move), false for a follow camera (zoom only — it rides the player).
func setup(camera: Camera2D, min_z: float = 1.0, max_z: float = 3.0, allow_pan: bool = false) -> void:

	_camera = camera
	_min = min_z
	_max = max_z
	_pan = allow_pan


func _ready() -> void:

	if _camera != null:
		_base_pos = _camera.position


func _unhandled_input(event: InputEvent) -> void:

	if not TouchEnv.is_touch() or _camera == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() < 2:
			_last_dist = -1.0   # pinch ended
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			_touches[event.index] = event.position
		if _touches.size() >= 2:
			_pinch()
			get_viewport().set_input_as_handled()   # a 2-finger gesture is ours — don't let the world also react


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
	if _pan:
		# Keep the world point the fingers grabbed anchored under the CURRENT midpoint — this single formula
		# folds zoom-toward-the-pinch AND pan-with-the-fingers together (DRAG_CENTER anchor).
		var vp : Vector2 = get_viewport().get_visible_rect().size
		var grabbed : Vector2 = _camera.position + (_last_mid - vp * 0.5) / old_zoom
		_camera.zoom = Vector2(new_zoom, new_zoom)
		if new_zoom <= _min + 0.001:
			_camera.position = _base_pos   # pinched all the way out → snap back to the framed default
		else:
			var want : Vector2 = grabbed - (mid - vp * 0.5) / new_zoom
			_camera.position = _clamp_pan(want, new_zoom, vp)
	else:
		_camera.zoom = Vector2(new_zoom, new_zoom)   # zoom only — the camera rides the player, leave its position
	_last_dist = dist
	_last_mid = mid


# Don't let the view pan past the board edges: the further you're zoomed in, the more slack there is.
func _clamp_pan(pos: Vector2, zoom: float, vp: Vector2) -> Vector2:

	var slack : Vector2 = vp * 0.5 * (1.0 - 1.0 / zoom)
	return Vector2(
		clampf(pos.x, _base_pos.x - slack.x, _base_pos.x + slack.x),
		clampf(pos.y, _base_pos.y - slack.y, _base_pos.y + slack.y))

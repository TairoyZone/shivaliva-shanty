## OverworldCamera — the overworld's TOUCH camera, built as an explicit state machine so the controls can never
## get into a messed-up in-between (Troy 2026-06-14). The camera is a CHILD of the player, so it already FOLLOWS +
## keeps them dead-centre; this rig only adds a peek offset / a zoom on top, and otherwise holds the offset at 0.
##
## THE RULE THAT STOPS THE MOVE-STICK AND THE LOOK-SWIPE FROM FIGHTING — ownership by where a touch STARTS:
##   • A finger born in the joystick zone (bottom-left) drives the PLAYER. VirtualJoystick claims + consumes it, so
##     this rig never even sees it; VirtualJoystick.active_index just tells us a move is in progress (J).
##   • A finger born ANYWHERE ELSE is a LOOK finger (L) and ONLY this rig acts on it.
## A finger keeps its job for its whole life, so the two can't cross over.
##
## STATE = a PURE FUNCTION of (J = joystick held, L = look-finger count), recomputed every event/frame — never a
## remembered flag that can desync. The four states from Troy's map:
##   IDLE / MOVE  (L == 0)            : dead-centre on the player; any leftover peek offset eases smoothly back to 0.
##   PEEK         (L >= 1)            : offset toward the swipe, clamped to ±50% of the screen, STILL following the
##                                     player — so you look around even WHILE moving.
##   ZOOM         (L >= 2 and not J)  : two-finger pinch in/out; the level persists. NEVER while moving.
##   (moving + 2) (L >= 2 and J)      : a 2nd finger just keeps peeking — zoom is structurally impossible mid-move.
## On release: a peek eases back to dead-centre (no snap); a zoom stays where you left it.
class_name OverworldCamera
extends Node

## Peek reaches up to this fraction of the screen in each direction (Troy 2026-06-14: 50%).
const PEEK_FRAC : float = 0.5
## A look finger must travel this far before it counts as a peek — under it, the touch stays a TAP and passes
## through to world interaction (the click/tap-on-target rule), so looking never eats a tap.
const PAN_THRESHOLD : float = 12.0
## How fast the peek eases back to centre on release (higher = snappier; ~1/this seconds).
const RETURN_SPEED : float = 9.0
const MIN_ZOOM : float = 1.0
const MAX_ZOOM : float = 2.6

## Persisted zoom, kept across overworld scenes so a zoom survives walking between locations.
static var shared_zoom : float = 1.0

var _cam : Camera2D
var _joystick : VirtualJoystick           # to test the joystick zone (ownership-by-origin); may be null
var _looks : Dictionary = {}              # finger index -> {pos, start, panning} for LOOK-origin fingers ONLY
var _offset : Vector2 = Vector2.ZERO      # the live peek offset = the camera's local position
var _pinch_dist : float = -1.0            # finger separation last frame while zooming (-1 = not pinching)


func setup(camera: Camera2D, joystick: VirtualJoystick) -> void:

	_cam = camera
	_joystick = joystick


func _ready() -> void:

	if _cam != null:
		var z : float = clampf(shared_zoom, MIN_ZOOM, MAX_ZOOM)
		_cam.zoom = Vector2(z, z)


func _unhandled_input(event: InputEvent) -> void:

	if not TouchEnv.is_touch() or _cam == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# A finger born in the joystick zone is a MOVE finger, not ours — ignore it (the joystick usually
			# consumes it first; this is the belt-and-suspenders for a 2nd finger dropped in the zone).
			if _joystick != null and _joystick.in_zone(event.position):
				return
			_looks[event.index] = {"pos": event.position, "start": event.position, "panning": false}
			# Do NOT consume the press — a tap may be a world interaction; only a real drag-peek (below) consumes.
		else:
			_looks.erase(event.index)
			if _looks.size() < 2:
				_pinch_dist = -1.0   # pinch ended
	elif event is InputEventScreenDrag and _looks.has(event.index):
		var moving : bool = VirtualJoystick.active_index != -1
		if _looks.size() >= 2 and not moving:
			_looks[event.index]["pos"] = event.position
			_do_pinch()
			get_viewport().set_input_as_handled()
		else:
			# PEEK — one finger, OR a finger while moving (which never zooms). Drag the view like the swipe-pan that
			# felt good (the world tracks the finger); cross the tap threshold first so a tap still reaches the world.
			var info : Dictionary = _looks[event.index]
			info["pos"] = event.position
			if not bool(info["panning"]) and Vector2(info["start"]).distance_to(event.position) < PAN_THRESHOLD:
				return   # still a tap — let it through to interaction
			info["panning"] = true
			_offset -= event.relative / _cam.zoom.x
			_clamp_offset()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:

	if _cam == null:
		return
	# IDLE / MOVE (no look fingers): ease any peek offset back to dead-centre (smooth, never a snap).
	if _looks.is_empty() and not _offset.is_equal_approx(Vector2.ZERO):
		_offset = _offset.lerp(Vector2.ZERO, clampf(RETURN_SPEED * delta, 0.0, 1.0))
		if _offset.length() < 0.5:
			_offset = Vector2.ZERO
	_cam.position = _offset   # local offset on the child camera; 0 = dead-centre on the player


# Two-finger pinch → zoom toward/away, keeping the player centred (no positional shift). Level persists.
func _do_pinch() -> void:

	var ks : Array = _looks.keys()
	if ks.size() < 2:
		return
	var p0 : Vector2 = _looks[ks[0]]["pos"]
	var p1 : Vector2 = _looks[ks[1]]["pos"]
	var dist : float = p0.distance_to(p1)
	if _pinch_dist <= 0.0 or dist <= 0.0:
		_pinch_dist = dist   # first frame of a pinch: just record the baseline (no jump)
		return
	var z : float = clampf(_cam.zoom.x * (dist / _pinch_dist), MIN_ZOOM, MAX_ZOOM)
	_cam.zoom = Vector2(z, z)
	shared_zoom = z
	_pinch_dist = dist


# Clamp the peek to ±PEEK_FRAC of the screen each direction (world units; the canvas is the reference size).
func _clamp_offset() -> void:

	var vp : Vector2 = _viewport_size()
	_offset.x = clampf(_offset.x, -vp.x * PEEK_FRAC, vp.x * PEEK_FRAC)
	_offset.y = clampf(_offset.y, -vp.y * PEEK_FRAC, vp.y * PEEK_FRAC)


# The live viewport size, or the design resolution if there's no viewport yet (headless tests / pre-tree).
func _viewport_size() -> Vector2:

	var vp_node : Viewport = get_viewport()
	return vp_node.get_visible_rect().size if vp_node != null else Vector2(1280.0, 720.0)

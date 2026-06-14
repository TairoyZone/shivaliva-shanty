## Headless regression test for OverworldCamera — proves EVERY row of the state table + the transitions Troy
## locked (2026-06-14): follow/return-to-centre, peek (incl. while moving), the 50% clamp, tap-passes-through,
## zoom ONLY when not moving, zoom persistence, and ownership-by-where-the-touch-starts. Run:
##   Godot_v4.6.3_console.exe --headless --path <proj> --script res://components/touch_controls/test_overworld_camera.gd
extends SceneTree


func _press(i: int, p: Vector2) -> InputEventScreenTouch:
	var e : InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = i; e.pressed = true; e.position = p
	return e

func _release(i: int, p: Vector2) -> InputEventScreenTouch:
	var e : InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = i; e.pressed = false; e.position = p
	return e

func _drag(i: int, p: Vector2, rel: Vector2) -> InputEventScreenDrag:
	var e : InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = i; e.position = p; e.relative = rel
	return e


func _initialize() -> void:

	var ok : bool = true
	TouchEnv._cached_touch = 1
	VirtualJoystick.active_index = -1
	OverworldCamera.shared_zoom = 1.0

	var cam : Camera2D = Camera2D.new()
	cam.zoom = Vector2.ONE
	cam.position = Vector2.ZERO
	var rig : OverworldCamera = OverworldCamera.new()
	rig.setup(cam, null)   # null joystick: every press counts as a look finger (no zone to exclude)
	root.add_child(cam)
	root.add_child(rig)
	var vp : Vector2 = rig._viewport_size()

	# --- PEEK: a one-finger drag past the threshold offsets the view (map-drag: the world tracks the finger) ---
	rig._unhandled_input(_press(0, Vector2(800, 400)))
	rig._unhandled_input(_drag(0, Vector2(900, 400), Vector2(100, 0)))   # swipe right
	rig._process(0.016)
	var t_peek : bool = cam.position.x < -50.0 and is_equal_approx(cam.position.y, 0.0)
	print("peek: %s (x=%.1f)" % [t_peek, cam.position.x])
	ok = ok and t_peek

	# --- CLAMP: a huge drag is clamped to exactly ±50% of the screen ---
	rig._unhandled_input(_drag(0, Vector2(99999, 400), Vector2(99999, 0)))
	rig._process(0.016)
	var t_clamp : bool = is_equal_approx(cam.position.x, -vp.x * 0.5)
	print("clamp50: %s (x=%.1f limit=%.1f)" % [t_clamp, cam.position.x, -vp.x * 0.5])
	ok = ok and t_clamp

	# --- RETURN: releasing eases the peek smoothly back to dead-centre ---
	rig._unhandled_input(_release(0, Vector2(99999, 400)))
	for _i in 120:
		rig._process(0.05)
	var t_return : bool = cam.position.is_equal_approx(Vector2.ZERO)
	print("return-to-centre: %s" % t_return)
	ok = ok and t_return

	# --- TAP passes through: a press + a tiny drag (under the threshold) must NOT peek (so taps still interact) ---
	rig._unhandled_input(_press(1, Vector2(500, 500)))
	rig._unhandled_input(_drag(1, Vector2(505, 500), Vector2(5, 0)))
	rig._process(0.016)
	var t_tap : bool = cam.position.is_equal_approx(Vector2.ZERO)
	print("tap-no-peek: %s" % t_tap)
	ok = ok and t_tap
	rig._unhandled_input(_release(1, Vector2(505, 500)))

	# --- ZOOM (two fingers, NOT moving): pinch apart zooms in; the level persists ---
	cam.zoom = Vector2.ONE
	OverworldCamera.shared_zoom = 1.0
	rig._unhandled_input(_press(2, Vector2(400, 400)))
	rig._unhandled_input(_press(3, Vector2(600, 400)))
	rig._unhandled_input(_drag(3, Vector2(700, 400), Vector2(100, 0)))   # baseline (separation 300)
	rig._unhandled_input(_drag(3, Vector2(900, 400), Vector2(200, 0)))   # separation 500 -> zoom up
	var t_zoom : bool = cam.zoom.x > 1.05
	var t_persist : bool = OverworldCamera.shared_zoom > 1.05
	print("zoom: %s persist: %s (z=%.3f)" % [t_zoom, t_persist, cam.zoom.x])
	ok = ok and t_zoom and t_persist
	rig._unhandled_input(_release(2, Vector2(400, 400)))
	rig._unhandled_input(_release(3, Vector2(900, 400)))

	# --- NO ZOOM while MOVING: two look fingers + the joystick held must NOT zoom (it peeks instead) ---
	cam.zoom = Vector2.ONE
	cam.position = Vector2.ZERO
	rig._offset = Vector2.ZERO
	VirtualJoystick.active_index = 7   # the move stick is engaged
	rig._unhandled_input(_press(4, Vector2(400, 400)))
	rig._unhandled_input(_press(5, Vector2(600, 400)))
	rig._unhandled_input(_drag(5, Vector2(700, 400), Vector2(100, 0)))
	rig._unhandled_input(_drag(5, Vector2(900, 400), Vector2(200, 0)))
	rig._process(0.016)
	var t_nozoom : bool = is_equal_approx(cam.zoom.x, 1.0)               # zoom NEVER changed while moving
	var t_movepeek : bool = not cam.position.is_equal_approx(Vector2.ZERO)   # it peeked instead
	print("no-zoom-while-moving: %s  peeked-instead: %s (z=%.3f x=%.1f)" % [t_nozoom, t_movepeek, cam.zoom.x, cam.position.x])
	ok = ok and t_nozoom and t_movepeek
	rig._unhandled_input(_release(4, Vector2(400, 400)))
	rig._unhandled_input(_release(5, Vector2(900, 400)))
	VirtualJoystick.active_index = -1

	# --- PEEK while MOVING: one look finger + the joystick held peeks (and never zooms) ---
	cam.zoom = Vector2.ONE
	cam.position = Vector2.ZERO
	rig._offset = Vector2.ZERO
	VirtualJoystick.active_index = 7
	rig._unhandled_input(_press(6, Vector2(800, 300)))
	rig._unhandled_input(_drag(6, Vector2(700, 300), Vector2(-100, 0)))   # swipe left while moving
	rig._process(0.016)
	var t_movelook : bool = cam.position.x > 50.0 and is_equal_approx(cam.zoom.x, 1.0)
	print("peek-while-moving: %s (x=%.1f)" % [t_movelook, cam.position.x])
	ok = ok and t_movelook
	rig._unhandled_input(_release(6, Vector2(700, 300)))
	VirtualJoystick.active_index = -1

	# --- ZOOM must NOT flow into PAN (Troy 2026-06-14): after a pinch, the leftover finger is inert (it used to
	# snap into a jerky peek) until ALL fingers lift; then a fresh single touch peeks normally again. ---
	cam.zoom = Vector2.ONE; cam.position = Vector2.ZERO
	rig._offset = Vector2.ZERO; rig._looks.clear(); rig._pinch_locked = false; rig._pinch_dist = -1.0
	VirtualJoystick.active_index = -1
	rig._unhandled_input(_press(8, Vector2(400.0, 400.0)))
	rig._unhandled_input(_press(9, Vector2(600.0, 400.0)))
	rig._unhandled_input(_drag(9, Vector2(700.0, 400.0), Vector2(100.0, 0.0)))   # pinch baseline
	rig._unhandled_input(_drag(9, Vector2(800.0, 400.0), Vector2(100.0, 0.0)))   # pinch -> zoom + lock
	rig._unhandled_input(_release(8, Vector2(400.0, 400.0)))                       # lift ONE finger, one remains
	rig._unhandled_input(_drag(9, Vector2(200.0, 400.0), Vector2(-600.0, 0.0)))    # leftover finger drags hard
	rig._process(0.016)
	var no_zoom_to_pan : bool = cam.position.is_equal_approx(Vector2.ZERO)          # leftover finger did NOT pan
	rig._unhandled_input(_release(9, Vector2(200.0, 400.0)))                        # lift ALL -> unlock
	var unlocked : bool = not rig._pinch_locked
	rig._unhandled_input(_press(10, Vector2(500.0, 300.0)))
	rig._unhandled_input(_drag(10, Vector2(600.0, 300.0), Vector2(100.0, 0.0)))     # a fresh single touch
	rig._process(0.016)
	var fresh_peek_ok : bool = not cam.position.is_equal_approx(Vector2.ZERO)        # peeks normally again
	print("zoom-not-to-pan: lockedLeftover=%s unlocksAfterRelease=%s freshPeekWorks=%s" % [no_zoom_to_pan, unlocked, fresh_peek_ok])
	ok = ok and no_zoom_to_pan and unlocked and fresh_peek_ok
	rig._unhandled_input(_release(10, Vector2(600.0, 300.0)))

	# --- THE STICK'S FINGER MUST NOT BLEED INTO THE PEEK (Troy 2026-06-14): a finger the joystick owns
	# (active_index) is excluded from the look set, so dragging the move thumb can never move the camera offset. ---
	cam.position = Vector2.ZERO
	rig._offset = Vector2.ZERO
	rig._looks.clear()
	VirtualJoystick.active_index = 3                       # the stick owns finger 3
	rig._unhandled_input(_press(3, Vector2(120.0, 600.0)))   # the stick's own finger presses
	var excl_press : bool = not rig._looks.has(3)            # excluded from the look set
	rig._unhandled_input(_drag(3, Vector2(420.0, 600.0), Vector2(300.0, 0.0)))   # the move thumb drags hard
	rig._process(0.016)
	var excl_drag : bool = cam.position.is_equal_approx(Vector2.ZERO)   # the camera/peek did NOT move
	print("stick-finger excluded from peek: press=%s drag=%s" % [excl_press, excl_drag])
	ok = ok and excl_press and excl_drag
	VirtualJoystick.active_index = -1

	# --- OWNERSHIP by where the touch STARTS: a press in the joystick zone is ignored (a move finger), one
	# outside it is a look finger the rig tracks. ---
	var js : VirtualJoystick = VirtualJoystick.new()
	root.add_child(js)
	# Control anchor layout doesn't resolve inside _initialize (there's no frame loop), so pin the zone geometry
	# directly rather than relying on the bottom-left anchor preset that _ready sets.
	js.set_anchors_preset(Control.PRESET_TOP_LEFT)
	js.size = Vector2(200.0, 200.0)
	js.position = Vector2(0.0, 500.0)
	var rig2 : OverworldCamera = OverworldCamera.new()
	rig2.setup(cam, js)
	root.add_child(rig2)
	var zone : Rect2 = js._zone()
	rig2._unhandled_input(_press(0, zone.position + zone.size * 0.5))     # inside the zone -> ignored
	var own_in : bool = rig2._looks.is_empty()
	rig2._unhandled_input(_press(1, zone.position - Vector2(100.0, 100.0)))   # outside the zone -> tracked
	var own_out : bool = rig2._looks.has(1)
	print("ownership: ignoresMoveZone=%s tracksLook=%s (zone=%s)" % [own_in, own_out, zone])
	ok = ok and own_in and own_out
	js.free(); rig2.free()

	cam.free(); rig.free()
	TouchEnv._cached_touch = -1
	print("RESULT: ", "ALL PASS" if ok else "FAILURE")
	quit(0 if ok else 1)

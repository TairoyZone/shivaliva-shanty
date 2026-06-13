## Headless regression test for PinchZoom: zoom ratio + clamp, the persisted shared_zoom, and the pan clamp.
## Run:
##   Godot_v4.6.3_console.exe --headless --path <proj> --script res://components/touch_controls/test_pinch_zoom.gd
extends SceneTree


func _initialize() -> void:

	var ok : bool = true
	PinchZoom.shared_zoom = 1.0   # reset the static so a prior run can't leak in

	# --- Zoom ratio + clamp, and shared_zoom persistence ---
	var cam : Camera2D = Camera2D.new()
	cam.zoom = Vector2.ONE
	cam.position = Vector2(640.0, 360.0)
	var pz : PinchZoom = PinchZoom.new()
	pz.setup(cam, 1.0, 2.6, Vector2.ZERO)
	root.add_child(cam)
	root.add_child(pz)        # in the tree so _pinch's get_viewport() works
	pz._base_pos = cam.position

	pz._touches = {0: Vector2(100, 0), 1: Vector2(200, 0)}   # baseline, dist 100
	pz._pinch()
	var t1 : bool = is_equal_approx(cam.zoom.x, 1.0)
	pz._touches = {0: Vector2(50, 0), 1: Vector2(250, 0)}    # dist 200, ratio 2 -> 2.0
	pz._pinch()
	var t2 : bool = is_equal_approx(cam.zoom.x, 2.0)
	pz._touches = {0: Vector2(-50, 0), 1: Vector2(350, 0)}   # dist 400, ratio 2 -> clamp 2.6
	pz._pinch()
	var t3 : bool = is_equal_approx(cam.zoom.x, 2.6)
	pz._touches = {0: Vector2(100, 0), 1: Vector2(200, 0)}   # dist 100, ratio .25 -> clamp 1.0
	pz._pinch()
	var t4 : bool = is_equal_approx(cam.zoom.x, 1.0)
	var t5 : bool = is_equal_approx(PinchZoom.shared_zoom, cam.zoom.x)   # zoom PERSISTS to the static
	print("zoom: baseline=%s spread=%s clampMax=%s clampMin=%s persisted=%s" % [t1, t2, t3, t4, t5])
	ok = ok and t1 and t2 and t3 and t4 and t5

	# --- One-finger pan moves the view opposite the finger, clamped to the look-around (overworld style) ---
	var cam2 : Camera2D = Camera2D.new()
	cam2.zoom = Vector2.ONE
	cam2.position = Vector2.ZERO
	var pz2 : PinchZoom = PinchZoom.new()
	pz2.setup(cam2, 1.0, 2.6, Vector2(240.0, 160.0))   # follow-cam look-around
	root.add_child(cam2)
	root.add_child(pz2)
	pz2._base_pos = Vector2.ZERO

	# A small drag right (100px) -> camera moves LEFT 100 (within the ±240 clamp).
	var d1 : InputEventScreenDrag = InputEventScreenDrag.new()
	d1.index = 0
	d1.position = Vector2(200.0, 200.0)
	d1.relative = Vector2(100.0, 0.0)
	pz2._touches = {0: Vector2(200.0, 200.0)}
	pz2._panning = true
	pz2._one_finger_pan(d1)
	var p1 : bool = is_equal_approx(cam2.position.x, -100.0)

	# A big drag right (400px) -> would push to -500, CLAMPED to -240.
	var d2 : InputEventScreenDrag = InputEventScreenDrag.new()
	d2.index = 0
	d2.position = Vector2(600.0, 200.0)
	d2.relative = Vector2(400.0, 0.0)
	pz2._one_finger_pan(d2)
	var p2 : bool = is_equal_approx(cam2.position.x, -240.0)
	print("pan: moves=%s clamped=%s" % [p1, p2])
	ok = ok and p1 and p2

	cam.free(); pz.free(); cam2.free(); pz2.free()
	print("RESULT: ", "ALL PASS" if ok else "FAILURE")
	quit(0 if ok else 1)

## Headless regression test for PinchZoom: zoom ratio + clamp, persisted shared_zoom, pan + clamp, AND the
## release behaviour Troy asked about — overworld PULLS BACK to base on release; a puzzle CLAMPS to the canvas and
## STAYS where you let go. Run:
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
	root.add_child(pz)
	pz._base_pos = cam.position

	pz._touches = {0: Vector2(100, 0), 1: Vector2(200, 0)}
	pz._pinch()
	var t1 : bool = is_equal_approx(cam.zoom.x, 1.0)
	pz._touches = {0: Vector2(50, 0), 1: Vector2(250, 0)}
	pz._pinch()
	var t2 : bool = is_equal_approx(cam.zoom.x, 2.0)
	pz._touches = {0: Vector2(-50, 0), 1: Vector2(350, 0)}
	pz._pinch()
	var t3 : bool = is_equal_approx(cam.zoom.x, 2.6)
	pz._touches = {0: Vector2(100, 0), 1: Vector2(200, 0)}
	pz._pinch()
	var t4 : bool = is_equal_approx(cam.zoom.x, 1.0)
	var t5 : bool = is_equal_approx(PinchZoom.shared_zoom, cam.zoom.x)
	print("zoom: baseline=%s spread=%s clampMax=%s clampMin=%s persisted=%s" % [t1, t2, t3, t4, t5])
	ok = ok and t1 and t2 and t3 and t4 and t5

	# --- OVERWORLD (recenter=true): pan moves + clamps to the look-around, then PULLS BACK on release ---
	var camO : Camera2D = Camera2D.new()
	camO.zoom = Vector2.ONE
	camO.position = Vector2.ZERO
	var pzo : PinchZoom = PinchZoom.new()
	pzo.setup(camO, 1.0, 2.6, Vector2(240.0, 160.0), true)   # follow-cam look-around + recenter
	root.add_child(camO)
	root.add_child(pzo)
	pzo._base_pos = Vector2.ZERO

	var d1 : InputEventScreenDrag = InputEventScreenDrag.new()
	d1.index = 0; d1.position = Vector2(200.0, 200.0); d1.relative = Vector2(100.0, 0.0)
	pzo._touches = {0: Vector2(200.0, 200.0)}; pzo._panning = true
	pzo._one_finger_pan(d1)
	var o1 : bool = is_equal_approx(camO.position.x, -100.0)            # moved opposite the finger
	var d2 : InputEventScreenDrag = InputEventScreenDrag.new()
	d2.index = 0; d2.position = Vector2(600.0, 200.0); d2.relative = Vector2(400.0, 0.0)
	pzo._one_finger_pan(d2)
	var o2 : bool = is_equal_approx(camO.position.x, -240.0)            # clamped to the look-around
	# RELEASE: fingers up -> _process eases the pan back to base (the player).
	pzo._touches = {}; pzo._panning = false
	for _i in 60:
		pzo._process(0.05)
	var o3 : bool = camO.position.is_equal_approx(Vector2.ZERO)        # PULLED BACK to original on release
	print("overworld: panMoves=%s panClamp=%s recenters=%s" % [o1, o2, o3])
	ok = ok and o1 and o2 and o3

	# --- PUZZLE (recenter=false): pan CLAMPS to the canvas, then STAYS where released ---
	var camP : Camera2D = Camera2D.new()
	camP.zoom = Vector2(2.0, 2.0)                # zoomed in so there IS room to pan
	camP.position = Vector2(640.0, 360.0)        # canvas centre
	var pzp : PinchZoom = PinchZoom.new()
	pzp.setup(camP, 1.0, 2.8, Vector2.ZERO, false)   # static table, clamp to edges, no recenter
	root.add_child(camP)
	root.add_child(pzp)
	pzp._base_pos = Vector2(640.0, 360.0)

	# Shove hard right (finger left): want = 640 - (-2000)/2 = 1640 -> CLAMPED to 640 + 320 = 960 (view edge = 1280).
	var d3 : InputEventScreenDrag = InputEventScreenDrag.new()
	d3.index = 0; d3.position = Vector2(100.0, 360.0); d3.relative = Vector2(-2000.0, 0.0)
	pzp._touches = {0: Vector2(100.0, 360.0)}; pzp._panning = true
	pzp._one_finger_pan(d3)
	var q1 : bool = is_equal_approx(camP.position.x, 960.0)            # clamped so the view stays ON the canvas
	var view_right : float = camP.position.x + 1280.0 / (2.0 * camP.zoom.x)
	var q2 : bool = view_right <= 1280.0 + 0.5                         # view's right edge never passes the canvas
	# RELEASE: a puzzle does NOT recenter -> stays put.
	pzp._touches = {}; pzp._panning = false
	for _i in 60:
		pzp._process(0.05)
	var q3 : bool = is_equal_approx(camP.position.x, 960.0)           # STAYED where the player let go
	print("puzzle: clampToCanvas=%s viewOnCanvas=%s staysPut=%s" % [q1, q2, q3])
	ok = ok and q1 and q2 and q3

	cam.free(); pz.free(); camO.free(); pzo.free(); camP.free(); pzp.free()
	print("RESULT: ", "ALL PASS" if ok else "FAILURE")
	quit(0 if ok else 1)

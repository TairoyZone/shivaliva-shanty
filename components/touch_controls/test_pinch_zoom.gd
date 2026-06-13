## Headless regression test for PinchZoom's zoom math (ratio + clamp). Zoom-only mode needs no viewport, so we
## drive _pinch() directly. Run:
##   Godot_v4.6.3_console.exe --headless --path <proj> --script res://components/touch_controls/test_pinch_zoom.gd
extends SceneTree


func _initialize() -> void:

	var ok : bool = true
	var cam : Camera2D = Camera2D.new()
	cam.zoom = Vector2.ONE
	var pz : PinchZoom = PinchZoom.new()
	pz.setup(cam, 1.0, 2.6, false)   # zoom-only: _pinch() never touches the viewport
	pz._base_pos = cam.position

	# Baseline frame: two fingers 100px apart → just records, no zoom change.
	pz._touches = {0: Vector2(100, 0), 1: Vector2(200, 0)}
	pz._pinch()
	var t1 : bool = is_equal_approx(cam.zoom.x, 1.0)

	# Spread to 200px (ratio 2.0) → zoom 2.0.
	pz._touches = {0: Vector2(50, 0), 1: Vector2(250, 0)}
	pz._pinch()
	var t2 : bool = is_equal_approx(cam.zoom.x, 2.0)

	# Spread to 400px (ratio 2.0) → 4.0, CLAMPED to max 2.6.
	pz._touches = {0: Vector2(-50, 0), 1: Vector2(350, 0)}
	pz._pinch()
	var t3 : bool = is_equal_approx(cam.zoom.x, 2.6)

	# Pinch back to 100px (ratio 0.25) → 0.65, CLAMPED to min 1.0 (never below the default view).
	pz._touches = {0: Vector2(100, 0), 1: Vector2(200, 0)}
	pz._pinch()
	var t4 : bool = is_equal_approx(cam.zoom.x, 1.0)

	# Zoom stays symmetric (square pixels).
	var t5 : bool = is_equal_approx(cam.zoom.x, cam.zoom.y)

	ok = t1 and t2 and t3 and t4 and t5
	print("zoom: baseline=%s spread2x=%s clampMax=%s clampMin=%s square=%s" % [t1, t2, t3, t4, t5])
	cam.free()
	pz.free()
	print("RESULT: ", "ALL PASS" if ok else "FAILURE")
	quit(0 if ok else 1)

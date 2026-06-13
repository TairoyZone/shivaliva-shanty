## Headless regression check for the puzzle joystick mapping + that the VirtualJoystick refactor
## kept the overworld iso map intact (guards the shared _actions_for seam). Run:
##   Godot_v4.6.3_console.exe --headless --path <proj> --script res://components/touch_controls/test_touch_joystick.gd
extends SceneTree


func _initialize() -> void:

	var ok : bool = true
	var R : float = VirtualJoystick.RADIUS

	# Parse-check the changed scripts (load() forces a fresh compile + prints any error).
	for s in [
		"res://components/touch_controls/virtual_joystick.gd",
		"res://components/touch_controls/puzzle_joystick.gd",
		"res://components/puzzle_scene/puzzle_scene.gd",
		"res://autoloads/dev_cheats.gd",
		"res://puzzles/mining/mining.gd",
		"res://puzzles/skirmish/skirmish.gd",
		"res://puzzles/skirmish/skirmish_duel.gd",
		"res://puzzles/skirmish/skirmish_boarding.gd",
	]:
		if load(s) == null:
			print("LOAD FAIL: ", s)
			ok = false

	# PuzzleJoystick "both" (4-way cardinal, dominant axis wins).
	var stick : PuzzleJoystick = PuzzleJoystick.new()
	stick.set_mode("both")
	var both_ok : bool = stick._actions_for(Vector2(R, 0)) == ["ui_right"] \
		and stick._actions_for(Vector2(-R, 0)) == ["ui_left"] \
		and stick._actions_for(Vector2(0, R)) == ["ui_down"] \
		and stick._actions_for(Vector2(0, -R)) == ["ui_up"] \
		and stick._actions_for(Vector2(R, R * 0.3)) == ["ui_right"] \
		and stick._actions_for(Vector2(R * 0.3, -R)) == ["ui_up"]
	print("both mode (4-way): ", "PASS" if both_ok else "FAIL")
	ok = ok and both_ok

	# PuzzleJoystick "drop" (left/right + pull-DOWN soft-drop; UP does nothing — no hard drop).
	stick.set_mode("drop")
	var drop_ok : bool = stick._actions_for(Vector2(R, 0)) == ["ui_right"] \
		and stick._actions_for(Vector2(-R, 0)) == ["ui_left"] \
		and stick._actions_for(Vector2(0, R)) == ["ui_down"] \
		and stick._actions_for(Vector2(0, -R)) == [] \
		and stick._actions_for(Vector2(R * 0.3, R)) == ["ui_down"] \
		and stick._actions_for(Vector2(R, R * 0.3)) == ["ui_right"]
	print("drop mode (left/right + down, no hard drop): ", "PASS" if drop_ok else "FAIL")
	ok = ok and drop_ok

	# PuzzleJoystick "horizontal" (left/right only; vertical ignored).
	stick.set_mode("horizontal")
	var horiz_ok : bool = stick._actions_for(Vector2(R, 0)) == ["ui_right"] \
		and stick._actions_for(Vector2(-R, 0)) == ["ui_left"] \
		and stick._actions_for(Vector2(0, R)) == [] \
		and stick._actions_for(Vector2(0, -R)) == [] \
		and stick._actions_for(Vector2(R, R)) == ["ui_right"]
	print("horizontal mode (left/right): ", "PASS" if horiz_ok else "FAIL")
	ok = ok and horiz_ok

	# VirtualJoystick (overworld) iso octant map must survive the refactor.
	var vj : VirtualJoystick = VirtualJoystick.new()
	var iso_ok : bool = vj._actions_for(Vector2(0, -R)) == ["move_right", "move_up"] \
		and vj._actions_for(Vector2(R, 0)) == ["move_right", "move_down"] \
		and vj._actions_for(Vector2(0, R)) == ["move_left", "move_down"] \
		and vj._actions_for(Vector2(-R, 0)) == ["move_left", "move_up"]
	print("overworld iso map intact: ", "PASS" if iso_ok else "FAIL")
	ok = ok and iso_ok

	# --- MULTI-TOUCH ROUTING: the joystick OWNS its finger globally; PinchZoom ignores fingers it didn't claim.
	# This is the "move + swipe-pan no longer fight" fix. ---
	var jz : VirtualJoystick = VirtualJoystick.new()
	root.add_child(jz)
	jz.set_anchors_preset(Control.PRESET_TOP_LEFT)
	jz.position = Vector2(0.0, 500.0)
	jz.size = Vector2(212.0, 212.0)
	# A press INSIDE the stick zone claims the finger.
	var jt : InputEventScreenTouch = InputEventScreenTouch.new()
	jt.index = 0; jt.position = Vector2(100.0, 560.0); jt.pressed = true
	jz._input(jt)
	var claim_ok : bool = jz._touch_index == 0
	# That finger DRAGS far outside the zone — still tracked (global ownership, ML-style).
	var jd : InputEventScreenDrag = InputEventScreenDrag.new()
	jd.index = 0; jd.position = Vector2(700.0, 150.0)
	jz._input(jd)
	var global_track_ok : bool = jz._knob != Vector2.ZERO
	# Release, then a press OUTSIDE the zone must NOT be claimed (it's free for the camera pan).
	var jr : InputEventScreenTouch = InputEventScreenTouch.new()
	jr.index = 0; jr.position = Vector2(700.0, 150.0); jr.pressed = false
	jz._input(jr)
	var jt2 : InputEventScreenTouch = InputEventScreenTouch.new()
	jt2.index = 1; jt2.position = Vector2(640.0, 360.0); jt2.pressed = true
	jz._input(jt2)
	var zone_ok : bool = jz._touch_index == -1
	print("joystick routing: claims=%s globalTrack=%s ignoresOutOfZone=%s" % [claim_ok, global_track_ok, zone_ok])
	ok = ok and claim_ok and global_track_ok and zone_ok
	jz.free()

	# PinchZoom must IGNORE a finger whose press it never tracked (the joystick owns it), but PAN on its own finger.
	TouchEnv._cached_touch = 1   # force is_touch() past the _unhandled_input guard
	var pcam : Camera2D = Camera2D.new()
	pcam.zoom = Vector2.ONE; pcam.position = Vector2.ZERO
	var pz2 : PinchZoom = PinchZoom.new()
	pz2.setup(pcam, 1.0, 2.6, Vector2(300.0, 300.0), false)
	root.add_child(pcam); root.add_child(pz2)
	pz2._base_pos = Vector2.ZERO
	var pt : InputEventScreenTouch = InputEventScreenTouch.new()      # the PAN finger presses (tracked)
	pt.index = 1; pt.position = Vector2(300.0, 300.0); pt.pressed = true
	pz2._unhandled_input(pt)
	var ud : InputEventScreenDrag = InputEventScreenDrag.new()        # an UNTRACKED finger drags hard
	ud.index = 0; ud.position = Vector2(800.0, 300.0); ud.relative = Vector2(500.0, 0.0)
	pz2._unhandled_input(ud)
	var ignore_ok : bool = pcam.position.is_equal_approx(Vector2.ZERO)   # ignored — camera stayed
	var td : InputEventScreenDrag = InputEventScreenDrag.new()        # the tracked finger drags
	td.index = 1; td.position = Vector2(380.0, 300.0); td.relative = Vector2(80.0, 0.0)
	pz2._unhandled_input(td)
	var pan_ok : bool = not pcam.position.is_equal_approx(Vector2.ZERO)  # panned
	print("pinch routing: ignoresUntracked=%s pansTracked=%s" % [ignore_ok, pan_ok])
	ok = ok and ignore_ok and pan_ok
	pcam.free(); pz2.free()
	TouchEnv._cached_touch = -1

	stick.free()
	vj.free()
	print("RESULT: ", "ALL PASS" if ok else "FAILURE")
	quit(0 if ok else 1)

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

	# --- EMULATED-MOUSE HIJACK GUARD (Troy 2026-06-14): on a touchscreen the stick must IGNORE mouse events, so a
	# 2nd finger (a camera peek) routed through emulate_mouse_from_touch can't seize the stick and seesaw movement.
	VirtualJoystick.mouse_for_test = 0   # simulate a real phone (no mouse), independent of the headless host
	var hj : VirtualJoystick = VirtualJoystick.new()
	root.add_child(hj)
	hj.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hj.position = Vector2(0.0, 500.0)
	hj.size = Vector2(212.0, 212.0)
	# An emulated MOUSE press lands in-zone FIRST (the ordering that used to hijack the stick) — must be IGNORED.
	var em : InputEventMouseButton = InputEventMouseButton.new()
	em.button_index = MOUSE_BUTTON_LEFT; em.pressed = true; em.position = Vector2(100.0, 560.0)
	hj._input(em)
	var no_mouse_claim : bool = hj._touch_index == -1            # the mouse did NOT claim the stick
	# The REAL touch finger then claims + drives the stick.
	var ht : InputEventScreenTouch = InputEventScreenTouch.new()
	ht.index = 0; ht.pressed = true; ht.position = Vector2(100.0, 560.0)
	hj._input(ht)
	var htd : InputEventScreenDrag = InputEventScreenDrag.new()
	htd.index = 0; htd.position = Vector2(150.0, 560.0)
	hj._input(htd)
	var real_claim : bool = hj._touch_index == 0
	var knob_after_move : Vector2 = hj._knob
	# A 2nd finger now peeks — routed as an emulated MOUSE MOTION (the hijack vector) AND its own touch drag. Neither
	# may move the stick.
	var emm : InputEventMouseMotion = InputEventMouseMotion.new()
	emm.position = Vector2(900.0, 120.0)
	hj._input(emm)
	var f1d : InputEventScreenDrag = InputEventScreenDrag.new()
	f1d.index = 1; f1d.position = Vector2(900.0, 120.0)
	hj._input(f1d)
	var immune : bool = hj._knob.is_equal_approx(knob_after_move) and hj._touch_index == 0
	print("emulated-mouse hijack guard: ignoresMouseClaim=%s realTouchDrives=%s immuneToPeek=%s" % [no_mouse_claim, real_claim, immune])
	ok = ok and no_mouse_claim and real_claim and immune
	hj.free()
	VirtualJoystick.mouse_for_test = -1

	stick.free()
	vj.free()
	print("RESULT: ", "ALL PASS" if ok else "FAILURE")
	quit(0 if ok else 1)

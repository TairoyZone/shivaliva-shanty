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

	stick.free()
	vj.free()
	print("RESULT: ", "ALL PASS" if ok else "FAILURE")
	quit(0 if ok else 1)

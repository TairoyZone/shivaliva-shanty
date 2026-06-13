## PuzzleJoystick — a touch stick for PUZZLE boards (not the overworld). Where [VirtualJoystick] drives the iso
## `move_*` actions, this drives the `ui_left/ui_right/ui_up/ui_down` actions the puzzle boards ALREADY poll +
## DAS-repeat (Mining's 2x2 cursor, Skirmish's piece-shift) — so the cursor / piece moves with ZERO board change.
## It inherits all the touch/hold/release/cleanup plumbing from [VirtualJoystick] and only overrides the
## direction -> action mapping.
##
## Modes (set via [method set_mode] BEFORE adding to the tree):
##   "both"        — 4-way cardinal d-pad: snap to the DOMINANT axis so a grid cursor never drifts diagonally.
##   "drop"        — left/right + pull-DOWN = soft-drop; UP does nothing (Skirmish has NO hard drop).
##   "horizontal"  — left/right only; vertical is ignored.
##
## Spawned by [PuzzleScene] when a puzzle's [method PuzzleScene._touch_joystick] returns a mode. Bottom-left,
## gamepad-style — the rotate button stays bottom-right on the [TouchControlBar]. See [[touch-input-foundation]].
class_name PuzzleJoystick
extends VirtualJoystick


var _mode : String = "both"


## "both" (4-way), "drop" (left/right + down), or "horizontal" (left/right only). Default "both".
func set_mode(mode: String) -> void:
	_mode = mode


# Map the thumb to ONE ui_* action by the DOMINANT axis (predictable for a grid cursor / piece-shift).
func _actions_for(v: Vector2) -> Array:

	if absf(v.x) >= absf(v.y):
		return ["ui_right"] if v.x > 0.0 else ["ui_left"]
	# Vertical dominates:
	if _mode == "horizontal":
		return []                          # left/right only — ignore vertical
	if v.y > 0.0:
		return ["ui_down"]                 # pull DOWN = move-down / soft-drop
	if _mode == "drop":
		return []                          # pull UP does nothing — Skirmish has no hard drop
	return ["ui_up"]                       # "both": 4-way grid cursor

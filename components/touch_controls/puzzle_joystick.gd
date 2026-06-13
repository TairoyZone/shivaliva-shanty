## PuzzleJoystick — a touch stick for PUZZLE boards (not the overworld). Where [VirtualJoystick] drives the iso
## `move_*` actions, this drives the `ui_left/ui_right/ui_up/ui_down` actions the puzzle boards ALREADY poll +
## DAS-repeat (Mining's 2x2 cursor, Skirmish's piece-shift) — so the cursor / piece moves with ZERO board change.
## It inherits all the touch/hold/release/cleanup plumbing from [VirtualJoystick] and only overrides the
## direction -> action mapping.
##
## Two modes (set via [method set_mode] BEFORE adding to the tree):
##   "both"        — 4-way cardinal d-pad: snap to the DOMINANT axis so a grid cursor never drifts diagonally.
##   "horizontal"  — left/right only (Troy's "left-right joystick" for Skirmish); vertical is ignored.
##
## Spawned by [PuzzleScene] when a puzzle's [method PuzzleScene._touch_joystick] returns a mode. Bottom-left,
## gamepad-style — the rotate/drop buttons stay bottom-right on the [TouchControlBar]. See [[touch-input-foundation]].
class_name PuzzleJoystick
extends VirtualJoystick


var _horizontal_only : bool = false


## "both" (4-way) or "horizontal" (left/right only). Default "both".
func set_mode(mode: String) -> void:
	_horizontal_only = (mode == "horizontal")


# Map the thumb to ONE ui_* action by the dominant axis (predictable for a grid cursor). Horizontal mode needs
# real horizontal displacement before it fires, so a stray vertical push moves nothing.
func _actions_for(v: Vector2) -> Array:

	if _horizontal_only:
		if absf(v.x) < RADIUS * DEADZONE_FRAC:
			return []
		return ["ui_right"] if v.x > 0.0 else ["ui_left"]
	if absf(v.x) >= absf(v.y):
		return ["ui_right"] if v.x > 0.0 else ["ui_left"]
	return ["ui_down"] if v.y > 0.0 else ["ui_up"]

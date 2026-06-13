## Base class for the actual playable parlor-game scene that a [Puzzle]
## prop launches into. Gem Drop, Poker, and future job-puzzles all
## extend this. Naming distinction:
##
##   [Puzzle]      — the prop in the overworld the player walks up to.
##   [PuzzleScene] — the standalone scene that runs when the puzzle
##                   is launched.
##
## Shared responsibilities bundled here:
##   - hide the overworld HUD on enter, restore it on exit,
##   - ESC → return to whichever scene launched us
##     ([PlayerState.last_scene], written by BaseLocation on its way out),
##   - "game over → click anywhere to return" affordance,
##   - convenience helper to award gold.
##
## Concrete puzzles implement their own mechanics + UI; they call
## `_set_awaiting_dismiss(true)` when the game finishes so the click-to-
## dismiss kicks in, and `award_winnings(N)` to credit the player.
extends Node2D
class_name PuzzleScene


var _awaiting_dismiss : bool = false
var _hud_swapped : bool = false   # touch action puzzle: did we relocate this puzzle's top HUD to the bottom?


func _ready() -> void:

	if HUD:
		HUD.visible = false
	_relocate_touch_hud()   # action puzzle on touch: centre its top HUD so Leave/Chat take the top corners
	_build_leave_button()
	_build_touch_controls()


func _exit_tree() -> void:

	UserPanel.set_puzzle_help("")   # clear this puzzle's how-to from the persistent Tutorial tab
	if HUD:
		HUD.visible = true
		# Replay any gold-change animation that was deferred while
		# the HUD was hidden — otherwise the +N / -N from this puzzle
		# session never shows on the purse.
		if HUD.has_method("flush_pending_change"):
			HUD.flush_pending_change()
		# Same idea for wood — Lumberjacking adds wood to inventory while
		# the HUD is hidden, the gain has to be replayed on the overworld.
		if HUD.has_method("flush_pending_wood_change"):
			HUD.flush_pending_wood_change()


func _unhandled_input(event: InputEvent) -> void:

	# Click anywhere to dismiss the results once a game has ended.
	if _awaiting_dismiss and event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_return_to_launching_scene()
		return
	# ESC follows the SAME priority as the overworld: close an open panel / the chat log FIRST, else open the
	# pause menu. The HUD owns that chain (_on_escape) but is HIDDEN inside a puzzle, so reuse it directly rather
	# than duplicate it — otherwise ESC would skip straight to pause over an open log (Troy 2026-06-11). Leaving
	# is still the deliberate Leave button; the pause menu's Resume drops you right back in.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		HUD._on_escape()


## Override → true to dock the Leave button at the TOP-left instead of the default BOTTOM-left — for scenes
## where the bottom-left is occupied (e.g. poker, whose chat bar lives there).
func _leave_at_top_left() -> bool:
	return false


## Override → the puzzle's TOP score/status HUD container (a single Control) so PuzzleScene CENTRES it at the top
## on touch, freeing the top CORNERS for the Leave + Chat buttons (Troy 2026-06-12). Default null = no relocation
## (the buttons fall back to top-centre, clear of the corners).
func _touch_hud_node() -> Control:
	return null


## Override → true if the puzzle's own HUD leaves the top CORNERS free (e.g. Mining's centre bar, Skirmish's
## headers above the boards), so the Leave + Chat buttons take the corners — no HUD relocation needed (Troy
## 2026-06-13).
func _touch_buttons_at_corners() -> bool:
	return false


## True once this puzzle's top HUD has been relocated to the bottom (so Leave/Chat take the top corners). ChatBox
## reads this to place the Chat button to match.
func touch_hud_swapped() -> bool:
	return _hud_swapped


# Centre the puzzle's top HUD (if it declares one) at the TOP, content-sized — between the Leave (top-left) and
# Chat (top-right) buttons that take the corners. MINSIZE preset so an HBox HUD still lays its children out (a
# zero-width grown anchor would not).
func _relocate_touch_hud() -> void:

	if not _has_touch_bar():
		return
	if _touch_buttons_at_corners():
		_hud_swapped = true   # the puzzle's HUD leaves the corners free — just send Leave/Chat there
		return
	var hud : Control = _touch_hud_node()
	if hud == null:
		return
	hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)
	_hud_swapped = true


# Persistent "Leave" button, bottom-left, on its own high CanvasLayer so
# it sits above the puzzle's own UI. Replaces the old instant-ESC exit:
# leaving is now an explicit click. Leaving mid-hand forfeits whatever's
# committed (poker: chips already in the pot; gem drop: the match) —
# that falls out naturally since [method _return_to_launching_scene]
# only banks what the player still holds.
func _build_leave_button() -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 20
	layer.name = "LeaveLayer"
	add_child(layer)
	var btn : Button = Button.new()
	btn.text = "← Leave"
	btn.focus_mode = Control.FOCUS_NONE
	# Placement: a touch action puzzle that RELOCATED its HUD to the bottom (_hud_swapped) — or poker — puts Leave
	# in the TOP-left corner. A touch action puzzle that HASN'T yet -> TOP-CENTRE (clear of its top-corner HUD).
	# Everything else -> the default BOTTOM-left (Troy 2026-06-12).
	if _hud_swapped or _leave_at_top_left():
		btn.offset_left = 20.0
		btn.offset_right = 140.0
		btn.offset_top = 16.0
		btn.offset_bottom = 56.0
	elif _has_touch_bar():
		# Un-swapped action puzzle (HUD lives in the top CORNERS, e.g. Skirmish's YOU/foe headers) -> Leave sits
		# just LEFT of centre and GROWS left, so its "← Leave" text can never push into the Chat button on the
		# right of centre (Troy 2026-06-13, the Skirmish self-overlap). Its right edge is pinned at centre-12.
		btn.anchor_left = 0.5
		btn.anchor_right = 0.5
		btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		btn.offset_left = -150.0
		btn.offset_right = -12.0
		btn.offset_top = 16.0
		btn.offset_bottom = 56.0
	else:
		btn.offset_left = 20.0
		btn.offset_right = 140.0
		btn.anchor_top = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_top = -56.0
		btn.offset_bottom = -16.0
	btn.add_theme_font_size_override("font_size", 18)
	# Walnut/brass styling to match the tavern UI. Same box for normal /
	# hover / pressed with small tint shifts so it reads as a real button.
	for state in ["normal", "hover", "pressed"]:
		var style : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.18, 0.11, 0.06, 0.94)
		if state == "hover":
			bg = bg.lightened(0.08)
		elif state == "pressed":
			bg = bg.darkened(0.15)
		style.bg_color = bg
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.78, 0.58, 0.24, 1.0)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		btn.add_theme_stylebox_override(state, style)
	btn.add_theme_color_override("font_color", Color(0.97, 0.87, 0.55, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.6, 1.0))
	btn.pressed.connect(_return_to_launching_scene)   # the click SFX comes from the global Audio button hook
	layer.add_child(btn)


## Override -> a touch-control spec for THIS puzzle: an Array of {label, action/callable, hold} dicts (see
## [TouchControlBar]). Empty (default) = a tap-only puzzle (Loft / Gem Drop / poker) that needs no on-screen
## buttons. Each action puzzle fills this in (Phase 2). See [[touch-input-foundation]].
func _touch_spec() -> Array:
	return []


# True when this puzzle shows an on-screen touch control bar — its buttons claim the bottom corners, so the Leave
# button moves to the top-left and the UserPanel rail is hidden (Troy 2026-06-12).
func _has_touch_bar() -> bool:
	return TouchEnv.is_touch() and not _touch_spec().is_empty()


# Spawn the shared touch button bar from _touch_spec() on a touch device — one inherited seam, every action puzzle
# just declares its buttons. On its own CanvasLayer below the Leave button (layer 20) so Leave stays tappable.
func _build_touch_controls() -> void:

	if not TouchEnv.is_touch():
		return
	var spec : Array = _touch_spec()
	if spec.is_empty():
		return
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 18
	layer.name = "TouchControlsLayer"
	add_child(layer)
	var bar : TouchControlBar = TouchControlBar.new()
	bar.setup(spec)
	layer.add_child(bar)


## Puzzle instructions feed the persistent USER PANEL's Tutorial tab — the Sunshine-widget rail is always
## docked (overworld + in-puzzle), so the how-to sits in its Tutorial tab right beside the board. (Replaced
## the per-puzzle "?" / in-puzzle book 2026-06-07.) Concrete puzzles still call this with their how-to text.
func set_help_text(text: String) -> void:

	UserPanel.set_puzzle_help(text)


# Concrete puzzles call this when the game ends so the next click /
# ESC sends the player back to the overworld.
func _set_awaiting_dismiss(value: bool) -> void:

	_awaiting_dismiss = value


# Credit the player with winnings. Concrete puzzles call this from
# their game-complete handler.
func award_winnings(amount: int, reason: String = "") -> void:

	if amount <= 0:
		return
	PlayerState.add_coins(amount, reason)


# Returns to the scene that launched the puzzle. BaseLocation wrote
# its scene path into PlayerState.last_scene on its way out, and the
# [Puzzle] launcher set a pending_spawn_anchor so the player will
# appear right next to the prop they came from.
func _return_to_launching_scene() -> void:

	# A one-shot override (set by e.g. a Voyage that launched us as a
	# boarding fight) takes priority over last_scene, so last_scene keeps
	# pointing at a real resumable location.
	var return_scene : String = PlayerState.last_scene
	if not PlayerState.puzzle_return_scene.is_empty():
		return_scene = PlayerState.puzzle_return_scene
		PlayerState.puzzle_return_scene = ""
	if return_scene.is_empty():
		return_scene = "res://main.tscn"
	get_tree().change_scene_to_file(return_scene)

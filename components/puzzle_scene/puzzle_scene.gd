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


func _ready() -> void:

	if HUD:
		HUD.visible = false
	_build_leave_button()


func _exit_tree() -> void:

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

	# Note: ESC no longer bails out of a puzzle — leaving is a deliberate
	# act via the persistent Leave button (built below). The only input
	# handled here is the click-to-dismiss after a game has ended.
	if _awaiting_dismiss and event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_return_to_launching_scene()


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
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = 20.0
	btn.offset_top = -56.0
	btn.offset_right = 140.0
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
	btn.pressed.connect(_return_to_launching_scene)
	layer.add_child(btn)


## STANDING RULE (Troy 2026-06-01): puzzle instructions live behind a hoverable
## "?" button — NEVER a long text strip under the board (it runs off-screen + reads
## messy). Concrete puzzles call this with their how-to-play text; reuse everywhere.
## A small "?" sits bottom-right; hovering it reveals a fixed-width, word-wrapped
## panel just above it (so it can never overflow the screen).
func set_help_text(text: String) -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 21
	layer.name = "HelpLayer"
	add_child(layer)

	# The instruction panel — hidden until the "?" is hovered.
	var panel : PanelContainer = PanelContainer.new()
	var ps : StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.16, 0.11, 0.07, 0.97)
	ps.border_color = Color(0.78, 0.58, 0.24, 1.0)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(10)
	ps.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", ps)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -440.0
	panel.offset_right = -18.0
	panel.offset_bottom = -64.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.94, 0.89, 0.74, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(404.0, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	layer.add_child(panel)

	# The "?" button, bottom-right (opposite the Leave button), walnut/brass.
	var btn : Button = Button.new()
	btn.text = "?"
	btn.focus_mode = Control.FOCUS_NONE
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = -54.0
	btn.offset_right = -18.0
	btn.offset_top = -54.0
	btn.offset_bottom = -16.0
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.97, 0.87, 0.55, 1.0))
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.18, 0.11, 0.06, 0.94)
		if state == "hover":
			bg = bg.lightened(0.10)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0)
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		btn.add_theme_stylebox_override(state, s)
	btn.mouse_entered.connect(panel.show)
	btn.mouse_exited.connect(panel.hide)
	layer.add_child(btn)


# Concrete puzzles call this when the game ends so the next click /
# ESC sends the player back to the overworld.
func _set_awaiting_dismiss(value: bool) -> void:

	_awaiting_dismiss = value


# Credit the player with winnings. Concrete puzzles call this from
# their game-complete handler.
func award_winnings(amount: int) -> void:

	if amount <= 0:
		return
	PlayerState.add_coins(amount)


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

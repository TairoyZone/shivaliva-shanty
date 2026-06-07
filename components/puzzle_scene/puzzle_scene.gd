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
	btn.pressed.connect(_return_to_launching_scene)   # the click SFX comes from the global Audio button hook
	layer.add_child(btn)


## Puzzle instructions live behind a 📖 TUTORIAL button (Troy: never a strip under the board — it runs
## off-screen). A small book sits bottom-right; CLICK it to fold a word-wrapped how-to card open/shut — the
## in-puzzle face of the user panel's Tutorial tab (it replaced the old hover "?" 2026-06-07, same book glyph
## + footprint so help reads the same everywhere). Concrete puzzles call this with their how-to-play text.
func set_help_text(text: String) -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 21
	layer.name = "HelpLayer"
	add_child(layer)

	# The tutorial CARD — bottom-right (where the old help panel sat), hidden until the book is clicked.
	var card : PanelContainer = PanelContainer.new()
	var ps : StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = Color(0.18, 0.11, 0.06, 0.98)
	ps.border_color = Palette.BRASS_FRAME
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(12)
	ps.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", ps)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -448.0
	card.offset_right = -18.0
	card.offset_bottom = -66.0
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var head : Label = Label.new()
	head.text = "How to play"
	head.add_theme_font_size_override("font_size", 19)
	head.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	box.add_child(head)
	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.74, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(404.0, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	layer.add_child(card)

	# 📖 Tutorial book — bottom-right (replaces the old "?"), the same book glyph as the user panel's rail
	# Tutorial tab. CLICK to fold the card open/shut (the YPP fold mechanic), instead of the old hover.
	var btn : Button = Button.new()
	btn.custom_minimum_size = Vector2(40.0, 40.0)
	btn.tooltip_text = "Tutorial — how to play"
	btn.focus_mode = Control.FOCUS_NONE
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = -58.0
	btn.offset_right = -18.0
	btn.offset_top = -58.0
	btn.offset_bottom = -18.0
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.18, 0.11, 0.06, 0.94)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.10)
		s.bg_color = bg
		s.border_color = Palette.BRASS_FRAME
		s.set_border_width_all(2)
		s.set_corner_radius_all(9)
		btn.add_theme_stylebox_override(state, s)
	var glyph : MenuGlyph = MenuGlyph.new()
	glyph.kind = "book"
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(glyph)
	btn.pressed.connect(_toggle_help_card.bind(card))
	layer.add_child(btn)


# Fold the in-puzzle tutorial card open/shut; fades in (animate-everything) so it never pops.
func _toggle_help_card(card: PanelContainer) -> void:

	card.visible = not card.visible
	if card.visible:
		card.modulate.a = 0.0
		create_tween().tween_property(card, "modulate:a", 1.0, 0.12)


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

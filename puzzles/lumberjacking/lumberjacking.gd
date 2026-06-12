## Lumberjacking — the playable job-puzzle launched by the
## [LumberjackingSign] prop in the Forest. Inherits HUD-hiding, the
## persistent Leave button, click-to-dismiss-after-end, and the wood
## yield commit from [PuzzleScene] — this script only owns the
## puzzle-specific UI label bindings + signal wiring to the board.
##
## See [[lumberjacking-spec]] for the full mechanical design.
extends PuzzleScene


# TOUCH controls (mobile web): move held, rotate taps (ui_up=CCW, ui_down=CW), soft-drop held (Space). See [[touch-input-foundation]].
func _touch_spec() -> Array:
	return [
		{"label": "◄", "action": "ui_left", "hold": true, "side": "left"},
		{"label": "►", "action": "ui_right", "hold": true, "side": "left"},
		{"label": "↺", "action": "ui_up"},
		{"label": "↻", "action": "ui_down"},
		{"label": "▼", "key": KEY_SPACE, "hold": true},
	]


## Gold paid out automatically alongside the wood-yield grant.
## Lumberjacking is positive-income (no entry fee, no leaving penalty —
## the wood IS the wage). The actual wood is granted as
## PlayerState.total_wood; gold are converted later at the
## Workshop drop-off, so this is 0 here by design.
const SESSION_BASE_GOLD : int = 0

## Player-facing chain step names — matches the spec's chain ladder.
## Index = chain depth (0 unused, 1 = Clean Split = no toast).
const CHAIN_NAMES : Array = [
	"",
	"Clean Split",
	"Double-Through",
	"Triple-Through",
	"Bingo Split",
	"Donkey Split",
	"Vegas Split",
]


@onready var _board : LumberjackingBoard = $Board
@onready var _next_preview : LumberNextPreview = $NextPreview
@onready var _yield_label : Label = $UI/TopBar/YieldPanel/YieldLabel
@onready var _difficulty_label : Label = $UI/TopBar/DifficultyPanel/DifficultyLabel


## Running SCORE this session (combo/chain skill metric → mastery rank) and
## WOOD haul (fused-block currency → backpack). Mirrored from the board's
## score_changed / wood_changed signals for the HUD + the final commit.
var _running_score : int = 0
var _running_wood : int = 0

## Guard so the running wood haul doesn't get granted twice — once on the
## natural session_ended path AND again when the player clicks through the
## dismiss prompt to return to the overworld.
var _session_yield_committed : bool = false
## Wood the backpack couldn't hold when the session's haul was committed
## (bag was full). Surfaced in the result line so the player knows to
## deliver before chopping more.
var _overflow_lost : int = 0


func _ready() -> void:

	super._ready()
	set_help_text("Lumberjacking — work the felled wood\n\n"
		+ "• ← → move the falling pair  ·  ↑ rotate ccw  ·  ↓ rotate cw  ·  SPACE drop faster (hold)\n"
		+ "• Match 3+ of the SAME wood (row, column, or bend) to SHATTER it — that's your score\n"
		+ "• Pack a 2×2 or bigger square of one wood and it FUSES into planks — that's your wood haul\n"
		+ "• Chain shatters back-to-back for combo score\n"
		+ "• Knots are junk — they won't clear, so build around them\n"
		+ "• Let the pile reach the top and the shift's over")
	_board.score_changed.connect(_on_score_changed)
	_board.wood_changed.connect(_on_wood_changed)
	_board.session_ended.connect(_on_session_ended)
	_board.chain_landed.connect(_on_chain_landed)
	_board.difficulty_tier_changed.connect(_on_difficulty_tier_changed)
	_board.next_pair_changed.connect(_on_next_pair_changed)
	_refresh_yield_label()
	_difficulty_label.text = "Steady"
	# The board rolls its first preview pair in its own _ready (which runs
	# before this scene's _ready, since children ready first), so that
	# emit was missed — seed the preview from the board's current queue.
	var queued : Dictionary = _board.peek_next_pair()
	if not queued["a"].is_empty():
		_on_next_pair_changed(
			queued["a"]["kind"], queued["a"]["variant"],
			queued["b"]["kind"], queued["b"]["variant"])


func _on_score_changed(new_total: int) -> void:

	if new_total > _running_score:
		Audio.play_sfx("hit")   # a component shattered
	_running_score = new_total
	_refresh_yield_label()


func _on_wood_changed(new_total: int) -> void:

	if new_total > _running_wood:
		Audio.play_sfx("thunk")   # a fused 2x2 paid out a plank
	_running_wood = new_total
	_refresh_yield_label()


func _on_next_pair_changed(a_kind: int, a_variant: int, b_kind: int, b_variant: int) -> void:

	_next_preview.set_pair(a_kind, a_variant, b_kind, b_variant)


# When the bin tops out, commit the accumulated wood to the player's
# backpack + arm the click-to-dismiss. If the bag was too full to hold
# the whole haul, the result line calls out how much was left behind so
# the player learns to deliver before chopping more (the "tight" bag
# Troy chose makes this real pressure).
func _on_session_ended(final_score: int, final_wood: int) -> void:

	_running_score = final_score
	_running_wood = final_wood
	_commit_yield_once()
	if _overflow_lost > 0:
		_yield_label.text = "WOOD KEPT:  %d   ·   BAG FULL — %d LEFT BEHIND" % [
			final_wood - _overflow_lost, _overflow_lost]
		_yield_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.42, 1.0))
	else:
		_refresh_yield_label()
	if SESSION_BASE_GOLD > 0:
		award_winnings(SESSION_BASE_GOLD, "Lumberjacking pay")
	# Mastery is keyed on SCORE (the combo/skill metric), NOT the wood haul —
	# combos determine your rank. Pop the flourish on a tier-up (the
	# high-water-mark ladder updates itself).
	var mastery : Dictionary = PlayerState.record_puzzle_result("lumberjacking", final_score)
	_show_game_over_panel(final_wood - _overflow_lost, _overflow_lost, final_score)
	if mastery["ranked_up"]:
		add_child(MasteryToast.create(String(mastery["tier_name"])))
	_set_awaiting_dismiss(true)


# Centered "bin full / session over" panel shown when the board tops out.
# Purely informational — PuzzleScene's click-to-dismiss (armed via
# _set_awaiting_dismiss) handles the actual return to the Grove on the
# next click; the persistent Leave button also works.
func _show_game_over_panel(wood_kept: int, overflow: int, final_score: int) -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	# Dim the board behind the panel.
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _game_over_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	_add_go_label(vbox, "BIN FULL!", 40, Color(1.0, 0.5, 0.4, 1.0))
	_add_go_label(vbox, "The chute jammed — session over.", 18, Color(0.92, 0.82, 0.58, 1.0))
	_add_go_label(vbox, "Wood gathered:  %d  (added to your backpack)" % wood_kept,
		22, Color(0.95, 0.82, 0.5, 1.0))
	if overflow > 0:
		_add_go_label(vbox, "Bag was full — %d left behind" % overflow,
			16, Color(1.0, 0.6, 0.42, 1.0))
	_add_go_label(vbox, "Score:  %d  (sets your skill rank)" % final_score,
		18, Color(0.80, 0.85, 0.96, 1.0))
	_add_go_label(vbox, "Click anywhere to head back to the Grove",
		15, Color(0.78, 0.66, 0.42, 1.0))


func _add_go_label(parent: VBoxContainer, text: String, size: int, color: Color) -> void:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _game_over_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.10, 0.05, 0.97)
	s.border_color = Color(0.82, 0.4, 0.28, 1.0)
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	s.content_margin_left = 40
	s.content_margin_right = 40
	s.content_margin_top = 28
	s.content_margin_bottom = 28
	return s


# If the player taps Leave mid-session (PuzzleScene's persistent button
# calls into _return_to_launching_scene), commit whatever they've
# earned before the base class navigates away.
func _return_to_launching_scene() -> void:

	_commit_yield_once()
	super._return_to_launching_scene()


# Idempotent — runs the add_wood exactly once across all entry paths
# (natural session end, click-through dismiss, mid-session Leave).
# add_wood returns the overflow (wood the backpack couldn't hold), which
# _on_session_ended surfaces to the player.
func _commit_yield_once() -> void:

	# Record this session's haul for anything that wants it (e.g. a Voyage
	# using Lumberjacking as a boarding fight) — independent of how much
	# the backpack could actually hold.
	# The voyage boarding-fight reads this as the wood looted from the fight,
	# so it tracks the haul (not the skill score).
	PlayerState.last_lumberjacking_yield = _running_wood
	if _session_yield_committed:
		return
	_session_yield_committed = true
	if _running_wood > 0:
		_overflow_lost = PlayerState.add_wood(_running_wood)


func _refresh_yield_label() -> void:

	# Both axes live: WOOD is the haul you bank, SCORE is your combo/skill
	# rating (which also drives the difficulty heat + your mastery rank).
	_yield_label.text = "WOOD  %d      SCORE  %d" % [_running_wood, _running_score]


# --- Phase 3 / 4 feedback --------------------------------------------

# Chain step landed. Depth 1 is a "Clean Split" — no toast, that's
# just a normal shatter. Depth 2+ pops a big chunky banner near the
# top of the bin, scales up + holds + fades.
func _on_chain_landed(depth: int) -> void:

	if depth < 2:
		return
	var chain_name : String = (CHAIN_NAMES[depth] if depth < CHAIN_NAMES.size()
		else "Chain ×%d" % depth)
	_spawn_chain_toast(chain_name, depth)


# Difficulty tier crossed a threshold — update the top-right panel.
# Color escalates from gold (Steady) to red (MAX HARDNESS) so the
# player can read the heat at a glance.
func _on_difficulty_tier_changed(tier_name: String) -> void:

	_difficulty_label.text = tier_name
	var color : Color = _difficulty_color_for_tier(tier_name)
	_difficulty_label.add_theme_color_override("font_color", color)


func _difficulty_color_for_tier(tier: String) -> Color:

	match tier:
		"Steady":
			return Color(0.92, 0.76, 0.36, 1.0)
		"Picking up":
			return Color(0.98, 0.78, 0.30, 1.0)
		"Pressing":
			return Color(1.00, 0.62, 0.20, 1.0)
		"Hard":
			return Color(1.00, 0.42, 0.18, 1.0)
		"MAX HARDNESS":
			return Color(1.00, 0.28, 0.20, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)


# Spawn a chunky chain toast — punches in with a back-ease scale, holds
# the value visible for ~0.6 sec, then fades and frees. Color scales
# with chain depth so deeper chains feel hotter (yellow → orange → red).
func _spawn_chain_toast(chain_name: String, depth: int) -> void:

	var label : Label = Label.new()
	label.text = "%s\n×%d" % [chain_name.to_upper(), depth]
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", _chain_color_for_depth(depth))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(640.0, 160.0)
	var vp_size : Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2(
		vp_size.x * 0.5 - 320.0,
		vp_size.y * 0.32 - 80.0)
	label.scale = Vector2(0.4, 0.4)
	label.pivot_offset = label.size * 0.5
	# Sit the toast above the board's own UI layer.
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	layer.add_child(label)
	# Punch-in scale → hold → fade → free.
	var tw : Tween = create_tween().set_parallel(false)
	tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.45)
	tw.tween_property(label, "modulate:a", 0.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)


# Yellow at depth 2, sliding through orange to red at depth 6+.
func _chain_color_for_depth(depth: int) -> Color:

	match depth:
		2:
			return Color(1.00, 0.92, 0.42, 1.0)
		3:
			return Color(1.00, 0.78, 0.30, 1.0)
		4:
			return Color(1.00, 0.62, 0.20, 1.0)
		5:
			return Color(1.00, 0.42, 0.18, 1.0)
	return Color(1.00, 0.28, 0.20, 1.0)

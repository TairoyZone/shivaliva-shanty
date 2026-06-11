@tool
class_name GemDropBoard extends Node2D


const GEM_SCENE : PackedScene = preload("res://puzzles/gem_drop/gem.tscn")
const HOLE_SCENE : PackedScene = preload("res://puzzles/gem_drop/hole.tscn")
const SWITCH_SCENE : PackedScene = preload("res://puzzles/gem_drop/switch.tscn")

# --- Board geometry ---------------------------------------------------------
# 8 entries CLUSTERED at the center top (cols 4-11), widening through a
# 4-row funnel into the full 16-column scoring grid. This is what makes
# edge-slot scoring high-risk: a coin entering near the center must bounce
# outward through several switches to reach the 34/64-point edge slots.
const SCORING_SLOTS : int = 16
const SWITCH_ROWS : int = 8
const FUNNEL_DEPTH : int = 4  # first N rows widen from entry-width to full width
const ENTRY_POSITIONS : Array = [4, 5, 6, 7, 8, 9, 10, 11]
const COLUMN_SPACING : float = 36.0
const ROW_SPACING : float = 56.0
const TOP_PADDING : float = 56.0
const BOTTOM_PADDING : float = 72.0

# Re-exposed from [Switch] for readability of board-side code. Switch
# owns the canonical values; these are aliases so call sites don't have
# to reach across the class boundary.
const PAD_LEFT : int = Switch.PAD_LEFT
const PAD_RIGHT : int = Switch.PAD_RIGHT

# --- Players ---------------------------------------------------------------
const HUMAN_PLAYER : int = 0
const AI_PLAYER : int = 1
const AI_THINK_TIME : float = 0.9
const ROUND_ADVANCE_PAUSE : float = 1.5
const BOUNCE_TWEEN_DURATION : float = 0.08
const MERGE_FLASH_DURATION : float = 0.35
const MERGE_FLASH_COLOR : Color = Color(1.7, 1.7, 1.1, 1.0)
const MINIMAX_DEPTH : int = 3            # plies AI looks ahead (mine / opp / mine)

# Switch geometry + animation now live on the [Switch] class itself.
# Board reads [const Switch.PAD_TOP_OFFSET_FROM_ROW_Y] when landing a
# coin pixel-flush on the pad surface.

# --- Colors --------------------------------------------------------------
# All colors flow from [Palette]. Parlor-table feel: warm aged-oak interior,
# dark walnut plank shadows, brass-inlaid outer rim.
const COLOR_BOARD_BG : Color = Palette.WOOD_PLANK
const COLOR_BOARD_GRAIN : Color = Palette.WOOD_PLANK_DARK  # diagonal plank shadow lines
const COLOR_FRAME_OUTER : Color = Palette.BRASS_FRAME      # ornate brass rim
const COLOR_FRAME_MID : Color = Palette.WOOD_FRAME_DARK    # dark walnut band
const COLOR_FRAME_INLAY : Color = Palette.BRASS_INLAY      # bright inner inlay
const COLOR_FRAME : Color = Palette.WOOD_FRAME_DARK        # legacy: column dividers, slot outlines
const COLOR_ENTRY_SLOT : Color = Palette.WOOD_BEAM_DARK
const COLOR_SWITCH_BEAM : Color = Palette.WOOD_BEAM
const COLOR_SWITCH_PAD : Color = Palette.BRASS_PAD
const COLOR_SWITCH_PIVOT : Color = Palette.WOOD_PIVOT
const COLOR_SCORE_LOW : Color = Palette.SCORE_LOW
const COLOR_SCORE_HIGH : Color = Palette.SCORE_HIGH
const COLOR_SCORE_TEXT : Color = Palette.GOLD_TEXT
const SCORE_COLOR_MAX_REF : float = 64.0  # round-4 max, used for color grading

# Per-owner visual identity. Human coins stay gold (Color.WHITE modulate),
# AI coins get a red tint so you can tell who owns each coin / resting coin
# at a glance. Toasts use saturated bright versions for readability.
const COIN_TINT_HUMAN : Color = Color(1.0, 1.0, 1.0, 1.0)
const COIN_TINT_AI : Color = Palette.GEM_RUBY_LIGHT
const TOAST_COLOR_HUMAN : Color = Palette.BRASS_BRIGHT
const TOAST_COLOR_AI : Color = Palette.GEM_RUBY_LIGHT
const TOAST_RISE_DISTANCE : float = 80.0
const TOAST_LIFETIME : float = 1.1

# --- Round configuration ---------------------------------------------------
# Scoring tables from the Puzzle Pirates wiki — high values on the edges so
# the funnel's bias toward the middle creates real risk/reward tension.
# Targets match the YPP wiki exactly (10 / 40 / 20 / 80). Round 5 is
# our invented sudden-death Holes tiebreaker (not in the wiki).
const ROUND_TABLES : Dictionary = {
	1: [2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
	2: [34, 21, 13, 8, 5, 3, 2, 1, 1, 2, 3, 5, 8, 13, 21, 34],
	3: [9, 8, 7, 6, 5, 4, 3, 2, 2, 3, 4, 5, 6, 7, 8, 9],
	4: [64, 49, 36, 25, 16, 9, 4, 1, 1, 4, 9, 16, 25, 36, 49, 64],
	# Round 5 — Holes tiebreaker. Same edge-heavy squares as R4 so the
	# scoring pressure feels familiar, but HALF the target so the round
	# ends snappy. Triggered only when round 4 closes with rounds_won == 2-2.
	5: [64, 49, 36, 25, 16, 9, 4, 1, 1, 4, 9, 16, 25, 36, 49, 64],
}
const ROUND_TARGETS : Dictionary = {1: 10, 2: 40, 3: 20, 4: 80, 5: 40}
## Last regular round of a normal best-of-4 match.
const FINAL_ROUND : int = 4
## Sudden-death round only played when the match is dead-tied at 2-2
## after [const FINAL_ROUND]. Carries the Holes variant from the YPP
## wiki — random warp-hole pairs teleport coins, adding chaos.
const TIEBREAKER_ROUND : int = 5

# --- Holes variant (round 5 only) ---------------------------------------
## Number of hole PAIRS placed on the round-5 board. 2 pairs = 4 holes.
## Sparse enough that they read as occasional chaos, not constant warps.
const HOLE_PAIR_COUNT : int = 2
## Coins exit the partner hole this far below the hole's center so they
## don't immediately re-trigger the same hole's overlap.
const HOLE_EXIT_OFFSET : float = 22.0
## Minimum pixel distance between hole centers when randomly placing
## them at round-5 start. Roughly four hole-diameters so they don't
## visually crowd each other. Hole radius itself is set per-instance
## on each [Hole] node (default 11 px, editable on the scene).
const HOLE_MIN_SPACING : float = 44.0

# --- Signals ---------------------------------------------------------------
signal scores_changed(human_score: int, ai_score: int, target: int)
signal round_advanced(new_round: int, new_target: int)
signal round_clearing(winner: int)
signal rounds_won_changed(human_rounds: int, ai_rounds: int)
signal turn_changed(player: int)
signal game_complete(winner: int, human_rounds: int, ai_rounds: int)

# --- Runtime state ---------------------------------------------------------
var scoring_values : Array = []
var round_target : int = 0
var round_number : int = 1
var player_scores : Array = [0, 0]    # this round's score, resets each round
var total_scores : Array = [0, 0]     # cumulative across the whole game
var rounds_won : Array = [0, 0]       # best-of-4: each round won bumps this
var current_player : int = HUMAN_PLAYER
var game_over : bool = false

# Live switches as [Switch] nodes, one row of nodes per board row.
# Outer Array indexed by row (0..SWITCH_ROWS-1), inner Array is the
# Switches sitting in that row. The minimax simulator works on a
# detached dict snapshot of this state — see [method
# _snapshot_switches_for_sim].
var switches : Array = []
# Active warp holes for this match. Includes:
#   • Scene-placed Hole nodes (registered on _ready, persist across rounds)
#   • Procedurally-spawned Holes from [method _init_holes] (round 5 only,
#     freed at next round-change — tracked separately in [member _procedural_holes])
# Manual placement is the testing path; procedural is the production
# tiebreaker path. They coexist cleanly: if any scene-placed holes
# exist, _init_holes skips the procedural spawn for round 5.
var holes : Array[Hole] = []
# Subset of [member holes] that the board itself spawned in round-5
# init. Tracked separately so we free only these on round changes,
# never touching hand-authored Holes from the .tscn.
var _procedural_holes : Array[Hole] = []
var _active_coins : Array[Gem] = []
var _score_labels : Array[Label] = []

var _ai_pending : bool = false
var _ai_timer : float = 0.0
var _round_advancing : bool = false

## Background-thread minimax. The search is pure data — it operates only
## on the _sim_* snapshots taken on the main thread in [method
## _begin_ai_search], never touching live nodes — so it runs off-thread
## without stalling the frame. This eliminates the per-AI-turn hitch the
## old synchronous search caused. [member _ai_searching] is true between
## kicking the thread off and collecting its result.
var _ai_thread : Thread = null
var _ai_searching : bool = false
## Watchdog: seconds the current search has been in flight. A healthy
## search reports back (via _on_ai_search_complete) in well under a
## second; if this ever runs far past any plausible search time the
## worker must have died without reporting (e.g. a script error aborted
## it), so we force a fallback drop rather than let the AI turn deadlock
## the whole match. Reset when a search starts.
var _ai_search_watchdog : float = 0.0
## Generous ceiling — the deepest search (depth 5) finishes in well
## under a second even on slow hardware, so this never false-triggers.
const AI_SEARCH_TIMEOUT : float = 4.0
# --- Snapshotted search inputs ---------------------------------------
# Written on the MAIN thread in _begin_ai_search (right before the search
# thread starts); read ONLY by the threaded search path
# (_threaded_pick_column / _minimax / _simulate_with_switches /
# _weighted_eval / _perception_bias_for). Never mutated while the search
# runs, so no locking is needed.
var _sim_switch_snapshot : Array = []
var _sim_scoring_values : Array = []
var _sim_human_drops : Array[int] = []
var _sim_w_score : float = 1.0
var _sim_w_denial : float = 1.0
var _sim_perception : float = 0.0
var _sim_depth : int = MINIMAX_DEPTH
## The NPC opponent for this match — read for minimax eval weights and
## search depth. Set by the scene controller at start; null falls back
## to neutral defaults so the board still runs solo for tests.
var ai_personality : NpcPersonality = null
## Talk-influence bias for the AI seat, SET BY THE SCENE on the main thread before each search
## (gem_drop._on_turn_changed → [VersusPuzzleScene].mood_bias). + = rattled (chases points, under-defends,
## may think shallower); − = cowed (over-defends, scores less). Snapshotted into the _sim_ weights below.
var mood_bias : float = 0.0
# Histogram of which columns the human has dropped into this session.
# Indexed 0..SCORING_SLOTS-1; only ENTRY_POSITIONS see real counts.
# Drives the AI's "perception" — high-perception NPCs (Godfrey,
# Ellison) lean toward the human's favored lanes; low-perception ones
# (Mia, Kerr) ignore the pattern.
var _human_drops_by_col : Array[int] = []
## Minimum drops before perception affects the AI's choice. Below
## this, the histogram is too noisy to bias on.
const PERCEPTION_SAMPLE_FLOOR : int = 3
## Scale factor applied to (frequency × perception) when nudging the
## AI's column choice. Calibrated so the bias is felt but doesn't
## override the minimax value — your top column gets at most ~+6 eval
## added at perception = 1.0, which is a strong tiebreaker but not a
## dominating force.
const PERCEPTION_BIAS_MAX : float = 8.0

# The entry column the player's mouse is currently aimed at (-1 = none /
# AI turn / mouse off-board). Updates every frame in _process and drives
# the translucent column highlight in _draw_hover_indicator.
var _hover_col : int = -1


# ---------- Lifecycle ----------

func _ready() -> void:

	_register_scene_holes()
	start_round(1)


# Pick up any [Hole] nodes the level designer hand-placed under this
# board in the .tscn. They become active warp pairs immediately (the
# warp check runs every frame whenever [member holes] isn't empty)
# and override the round-5 procedural spawn — if you've placed holes
# yourself, the board uses yours and skips its own.
func _register_scene_holes() -> void:

	for node in find_children("*", "Hole", true, false):
		var h : Hole = node as Hole
		if h != null and not holes.has(h):
			holes.append(h)


func start_round(n: int) -> void:

	# Any in-flight AI search is stale the moment the board resets — join
	# it before re-initializing so its thread is never left dangling.
	_join_ai_thread()
	# Round 1 is a fresh game — wipe lifetime stats AND the human's
	# column histogram so perception starts from zero each new match.
	if n == 1:
		total_scores = [0, 0]
		rounds_won = [0, 0]
		game_over = false
		_human_drops_by_col = []
		_human_drops_by_col.resize(SCORING_SLOTS)
		for i in SCORING_SLOTS:
			_human_drops_by_col[i] = 0
	round_number = n
	scoring_values = ROUND_TABLES[n].duplicate()
	round_target = ROUND_TARGETS[n]
	player_scores = [0, 0]
	current_player = HUMAN_PLAYER
	_ai_pending = false
	_ai_timer = 0.0
	_round_advancing = false
	_clear_active_coins()
	_init_switches()
	_init_holes()
	_refresh_score_labels()
	round_advanced.emit(round_number, round_target)
	scores_changed.emit(player_scores[0], player_scores[1], round_target)
	rounds_won_changed.emit(rounds_won[HUMAN_PLAYER], rounds_won[AI_PLAYER])
	turn_changed.emit(current_player)
	queue_redraw()


func _init_switches() -> void:

	# Free old Switch nodes before clearing the array.
	for row_switches in switches:
		for sw in row_switches:
			if is_instance_valid(sw):
				sw.queue_free()
	switches.clear()
	# In the editor we skip switch creation entirely — the user runs
	# the game to see paddles. The board frame still previews fine
	# without them.
	if Engine.is_editor_hint():
		for _row in SWITCH_ROWS:
			switches.append([])
		return
	for row in SWITCH_ROWS:
		var row_switches : Array = []
		for pair in _switch_layout_in_row(row):
			var initial_side : int = Switch.PAD_RIGHT if randf() < 0.5 else Switch.PAD_LEFT
			var sw : Switch = SWITCH_SCENE.instantiate()
			sw.column_spacing = COLUMN_SPACING
			sw.col_left = pair[0]
			sw.col_right = pair[1]
			sw.initial_pad_side = initial_side
			# Position the Switch at its pivot point — mid-column at row_y.
			var pivot_x : float = (column_to_x(pair[0]) + column_to_x(pair[1])) * 0.5
			sw.position = Vector2(pivot_x, switch_row_to_y(row))
			add_child(sw)
			row_switches.append(sw)
		switches.append(row_switches)


# Holes are warp pairs placed only on the tiebreaker round (round 5).
# Each pair is two [Hole] nodes at random positions between switch
# rows; a coin whose center crosses one teleports to its partner and
# keeps falling. Rounds 1–4 leave [member holes] empty.
#
# Placement rules:
#   • y sits in the *gap* between two switch rows (row + 0.5) so the
#     hole never visually clashes with a switch.
#   • cols are picked from [1 .. SCORING_SLOTS - 2] (no edges — saves
#     the highest-scoring slots from being trivially reachable).
#   • Each new hole must be at least HOLE_MIN_SPACING px from every
#     previously-placed hole so they don't visually crowd.
#   • Each hole is assigned a [enum Hole.Pair] value (0 → ONE, 1 → TWO, …);
#     [Hole]'s own _ready scans siblings and auto-links matching pairs.
func _init_holes() -> void:

	# Tear down ONLY the procedurally-spawned holes from a previous
	# round-5 init — leave any scene-placed Hole nodes alone.
	for h in _procedural_holes:
		if is_instance_valid(h):
			holes.erase(h)
			h.queue_free()
	_procedural_holes.clear()
	if round_number != TIEBREAKER_ROUND:
		return
	if Engine.is_editor_hint():
		return
	# If the level designer hand-placed Holes under the board, use those
	# and don't spawn additional ones — gives them full control during
	# testing without the procedural code stomping on their layout.
	if not holes.is_empty():
		return
	# Build the gap-row Y positions: midpoints between consecutive switch rows.
	var candidates : Array = []
	for r in range(0, SWITCH_ROWS - 1):
		var y : float = (switch_row_to_y(r) + switch_row_to_y(r + 1)) * 0.5
		for col in range(1, SCORING_SLOTS - 1):
			candidates.append(Vector2(col, y))
	candidates.shuffle()
	var min_dist_sq : float = HOLE_MIN_SPACING * HOLE_MIN_SPACING
	var picked : Array[Hole] = []
	for cand in candidates:
		if picked.size() >= HOLE_PAIR_COUNT * 2:
			break
		var cand_pos : Vector2 = Vector2(column_to_x(int(cand.x)), cand.y)
		var too_close : bool = false
		for existing in picked:
			if cand_pos.distance_squared_to(existing.position) < min_dist_sq:
				too_close = true
				break
		if too_close:
			continue
		var hole : Hole = HOLE_SCENE.instantiate()
		hole.position = cand_pos
		# Assign the pair enum BEFORE add_child so the hole's _ready
		# auto-resolves its partner from sibling Holes sharing this
		# pair. No manual wiring needed.
		@warning_ignore("integer_division")
		var pair_idx : int = picked.size() / 2
		hole.pair = pair_idx as Hole.Pair
		add_child(hole)
		picked.append(hole)
	# Track these as procedurally-spawned so the next round-change
	# tear-down only frees these, not any scene-placed Holes.
	for h in picked:
		_procedural_holes.append(h)
		holes.append(h)


# Trapezoidal funnel layout. The first FUNNEL_DEPTH rows widen from the
# 8-column entry band out to full 16-column width; below that, a standard
# brick pattern alternates 7- and 8-switch rows.
func _switch_layout_in_row(row: int) -> Array:

	var layout : Array = []
	var leftmost : int
	var rightmost_exclusive : int

	if row < FUNNEL_DEPTH:
		# row 0: cols 4..12, row 1: 3..13, row 2: 2..14, row 3: 1..15
		leftmost = 4 - row
		rightmost_exclusive = 12 + row
	else:
		# Full-width brick alternating
		var is_offset : bool = (row % 2 == 1)
		if is_offset:
			leftmost = 1
			rightmost_exclusive = 15
		else:
			leftmost = 0
			rightmost_exclusive = 16

	var col : int = leftmost
	while col + 1 < rightmost_exclusive + 1:
		if col + 1 >= rightmost_exclusive:
			break
		layout.append([col, col + 1])
		col += 2
	return layout


# ---------- Geometry helpers ----------

func board_width() -> float:

	return SCORING_SLOTS * COLUMN_SPACING


func board_height() -> float:

	return TOP_PADDING + SWITCH_ROWS * ROW_SPACING + BOTTOM_PADDING


func column_to_x(col: float) -> float:

	return (col + 0.5) * COLUMN_SPACING


func switch_row_to_y(row: int) -> float:

	return TOP_PADDING + (row + 0.5) * ROW_SPACING


# Y at which the funnel reaches full board width.
func funnel_end_y() -> float:

	return TOP_PADDING + FUNNEL_DEPTH * ROW_SPACING


# Trapezoid vertices defining the playable board interior.
func _frame_polygon() -> PackedVector2Array:

	var fy : float = funnel_end_y()
	var bw : float = board_width()
	var bh : float = board_height()
	var entry_left_x : float = ENTRY_POSITIONS[0] * COLUMN_SPACING
	var entry_right_x : float = (ENTRY_POSITIONS[-1] + 1) * COLUMN_SPACING
	return PackedVector2Array([
		Vector2(entry_left_x, 0.0),
		Vector2(entry_right_x, 0.0),
		Vector2(bw, fy),
		Vector2(bw, bh),
		Vector2(0.0, bh),
		Vector2(0.0, fy),
	])


# ---------- Gem lifecycle ----------

func _process(delta: float) -> void:

	_update_hover_col()
	if game_over or _round_advancing:
		return
	# Switches animate themselves now — each Switch's _process lerps
	# its own visual_pad_t toward pad_side.
	#
	# AI turn: the think-timer covers pacing + the human's just-dropped
	# coin settling. When it expires we snapshot the board and launch
	# the minimax on a BACKGROUND thread (see _begin_ai_search). The
	# worker reports its result back to the main thread via call_deferred
	# (_on_ai_search_complete) — so the search never freezes the frame
	# the way the old synchronous call did. Snapshot timing is unchanged,
	# so the AI's decision is identical to before; it just no longer
	# hitches. (We deliberately do NOT poll Thread.is_alive() here:
	# is_alive() reads false in the scheduling window right after start(),
	# which would trip a same-frame wait_to_finish() and stall on the
	# launch frame — exactly the hitch we're removing.)
	if _ai_pending:
		_ai_timer -= delta
		if _ai_timer <= 0.0:
			_ai_pending = false
			_begin_ai_search()
	# Watchdog — recover the AI turn if a search ever dies without
	# reporting back, so a worker failure can never permanently freeze
	# the match on the AI's move. Never fires in normal play.
	if _ai_searching:
		_ai_search_watchdog += delta
		if _ai_search_watchdog > AI_SEARCH_TIMEOUT:
			push_warning("Gem Drop AI search exceeded %ss without reporting — forcing fallback drop." % AI_SEARCH_TIMEOUT)
			_join_ai_thread()
			if not (game_over or _round_advancing):
				_spawn_coin_in_column(ENTRY_POSITIONS[0], AI_PLAYER)
				_switch_turn()
	if _active_coins.is_empty():
		return
	var to_despawn : Array[Gem] = []
	# Iterate a SNAPSHOT — a switch merge inside the loop can erase a coin
	# from _active_coins (_attempt_merge_into_passing_coin), and mutating
	# the live array mid-`for` shifts indices and silently skips the next
	# coin that frame. The snapshot + membership/validity guard makes the
	# set stable for the whole frame. (Audit major, 2026-05-29.)
	for coin in _active_coins.duplicate():
		if not is_instance_valid(coin) or not _active_coins.has(coin):
			continue  # merged away (or freed) earlier this frame
		if coin.resting:
			continue
		coin.position.y += Gem.FALL_SPEED * delta
		_clamp_to_funnel_walls(coin)
		# Hole warp check — only on round 5. Mutates coin.position +
		# coin.next_switch_row when a teleport fires.
		if not holes.is_empty():
			_check_hole_warp(coin)
		while coin.next_switch_row < SWITCH_ROWS:
			var row_y : float = switch_row_to_y(coin.next_switch_row)
			if coin.position.y < row_y:
				break
			_resolve_coin_at_switch_row(coin, coin.next_switch_row)
			coin.next_switch_row += 1
			if coin.resting:
				break
		if (not coin.resting) and coin.next_switch_row >= SWITCH_ROWS and coin.position.y > board_height() - BOTTOM_PADDING + 30.0:
			to_despawn.append(coin)
	for coin in to_despawn:
		# Once the round/game is settled, don't keep scoring trailing
		# coins (it briefly over-credits totals that feed the round-5
		# cumulative tiebreaker) — just clean them up. (Audit minor.)
		if _round_advancing or game_over:
			_active_coins.erase(coin)
			coin.queue_free()
			continue
		_despawn_and_score(coin)


func _resolve_coin_at_switch_row(coin: Gem, row: int) -> void:

	var col : int = _coin_column(coin)
	var sw : Switch = _find_switch_at(row, col)
	if sw == null:
		return
	var pad_col : int = sw.pad_col()
	var lever_col : int = sw.lever_col()
	if col == pad_col:
		_resolve_pad_hit(coin, sw, row, pad_col, lever_col)
	elif col == lever_col:
		_resolve_lever_pass(coin, sw, row)


# Round-5 hole physics: if [param coin]'s CENTER falls within
# [const HOLE_RADIUS] of a hole center — i.e. the coin is sitting on
# top of the visible hole, not merely near it — teleport it to the
# partner hole and update [member Gem.next_switch_row] so the
# resume-fall logic picks the right row below. The exit offset prevents
# the partner hole from immediately re-triggering on the next frame.
#
# Note: the minimax AI in [method _threaded_pick_column] does NOT simulate
# holes — this is intentional for round 5, so the chaos cuts equally
# in both directions and the AI doesn't try to "use" the warps. If we
# later want a hole-aware AI, mirror this check in _simulate_with_switches.
func _check_hole_warp(coin: Gem) -> void:

	for hole in holes:
		if not is_instance_valid(hole) or not hole.contains(coin.position):
			continue
		var partner : Hole = hole.partner
		if partner == null or not is_instance_valid(partner):
			continue  # unpaired hole shouldn't suppress a valid warp from another (audit minor)
		# Teleport. Coin re-emerges just below the partner so the falling
		# loop continues naturally from there and the partner's own
		# overlap doesn't immediately re-trigger.
		coin.position = Vector2(partner.position.x, partner.position.y + HOLE_EXIT_OFFSET)
		# Rewind next_switch_row to the row immediately below the new
		# position so the switch-resolution loop doesn't skip ahead.
		var new_row : int = 0
		while new_row < SWITCH_ROWS and switch_row_to_y(new_row) < coin.position.y:
			new_row += 1
		coin.next_switch_row = new_row
		return


func _resolve_pad_hit(coin: Gem, sw: Switch, row: int, pad_col: int, lever_col: int) -> void:

	if sw.resting_coin == null:
		coin.resting = true
		# Land the coin pixel-flush on the pad: gem bottom = pad top surface.
		var pad_top_y : float = switch_row_to_y(row) + Switch.PAD_TOP_OFFSET_FROM_ROW_Y
		coin.position = Vector2(column_to_x(pad_col), pad_top_y - Gem.VISUAL_HALF_HEIGHT)
		sw.resting_coin = coin
	else:
		# Pad is occupied. The new coin bounces to the formerly-raised lever
		# end; its weight there TIPS the paddle over. That flips pad_side, and
		# the previously-resting coin — now on the raised side — falls off.
		# Both coins keep falling. visual_pad_t is kicked past the OLD pad
		# side first (impact dip on landing) before the Switch's _process
		# lerps it through to the new orientation.
		var target_x : float = column_to_x(lever_col)
		var tw : Tween = create_tween()
		tw.tween_property(coin, "position:x", target_x, BOUNCE_TWEEN_DURATION)
		sw.wobble_kick()
		# Paddle tips over (lever-side weight).
		sw.flip()
		# Launch the previously-resting coin — its pad is now raised. Pass
		# `coin` as the exclude so the launched coin isn't spuriously merged
		# into the bouncing coin (whose x is still mid-tween at pad_col).
		var resting : Gem = sw.resting_coin
		sw.resting_coin = null
		resting.resting = false
		resting.next_switch_row = row + 1
		resting.position.y = switch_row_to_y(row) + 4.0
		_attempt_merge_into_passing_coin(resting, coin)


func _resolve_lever_pass(coin: Gem, sw: Switch, row: int) -> void:

	var flips : int = coin.size
	for i in flips:
		sw.flip()
	var resting : Gem = sw.resting_coin
	if resting != null and (flips % 2 == 1):
		sw.resting_coin = null
		resting.resting = false
		resting.next_switch_row = row + 1
		resting.position.y = switch_row_to_y(row) + 4.0
		_attempt_merge_into_passing_coin(resting)


func _attempt_merge_into_passing_coin(launched: Gem, exclude: Gem = null) -> void:

	var launched_col : int = _coin_column(launched)
	for other in _active_coins:
		# Skip the launched coin itself, any coin we've been asked to ignore
		# (e.g. a bouncing coin still mid-tween whose visual x hasn't caught
		# up to its target column yet), and any resting coin.
		if other == launched or other == exclude or other.resting:
			continue
		if _coin_column(other) != launched_col:
			continue
		if abs(other.position.y - launched.position.y) > ROW_SPACING * 0.75:
			continue
		other.size += launched.size
		other.modulate = MERGE_FLASH_COLOR
		var tw : Tween = create_tween()
		tw.tween_property(other, "modulate", Color.WHITE, MERGE_FLASH_DURATION)
		_active_coins.erase(launched)
		launched.queue_free()
		return


func _coin_column(coin: Gem) -> int:

	return clampi(int(round(coin.position.x / COLUMN_SPACING - 0.5)), 0, SCORING_SLOTS - 1)


## Returns the [Switch] node at the given row containing [param col] as
## either its col_left or col_right, or null if none does.
func _find_switch_at(row: int, col: int) -> Switch:

	for sw in switches[row]:
		var s : Switch = sw as Switch
		if s != null and (s.col_left == col or s.col_right == col):
			return s
	return null


# Sim-side variant: scans a dict-row (used by the minimax simulator
# after [method _snapshot_switches_for_sim] has converted the live
# Switch nodes into plain dicts).
func _find_sim_switch_in_row(row_switches: Array, col: int) -> Dictionary:

	for sw in row_switches:
		if sw["col_left"] == col or sw["col_right"] == col:
			return sw
	return {}


# Smoothly lerp each switch's visual_pad_t toward its logical pad_side so the
# see-saw beam ROTATES through the flip instead of snapping. Triggers redraw
# while anything is animating.
# _animate_paddles was removed when [Switch] became its own scene —
# each Switch's own _process now lerps its visual_pad_t toward pad_side.


# If the coin's half-radius edge crosses the trapezoidal funnel wall, push
# it back inside. The walls are diagonal only in the top FUNNEL_DEPTH rows;
# below that the board is rectangular and the X bounds are board edges that
# coins can't reach anyway via switch routing.
func _clamp_to_funnel_walls(coin: Gem) -> void:

	var fy : float = funnel_end_y()
	if coin.position.y >= fy:
		return
	var entry_left_x : float = ENTRY_POSITIONS[0] * COLUMN_SPACING
	var entry_right_x : float = (ENTRY_POSITIONS[-1] + 1) * COLUMN_SPACING
	var bw : float = board_width()
	var t : float = clampf(coin.position.y / fy, 0.0, 1.0)
	var left_wall_x : float = lerpf(entry_left_x, 0.0, t)
	var right_wall_x : float = lerpf(entry_right_x, bw, t)
	var radius : float = Gem.RADIUS
	if coin.position.x - radius < left_wall_x:
		coin.position.x = left_wall_x + radius
	elif coin.position.x + radius > right_wall_x:
		coin.position.x = right_wall_x - radius


func _clear_active_coins() -> void:

	for coin in _active_coins:
		coin.queue_free()
	_active_coins.clear()


func _despawn_and_score(coin: Gem) -> void:

	var slot : int = _coin_column(coin)
	var slot_value : int = scoring_values[slot]
	var gained : int = slot_value * coin.size
	var player_id : int = coin.owner_player
	player_scores[player_id] += gained
	total_scores[player_id] += gained
	# Note: in-puzzle scoring no longer feeds PlayerState directly. The
	# overworld gold reward is granted once, on a human game win, in
	# _check_round_progression's FINAL_ROUND branch.
	scores_changed.emit(player_scores[HUMAN_PLAYER], player_scores[AI_PLAYER], round_target)
	_spawn_score_toast(slot, gained, player_id)
	_active_coins.erase(coin)
	coin.queue_free()
	_check_round_progression()


# Floating "+N" toast that pops at the scored slot in the owner's color,
# rises TOAST_RISE_DISTANCE px while fading, then frees itself.
func _spawn_score_toast(slot_col: int, points: int, player_id: int) -> void:

	var label : Label = Label.new()
	label.text = "+%d" % points
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", TOAST_COLOR_HUMAN if player_id == HUMAN_PLAYER else TOAST_COLOR_AI)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(80.0, 36.0)
	var y_top : float = TOP_PADDING + SWITCH_ROWS * ROW_SPACING + 4.0
	var slot_h : float = BOTTOM_PADDING - 8.0
	label.position = Vector2(column_to_x(slot_col) - 40.0, y_top + slot_h * 0.5 - 18.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tw : Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - TOAST_RISE_DISTANCE, TOAST_LIFETIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, TOAST_LIFETIME * 0.55) \
		.set_delay(TOAST_LIFETIME * 0.45)
	tw.chain().tween_callback(label.queue_free)


func _check_round_progression() -> void:

	if _round_advancing or game_over:
		return
	var human_done : bool = player_scores[HUMAN_PLAYER] >= round_target
	var ai_done : bool = player_scores[AI_PLAYER] >= round_target
	if not (human_done or ai_done):
		return
	var round_winner : int = HUMAN_PLAYER if human_done else AI_PLAYER
	if human_done and ai_done:
		round_winner = HUMAN_PLAYER if player_scores[HUMAN_PLAYER] >= player_scores[AI_PLAYER] else AI_PLAYER
	# Best-of-4: tally this round's winner.
	rounds_won[round_winner] += 1
	rounds_won_changed.emit(rounds_won[HUMAN_PLAYER], rounds_won[AI_PLAYER])
	# End-of-round routing. Three branches:
	#   • End of round 4, rounds_won tied 2-2 → step into the round-5
	#     Holes tiebreaker instead of declaring the game.
	#   • End of round 5 (or any round past FINAL_ROUND) → game over.
	#   • Otherwise → normal inter-round pause + advance.
	var match_tied_after_final : bool = (
		round_number == FINAL_ROUND
		and rounds_won[HUMAN_PLAYER] == rounds_won[AI_PLAYER])
	if round_number >= TIEBREAKER_ROUND or (round_number >= FINAL_ROUND and not match_tied_after_final):
		game_over = true
		_ai_pending = false
		# A search may be mid-flight if the human's coin closed the round
		# during the AI's think — abandon it cleanly.
		_join_ai_thread()
		# Overall game winner: most rounds won. Cumulative-points
		# tiebreaker is only reached if rounds_won is still tied at the
		# end of round 5 (e.g. both players also tied that round) — a
		# narrow edge case but worth keeping the deterministic path.
		var game_winner : int
		if rounds_won[HUMAN_PLAYER] > rounds_won[AI_PLAYER]:
			game_winner = HUMAN_PLAYER
		elif rounds_won[AI_PLAYER] > rounds_won[HUMAN_PLAYER]:
			game_winner = AI_PLAYER
		else:
			game_winner = HUMAN_PLAYER if total_scores[HUMAN_PLAYER] >= total_scores[AI_PLAYER] else AI_PLAYER
		# Gold are awarded by the scene-level controller via
		# [method PuzzleScene.award_winnings] — don't touch PlayerState
		# directly from the board (was a double-pay bug).
		game_complete.emit(game_winner, rounds_won[HUMAN_PLAYER], rounds_won[AI_PLAYER])
		return
	_round_advancing = true
	_ai_pending = false
	# Same as above — drop any in-flight search before the inter-round pause.
	_join_ai_thread()
	round_clearing.emit(round_winner)
	var tw : Tween = create_tween()
	tw.tween_interval(ROUND_ADVANCE_PAUSE)
	tw.tween_callback(_advance_to_next_round)


func _advance_to_next_round() -> void:

	start_round(round_number + 1)


# ---------- Input ----------

func _unhandled_input(event: InputEvent) -> void:

	if game_over or _round_advancing:
		return
	if current_player != HUMAN_PLAYER:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_drop_at_viewport_pos(event.position)


func _update_hover_col() -> void:

	if Engine.is_editor_hint():
		return
	var new_hover : int = -1
	if not game_over and not _round_advancing and current_player == HUMAN_PLAYER:
		var local_pos : Vector2 = get_local_mouse_position()
		# Active while the mouse is anywhere over the board's vertical
		# span — players often aim by looking at the scoring slots, not
		# the entry chutes, so the guide should follow even down-low.
		if local_pos.y >= -16.0 and local_pos.y <= board_height():
			var best_dist : float = COLUMN_SPACING * 0.9
			for col in ENTRY_POSITIONS:
				var col_x : float = column_to_x(col)
				var dist : float = abs(local_pos.x - col_x)
				if dist < best_dist:
					best_dist = dist
					new_hover = col
	if new_hover != _hover_col:
		_hover_col = new_hover
		queue_redraw()


func _try_drop_at_viewport_pos(viewport_pos: Vector2) -> void:

	var local_pos : Vector2 = to_local(viewport_pos)
	if local_pos.y < 0.0 or local_pos.y > TOP_PADDING:
		return
	# Snap the click to the nearest entry column (only 8 valid drops, at cols
	# 4-11). Click outside that band is ignored.
	var nearest_col : int = -1
	var best_dist : float = COLUMN_SPACING * 0.7
	for col in ENTRY_POSITIONS:
		var col_x : float = column_to_x(col)
		var dist : float = abs(local_pos.x - col_x)
		if dist < best_dist:
			best_dist = dist
			nearest_col = col
	if nearest_col < 0:
		return
	_spawn_coin_in_column(nearest_col, HUMAN_PLAYER)
	_switch_turn()


func _spawn_coin_in_column(col: int, player_id: int) -> void:

	var coin : Gem = GEM_SCENE.instantiate()
	coin.position = Vector2(column_to_x(col), TOP_PADDING - 24.0)
	coin.owner_player = player_id
	add_child(coin)
	_active_coins.append(coin)
	# Profile observation — tally the human's column preference so
	# perception-aware AIs can lean toward their lanes next decision.
	if player_id == HUMAN_PLAYER and col >= 0 and col < _human_drops_by_col.size():
		_human_drops_by_col[col] += 1


# ---------- Turns + AI ----------

func _switch_turn() -> void:

	current_player = AI_PLAYER if current_player == HUMAN_PLAYER else HUMAN_PLAYER
	turn_changed.emit(current_player)
	if current_player == AI_PLAYER and not game_over and not _round_advancing:
		_ai_pending = true
		_ai_timer = AI_THINK_TIME


# Snapshot every input the minimax reads into the _sim_* members (on the
# MAIN thread — _snapshot_switches_for_sim touches live nodes and randi()
# touches the global RNG, neither safe off-thread), then launch the
# search on a background [Thread]. The collection in _process picks up
# the chosen column once the thread finishes.
func _begin_ai_search() -> void:

	# Paranoia: never start a second search over a live one.
	_join_ai_thread()
	_sim_switch_snapshot = _snapshot_switches_for_sim()
	_sim_scoring_values = scoring_values.duplicate()
	_sim_human_drops = _human_drops_by_col.duplicate()
	# Fold the talk-influence mood into the snapshotted weights (capped → an edge, not a cheat). + = chase
	# points + under-defend (lets YOU score — "send the gems my way"); − = over-defend + score less.
	var mb : float = clampf(mood_bias, -1.0, 1.0)
	_sim_w_score = (ai_personality.w_score if ai_personality != null else 1.0) * (1.0 + 0.4 * mb)
	_sim_w_denial = (ai_personality.w_denial if ai_personality != null else 1.0) * (1.0 - 0.4 * mb)
	_sim_perception = ai_personality.perception if ai_personality != null else 0.0
	_sim_depth = _personality_depth()
	if mb >= 0.6 and _sim_depth >= 4:
		_sim_depth -= 1   # near-max tilt: a rattled deep-thinker literally thinks one ply shallower
	_ai_searching = true
	_ai_search_watchdog = 0.0
	_ai_thread = Thread.new()
	_ai_thread.start(_threaded_search_and_report)


# Background-thread entry point. Runs the pure minimax, then hands the
# chosen column back to the MAIN thread via call_deferred — the
# canonical Godot pattern for thread→scene-tree communication. This
# avoids polling Thread.is_alive() (which is ambiguous in the
# just-started window) and guarantees the result is consumed on the
# main thread, on a later idle frame, with no main-thread blocking.
func _threaded_search_and_report() -> void:

	var col : int = _threaded_pick_column()
	call_deferred("_on_ai_search_complete", col)


# Runs on the MAIN thread (deferred from the worker). The search has
# definitively finished by now, so wait_to_finish() returns instantly.
# Guards against the turn having been abandoned mid-search (round end,
# game over, or the player leaving) — in those cases _join_ai_thread
# already cleared _ai_searching / _ai_thread and we simply drop the
# stale result.
func _on_ai_search_complete(col: int) -> void:

	if not _ai_searching:
		return
	_ai_searching = false
	if _ai_thread != null:
		_ai_thread.wait_to_finish()
		_ai_thread = null
	# A round/game may have ended in the same frame the search reported —
	# don't drop a coin into a finished board.
	if game_over or _round_advancing:
		return
	_spawn_coin_in_column(col, AI_PLAYER)
	_switch_turn()


# Join + clear the search thread if one exists. Safe to call when no
# thread is running (no-op). Called whenever the AI turn is abandoned
# (round end, game over, leaving the scene) so a detached search thread
# is never left dangling — Godot requires threads be joined before the
# owning object is freed.
func _join_ai_thread() -> void:

	if _ai_thread != null:
		if _ai_thread.is_started():
			_ai_thread.wait_to_finish()
		_ai_thread = null
	_ai_searching = false


func _exit_tree() -> void:

	_join_ai_thread()


# Minimax search seeded from the AI's perspective. RUNS ON A BACKGROUND
# THREAD — reads ONLY the _sim_* snapshots (never live nodes / instance
# state that the main thread might touch concurrently), so it's safe to
# run off the main thread. Top-level entry iterates AI's 8 candidate
# drops, simulates each on a mutating copy, then recurses with opponent
# at depth-1. Eval = w_score * ai_inc - w_denial * human_inc; both
# weights + the search depth come from the snapshotted personality.
func _threaded_pick_column() -> int:

	# Deterministic seed for best_col — the loop's first candidate always
	# beats the -999999 floor and overwrites it, so this initial value is
	# never actually returned. Using a fixed column (not randi()) keeps
	# the global RNG sequence identical to a no-AI frame; pre-rolling a
	# random fallback every turn would needlessly perturb downstream
	# randomness (switch sides, gem spin, round-5 hole placement).
	var best_col : int = ENTRY_POSITIONS[0]
	var best_value : int = -999999
	var best_ai_inc : int = -1
	for ai_col in ENTRY_POSITIONS:
		# Sim works on the dict snapshot, never live Switch nodes — minimax
		# recurses on deep-copied dicts (fast, no node churn, thread-safe).
		var ai_state : Array = _deep_copy_switches(_sim_switch_snapshot)
		var ai_result : Dictionary = _simulate_with_switches(ai_state, ai_col, AI_PLAYER)
		var ai_inc : int = ai_result["ai_score"]
		var human_inc : int = ai_result["human_score"]
		var immediate : int = _weighted_eval(ai_inc, human_inc)
		var future : int = _minimax(ai_state, _sim_depth - 1, false)
		# Perception bias — high-perception NPCs lean toward the
		# columns the human has been favoring (with w_denial they
		# block; with w_score they contest the same scoring lane).
		# Low-perception NPCs ignore the pattern.
		var perception_bias : int = _perception_bias_for(ai_col)
		var total : int = immediate + future + perception_bias
		# Tie-break: prefer the column with higher own-score so AI doesn't
		# default to pure-denial when a real scoring play is available.
		if total > best_value or (total == best_value and ai_inc > best_ai_inc):
			best_value = total
			best_ai_inc = ai_inc
			best_col = ai_col
	return best_col


# Returns an eval bias toward [param col] based on how often the human
# has dropped there this session, scaled by the AI's perception. Zero
# until [const PERCEPTION_SAMPLE_FLOOR] drops have been observed, so
# early-game AIs don't react to two-sample noise.
# Reads the snapshotted perception + human-drop histogram (_sim_*),
# NOT the live members — this runs on the search thread.
func _perception_bias_for(col: int) -> int:

	if _sim_perception <= 0.0:
		return 0
	if _sim_human_drops.is_empty():
		return 0
	var total_drops : int = 0
	for c in _sim_human_drops:
		total_drops += c
	if total_drops < PERCEPTION_SAMPLE_FLOOR:
		return 0
	if col < 0 or col >= _sim_human_drops.size():
		return 0
	var freq : float = float(_sim_human_drops[col]) / float(total_drops)
	return roundi(freq * _sim_perception * PERCEPTION_BIAS_MAX)


# Recursive zero-sum minimax. Returns the AI's net value over the
# remaining `depth` plies, weighted by personality. `is_ai_turn = true`
# means it's our move at this level (maximize); false = opponent's move
# (minimize). Each call simulates over all 8 entries.
func _minimax(state: Array, depth: int, is_ai_turn: bool) -> int:

	if depth <= 0:
		return 0
	var player_id : int = AI_PLAYER if is_ai_turn else HUMAN_PLAYER
	var best : int = -999999 if is_ai_turn else 999999
	for col in ENTRY_POSITIONS:
		var next_state : Array = _deep_copy_switches(state)
		var result : Dictionary = _simulate_with_switches(next_state, col, player_id)
		var immediate : int = _weighted_eval(result["ai_score"], result["human_score"])
		var future : int = _minimax(next_state, depth - 1, not is_ai_turn)
		var value : int = immediate + future
		if is_ai_turn:
			if value > best:
				best = value
		else:
			if value < best:
				best = value
	return best


# Personality-weighted eval: scales own gain by w_score, opponent gain
# by w_denial. A "fighter" NPC with w_denial > w_score plays as a
# spoiler; a "scorer" NPC with w_score > w_denial prioritizes points.
# The w_chain weight is not yet plumbed — chain length isn't surfaced
# from the simulation; tracked as future work.
# Reads the snapshotted weights (_sim_*), NOT ai_personality directly —
# this runs on the search thread.
func _weighted_eval(ai_inc: int, human_inc: int) -> int:

	return roundi(_sim_w_score * ai_inc - _sim_w_denial * human_inc)


# Personality-derived minimax depth, clamped sane. Falls back to the
# const default when no personality is attached.
func _personality_depth() -> int:

	if ai_personality == null:
		return MINIMAX_DEPTH
	return clampi(ai_personality.search_depth, 1, 5)


# Mutating simulation: drop a coin owned by `dropper_owner` at `start_col`
# on `sim_state`. Switches flip as the coin passes the lever side. When a
# switch flips an odd number of times with a resting coin on its pad, the
# resting coin is LAUNCHED and traced through the rest of the board too —
# scoring is attributed to whichever player ORIGINALLY dropped each coin.
# Returns { "human_score": int, "ai_score": int } for this entire chain.
func _simulate_with_switches(sim_state: Array, start_col: int, dropper_owner: int) -> Dictionary:

	var scores : Array = [0, 0]
	# Queue of falling coins, each: { col, row, owner, size }.
	var falling : Array = [{"col": start_col, "row": 0, "owner": dropper_owner, "size": 1}]
	while not falling.is_empty():
		var c : Dictionary = falling.pop_back()
		var col : int = c["col"]
		var coin_owner : int = c["owner"]
		var size : int = c["size"]
		var rested : bool = false
		for r in range(c["row"], SWITCH_ROWS):
			var switch : Dictionary = _find_sim_switch_in_row(sim_state[r], col)
			if switch.is_empty():
				continue
			var pad_col : int = switch["col_right"] if switch["pad_side"] == PAD_RIGHT else switch["col_left"]
			var lever_col : int = switch["col_left"] if switch["pad_side"] == PAD_RIGHT else switch["col_right"]
			if col == pad_col:
				if switch["resting_coin"] == null:
					switch["resting_coin"] = {"owner": coin_owner, "size": size, "col": col}
					rested = true
					break
				else:
					# Bounce + flip + launch (mirrors _resolve_pad_hit). The
					# bouncing coin's weight on the lever side tips the
					# paddle, which then drops the formerly-resting coin.
					col = lever_col
					switch["pad_side"] = -switch["pad_side"]
					var bounced_resting = switch["resting_coin"]
					switch["resting_coin"] = null
					var bounced_launched : Dictionary = {
						"col": bounced_resting["col"],
						"row": r + 1,
						"owner": bounced_resting["owner"],
						"size": bounced_resting["size"],
					}
					var bounced_merged : bool = false
					for bq_idx in falling.size():
						var bq : Dictionary = falling[bq_idx]
						if bq["col"] == bounced_launched["col"] and absi(bq["row"] - bounced_launched["row"]) <= 1:
							bq["size"] += bounced_launched["size"]
							bounced_merged = true
							break
					if not bounced_merged:
						falling.push_back(bounced_launched)
			elif col == lever_col:
				for i in size:
					switch["pad_side"] = -switch["pad_side"]
				var resting = switch["resting_coin"]
				if resting != null and (size % 2 == 1):
					switch["resting_coin"] = null
					var launched : Dictionary = {
						"col": resting["col"],
						"row": r + 1,
						"owner": resting["owner"],
						"size": resting["size"],
					}
					# Multi-coin merge approximation: if a queued coin is in
					# the same column at an adjacent row, the launched coin
					# is absorbed into it (queued coin's owner keeps the
					# combined size). Mirrors the real-game merge mechanic
					# without needing a continuous-time sim.
					var merged : bool = false
					for q_idx in falling.size():
						var q : Dictionary = falling[q_idx]
						if q["col"] == launched["col"] and absi(q["row"] - launched["row"]) <= 1:
							q["size"] += launched["size"]
							merged = true
							break
					if not merged:
						falling.push_back(launched)
		if not rested and col >= 0 and col < SCORING_SLOTS:
			# Snapshotted scoring table (_sim_*) — runs on the search thread.
			scores[coin_owner] += _sim_scoring_values[col] * size
	return {"human_score": scores[HUMAN_PLAYER], "ai_score": scores[AI_PLAYER]}


# Deep-copy switch state into a sim-friendly format. Real resting Gem
# references are converted into {owner, size, col} dicts so the sim can
# mutate freely and still credit launched coins to the right player.
# Snapshot the live [Switch] node state into the plain-dict shape the
# minimax sim works on. Called once at the top of [method
# _begin_ai_search]; from there the sim deep-copies the dict tree for
# each candidate branch without touching nodes. resting_coin is
# converted from a [Gem] ref into {owner, size, col} so the sim's
# bounce/launch logic can manipulate it freely.
func _snapshot_switches_for_sim() -> Array:

	var out : Array = []
	for row_switches in switches:
		var row_dicts : Array = []
		for sw_var in row_switches:
			var sw : Switch = sw_var as Switch
			if sw == null:
				continue
			var sim_resting = null
			if sw.resting_coin != null:
				var coin : Gem = sw.resting_coin
				sim_resting = {
					"owner": coin.owner_player,
					"size": coin.size,
					"col": _coin_column(coin),
				}
			row_dicts.append({
				"col_left": sw.col_left,
				"col_right": sw.col_right,
				"pad_side": sw.pad_side,
				"resting_coin": sim_resting,
			})
		out.append(row_dicts)
	return out


# Deep-copy a dict-shaped switch tree so the sim can mutate a branch
# freely. This runs ON THE SEARCH THREAD, so it must be PURE DATA — it
# must NEVER touch a live node. The input is always the already-flattened
# output of [method _snapshot_switches_for_sim] (resting_coin is null or a
# {owner,size,col} dict) or a prior _deep_copy_switches result, so a real
# [Gem] reference can never legitimately reach here. We assert that
# invariant instead of silently dereferencing a node off-thread — Gem
# flattening belongs solely in _snapshot_switches_for_sim (main thread).
func _deep_copy_switches(source: Array) -> Array:

	var copy : Array = []
	for row_switches in source:
		var row_copy : Array = []
		for sw in row_switches:
			var resting = sw["resting_coin"]
			var sim_resting = null
			if resting is Dictionary:
				sim_resting = {
					"owner": resting["owner"],
					"size": resting["size"],
					"col": resting["col"],
				}
			else:
				# Must be null. A live Gem here means a snapshotting bug
				# leaked a node onto the search thread — fail loud rather
				# than read node state off the main thread.
				assert(resting == null,
					"_deep_copy_switches got a live Gem off-thread; _snapshot_switches_for_sim must flatten resting_coin first")
			row_copy.append({
				"col_left": sw["col_left"],
				"col_right": sw["col_right"],
				"pad_side": sw["pad_side"],
				"resting_coin": sim_resting,
			})
		copy.append(row_copy)
	return copy


# ---------- Drawing ----------

func _draw() -> void:

	var poly : PackedVector2Array = _frame_polygon()
	# Board interior (warm aged-oak parlor table).
	draw_colored_polygon(poly, COLOR_BOARD_BG)
	_draw_plank_grain()
	# Layered ornate frame: thick brass rim outside, dark walnut band over
	# it, thin brass inlay on the inner edge. Three coincident polylines
	# of decreasing width fake the look of an inlaid border.
	var outline : PackedVector2Array = poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, COLOR_FRAME_OUTER, 10.0)
	draw_polyline(outline, COLOR_FRAME_MID, 6.0)
	draw_polyline(outline, COLOR_FRAME_INLAY, 1.5)
	_draw_entry_slots()
	_draw_column_dividers()
	# Switches draw themselves now ([Switch] is a Node2D added as a
	# child — its own _draw renders the beam/pad/pivot in local coords).
	_draw_scoring_slots()
	_draw_hover_indicator()


# Faint dark horizontal lines at the midpoint between every pair of switch
# rows — reads as wood-plank shadow grain on the aged-oak interior without
# clashing with the column dividers or switch beams.
func _draw_plank_grain() -> void:

	var fy : float = funnel_end_y()
	var bw : float = board_width()
	var entry_left_x : float = ENTRY_POSITIONS[0] * COLUMN_SPACING
	var entry_right_x : float = (ENTRY_POSITIONS[-1] + 1) * COLUMN_SPACING
	var grain_color : Color = Color(COLOR_BOARD_GRAIN.r, COLOR_BOARD_GRAIN.g, COLOR_BOARD_GRAIN.b, 0.55)
	for row in SWITCH_ROWS:
		var y : float = switch_row_to_y(row) + ROW_SPACING * 0.5
		# Clip to the trapezoidal walls so the grain doesn't poke past the funnel.
		var left_x : float
		var right_x : float
		if y >= fy:
			left_x = 0.0
			right_x = bw
		else:
			var t : float = clampf(y / fy, 0.0, 1.0)
			left_x = lerpf(entry_left_x, 0.0, t)
			right_x = lerpf(entry_right_x, bw, t)
		draw_line(Vector2(left_x, y), Vector2(right_x, y), grain_color, 1.0)


func _draw_entry_slots() -> void:

	# 8 narrow coin-chutes at the entry columns, each with a brass-trimmed
	# dark-wood slot + arrow below.
	for col in ENTRY_POSITIONS:
		var x : float = column_to_x(col)
		var slot_rect : Rect2 = Rect2(Vector2(x - 14.0, 6.0), Vector2(28.0, 34.0))
		draw_rect(slot_rect, COLOR_ENTRY_SLOT, true)
		draw_rect(slot_rect, COLOR_FRAME_OUTER, false, 2.0)
		var tri : PackedVector2Array = PackedVector2Array([
			Vector2(x - 11.0, 42.0),
			Vector2(x + 11.0, 42.0),
			Vector2(x, 54.0),
		])
		draw_colored_polygon(tri, COLOR_ENTRY_SLOT.darkened(0.3))
		var tri_outline : PackedVector2Array = tri.duplicate()
		tri_outline.append(tri[0])
		draw_polyline(tri_outline, COLOR_FRAME_OUTER, 1.0)


# Switch drawing lives on [Switch._draw] now — each Switch is a Node2D
# child that renders its own beam, pad, and pivot. Replacing the
# paddle art is a matter of editing switch.gd (or its scene), no
# board-side code touch required.


# Vertical column-divider rails between every scoring column, drawn under
# the paddles so they read as the structure the paddles are pinned into.
# In the funnel area the rails start where the diagonal trapezoid walls
# meet that column boundary (so they don't poke through the side walls).
func _draw_column_dividers() -> void:

	var fy : float = funnel_end_y()
	var bh : float = board_height()
	var bw : float = board_width()
	var entry_left_x : float = ENTRY_POSITIONS[0] * COLUMN_SPACING
	var entry_right_x : float = (ENTRY_POSITIONS[-1] + 1) * COLUMN_SPACING
	var line_end_y : float = bh - BOTTOM_PADDING + 4.0
	var line_color : Color = COLOR_FRAME.darkened(0.6)
	for col in range(1, SCORING_SLOTS):
		var x : float = col * COLUMN_SPACING
		var y_start : float
		if x >= entry_left_x and x <= entry_right_x:
			y_start = 0.0
		elif x < entry_left_x:
			y_start = fy * (1.0 - x / entry_left_x)
		else:
			y_start = fy * (x - entry_right_x) / (bw - entry_right_x)
		draw_line(Vector2(x, y_start), Vector2(x, line_end_y), line_color, 1.0)


# Pair colors now live on [Hole] itself (see [const Hole.PAIR_COLORS]).
# The board just hands each hole a [enum Hole.Pair] enum value and the
# hole picks its own visual color + resolves its partner. Less coupling.


func _draw_scoring_slots() -> void:

	var y_top : float = TOP_PADDING + SWITCH_ROWS * ROW_SPACING + 4.0
	var slot_h : float = BOTTOM_PADDING - 8.0
	for col in SCORING_SLOTS:
		var x : float = column_to_x(col)
		var rect : Rect2 = Rect2(Vector2(x - COLUMN_SPACING * 0.5 + 1.0, y_top), Vector2(COLUMN_SPACING - 2.0, slot_h))
		var bg : Color = _slot_color(scoring_values[col])
		draw_rect(rect, bg, true)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), COLOR_FRAME, 2.0)
		draw_rect(rect, COLOR_FRAME.darkened(0.2), false, 1.0)


# Translucent column highlight that follows the player's mouse during
# their turn — entry chute glows, a faint vertical trail runs down the
# full board, the drop-arrow brightens. Read like a YPP aiming guide:
# "here's where the gem would enter." Updated by [_update_hover_col].
func _draw_hover_indicator() -> void:

	if _hover_col < 0:
		return
	var x : float = column_to_x(_hover_col)
	var w : float = COLUMN_SPACING
	var h : float = board_height()
	# Faint vertical column trail spanning the full board height.
	draw_rect(Rect2(x - w * 0.5, 0.0, w, h), Color(1.0, 0.96, 0.78, 0.07))
	# Brighter highlight on the entry chute itself.
	var slot_rect : Rect2 = Rect2(Vector2(x - 14.0, 6.0), Vector2(28.0, 34.0))
	draw_rect(slot_rect, Color(1.0, 0.96, 0.65, 0.30))
	# Outline glow on the chute.
	draw_rect(slot_rect, Color(1.0, 0.96, 0.65, 0.85), false, 2.0)
	# Brightened drop arrow below the chute.
	var tri : PackedVector2Array = PackedVector2Array([
		Vector2(x - 11.0, 42.0),
		Vector2(x + 11.0, 42.0),
		Vector2(x, 54.0),
	])
	draw_colored_polygon(tri, Color(1.0, 0.96, 0.65, 0.7))


# Slot background grades from dim blue (low value) to warm red-brown (high
# value). Reference scale is round 4's max so round 1 reads as "all low."
func _slot_color(value: int) -> Color:

	var t : float = clampf(float(value) / SCORE_COLOR_MAX_REF, 0.0, 1.0)
	return COLOR_SCORE_LOW.lerp(COLOR_SCORE_HIGH, t)


func _refresh_score_labels() -> void:

	for label in _score_labels:
		label.queue_free()
	_score_labels.clear()
	var y_top : float = TOP_PADDING + SWITCH_ROWS * ROW_SPACING + 4.0
	var slot_h : float = BOTTOM_PADDING - 8.0
	for col in SCORING_SLOTS:
		var label : Label = Label.new()
		label.text = str(scoring_values[col])
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", COLOR_SCORE_TEXT)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("outline_size", 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(column_to_x(col) - COLUMN_SPACING * 0.5, y_top)
		label.size = Vector2(COLUMN_SPACING, slot_h)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_score_labels.append(label)

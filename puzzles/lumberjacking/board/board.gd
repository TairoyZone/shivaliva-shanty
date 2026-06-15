## The Lumberjacking bin — a 6×13 grid that runs the YPP-SwordFighting-
## faithful falling-pair puzzle. See [[lumberjacking-spec]] for the full
## design.
##
## All four phases of the mechanic are now wired:
##   Phase 1: falling pair input + locking + gravity.
##   Phase 2: breaker shatter + connected-component propagation +
##            chain cascades + score (combos) / wood (fused-block haul).
##   Phase 3: visual fusion overlay (2×2+ same-kind solid groups
##            outlined as one block) + chain_landed signal for the
##            UI toast.
##   Phase 4: knot drops with time-escalating difficulty +
##            4-turn decay state machine + game-over.
##
## Coordinate convention: grid[row][col]. row 0 = top, row ROWS-1 = bottom.
## col 0 = leftmost, col COLS-1 = rightmost. Spawn is the TOP of column 4
## (0-indexed = 3) per SwF — the right-of-center column.
@tool
class_name LumberjackingBoard
extends Node2D


# --- Board dimensions -------------------------------------------------

const COLS : int = 6
const ROWS : int = 13
const SPAWN_COL : int = 3   # 0-indexed; SwF's "column 4"
## Rows ABOVE the visible field where a fresh pair starts, then falls in.
## Spawning off the top (not at row 0) gives the player a moment to slide
## the piece toward an edge before it commits into the bin — essential
## when the stacks are high near the entry. Rendered above the bin via a
## visual chute; negative rows are treated as open "sky" (see _cell_open).
const SPAWN_OFFSET_ROWS : int = 2

# --- Falling pair timing ---------------------------------------------

## Normal fall interval (sec/row) now comes from the SCORE-tier table
## (see DIFFICULTY_TIERS) — difficulty escalates with the SCORE earned this
## session, not elapsed time. Reworked 2026-05-29 (Troy: difficulty
## ramped too fast on a timer; should come when you've genuinely earned
## it). Keyed on score since the 05-31 score/wood decouple.
## Fall interval while Space is held — soft drop. Engages immediately
## on press, no ramp. Pieces visibly fall fast but never teleport.
## Release snaps back to the current tier's NORMAL rate.
const FALL_INTERVAL_SOFT_DROP : float = 0.10
## Defensive cap on fall steps per frame — prevents a runaway
## while-loop from teleporting the pair through the floor if the
## frame is unusually long or the accumulator is mis-managed. At
## SOFT_DROP=0.10, normal rate at 60fps is ~1 step per 6 frames, so
## 3 is comfortably above the expected ceiling.
const MAX_FALL_STEPS_PER_FRAME : int = 3

## Probability that a freshly-generated piece is a BREAKER (axe-bitten
## variant) instead of a SOLID. Lowered from 0.25 → 0.18 so the player
## has more room to BUILD a big pile before a breaker arrives — the new
## economy rewards chopping huge connected blocks, which needs build time.
const BREAKER_CHANCE : float = 0.18

# --- SCORE formula (was the wood-yield economy; decoupled 2026-05-31) ---
#
# These knobs now drive the SKILL SCORE (difficulty + mastery rank), NOT
# the wood you bank — wood is the separate fusion tally in
# _fused_wood_for_component. Per shattered component of size n cells, at
# chain depth d (1-based), the component scores:
#   n <  MIN_PLANK_CELLS : WOOD_SAWDUST           (a token amount)
#   n >= MIN_PLANK_CELLS : round(PLANK_SCALE * n^PLANK_EXPONENT)
# then the whole pass is multiplied by the chain depth d. The superlinear
# exponent + chain multiplier mean deep combos rocket your score (and rank)
# — but the wood haul stays flat, so combos express skill, not currency.
# (Constant names kept under their original WOOD_/PLANK_ spelling.)
## Score from a small clear (breaker + a couple blocks). Deliberately tiny.
const WOOD_SAWDUST : int = 1
## A component this size or larger counts as a real "plank" chop (a 2×2
## is 4 cells).
const MIN_PLANK_CELLS : int = 4
## Superlinear growth — bigger single chops pay disproportionately more.
const PLANK_EXPONENT : float = 1.5
## Overall yield tuning knob (lower = stingier). Tune in playtest.
const PLANK_SCALE : float = 0.4
## Hard cap on the wood ONE shattered component can pay (before the chain
## multiplier). Stops a single giant chop from trivially filling the bag
## — the "still too easy" fix. A whole pass can still exceed this via
## multiple components or a chain. Tune in playtest.
const PLANK_MAX : int = 50

# --- Falling physics (gravity settle animation) ----------------------
#
# After a shatter, surviving pieces FALL into the gaps with a visible,
# accelerating drop instead of teleporting. Duration scales with the
# distance fallen (sqrt for a gravity feel), clamped so cascades stay
# snappy. The resolve loop awaits each settle before the next shatter
# scan, so a chain plays out as a watchable sequence of drops.
const GRAVITY_FALL_PER_ROW : float = 0.055
const GRAVITY_FALL_MIN : float = 0.07
const GRAVITY_FALL_MAX : float = 0.30
## Knot entry drop — much faster than the gravity settle. YPP-style:
## almost instant, but a quick visible streak from above so the eye
## registers it fell in rather than blinking into place. Fixed duration
## (not distance-scaled) so every knot snaps in at the same snappy pace.
const KNOT_DROP_TIME : float = 0.07

# --- Difficulty: SCORE tiers (reworked 2026-05-29; keyed on score 05-31) -
#
# Difficulty escalates with the SCORE earned this session, NOT elapsed
# time. Each tier sets the fall speed (sec/row) + the knot drop interval
# (sec). You cross into the next tier only by scoring — so a cautious
# player stays easy and a heavy comboer ramps up (they earned it). The
# thresholds are unchanged from when score was the wood yield, so the curve
# is identical. The tier is recomputed from score every frame in
# _emit_difficulty_if_changed.
#
# Each entry: { min_score, name, fall (sec/row), knot (sec between drops) }.
const DIFFICULTY_TIERS : Array = [
	{"min_score": 0,   "name": "Steady",       "fall": 0.90, "knot": 16.0},
	{"min_score": 40,  "name": "Picking up",   "fall": 0.78, "knot": 12.0},
	{"min_score": 110, "name": "Pressing",     "fall": 0.66, "knot": 9.0},
	{"min_score": 220, "name": "Hard",         "fall": 0.54, "knot": 6.5},
	{"min_score": 380, "name": "MAX HARDNESS", "fall": 0.44, "knot": 4.5},
]

# --- Visual constants ------------------------------------------------

## Pulse + outline for fusion overlays (2×2+ same-kind solid groups).
const FUSION_OUTLINE_COLOR : Color = Color(1.0, 0.95, 0.55, 0.92)
const FUSION_OUTLINE_WIDTH : float = 3.5
const FUSION_INNER_GLOW_COLOR : Color = Color(1.0, 0.95, 0.55, 0.10)

# --- Pair orientation -------------------------------------------------
#
# A pair is two pieces glued together. A is the pivot; B's grid position
# is derived from A + orientation. Rotation cycles through the 4 states:
#   CCW (Up arrow):    B_BELOW → B_RIGHT → B_ABOVE → B_LEFT → ...
#   CW  (Down arrow):  B_BELOW → B_LEFT  → B_ABOVE → B_RIGHT → ...

const PAIR_B_BELOW : int = 0
const PAIR_B_LEFT : int = 1
const PAIR_B_ABOVE : int = 2
const PAIR_B_RIGHT : int = 3

# --- Bin visual styling ----------------------------------------------
#
# Warmer + lighter than the first pass — saturated wood blocks need a
# medium-brown workshop-floor backdrop to pop, not a near-black void.
# Roughly matches the YPP SwF bin which is a soft warm brown.

const BIN_BG_COLOR : Color = Color(0.16, 0.11, 0.07, 1.0)        # deep walnut so wood pieces pop (was a mid brown)
const BIN_BORDER_COLOR : Color = Color(0.68, 0.46, 0.22, 1.0)
const BIN_GRID_COLOR : Color = Color(0.50, 0.34, 0.18, 0.22)
const BIN_BORDER_WIDTH : float = 3.0
const SPAWN_GUIDE_COLOR : Color = Color(0.98, 0.82, 0.42, 0.14)


## Emitted whenever the running SCORE changes. Score is the combo/chain
## skill metric — it drives difficulty + the mastery rank, NOT the wood you
## bank. (Decoupled 2026-05-31: combos are for skill, not currency.)
signal score_changed(new_total: int)
## Emitted whenever the running WOOD haul changes. Wood is earned ONLY by
## clearing fused blocks (2x2+), 1 wood per 2x2 sub-tile, with NO chain
## multiplier — this is the currency banked to the backpack.
signal wood_changed(new_total: int)
## Emitted once when the bin tops out and the session ends. Carries the
## final score (for mastery) and the final wood haul (for the backpack).
signal session_ended(final_score: int, final_wood: int)
## Fires when a chain step lands. depth=1 = Clean Split (no toast), 2 =
## Double-Through, 3 = Triple-Through, 4 = Bingo Split, 5 = Donkey Split,
## 6+ = Vegas Split. The PuzzleScene listens to spawn a big chain toast.
signal chain_landed(depth: int)
## Fires when the difficulty tier crosses a threshold. The PuzzleScene
## listens to update its DifficultyLabel.
signal difficulty_tier_changed(tier_name: String)
## Emitted whenever the upcoming pair changes (each spawn consumes the
## queued preview pair and rolls a fresh one). The scene's NextPreview
## UI listens to show the player what's coming — same as YPP SwordFight.
## Args are the A (top) and B (bottom) piece kind+variant enum ints.
signal next_pair_changed(a_kind: int, a_variant: int, b_kind: int, b_variant: int)


const LogPieceScene : PackedScene = preload("res://puzzles/lumberjacking/log_piece/log_piece.tscn")
const KnotScene : PackedScene = preload("res://puzzles/lumberjacking/knot/knot.tscn")


# --- Runtime state ---------------------------------------------------

## 2D grid: grid[row][col] holds null OR a Node2D (LogPiece for Phase 1;
## Knot will also live here in Phase 4).
var grid : Array = []

## The pair currently falling (or null between locks). Dictionary keys:
##   anchor_row, anchor_col, orientation, piece_a, piece_b
var current_pair : Dictionary = {}

## The NEXT pair to spawn, held as plain config dicts {kind, variant}.
## The board always keeps one pair queued ahead so the NextPreview can
## show it before it drops. [method _roll_next_pair] regenerates these
## and emits [signal next_pair_changed].
var _next_a : Dictionary = {}
var _next_b : Dictionary = {}

## Continuous fall progress: 0..1 = how far the active pair has visually
## descended toward the NEXT row. Advances by delta/interval each frame;
## at >= 1 a discrete row-step commits (for collision/lock) and the
## remainder carries. _update_pair_visuals lerps the pieces between rows
## by this, so the pair falls SMOOTHLY instead of snapping row-to-row.
var fall_progress : float = 0.0
## True while Space is held — fall interval flips immediately to
## SOFT_DROP. Release flips back to NORMAL.
var soft_dropping : bool = false

## DAS (delayed auto-shift) for held left/right. _move_dir is the held
## direction (-1 left, +1 right, 0 none); _das_timer counts down to the
## next auto-slide. Press moves once + arms the timer; after
## DAS_INITIAL_DELAY the piece slides column-to-column every
## DAS_REPEAT_INTERVAL, so HOLDING an arrow walks it across the board.
var _move_dir : int = 0
var _das_timer : float = 0.0
const DAS_INITIAL_DELAY : float = 0.17
const DAS_REPEAT_INTERVAL : float = 0.09

## True while a lock is resolving (gravity-settle + shatter-cascade
## animations are playing). Pauses falling, knot drops, and input so the
## board doesn't advance mid-cascade. Set in [method _lock_pair].
var _resolving : bool = false
## Set by [method _on_knot_resolved] when a knot decays into a LogPiece,
## so [method _lock_pair] runs an extra settle+cascade pass for it.
var _knot_resolve_pending : bool = false

## Running SCORE this session — the combo/chain skill metric. Drives the
## difficulty tier + the mastery rank. NOT the currency (see [member wood]).
var score : int = 0
## Running WOOD haul this session — earned only from cleared fused blocks
## (1 per 2x2 sub-tile, no chain multiplier). Banked to the backpack on
## session_ended.
var wood : int = 0

var session_ended_flag : bool = false

# --- Phase 4: knots + difficulty -------------------------------------

## Real-time seconds since the last knot dropped. Compared against the
## current tier's knot interval (which comes from the score earned, not
## elapsed time).
var knot_timer : float = 0.0
## Currently-on-board knots that need their decay advanced on every
## pair lock ("turn"). Knot.resolved removes from this list.
var active_knots : Array = []
## Most-recently emitted difficulty tier. Seeded to "Steady" (the tier
## the scene's label starts on + the tier at t=0) so the first _process
## frame doesn't emit a redundant difficulty_tier_changed (audit minor).
var _last_difficulty_tier : String = "Steady"

# --- Phase 3: visual fusion groups -----------------------------------

## Cached fusion rectangles re-computed after every gravity settle.
## Each entry: {"row": int, "col": int, "w": int, "h": int}.
## Drawn as a glow-outline overlay in [method _draw].
var _fusion_groups : Array = []


func _ready() -> void:

	if Engine.is_editor_hint():
		return
	# Hide the spawn-buffer pieces ABOVE the top edge so they emerge INTO view as they fall in. A static cover
	# (the scene bg colour) does this WITHOUT clip_children — its per-composite stencil is a heavy WebGL cost
	# (Troy 2026-06-13, the mobile perf pass; see [SpawnCover]).
	SpawnCover.add_above(self, Vector2(COLS * LogPiece.CELL_SIZE, ROWS * LogPiece.CELL_SIZE), Color(0.2, 0.14, 0.08, 1.0))
	_init_grid()
	# Seed the preview queue before the first spawn so the player always
	# sees the upcoming pair (the first spawn consumes this and rolls the
	# next one for the preview).
	_roll_next_pair()
	_spawn_pair()
	set_process_unhandled_input(true)


# Fresh empty grid — ROWS × COLS of nulls.
func _init_grid() -> void:

	grid = []
	for r in range(ROWS):
		var row : Array = []
		row.resize(COLS)
		for c in range(COLS):
			row[c] = null
		grid.append(row)


# --- Pair spawn / construction ---------------------------------------

func _spawn_pair() -> void:

	# Insta-loss: if EITHER half of the pair's spawn cells is blocked
	# (A at row 0, B at row 1 for default B_BELOW), the bin has topped
	# out and no more pieces can enter. SwF rule.
	if not _pair_fits(0, SPAWN_COL, PAIR_B_BELOW):
		_end_session()
		return
	# Pull the falling pair from the preview queue; safety-roll if empty.
	if _next_a.is_empty() or _next_b.is_empty():
		_roll_next_pair()
	var piece_a : LogPiece = _make_piece_from_config(_next_a)
	var piece_b : LogPiece = _make_piece_from_config(_next_b)
	add_child(piece_a)
	add_child(piece_b)
	# Start ABOVE the field (negative rows = sky) and fall in, so the
	# player gets reaction time before the piece enters the bin.
	current_pair = {
		"anchor_row": -SPAWN_OFFSET_ROWS,
		"anchor_col": SPAWN_COL,
		"orientation": PAIR_B_BELOW,
		"piece_a": piece_a,
		"piece_b": piece_b,
	}
	fall_progress = 0.0
	_update_pair_visuals()
	# Advance the preview to the pair AFTER the one now falling.
	_roll_next_pair()


# A uniformly-random wood kind + BREAKER_CHANCE-weighted variant, as a
# plain {kind, variant} config dict. Rolling configs (not live nodes)
# lets the preview show the upcoming pair without instancing it early.
func _make_random_piece_config() -> Dictionary:

	return {
		"kind": randi() % LogPiece.WoodKind.size(),
		"variant": (LogPiece.Variant.BREAKER if randf() < BREAKER_CHANCE
			else LogPiece.Variant.SOLID),
	}


# Instantiate a LogPiece node from a {kind, variant} config dict.
func _make_piece_from_config(cfg: Dictionary) -> LogPiece:

	var piece : LogPiece = LogPieceScene.instantiate() as LogPiece
	piece.wood_kind = cfg["kind"] as LogPiece.WoodKind
	piece.variant = cfg["variant"] as LogPiece.Variant
	return piece


# Roll a fresh next-pair into the preview queue + announce it.
func _roll_next_pair() -> void:

	_next_a = _make_random_piece_config()
	_next_b = _make_random_piece_config()
	next_pair_changed.emit(
		_next_a["kind"], _next_a["variant"],
		_next_b["kind"], _next_b["variant"])


# Read the currently-queued next pair without consuming it — used by the
# scene to seed the NextPreview after it connects (the board rolls its
# first pair in _ready, before the scene's signal connection exists).
func peek_next_pair() -> Dictionary:

	return {"a": _next_a, "b": _next_b}


# --- Input -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:

	if session_ended_flag:
		return
	# Soft-drop key state is tracked FIRST, unconditionally — even between
	# pairs / mid-cascade (current_pair empty). Otherwise a Space RELEASE
	# that lands during a cascade is swallowed by the early-return below,
	# leaving soft_dropping stuck true so the NEXT pair rockets down at
	# soft-drop speed (the "100x speed" bug, 2026-05-29).
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE:
		# fall_progress is a 0..1 fraction (interval-independent), so
		# switching to/from soft-drop just changes how fast it advances —
		# no reset needed, no burst.
		soft_dropping = event.pressed
		get_viewport().set_input_as_handled()
		return
	# Held left/right → DAS. Track the direction on the INITIAL press
	# (ignore OS echo; _process drives the repeat) and clear it on release,
	# so holding an arrow walks the piece column-to-column. Tracked even
	# between pairs so a held direction carries onto the next piece.
	if event.is_action_pressed("ui_left") and not event.echo:
		_start_move(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right") and not event.echo:
		_start_move(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("ui_left") and _move_dir == -1:
		_move_dir = 0
		return
	if event.is_action_released("ui_right") and _move_dir == 1:
		_move_dir = 0
		return
	# Rotation — discrete (no auto-repeat); only while a pair is falling.
	if current_pair.is_empty():
		return
	if event.is_action_pressed("ui_up") and not event.echo:
		_try_rotate(-1)  # CCW per SwF default
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") and not event.echo:
		_try_rotate(1)  # CW per SwF default
		get_viewport().set_input_as_handled()


# Begin a held move in [param dir] (-1 left / +1 right): an immediate
# step, then _process auto-repeats after DAS_INITIAL_DELAY.
func _start_move(dir: int) -> void:

	_move_dir = dir
	_das_timer = DAS_INITIAL_DELAY
	if not current_pair.is_empty():
		_try_move(dir)


# --- Pair movement / rotation ----------------------------------------

func _try_move(col_delta: int) -> void:

	if _pair_fits(current_pair.anchor_row, current_pair.anchor_col + col_delta,
		current_pair.orientation):
		current_pair.anchor_col += col_delta
		_update_pair_visuals()


# Rotate the pair around A. First tries the rotation in place; if the
# new B-cell is blocked or off-grid, walks through a small "kick"
# table and re-tries each shifted position. This matches YPP's actual
# rotation feel — pieces never get "stuck" against a wall at the edge.
# Order: try the cardinal shifts that are most natural for the failure
# (kick LEFT/RIGHT first since most rotation collisions happen at the
# side walls, then UP for ground/stack collisions).
func _try_rotate(direction: int) -> void:

	var new_orientation : int = (current_pair.orientation + direction + 4) % 4
	if _pair_fits(current_pair.anchor_row, current_pair.anchor_col, new_orientation):
		current_pair.orientation = new_orientation
		_update_pair_visuals()
		return
	const KICKS : Array = [
		Vector2i(0, -1),  # kick left
		Vector2i(0, 1),   # kick right
		Vector2i(-1, 0),  # kick up (clear of stacks / floor)
		Vector2i(0, -2),  # double-kick left (corner cases at col 0/5)
		Vector2i(0, 2),   # double-kick right
	]
	for kick in KICKS:
		var kicked_row : int = current_pair.anchor_row + kick.x
		var kicked_col : int = current_pair.anchor_col + kick.y
		if _pair_fits(kicked_row, kicked_col, new_orientation):
			current_pair.anchor_row = kicked_row
			current_pair.anchor_col = kicked_col
			current_pair.orientation = new_orientation
			_update_pair_visuals()
			return
	# No valid kick — silently deny the rotation.


# Does a hypothetical pair anchored at (row, col) with the given
# orientation fit (both A and B in-bounds and over empty cells)?
func _pair_fits(anchor_row: int, anchor_col: int, orientation: int) -> bool:

	var a : Vector2i = Vector2i(anchor_row, anchor_col)
	var b : Vector2i = _b_coord_from(a, orientation)
	return _cell_open(a) and _cell_open(b)


# Where does B sit given A's coord + the pair's orientation?
func _b_coord_from(a_coord: Vector2i, orientation: int) -> Vector2i:

	match orientation:
		PAIR_B_BELOW:
			return Vector2i(a_coord.x + 1, a_coord.y)
		PAIR_B_LEFT:
			return Vector2i(a_coord.x, a_coord.y - 1)
		PAIR_B_ABOVE:
			return Vector2i(a_coord.x - 1, a_coord.y)
		PAIR_B_RIGHT:
			return Vector2i(a_coord.x, a_coord.y + 1)
	return a_coord


# Can a piece occupy this cell? Off the sides or below the floor = no.
# ABOVE the field (negative rows) = yes ("sky") — that's the spawn buffer
# the piece falls through, and where it can be slid sideways during entry.
func _cell_open(coord: Vector2i) -> bool:

	if coord.y < 0 or coord.y >= COLS:
		return false
	if coord.x >= ROWS:
		return false
	if coord.x < 0:
		return true
	return grid[coord.x][coord.y] == null


# Sync the pair's pieces' world positions from their grid coords, plus a
# smooth partial-row offset from fall_progress so the pair descends
# continuously between discrete rows (no teleport). The offset only
# applies while the next row is enterable — once the pair is resting on a
# surface it sits exactly on its row.
func _update_pair_visuals() -> void:

	if current_pair.is_empty():
		return
	var a : Vector2i = Vector2i(current_pair.anchor_row, current_pair.anchor_col)
	var b : Vector2i = _b_coord_from(a, current_pair.orientation)
	var off : Vector2 = Vector2.ZERO
	if _pair_fits(current_pair.anchor_row + 1, current_pair.anchor_col, current_pair.orientation):
		off.y = clampf(fall_progress, 0.0, 1.0) * LogPiece.CELL_SIZE
	current_pair.piece_a.position = _cell_world(a) + off
	current_pair.piece_b.position = _cell_world(b) + off


# Grid coord (row, col) → world position (top-left of cell).
func _cell_world(coord: Vector2i) -> Vector2:

	return Vector2(coord.y * LogPiece.CELL_SIZE, coord.x * LogPiece.CELL_SIZE)


# --- Falling physics -------------------------------------------------

func _process(delta: float) -> void:

	if Engine.is_editor_hint():
		return
	if session_ended_flag:
		return
	# Freeze everything while a lock is resolving (gravity + shatter
	# animations are playing). Falling, knot drops, and the difficulty
	# clock all pause for the brief cascade.
	if _resolving:
		return
	# Difficulty is score-driven (not time) — recompute the tier from the
	# score earned so far. The knot timer counts real time between drops,
	# but the INTERVAL it targets comes from the current score tier.
	_emit_difficulty_if_changed()
	_advance_knot_timer(delta)
	# A knot landing in the spawn-column top can insta-lose inside the
	# timer above — bail before stepping/locking the current pair so the
	# frame doesn't sneak in one stray lock after the loss is signalled.
	if session_ended_flag:
		return
	# Falling pair physics only while a pair exists.
	if current_pair.is_empty():
		return
	# DAS: while left/right is held, auto-slide the piece column-to-column
	# after the initial delay (one step per expiry, so it walks across).
	if _move_dir != 0:
		_das_timer -= delta
		if _das_timer <= 0.0:
			_try_move(_move_dir)
			_das_timer = DAS_REPEAT_INTERVAL
	var interval : float = (FALL_INTERVAL_SOFT_DROP if soft_dropping
		else _current_normal_fall_interval())
	# Advance the smooth 0..1 fall toward the next row. Each whole unit is
	# a committed row-step; _update_pair_visuals lerps the visual between
	# rows by the leftover fraction so the descent is continuous.
	fall_progress += delta / interval
	var steps : int = 0
	while fall_progress >= 1.0 and not current_pair.is_empty():
		if steps >= MAX_FALL_STEPS_PER_FRAME:
			# Spike guard — never teleport more than a few rows in a frame.
			fall_progress = 1.0
			break
		if _pair_fits(current_pair.anchor_row + 1, current_pair.anchor_col,
			current_pair.orientation):
			current_pair.anchor_row += 1
			fall_progress -= 1.0
			steps += 1
		else:
			# Landed on the surface — lock (async settle/cascade follows).
			fall_progress = 0.0
			_lock_pair()
			return
	_update_pair_visuals()


# --- Locking + gravity -----------------------------------------------

func _lock_pair() -> void:

	var a : Vector2i = Vector2i(current_pair.anchor_row, current_pair.anchor_col)
	var b : Vector2i = _b_coord_from(a, current_pair.orientation)
	# Top-out: the piece jammed before it could descend into the field
	# (entry blocked, e.g. a knot in the spawn column) — it's still above
	# row 0. Never write negative grid rows; end the run instead.
	if a.x < 0 or b.x < 0:
		current_pair.piece_a.queue_free()
		current_pair.piece_b.queue_free()
		current_pair = {}
		_end_session()
		return
	grid[a.x][a.y] = current_pair.piece_a
	grid[b.x][b.y] = current_pair.piece_b
	current_pair = {}
	# Resolve the lock as an animated sequence: pieces FALL into gaps
	# (visible, not teleported), shatters cascade, and we await each
	# settle so a chain plays out as a watchable series of drops. The
	# _resolving flag (set here) pauses _process until we're done.
	_resolving = true
	await _animate_settle()
	# Bail if the player left mid-animation (the board was freed out from
	# under this coroutine by a scene change).
	if not is_inside_tree():
		return
	var result : Dictionary = await _resolve_cascade()
	if not is_inside_tree():
		return
	var gained_score : int = result["score"]
	var gained_wood : int = result["wood"]
	# Lock = "turn" tick in SwF terms. Advance every knot's decay. A knot
	# that decays into a LogPiece sets _knot_resolve_pending so we run one
	# more settle+cascade for any shatter it created.
	_advance_knot_turns()
	if _knot_resolve_pending:
		_knot_resolve_pending = false
		await _animate_settle()
		if not is_inside_tree():
			return
		var extra : Dictionary = await _resolve_cascade()
		if not is_inside_tree():
			return
		gained_score += extra["score"]
		gained_wood += extra["wood"]
	if gained_score > 0:
		score += gained_score
		score_changed.emit(score)
	if gained_wood > 0:
		wood += gained_wood
		wood_changed.emit(wood)
	_resolving = false
	_spawn_pair()


# --- Shatter resolution ----------------------------------------------
#
# Faithful YPP-SwF rules:
#   1. A "shatter component" is a 4-adjacent same-kind connected group
#      that contains BOTH at least one breaker AND at least one solid.
#      (A group of all-solids waits for a breaker to arrive; a group
#      of all-breakers floats inert.)
#   2. Every cell in a shattering component is cleared.
#   3. After clearing, gravity pulls pieces down. If gravity re-arranges
#      cells into NEW shatter components, those fire on the next chain
#      step. The Nth chain step multiplies the SCORE for that pass by N
#      (wood is unaffected by chains — see below).
#   4. Knots (damage pieces) do NOT participate in shatter components —
#      they're not LogPieces. They sit inert until their decay timer
#      finishes and the board converts them to normal LogPieces.
#
# Scoring vs wood (decoupled 2026-05-31):
#   • SCORE: each component yields _score_for_component(size) (tiny for
#     small clears, superlinear for big chops), summed per pass, then the
#     whole pass × chain depth. Deep chains are where the SCORE is.
#   • WOOD: each component pays _fused_wood_for_component(comp) — 1 per 2x2
#     sub-tile of its fused area, flat (no chain multiplier). Building real
#     2x2+ blocks is the only path to wood.


## Resolve every shatter chain from the current board state. ASYNC: after
## each chain step it awaits the gravity-settle animation, so the cascade
## plays out as a visible series of drops rather than instant teleports.
## Returns {"score": int, "wood": int} accumulated across all chain steps;
## emits chain_landed once per step for the UI toast.
##
## SCORE is the superlinear combo formula × chain depth — the skill metric.
## WOOD is decoupled: only the FUSED (2x2+) area of each cleared block pays,
## flat (no chain multiplier), so the haul tracks deliberate block-building
## while flashy chains only pump the score/rank.
func _resolve_cascade() -> Dictionary:

	var total_score : int = 0
	var total_wood : int = 0
	var chain_depth : int = 0
	while true:
		var components : Array = _find_shatter_components()
		if components.is_empty():
			break
		chain_depth += 1
		var pass_score : int = 0
		for comp in components:
			pass_score += _score_for_component(comp.size())
			total_wood += _fused_wood_for_component(comp)
			for coord in comp:
				_free_cell(coord)
		total_score += pass_score * chain_depth
		chain_landed.emit(chain_depth)
		await _animate_settle()
		# Player left mid-cascade → stop touching the (freed) board.
		if not is_inside_tree():
			break
	return {"score": total_score, "wood": total_wood}


## SCORE a single shattered component of [param n] cells contributes
## (before the chain multiplier). Small clears are token "sawdust";
## components of [constant MIN_PLANK_CELLS]+ pay superlinearly so chopping
## one huge connected pile beats several small ones. This feeds the
## skill/mastery score ONLY — wood is handled by [method
## _fused_wood_for_component]. (The PLANK_*/WOOD_SAWDUST constants are score
## knobs, kept under their original names.)
func _score_for_component(n: int) -> int:

	if n < MIN_PLANK_CELLS:
		return WOOD_SAWDUST
	return clampi(roundi(PLANK_SCALE * pow(float(n), PLANK_EXPONENT)), 1, PLANK_MAX)


## WOOD a single shattered component pays toward the backpack haul: 1 per
## 2x2 sub-tile of its FUSED area. A cell counts as "fused" when it belongs
## to at least one all-SOLID 2x2 square inside the component — the same
## thing the fusion overlay outlines (breakers/knots never fuse). So a 2x2
## pays 1, a 2x4 pays 2, a 4x4 pays 4, and thin lines / loose clears (no
## solid 2x2) pay ZERO. No chain multiplier: building real blocks is the
## only path to wood. MUST be called before the component's cells are
## freed (it reads the live grid via [method _solid_kind_at]).
func _fused_wood_for_component(comp: Array) -> int:

	var cells : Dictionary = {}
	for c in comp:
		cells[c] = true
	var fused : Dictionary = {}
	for c in comp:
		# c as the top-left of a 2x2: count it only if all four cells are in
		# this component AND hold a solid piece (same kind is guaranteed —
		# the component is a single-kind group).
		if _solid_kind_at(c.x, c.y) == -1:
			continue
		# c = (row, col); .x is the row, .y is the column. So +x is the cell
		# below, +y is the cell to the right.
		var below : Vector2i = Vector2i(c.x + 1, c.y)
		var right : Vector2i = Vector2i(c.x, c.y + 1)
		var diag : Vector2i = Vector2i(c.x + 1, c.y + 1)
		if (cells.has(below) and cells.has(right) and cells.has(diag)
				and _solid_kind_at(below.x, below.y) != -1
				and _solid_kind_at(right.x, right.y) != -1
				and _solid_kind_at(diag.x, diag.y) != -1):
			fused[c] = true
			fused[below] = true
			fused[right] = true
			fused[diag] = true
	# Intentional integer floor: 1 wood per complete 2x2 sub-tile of fused
	# area (a 2x3's 6 fused cells → 1, a 2x4's 8 → 2, …).
	@warning_ignore("integer_division")
	return fused.size() / 4


## Scan the grid, find every same-kind 4-adj connected component, and
## return only those that should shatter (have BOTH a breaker AND a
## solid). Each returned component is an Array of Vector2i cell coords.
func _find_shatter_components() -> Array:

	var visited : Dictionary = {}
	var components : Array = []
	for row in range(ROWS):
		for col in range(COLS):
			var coord : Vector2i = Vector2i(row, col)
			if visited.has(coord):
				continue
			var piece : Node = grid[row][col]
			if not (piece is LogPiece):
				visited[coord] = true
				continue
			var component : Array = _bfs_same_kind(coord)
			for c in component:
				visited[c] = true
			if _component_should_shatter(component):
				components.append(component)
	return components


## BFS the largest 4-adjacent connected component of same-kind
## LogPieces starting at [param start]. Stops at any cell of a
## different kind, any Knot, any null, or the grid edge.
func _bfs_same_kind(start: Vector2i) -> Array:

	var start_piece : Node = grid[start.x][start.y]
	if not (start_piece is LogPiece):
		return []
	var target_kind : int = (start_piece as LogPiece).wood_kind
	var visited : Dictionary = {}
	var component : Array = []
	var queue : Array = [start]
	const NEIGHBORS : Array = [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1)]
	while not queue.is_empty():
		var c : Vector2i = queue.pop_front()
		if visited.has(c):
			continue
		visited[c] = true
		if c.x < 0 or c.x >= ROWS or c.y < 0 or c.y >= COLS:
			continue
		var p : Node = grid[c.x][c.y]
		if not (p is LogPiece):
			continue
		if (p as LogPiece).wood_kind != target_kind:
			continue
		component.append(c)
		for d in NEIGHBORS:
			queue.append(c + d)
	return component


## Shatter trigger: component must contain at least one BREAKER AND
## at least one SOLID. A pure-solid group waits for a breaker; a
## pure-breaker group sits inert.
func _component_should_shatter(component: Array) -> bool:

	var has_breaker : bool = false
	var has_solid : bool = false
	for coord in component:
		var piece : LogPiece = grid[coord.x][coord.y] as LogPiece
		if piece.variant == LogPiece.Variant.BREAKER:
			has_breaker = true
		else:
			has_solid = true
		if has_breaker and has_solid:
			return true
	return false


## Drop the piece out of the grid logic immediately, then animate a
## brief flash + scale + fade before queue-freeing the actual node.
## The grid slot is cleared synchronously so gravity + chain detection
## stay correct — the visual decay happens in parallel.
func _free_cell(coord: Vector2i) -> void:

	var piece : Node = grid[coord.x][coord.y]
	grid[coord.x][coord.y] = null
	if piece == null:
		return
	if not (piece is Node2D):
		piece.queue_free()
		return
	var p2d : Node2D = piece as Node2D
	# Raise above other cells so gravity-moved pieces don't render on
	# top of the still-fading shatter visual.
	p2d.z_index = 50
	var tw : Tween = create_tween().set_parallel(true)
	# Quick bright flash (yellow tint pulse) — sells the "snap" of the
	# shatter beat.
	tw.tween_property(p2d, "modulate",
		Color(1.6, 1.5, 0.95, 1.0), 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Slight scale-up to add a pop without drifting too far off-cell.
	tw.parallel().tween_property(p2d, "scale",
		Vector2(1.18, 1.18), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Then fade to transparent and free.
	tw.chain().tween_property(p2d, "modulate",
		Color(1.5, 1.4, 0.9, 0.0), 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(p2d.queue_free)


# Settle the grid LOGICALLY (rearrange the array so each column's pieces
# rest at the bottom, preserving stacking order) and return the list of
# pieces that MOVED, as {node, to, rows}. The grid is correct immediately
# (shatter scans read the array, not visual positions); the visual catch-
# up is animated separately by [method _animate_settle].
func _settle_grid_logical() -> Array:

	var moves : Array = []
	for col in range(COLS):
		var stack : Array = []
		for row in range(ROWS):
			if grid[row][col] != null:
				stack.append(grid[row][col])
				grid[row][col] = null
		for i in range(stack.size()):
			var target_row : int = ROWS - stack.size() + i
			grid[target_row][col] = stack[i]
			var node : Node = stack[i]
			if node is Node2D:
				var to_pos : Vector2 = _cell_world(Vector2i(target_row, col))
				if (node as Node2D).position != to_pos:
					var rows : float = absf(to_pos.y - (node as Node2D).position.y) / LogPiece.CELL_SIZE
					moves.append({"node": node, "to": to_pos, "rows": rows})
	return moves


# Logically settle the grid, then ANIMATE each moved piece falling into
# its new resting spot (accelerating drop, duration scaled by distance).
# Awaits the longest drop so the caller (the cascade) waits for the
# pieces to land before the next shatter scan. Refreshes the fusion
# overlay for the settled state.
func _animate_settle() -> void:

	var moves : Array = _settle_grid_logical()
	_detect_fusions()
	queue_redraw()
	if moves.is_empty():
		return
	var tw : Tween = create_tween().set_parallel(true)
	for m in moves:
		var dur : float = clampf(
			GRAVITY_FALL_PER_ROW * sqrt(m["rows"]),
			GRAVITY_FALL_MIN, GRAVITY_FALL_MAX)
		tw.tween_property(m["node"], "position", m["to"], dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


# --- Phase 3: fusion detection ---------------------------------------
#
# After every settle, find every maximal 2×2+ rectangular group of
# same-kind SOLID pieces. These are rendered as glowing outlined
# rectangles in [method _draw] — a visual cue that the group will
# produce a bigger plank when shattered. The greedy algorithm finds
# rectangles starting top-left and expanding right then down; not
# guaranteed to find THE maximum rectangle by area, but always finds
# SOME valid 2×2+ rectangle covering all qualifying cells.

func _detect_fusions() -> void:

	_fusion_groups = []
	var marked : Dictionary = {}
	for row in range(ROWS - 1):
		for col in range(COLS - 1):
			if marked.has(Vector2i(row, col)):
				continue
			var kind : int = _solid_kind_at(row, col)
			if kind == -1:
				continue
			# Greedy width — walk right while same kind + solid + unmarked.
			var w : int = 1
			while (col + w < COLS
				and _solid_kind_at(row, col + w) == kind
				and not marked.has(Vector2i(row, col + w))):
				w += 1
			# Greedy height — walk down; each candidate row must have
			# ALL [col, col+w) cells be same kind + solid + unmarked.
			var h : int = 1
			while row + h < ROWS:
				var row_ok : bool = true
				for x in range(w):
					if (_solid_kind_at(row + h, col + x) != kind
						or marked.has(Vector2i(row + h, col + x))):
						row_ok = false
						break
				if not row_ok:
					break
				h += 1
			if w >= 2 and h >= 2:
				_fusion_groups.append({"row": row, "col": col, "w": w, "h": h})
				for dx in range(w):
					for dy in range(h):
						marked[Vector2i(row + dy, col + dx)] = true


# Returns the wood kind at (row, col) if that cell holds a SOLID
# LogPiece, or -1 for anything else (null, breaker, knot, out-of-bounds).
func _solid_kind_at(row: int, col: int) -> int:

	if row < 0 or row >= ROWS or col < 0 or col >= COLS:
		return -1
	var p : Node = grid[row][col]
	if not (p is LogPiece):
		return -1
	var lp : LogPiece = p as LogPiece
	if lp.variant != LogPiece.Variant.SOLID:
		return -1
	return lp.wood_kind


# --- Phase 4: knots + difficulty -------------------------------------

# Advance the knot timer + drop a knot when due. The interval targeted
# comes from the current SCORE tier (not elapsed time).
func _advance_knot_timer(delta: float) -> void:

	if current_pair.is_empty():
		# No pair = mid-shatter or post-game — pause knot drops.
		return
	knot_timer += delta
	var interval : float = _current_knot_interval()
	if knot_timer >= interval:
		knot_timer -= interval
		_drop_knot()


# The current difficulty tier (highest whose min_score the session has
# reached). Always returns a valid entry (tier 0's min_score is 0).
func _current_tier() -> Dictionary:

	var tier : Dictionary = DIFFICULTY_TIERS[0]
	for t in DIFFICULTY_TIERS:
		if score >= int(t["min_score"]):
			tier = t
	return tier


func _current_knot_interval() -> float:

	return float(_current_tier()["knot"])


# Normal fall interval (sec/row) for the current score tier.
func _current_normal_fall_interval() -> float:

	return float(_current_tier()["fall"])


# Drop a single knot into a random non-full column. Avoids SPAWN_COL
# during the early grace period so the player can't be insta-killed by
# a random first knot.
func _drop_knot() -> void:

	var candidates : Array = []
	# Grace: while still in the first (Steady) tier — before any score has
	# pushed difficulty up — knots avoid the spawn column so the player
	# can't be insta-killed by a random early drop.
	var avoid_spawn_col : bool = score < int(DIFFICULTY_TIERS[1]["min_score"])
	for col in range(COLS):
		if avoid_spawn_col and col == SPAWN_COL:
			continue
		# Column has space at the top → can accept a knot.
		if grid[0][col] == null:
			candidates.append(col)
	if candidates.is_empty():
		# Fall back to ANY non-full column (even SPAWN_COL) if no others
		# are open — the player has stacked so high that grace doesn't
		# matter anymore.
		for col in range(COLS):
			if grid[0][col] == null:
				candidates.append(col)
	if candidates.is_empty():
		return
	var col : int = candidates[randi() % candidates.size()]
	# Land at the lowest empty cell in that column.
	var target_row : int = -1
	for row in range(ROWS - 1, -1, -1):
		if grid[row][col] == null:
			target_row = row
			break
	if target_row == -1:
		return
	var knot : Knot = KnotScene.instantiate() as Knot
	add_child(knot)
	grid[target_row][col] = knot
	knot.resolved.connect(_on_knot_resolved.bind(knot))
	active_knots.append(knot)
	# Animate the knot FALLING in from above the top edge (clipped until it
	# enters the bin). Logical placement above is instant — this is just
	# the visual descent, same accelerating feel as the falling pieces.
	var start_pos : Vector2 = _cell_world(Vector2i(-SPAWN_OFFSET_ROWS, col))
	var target_pos : Vector2 = _cell_world(Vector2i(target_row, col))
	knot.position = start_pos
	var tw : Tween = create_tween()
	tw.tween_property(knot, "position", target_pos, KNOT_DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# SwF fidelity: a knot landing in the top of the spawn column means
	# nothing more can enter — that's an insta-loss, not a deferred
	# top-out on the next spawn attempt (audit minor / spec line 122).
	if target_row == 0 and col == SPAWN_COL:
		_end_session()


# A knot has finished its 4-turn decay. Replace it on the board with a
# fresh random LogPiece at the same cell. Fired (synchronously) from
# [method _advance_knot_turns], which runs inside [method _lock_pair]'s
# resolve sequence — so we DON'T resolve shatters here; we just set
# _knot_resolve_pending and let _lock_pair run the animated settle +
# cascade for any shatter the new piece created.
func _on_knot_resolved(knot: Knot) -> void:

	active_knots.erase(knot)
	for row in range(ROWS):
		for col in range(COLS):
			if grid[row][col] == knot:
				var piece : LogPiece = _make_piece_from_config(_make_random_piece_config())
				add_child(piece)
				piece.position = _cell_world(Vector2i(row, col))
				grid[row][col] = piece
				knot.queue_free()
				_knot_resolve_pending = true
				return


# Called once per pair lock (the SwF "turn"). Each knot advances one
# step through its decay state machine. Knots that hit RESOLVED fire
# their resolved signal, which triggers [method _on_knot_resolved].
func _advance_knot_turns() -> void:

	# Iterate a copy — _on_knot_resolved may mutate active_knots.
	for knot in active_knots.duplicate():
		if is_instance_valid(knot):
			knot.advance_turn()


func _emit_difficulty_if_changed() -> void:

	var tier : String = String(_current_tier()["name"])
	if tier == _last_difficulty_tier:
		return
	_last_difficulty_tier = tier
	difficulty_tier_changed.emit(tier)


# --- Session end -----------------------------------------------------

func _end_session() -> void:

	# Idempotent — several end paths (top-out at spawn, knot insta-loss,
	# top-out on lock) can theoretically reach here; emit + the game-over
	# panel must fire at most once (panel creation isn't idempotent).
	if session_ended_flag:
		return
	session_ended_flag = true
	session_ended.emit(score, wood)


# --- Visual draw -----------------------------------------------------

func _draw() -> void:

	var bin_size : Vector2 = Vector2(COLS * LogPiece.CELL_SIZE, ROWS * LogPiece.CELL_SIZE)
	var bin_rect : Rect2 = Rect2(Vector2.ZERO, bin_size)
	# Bin background — deep walnut back wall so the wood blocks pop.
	draw_rect(bin_rect, BIN_BG_COLOR)
	# The back wall is PLANKED: carved vertical seams (a dark cut + a faint lit
	# lip) so the empty bin reads as a timber mill wall, not flat brown.
	var seam : Color = Color(0.0, 0.0, 0.0, 0.28)
	var seam_lip : Color = Color(0.55, 0.40, 0.22, 0.10)
	for c in range(1, COLS):
		var sx : float = c * LogPiece.CELL_SIZE
		draw_line(Vector2(sx, 0.0), Vector2(sx, bin_size.y), seam, 1.5)
		draw_line(Vector2(sx + 1.0, 0.0), Vector2(sx + 1.0, bin_size.y), seam_lip, 1.0)
	# Soft spawn-column tint, within the bin only. (Drawing nothing above y=0; the spawn-buffer pieces above the
	# top edge stay hidden behind the SpawnCover added in _ready until they fall in.)
	var spawn_x : float = SPAWN_COL * LogPiece.CELL_SIZE
	draw_rect(Rect2(spawn_x, 0.0, LogPiece.CELL_SIZE, bin_size.y), SPAWN_GUIDE_COLOR)
	# Faint horizontal grid — just enough to read cell rows.
	for r in range(1, ROWS):
		var y : float = r * LogPiece.CELL_SIZE
		draw_line(Vector2(0.0, y), Vector2(bin_size.x, y), BIN_GRID_COLOR, 1.0)
	# Fusion overlays — draw BEHIND the LogPieces (parents draw first,
	# children after, so this lands underneath). Renders as a faint
	# inner glow + thick golden outline framing the fused group, so
	# the player sees "this 2×2+ block will produce a fine plank."
	for group in _fusion_groups:
		var px : float = group["col"] * LogPiece.CELL_SIZE
		var py : float = group["row"] * LogPiece.CELL_SIZE
		var pw : float = group["w"] * LogPiece.CELL_SIZE
		var ph : float = group["h"] * LogPiece.CELL_SIZE
		var rect : Rect2 = Rect2(px, py, pw, ph)
		draw_rect(rect, FUSION_INNER_GLOW_COLOR)
		draw_rect(rect, FUSION_OUTLINE_COLOR, false, FUSION_OUTLINE_WIDTH)
	# Beveled TIMBER frame (drawn last, on top): a dark outer edge, a warm wood
	# band, and a lit inner lip — a hewn-beam border around the mill bin.
	draw_rect(bin_rect, Color(0.09, 0.06, 0.03, 1.0), false, 6.0)
	draw_rect(bin_rect.grow(-3.0), BIN_BORDER_COLOR, false, 4.0)
	draw_rect(bin_rect.grow(-5.5), Color(0.86, 0.64, 0.34, 1.0), false, 1.5)

## SKIRMISH — the core Tetris board (single-player engine). A standard
## falling-block grid: 7 tetrominoes from a 7-bag fall under gravity; you
## move/rotate/soft-drop them (soft-drop-only by design — no hard drop);
## full rows clear and collapse;
## topping out the spawn area ends the run. Pure engine + procedural
## [method _draw] rendering — no versus / AI / garbage yet (that's the next
## build layer). The scene ([SkirmishScene]) forwards input + reads the
## signals. See [[combat-puzzle-direction]].
class_name SkirmishBoard
extends Node2D


# --- Dimensions --------------------------------------------------------
const COLS : int = 10
const ROWS : int = 20
## Hidden rows above the visible field. 0 = classic NES-style: pieces spawn
## at the top of the visible field (no invisible buffer), and a top-out is a
## spawn that collides with the stack.
const SPAWN_ROWS : int = 0
const TOTAL_ROWS : int = ROWS + SPAWN_ROWS
const CELL : int = 26
## Sentinel: no column along the top fits the fresh piece → a real top-out.
const NO_SPAWN : int = -999

# --- Tetromino data ----------------------------------------------------
# 7 pieces × 4 rotations × 4 cells, each cell = [col, row] within a 4-wide
# box. Plain ints so it's a valid const (no Vector2i constructor).
const SHAPES : Array = [
	# 0 I
	[[[0,1],[1,1],[2,1],[3,1]], [[2,0],[2,1],[2,2],[2,3]],
		[[0,2],[1,2],[2,2],[3,2]], [[1,0],[1,1],[1,2],[1,3]]],
	# 1 O
	[[[1,0],[2,0],[1,1],[2,1]], [[1,0],[2,0],[1,1],[2,1]],
		[[1,0],[2,0],[1,1],[2,1]], [[1,0],[2,0],[1,1],[2,1]]],
	# 2 T
	[[[1,0],[0,1],[1,1],[2,1]], [[1,0],[1,1],[2,1],[1,2]],
		[[0,1],[1,1],[2,1],[1,2]], [[1,0],[0,1],[1,1],[1,2]]],
	# 3 S
	[[[1,0],[2,0],[0,1],[1,1]], [[1,0],[1,1],[2,1],[2,2]],
		[[1,1],[2,1],[0,2],[1,2]], [[0,0],[0,1],[1,1],[1,2]]],
	# 4 Z
	[[[0,0],[1,0],[1,1],[2,1]], [[2,0],[1,1],[2,1],[1,2]],
		[[0,1],[1,1],[1,2],[2,2]], [[1,0],[0,1],[1,1],[0,2]]],
	# 5 J
	[[[0,0],[0,1],[1,1],[2,1]], [[1,0],[2,0],[1,1],[1,2]],
		[[0,1],[1,1],[2,1],[2,2]], [[1,0],[1,1],[0,2],[1,2]]],
	# 6 L
	[[[2,0],[0,1],[1,1],[2,1]], [[1,0],[1,1],[1,2],[2,2]],
		[[0,1],[1,1],[2,1],[0,2]], [[0,0],[1,0],[1,1],[1,2]]],
]

const COLORS : Array[Color] = [
	Color(0.36, 0.82, 0.92),  # I cyan
	Color(0.96, 0.84, 0.28),  # O yellow
	Color(0.74, 0.45, 0.86),  # T purple
	Color(0.46, 0.82, 0.44),  # S green
	Color(0.90, 0.36, 0.38),  # Z red
	Color(0.38, 0.54, 0.90),  # J blue
	Color(0.94, 0.60, 0.28),  # L orange
]
const COLOR_EMPTY : Color = Color(0.10, 0.11, 0.16, 1.0)
const COLOR_GRID : Color = Color(0.20, 0.22, 0.30, 1.0)
const COLOR_FRAME : Color = Color(0.55, 0.60, 0.78, 1.0)
const COLOR_GHOST : Color = Color(1.0, 1.0, 1.0, 0.16)
## Received garbage. It lands as an inert BLOCKAGE ([constant GARBAGE_CELL]) — solid
## for collision but NOT counted toward a line clear (it just clutters + shoves your
## stack up). After [constant DECAY_MOVES] of your piece-locks it DECAYS into a usable
## real tile ([constant GARBAGE_DECAYED]) that DOES complete lines — the YPP model.
const GARBAGE_CELL : int = 7
const GARBAGE_DECAYED : int = 8
## Piece-locks an incoming clump sits as un-clearable blockage before it ripens.
const DECAY_MOVES : int = 2
const COLOR_GARBAGE : Color = Color(0.50, 0.52, 0.58, 1.0)        # decayed (usable) stone
const COLOR_GARBAGE_BLOCK : Color = Color(0.25, 0.26, 0.31, 1.0)  # fresh blockage (inert)
## A "bruise" (slow-decay sword garbage, age above the normal max) draws PURPLE so you
## can tell the sticky stuff apart from ordinary grey blockage.
const COLOR_BRUISE : Color = Color(0.62, 0.40, 0.66, 1.0)
const COLOR_BRUISE_DK : Color = Color(0.34, 0.18, 0.40, 1.0)

# Wall-kick attempts on rotate: try the spot, then nudge sideways.
const KICKS : Array = [[0, 0], [-1, 0], [1, 0], [-2, 0], [2, 0]]

# Score per simultaneous line clear (×level), and gravity speed per level.
const LINE_SCORES : Array[int] = [0, 100, 300, 500, 800]
const SOFT_DROP_POINTS : int = 1
const LINES_PER_LEVEL : int = 10
## Soft-drop falls at this FIXED rate (sec/row), independent of level, so holding
## down/space is always a smooth, watchable fast-fall — never the near-instant
## blur a level-scaled multiplier would give at high levels.
const SOFT_DROP_INTERVAL : float = 0.03
## Hard ceiling on gravity steps applied in a single frame. With the soft-drop
## timer reset on press (see [method set_soft_drop]) the piece can't burst on a
## key-press; this is the remaining guard so a frame HITCH can't teleport it.
const MAX_FALL_STEPS_PER_FRAME : int = 3
## AI piece-fall speed BAND (sec/row). Each piece picks a FRESH random pace in a
## skill-scaled range (set in [method ai_place]) so the foe drops like a believable
## HUMAN — "sometimes slow, sometimes fast", never a robotic constant (Troy). A
## sharp foe trends quick + tight; a novice trends slow + loose. Never an instant
## teleport. Clamped to [AI_DROP_FAST, AI_DROP_CEIL]. ([[animate-everything-principle]])
const AI_DROP_FAST : float = 0.030
const AI_DROP_SLOW : float = 0.120
const AI_DROP_CEIL : float = 0.150
## Incoming garbage DROPS from the ceiling to its rest at this fixed rate (sec/row)
## so you SEE it arrive — never an instant pop ([[animate-everything-principle]]).
const GARBAGE_FALL_INTERVAL : float = 0.022
## How many of the receiver's piece-drops an incoming shaped attack is shown as
## a ghostly WARNING before it solidifies (faithful to YPP's "ripens over your
## next drop" telegraph). See [[combat-puzzle-direction]].
const TELEGRAPH_DROPS : int = 1
## Outline colour for a telegraphed incoming attack.
const COLOR_TELEGRAPH : Color = Color(0.95, 0.82, 0.42, 0.55)
## A completed line FLASHES white for this long before it collapses — the clear
## animation (so a clear is SEEN, never an instant disappear). Gravity pauses during it.
const CLEAR_FLASH_TIME : float = 0.16
const COLOR_CLEAR_FLASH : Color = Color(0.97, 0.98, 1.0, 1.0)
## On a top-out, the doomed piece that couldn't fit JAMS at the top (flashing red,
## overlapping the obstacles it couldn't clear) for this long BEFORE the KO — so you SEE
## the failure, not an instant game-over (Troy).
const TOPOUT_TIME : float = 0.55
const COLOR_TOPOUT : Color = Color(0.96, 0.26, 0.28, 1.0)
## When a blockage ripens into a usable tile it POPS its colour for this long BEFORE any
## line it completes is checked/cleared — so the inert→usable flip is SEEN, never the same
## instant as the clear (Troy: "cleared a block without it revealing its colour yet").
const REVEAL_TIME : float = 0.18
## A DEFEATED board paints every filled cell (the whole STACK) this red, on the normal
## dark field, so a glance reads "this fighter is down" (Troy). Set via defeat(); the
## WINNER's board uses stop() and keeps its colours.
const COLOR_DEFEAT : Color = Color(0.82, 0.22, 0.24, 1.0)

# --- Signals -----------------------------------------------------------
signal score_changed(score: int)
signal lines_changed(total_lines: int)
signal level_changed(level: int)
signal lines_cleared(count: int)
signal game_over(score: int)
## A fresh piece just became active (top of the field). The duel scene uses
## this to wake the AI for an AI-controlled board.
signal piece_spawned()


# --- State -------------------------------------------------------------
## grid[row][col] = -1 empty, 0..6 piece type, GARBAGE_CELL blockage, GARBAGE_DECAYED stone.
var _grid : Array = []
## Parallel to [member _grid]: for a blockage [constant GARBAGE_CELL] cell, the
## piece-locks left until it ripens into a usable tile; 0 everywhere else. Kept in
## lock-step with _grid through clears.
var _garbage_age : Array = []
var _piece : int = -1
var _rot : int = 0
var _px : int = 0
var _py : int = 0
var _next : int = -1
var _bag : Array[int] = []

var _score : int = 0
var _lines : int = 0
var _level : int = 1
var _over : bool = false
## When true this board was DEFEATED (not merely stopped) — _draw floods every filled
## cell COLOR_DEFEAT so it reads as down at a glance.
var _defeated : bool = false

## Top-out animation: the fresh piece fit NOWHERE, so it JAMS at the top (flashing red,
## overlapping the stack) for TOPOUT_TIME before game_over fires — the visible "couldn't
## fit" moment. _doomed_piece = the piece type to draw jammed.
var _topping_out : bool = false
var _topout_t : float = 0.0
var _doomed_piece : int = -1

## Line-clear animation: while true the cleared rows FLASH (everything paused) before
## they collapse. _clear_rows = the rows mid-flash; _clear_t counts the flash down.
var _clearing : bool = false
var _clear_rows : Array = []
var _clear_t : float = 0.0

## Ripen-reveal beat: while true, cells that JUST decayed from blockage to a usable tile
## POP their colour AND slide down into the gap beneath (everything paused) before clears
## are checked. _revealed_cells = [{col, from, to, color}] drop animations (abs rows);
## _reveal_t counts the beat down.
var _revealing : bool = false
var _revealed_cells : Array = []
var _reveal_t : float = 0.0

var _fall_t : float = 0.0
var _soft : bool = false
## Set on each spawn: a held soft-drop key is IGNORED until released + re-pressed, so a
## key held through a lock never slams the fresh piece down the instant it appears
## (Troy's stress case). Cleared by releasing the key (see [method set_soft_drop]).
var _soft_lockout : bool = false

## When true, the board ignores gravity/soft-drop — an external AI drives
## placement via [method ai_place]. Used for the opponent board in a duel.
var _ai_controlled : bool = false
## The foe's skill (0..1), set with [method set_ai_controlled] — shapes the
## per-piece fall pace (sharp = quicker + tighter, novice = slower + looser).
var _ai_skill : float = 0.5
## A team-fight scene sets this (via [method set_highlight]) to ring the board the
## player is currently TARGETING. Transparent = no ring. Drawn just outside the field.
var _highlight : Color = Color(0, 0, 0, 0)
## Roster thumbnails hide the next-piece box (via [method set_show_preview]) so they're
## clean + narrow; the player's full board keeps it.
var _show_preview : bool = true
## True while an AI piece is mid-fall (after ai_place commits). The piece SITS
## at the top during the bot's think-time, then falls when this flips true.
var _ai_dropping : bool = false
var _ai_drop_t : float = 0.0
## THIS AI piece's randomized fall pace (sec/row), rolled fresh in [method ai_place].
var _ai_drop_interval : float = 0.06
## A garbage clump currently FALLING into place after its telegraph expired: {} or
## {"shape": Array, "col": int, "dy": int live row offset}. Drawn SOLID (like landed
## garbage) at "dy"; falls one row per step while it still fits below, then writes
## into the grid at the live rest. The visible drop ([[animate-everything-principle]])
## — no instant pop, no frozen target (re-resolved against the live stack as it falls).
var _falling_garbage : Dictionary = {}
var _garbage_fall_t : float = 0.0
## A telegraphed INCOMING shaped attack: {} or {"shape": Array[Vector2i] of
## [dc,dr] offsets, "col": int, "color": Color}. Shown as a ghostly translucent
## block for _telegraph_drops of the receiver's drops, then it DROPS to rest as a
## solid GARBAGE_CELL clump. The resting row is NOT stored — it is re-resolved
## against the live stack on every draw + at impact, so the block rises in real
## time as you build under it. Destroyable-shaped garbage (replaces the old
## rising rows) — see [[combat-puzzle-direction]].
var _pending_attack : Dictionary = {}
var _telegraph_drops : int = 0


func _ready() -> void:

	for r in TOTAL_ROWS:
		var row : Array = []
		var ages : Array = []
		for c in COLS:
			row.append(-1)
			ages.append(0)
		_grid.append(row)
		_garbage_age.append(ages)
	_next = _bag_next()
	_spawn()
	score_changed.emit(_score)
	lines_changed.emit(_lines)
	level_changed.emit(_level)


func _process(delta: float) -> void:

	if _over:
		return
	# Top-out jam: the doomed piece sits flashing at the top (it fit nowhere) for a beat,
	# THEN the KO fires — so the failure is SEEN, not an instant game-over.
	if _topping_out:
		_topout_t -= delta
		if _topout_t <= 0.0:
			_topping_out = false
			_over = true
			queue_redraw()
			game_over.emit(_score)
		else:
			queue_redraw()   # keep the flash animating
		return
	# A ripen-reveal beat is playing — freeze everything while freshly-decayed tiles POP
	# their colour, THEN check for clears (so a ripened tile never clears the same instant
	# it turns colour). This is the reveal animation's pause.
	if _revealing:
		_reveal_t -= delta
		if _reveal_t <= 0.0:
			_revealing = false
			_revealed_cells = []
			_resolve_clears()
		return
	# A line-clear flash is playing — freeze everything (gravity, AI, garbage) until it
	# finishes, then collapse + resume. This is the clear animation's pause.
	if _clearing:
		_clear_t -= delta
		if _clear_t <= 0.0:
			_finish_clear()
		return
	# Incoming garbage falls independently of the piece, on BOTH player + AI boards.
	_advance_garbage_fall(delta)
	if _piece < 0:
		return
	if _ai_controlled:
		_process_ai(delta)
		return
	_fall_t += delta
	# Soft-drop uses a fixed fast rate (but never slower than gravity); normal fall
	# uses the level-scaled gravity. Cap steps/frame + drop the backlog so a hitch
	# can never teleport the piece.
	var interval : float = minf(SOFT_DROP_INTERVAL, _fall_interval()) if _soft else _fall_interval()
	var steps : int = 0
	while _fall_t >= interval:
		_fall_t -= interval
		_step_down()
		# _step_down may have locked the piece (clear / reveal / top-out all set
		# _piece = -1). STOP the instant that happens — re-entering with no active
		# piece would index SHAPES[-1] (the L piece) and re-lock a phantom mid-clear,
		# stranding the _clearing/_revealing flag and freezing the board. Mirrors the
		# `not _ai_dropping` guard in _process_ai (Troy 2026-06-13, the mobile freeze).
		if _over or _piece < 0:
			return
		steps += 1
		if steps >= MAX_FALL_STEPS_PER_FRAME:
			_fall_t = 0.0
			break


# An AI board's piece SITS at the top during the bot's think-time, then — once
# [method ai_place] commits a placement — falls visibly (at this piece's randomized
# _ai_drop_interval per row) to its spot and locks. No instant teleport.
func _process_ai(delta: float) -> void:

	if not _ai_dropping:
		return
	_ai_drop_t += delta
	var steps : int = 0
	while _ai_drop_t >= _ai_drop_interval:
		_ai_drop_t -= _ai_drop_interval
		_step_down()
		# _step_down may have locked + spawned a fresh piece (which clears
		# _ai_dropping) or topped out — either way, stop falling.
		if _over or not _ai_dropping:
			return
		# Same hitch guard as the player fall — never teleport on a slow frame.
		steps += 1
		if steps >= MAX_FALL_STEPS_PER_FRAME:
			_ai_drop_t = 0.0
			break


# Gravity interval (seconds per row) — faster each level.
func _fall_interval() -> float:

	return maxf(0.06, 0.80 - float(_level - 1) * 0.07)


# --- Public input (called by the scene) --------------------------------

func move(dx: int) -> void:

	if _over or _piece < 0:
		return
	if not _collides(_piece, _rot, _px + dx, _py):
		_px += dx
		queue_redraw()


func rotate_cw() -> void:

	if _over or _piece < 0:
		return
	var nr : int = (_rot + 1) % 4
	for k in KICKS:
		if not _collides(_piece, nr, _px + int(k[0]), _py + int(k[1])):
			_rot = nr
			_px += int(k[0])
			_py += int(k[1])
			queue_redraw()
			return


func set_soft_drop(on: bool) -> void:

	# Releasing the key clears the post-lock lockout — soft drop re-arms for the next
	# DELIBERATE press.
	if not on:
		_soft = false
		_soft_lockout = false
		return
	# Held over from the lock that spawned the current piece: ignore the soft drop until
	# the key is released + re-pressed, so a held key never slams a fresh piece down the
	# moment it appears (Troy's stress case).
	if _soft_lockout:
		_soft = false
		return
	# Fresh press: restart the fall clock so the gravity time banked in _fall_t isn't
	# spent at the fast soft rate in one frame (the old "sometimes instant" lurch).
	if not _soft:
		_fall_t = 0.0
	_soft = true


# --- Engine ------------------------------------------------------------

# One row of gravity. Locks if it can't fall further. Soft-drop earns points.
func _step_down() -> void:

	if _piece < 0:
		return   # no active piece (mid-clear/reveal) — never index SHAPES[-1]
	if not _collides(_piece, _rot, _px, _py + 1):
		_py += 1
		if _soft:
			_add_score(SOFT_DROP_POINTS)
		queue_redraw()
	else:
		_lock()


func _spawn() -> void:

	_piece = _next
	_next = _bag_next()
	_rot = 0
	_py = 0
	_ai_dropping = false  # a fresh AI piece sits at the top until ai_place commits
	_soft_lockout = true  # a held soft-drop key must be re-pressed before it grabs this piece
	# Spawn at the CENTRE if it's clear; otherwise SCOOT to the nearest open slot along the
	# top (a piece that can still fit a gap is NOT a KO — Troy). Top-out only when it fits
	# NOWHERE across the top row = the stack is genuinely blocked wall-to-wall.
	_px = _find_spawn_x()
	if _px == NO_SPAWN:
		# Buried: the piece fits NOWHERE. JAM it at the top (drawn flashing red, overlapping
		# the obstacles it couldn't clear) for a beat so the failure is SEEN; _process fires
		# game_over when the jam ends.
		_doomed_piece = _piece
		_piece = -1
		_topping_out = true
		_topout_t = TOPOUT_TIME
		queue_redraw()
		return
	queue_redraw()
	piece_spawned.emit()


## The most-central column the fresh piece fits at spawn (tries centre, then fans OUT), or
## NO_SPAWN if it overlaps at EVERY horizontal position — only then is the board buried.
func _find_spawn_x() -> int:

	if not _collides(_piece, _rot, 3, _py):
		return 3
	for d in range(1, COLS):
		if not _collides(_piece, _rot, 3 - d, _py):
			return 3 - d
		if not _collides(_piece, _rot, 3 + d, _py):
			return 3 + d
	return NO_SPAWN


func _lock() -> void:

	for cell in _cells(_piece, _rot, _px, _py):
		var c : int = cell.x
		var r : int = cell.y
		if r >= 0 and r < TOTAL_ROWS and c >= 0 and c < COLS:
			_grid[r][c] = _piece
	_piece = -1   # locked — no active piece until resolution finishes + spawns the next
	_ai_dropping = false  # the AI piece has landed; stop the fall-loop re-entering during
						  # the deferred reveal/flash (re-armed by ai_place after the next spawn)
	# A move passed: ripen the blockage garbage one tick (some may decay into usable
	# coloured tiles). If any flipped, hold a REVEAL beat so the player SEES the colour
	# appear BEFORE we check clears — then _resolve_clears runs from _process. Otherwise
	# resolve clears straight away.
	if _age_garbage():
		_revealing = true
		_reveal_t = REVEAL_TIME
		queue_redraw()
		return
	_resolve_clears()


# Clear any full rows (with a flash), else advance the telegraph + spawn the next piece.
# Deferred behind the ripen-reveal so a freshly-decayed tile never clears the same instant
# it turns colour; reached either straight from _lock (nothing ripened) or from _process
# when the reveal beat ends.
func _resolve_clears() -> void:

	# If a clear STARTS, it flashes first — _finish_clear resumes the telegraph + spawn
	# once the flash ends (so the line-clear is animated, not instant).
	if _clear_lines():
		return
	# Advance the incoming-attack telegraph by one drop; when the warning
	# expires the shaped garbage LANDS — AFTER our own clears, BEFORE the next
	# spawn (which then tops out if the landed clump fills the spawn zone).
	_advance_telegraph()
	_fall_t = 0.0
	_spawn()


# Detect full clearable rows. If any, start the FLASH (gravity paused) — the collapse +
# scoring happen in _finish_clear when the flash ends. Returns true if a clear started
# (the caller then defers its spawn). A row clears when EVERY cell is filled AND none is
# un-decayed blockage (see _row_clearable) — blockage holds the row hostage until it ripens.
func _clear_lines() -> bool:

	var clearable : Array = []
	for r in TOTAL_ROWS:
		if _row_clearable(r):
			clearable.append(r)
	if clearable.is_empty():
		return false
	_clear_rows = clearable
	_clearing = true
	_clear_t = CLEAR_FLASH_TIME
	_piece = -1   # no active piece during the flash
	queue_redraw()
	return true


# The flash ended: collapse the cleared rows, score, and resume the deferred lock flow
# (advance the telegraph + spawn the next piece).
func _finish_clear() -> void:

	var clearable : Array = _clear_rows
	_clearing = false
	_clear_rows = []
	clearable.sort()
	# Collapse in TWO passes. First REMOVE every cleared row, highest index first — a
	# higher removal never shifts a lower not-yet-removed index, so each delete hits the
	# right row. THEN drop in one blank row at the top per cleared row. (Doing remove +
	# insert(0) together per-iteration shifted later indices, so a MULTI-line clear
	# deleted the wrong rows and left a completed line behind — Troy's "didn't clear" bug.)
	for i in range(clearable.size() - 1, -1, -1):
		_grid.remove_at(clearable[i])
		_garbage_age.remove_at(clearable[i])
	for _n in clearable.size():
		var blank : Array = []
		var blank_age : Array = []
		for c in COLS:
			blank.append(-1)
			blank_age.append(0)
		_grid.insert(0, blank)
		_garbage_age.insert(0, blank_age)
	var cleared : int = clearable.size()
	_lines += cleared
	_add_score(LINE_SCORES[clampi(cleared, 0, 4)] * _level)
	# Intentional integer floor: every LINES_PER_LEVEL lines bumps the level.
	@warning_ignore("integer_division")
	var new_level : int = 1 + _lines / LINES_PER_LEVEL
	if new_level != _level:
		_level = new_level
		level_changed.emit(_level)
	lines_changed.emit(_lines)
	lines_cleared.emit(cleared)
	# Resume the lock flow that was deferred for the flash.
	_advance_telegraph()
	_fall_t = 0.0
	_spawn()


# A row clears only when every cell is filled AND none is un-decayed blockage garbage.
# Decayed garbage (GARBAGE_DECAYED) and pieces count; fresh blockage (GARBAGE_CELL) does
# NOT — it must ripen first (the YPP "incoming damage isn't usable yet" rule).
func _row_clearable(r: int) -> bool:

	for c in COLS:
		var v : int = _grid[r][c]
		if v < 0:
			return false           # empty
		if v == GARBAGE_CELL:
			return false           # blockage — not usable until it decays
	return true


# A move passed (a piece locked): ripen every blockage cell by one tick. A cell that
# hits 0 DECAYS into a real COLORED tile (a random piece colour) — it "reveals its
# colour", which is the clear tell that it's now usable + counts for line clears. The
# dark X-blockage → coloured-tile flip is the legible cue (Troy). A ripened tile then
# obeys gravity (inert blockage floats; ripe falls) — _settle_ripened drops it into the
# empty space beneath. Returns true if ANY cell ripened (the caller plays the REVEAL beat,
# which also animates the drop) and records the from→to drops in _revealed_cells.
func _age_garbage() -> bool:

	var ripened : Array = []   # Vector2i(col, row) cells that ripened this tick (pre-drop)
	for r in TOTAL_ROWS:
		for c in COLS:
			if _grid[r][c] == GARBAGE_CELL:
				_garbage_age[r][c] -= 1
				if _garbage_age[r][c] <= 0:
					_grid[r][c] = randi() % COLORS.size()   # ripens into a coloured tile
					_garbage_age[r][c] = 0
					ripened.append(Vector2i(c, r))
	if ripened.is_empty():
		_revealed_cells = []
		return false
	_revealed_cells = _settle_ripened(ripened)
	queue_redraw()
	return true


# Drop each just-ripened cell straight down its column into empty space — ONLY ripened
# cells fall, so inert blockage and intentional Tetris holes (an overhang's gap) are left
# untouched. Mutates _grid/_garbage_age; returns [{col, from, to, color}] (absolute rows)
# for the reveal-fall animation. Per column the LOWEST ripened cell settles first so a
# stacked pair re-stacks correctly.
func _settle_ripened(ripened: Array) -> Array:

	var anims : Array = []
	var by_col : Dictionary = {}
	for cell in ripened:
		if not by_col.has(cell.x):
			by_col[cell.x] = []
		by_col[cell.x].append(cell.y)
	for c in by_col:
		var rows : Array = by_col[c]
		rows.sort()
		rows.reverse()   # bottom-most (largest row) first
		for r in rows:
			var val : int = _grid[r][c]
			var dest : int = r
			while dest + 1 < TOTAL_ROWS and _grid[dest + 1][c] < 0:
				dest += 1
			if dest != r:
				_grid[r][c] = -1
				_garbage_age[r][c] = 0
				_grid[dest][c] = val
				_garbage_age[dest][c] = 0
			anims.append({"col": c, "from": r, "to": dest, "color": COLORS[val]})
	return anims


# Does the piece (type/rot at px,py) hit a wall, floor, or a filled cell?
func _collides(type: int, rot: int, px: int, py: int) -> bool:

	for cell in _cells(type, rot, px, py):
		var c : int = cell.x
		var r : int = cell.y
		if c < 0 or c >= COLS or r >= TOTAL_ROWS:
			return true
		if r >= 0 and _grid[r][c] >= 0:
			return true
	return false


# Absolute grid cells (Vector2i col,row) for a piece state.
func _cells(type: int, rot: int, px: int, py: int) -> Array:

	var out : Array = []
	for cell in SHAPES[type][rot]:
		out.append(Vector2i(px + int(cell[0]), py + int(cell[1])))
	return out


func _add_score(amount: int) -> void:

	_score += amount
	score_changed.emit(_score)


# 7-bag randomiser — each set of 7 pieces is a shuffled permutation, so no
# long droughts or floods of one piece.
func _bag_next() -> int:

	if _bag.is_empty():
		_bag = [0, 1, 2, 3, 4, 5, 6]
		_bag.shuffle()
	return _bag.pop_back()


# --- Read-outs for the scene ------------------------------------------

func next_piece() -> int:
	return _next

func is_over() -> bool:
	return _over

func score() -> int:
	return _score

func lines_total() -> int:
	return _lines


# --- Versus duel API --------------------------------------------------

## Hand control of this board to an external AI: no gravity, no soft-drop —
## the AI places each piece via [method ai_place] on [signal piece_spawned].
## [param skill] (0..1) shapes the per-piece fall pace (see [method ai_place]).
func set_ai_controlled(on: bool, skill: float = 0.5) -> void:
	_ai_controlled = on
	_ai_skill = clampf(skill, 0.0, 1.0)


## Ring this board in [param color] (a team-fight scene marks the player's current
## TARGET). Pass a transparent colour to clear the ring.
func set_highlight(color: Color) -> void:
	_highlight = color
	queue_redraw()


## Show/hide the next-piece preview box (off for roster thumbnails).
func set_show_preview(on: bool) -> void:
	_show_preview = on
	queue_redraw()


## DEFEND relief (a crewmate shielded this board): remove up to [param h] filled cells
## from the TOP of the stack — blockage garbage FIRST (the incoming threat), then any
## piece — so a buried board gets breathing room back from the top-out line. The mate's
## clear budget is spent un-burying instead of attacking ([[seabattle-research]] defend).
func relieve(h: int) -> void:
	if _over or h <= 0:
		return
	var removed : int = 0
	# Pass 1 = blockage garbage; pass 2 = anything else. Top rows down = shave the peak.
	for blockage_only in [true, false]:
		for r in range(SPAWN_ROWS, TOTAL_ROWS):
			for c in COLS:
				if removed >= h:
					break
				var v : int = _grid[r][c]
				if v < 0:
					continue
				if blockage_only != (v == GARBAGE_CELL):
					continue
				_grid[r][c] = -1
				_garbage_age[r][c] = 0
				removed += 1
			if removed >= h:
				break
		if removed >= h:
			break
	if removed > 0:
		queue_redraw()


## Freeze this board (the duel ended) — stop gravity/input + drop the active
## piece. Does NOT emit game_over (the caller already knows the result).
func stop() -> void:
	_over = true
	_piece = -1
	_topping_out = false
	_pending_attack = {}
	_falling_garbage = {}
	queue_redraw()


## This board lost: freeze it like stop() AND flood its whole stack red (see COLOR_DEFEAT)
## so a glance reads "down". Cancels any mid-clear/reveal/jam so nothing draws over the red.
func defeat() -> void:
	_defeated = true
	_revealing = false
	_revealed_cells = []
	_clearing = false
	_clear_rows = []
	_topping_out = false
	stop()


## The active piece type (0..6), or -1 if none / the board is over.
func piece_type() -> int:
	return _piece


## A deep copy of the grid (rows of -1 / 0..6 / GARBAGE_CELL) for the AI to
## simulate placements against without touching the live board.
func grid_rows() -> Array:
	var out : Array = []
	for row in _grid:
		out.append(row.duplicate())
	return out


## Receive a telegraphed SHAPED attack: a [param shape] (Array of Vector2i
## [dc,dr] offsets) that will drop into column [param col]. Shown as a ghostly
## translucent block for TELEGRAPH_DROPS of our drops, then it lands as solid
## GARBAGE_CELL. [param color] tints the telegraph by weapon so the threat reads.
## [param decay] = how many of the receiver's piece-locks this clump stays inert
## blockage before it ripens (a weapon SPECIAL: the sword's "bruise" lingers longer).
func receive_attack(shape: Array, col: int, color: Color = COLOR_TELEGRAPH,
		decay: int = DECAY_MOVES) -> void:
	if _over or shape.is_empty():
		return
	# An attack still in flight (telegraphing OR mid-fall) settles NOW rather than
	# being overwritten + lost. (Rare: two attacks within one telegraph window.)
	_force_settle_pending()
	# Store the shape only — the resting row is re-resolved against the LIVE stack
	# every frame (_draw) and at impact, so the telegraph rises in real time as you
	# build under it and always matches where it lands.
	_pending_attack = {"shape": shape, "col": col, "color": color, "decay": decay}
	_telegraph_drops = TELEGRAPH_DROPS
	queue_redraw()


# Tick the incoming telegraph down one drop; begin the attack's FALL when it expires.
func _advance_telegraph() -> void:
	if _pending_attack.is_empty():
		return
	_telegraph_drops -= 1
	if _telegraph_drops <= 0:
		_begin_garbage_fall()


# The telegraph expired: hand the pending attack off to a VISIBLE fall (it drops
# from the ceiling in _advance_garbage_fall) instead of popping in. Only shape+col
# are stored — the rest row is resolved against the LIVE stack as it falls, so a
# clear/build under the clump never leaves it floating or eats it.
func _begin_garbage_fall() -> void:
	var shape : Array = _pending_attack.get("shape", [])
	var col : int = int(_pending_attack.get("col", 0))
	var decay : int = int(_pending_attack.get("decay", DECAY_MOVES))
	_pending_attack = {}
	if shape.is_empty():
		return
	if _attack_rest_dy(shape, col) <= 0:
		# No room to fall (ceiling-high column) — settle at once; the buried spawn
		# rows top the board out on the next spawn.
		_write_garbage(shape, col, 0, decay)
		return
	_falling_garbage = {"shape": shape, "col": col, "dy": 0, "decay": decay}
	_garbage_fall_t = 0.0
	queue_redraw()


# Drop the falling clump one row per GARBAGE_FALL_INTERVAL — EXACTLY like a piece:
# step down only while it still fits below, settle when it can't. Re-checking the
# LIVE grid each step means a line-clear under it keeps it falling (no float) and a
# block placed under it stops it on that surface (no vanish). Capped per frame so a
# hitch can't teleport it.
func _advance_garbage_fall(delta: float) -> void:
	if _falling_garbage.is_empty():
		return
	var shape : Array = _falling_garbage.get("shape", [])
	var col : int = int(_falling_garbage.get("col", 0))
	_garbage_fall_t += delta
	var steps : int = 0
	while _garbage_fall_t >= GARBAGE_FALL_INTERVAL:
		_garbage_fall_t -= GARBAGE_FALL_INTERVAL
		if _attack_fits(shape, col, int(_falling_garbage["dy"]) + 1):
			_falling_garbage["dy"] = int(_falling_garbage["dy"]) + 1
		else:
			_settle_falling_garbage()
			return
		steps += 1
		if steps >= MAX_FALL_STEPS_PER_FRAME:
			_garbage_fall_t = 0.0
			break
	queue_redraw()


# The falling clump came to rest — write it into the grid as solid garbage at the
# LIVE rest row (re-resolved, so a force-settle of a mid-air clump still lands it
# on the real surface, never floating).
func _settle_falling_garbage() -> void:
	var shape : Array = _falling_garbage.get("shape", [])
	var col : int = int(_falling_garbage.get("col", 0))
	var decay : int = int(_falling_garbage.get("decay", DECAY_MOVES))
	_falling_garbage = {}
	if not shape.is_empty():
		_write_garbage(shape, col, _attack_rest_dy(shape, col), decay)


# Settle whatever attack is in flight (telegraphing OR mid-fall) immediately, so a
# newly-arriving attack can't overwrite + lose it.
func _force_settle_pending() -> void:
	if not _pending_attack.is_empty():
		var s : Array = _pending_attack.get("shape", [])
		var c : int = int(_pending_attack.get("col", 0))
		var d : int = int(_pending_attack.get("decay", DECAY_MOVES))
		_pending_attack = {}
		if not s.is_empty():
			_write_garbage(s, c, _attack_rest_dy(s, c), d)
	if not _falling_garbage.is_empty():
		_settle_falling_garbage()


# Write [param shape] as fresh BLOCKAGE garbage at row-offset [param dy] in [param col],
# filling only empty in-bounds cells, each stamped with a full DECAY_MOVES countdown.
# It does NOT clear lines yet — it's inert until it ripens (see _age_garbage). A clump
# resting in the spawn zone tops the board out on the next spawn.
func _write_garbage(shape: Array, col: int, dy: int, decay: int = DECAY_MOVES) -> void:
	for off in shape:
		var c : int = col + int(off.x)
		var r : int = dy + int(off.y)
		if r >= 0 and r < TOTAL_ROWS and c >= 0 and c < COLS and _grid[r][c] < 0:
			_grid[r][c] = GARBAGE_CELL
			_garbage_age[r][c] = decay
	queue_redraw()


## The resting row-offset for [param shape] dropped into [param col] against the
## CURRENT stack — the single source of truth for the telegraph (_draw), the fall
## target (_begin_garbage_fall) and the settle write (_write_garbage), so they can
## never disagree. dy=0 means the clump rests IN the spawn zone: a ceiling-high
## column swallows part of the clump and the buried spawn rows top the board out on
## the next spawn — the correct punishment for being hit while already at the roof.
func _attack_rest_dy(shape: Array, col: int) -> int:
	var dy : int = 0
	while _attack_fits(shape, col, dy + 1):
		dy += 1
	return dy


## The column whose stack is LOWEST (most empty) — what long-range aims at.
func lowest_col() -> int:
	var best_col : int = 0
	var best_h : int = TOTAL_ROWS + 1
	for c in COLS:
		var h : int = 0
		for r in TOTAL_ROWS:
			if _grid[r][c] >= 0:
				h = TOTAL_ROWS - r
				break
		if h < best_h:
			best_h = h
			best_col = c
	return best_col


# Does the shape sit at (col, dy) without any cell off the sides/floor or
# overlapping a filled cell? (Cells above the ceiling, r<0, are allowed.)
func _attack_fits(shape: Array, col: int, dy: int) -> bool:
	for off in shape:
		var c : int = col + int(off.x)
		var r : int = dy + int(off.y)
		if c < 0 or c >= COLS or r >= TOTAL_ROWS:
			return false
		if r >= 0 and _grid[r][c] >= 0:
			return false
	return true


## Place the active piece at the AI's chosen rotation + column, then hard-drop
## and lock it. The AI already verified the spot is reachable from spawn; if it
## somehow collides we fall back to the current orientation so we still lock.
func ai_place(target_rot: int, target_px: int) -> void:
	if _over or _piece < 0 or _ai_dropping:
		return
	# Snap to the chosen column/rotation at the top, then let _process_ai drop
	# it VISIBLY to the floor + lock — no instant teleport.
	if not _collides(_piece, target_rot, target_px, _py):
		_rot = target_rot
		_px = target_px
	# Roll a FRESH fall pace for this piece: a skill-scaled centre (sharp foe =
	# quick, novice = slow) times a wide per-piece jitter, so the foe's drops vary
	# believably — sometimes a crawl, sometimes a snap — instead of a constant rate.
	var centre : float = lerpf(AI_DROP_SLOW, AI_DROP_FAST, _ai_skill)
	_ai_drop_interval = clampf(centre * randf_range(0.6, 1.5), AI_DROP_FAST, AI_DROP_CEIL)
	_ai_dropping = true
	_ai_drop_t = 0.0
	queue_redraw()


# --- Rendering ---------------------------------------------------------

func _draw() -> void:

	var w : float = COLS * CELL
	var h : float = ROWS * CELL
	# Field background + frame.
	draw_rect(Rect2(0, 0, w, h), COLOR_EMPTY, true)
	# Grid lines.
	for c in range(1, COLS):
		draw_line(Vector2(c * CELL, 0), Vector2(c * CELL, h), COLOR_GRID, 1.0)
	for r in range(1, ROWS):
		draw_line(Vector2(0, r * CELL), Vector2(w, r * CELL), COLOR_GRID, 1.0)
	# Locked cells (skip the hidden spawn rows). A row mid-CLEAR flashes white; blockage
	# garbage draws dark + an X (inert, ripening); pieces (incl. ripened garbage) in colour.
	for r in range(SPAWN_ROWS, TOTAL_ROWS):
		var flashing : bool = _clearing and _clear_rows.has(r)
		for c in COLS:
			var v : int = _grid[r][c]
			if v < 0:
				continue
			if _revealing and _is_reveal_target(c, r):
				continue   # a ripened tile mid-fall — drawn separately, sliding, below
			if _defeated:
				_draw_cell(c, r - SPAWN_ROWS, COLOR_DEFEAT)   # whole stack red — this board is down
			elif flashing:
				_draw_cell(c, r - SPAWN_ROWS, COLOR_CLEAR_FLASH)
			elif v == GARBAGE_CELL:
				_draw_blockage(c, r - SPAWN_ROWS, _garbage_age[r][c])
			else:
				_draw_cell(c, r - SPAWN_ROWS, COLORS[v])
	# Ripened tiles dropping into place (the reveal-fall) — drawn sliding old→settled row
	# with a bright glow, so the inert→usable flip AND the fall into the gap are SEEN.
	if _revealing:
		_draw_reveal_anims()
	# Ghost (where the active piece would land) + the active piece.
	if _piece >= 0 and not _over:
		var gy : int = _py
		while not _collides(_piece, _rot, _px, gy + 1):
			gy += 1
		for cell in _cells(_piece, _rot, _px, gy):
			if cell.y - SPAWN_ROWS >= 0:
				_draw_cell_rect(cell.x, cell.y - SPAWN_ROWS, COLOR_GHOST, true)
		for cell in _cells(_piece, _rot, _px, _py):
			if cell.y - SPAWN_ROWS >= 0:
				_draw_cell(cell.x, cell.y - SPAWN_ROWS, COLORS[_piece])
	# Top-out JAM — the doomed piece sits where it tried to spawn (centre), FLASHING red and
	# overlapping the obstacles it couldn't fit over, so you SEE the piece that buried them.
	if _topping_out and _doomed_piece >= 0:
		var lit : bool = (int(_topout_t * 12.0) % 2) == 0
		var jam : Color = COLOR_TOPOUT if lit else COLOR_TOPOUT.darkened(0.45)
		for cell in _cells(_doomed_piece, 0, 3, 0):
			var vr : int = cell.y - SPAWN_ROWS
			if vr >= 0 and cell.x >= 0 and cell.x < COLS:
				_draw_cell(cell.x, vr, jam)
				if lit:
					draw_rect(Rect2(cell.x * CELL, vr * CELL, CELL, CELL), Color(1, 1, 1, 0.9), false, 2.0)
	# Telegraphed incoming attack — a ghostly translucent block AT ITS LANDING SPOT
	# (so you can read the threat — shape, column, weapon colour — a drop before it
	# solidifies). The rest row is re-resolved LIVE so the block tracks the stack.
	if not _pending_attack.is_empty():
		var tcol : int = int(_pending_attack.get("col", 0))
		var tshape : Array = _pending_attack.get("shape", [])
		var tdy : int = _attack_rest_dy(tshape, tcol)
		var tcolor : Color = _pending_attack.get("color", COLOR_TELEGRAPH)
		for off in tshape:
			var tc : int = tcol + int(off.x)
			var tvr : int = (tdy + int(off.y)) - SPAWN_ROWS
			if tc >= 0 and tc < COLS and tvr >= 0 and tvr < ROWS:
				_draw_cell_rect(tc, tvr, tcolor, false)
	# A garbage clump currently FALLING into place — drawn as fresh blockage (dark + X),
	# exactly how it'll look the instant it lands, so the landing is seamless.
	if not _falling_garbage.is_empty():
		var gcol : int = int(_falling_garbage.get("col", 0))
		var gdy : int = int(_falling_garbage.get("dy", 0))
		# Pass the clump's decay as the "age" so a sticky bruise already draws purple mid-fall.
		var gdecay : int = int(_falling_garbage.get("decay", DECAY_MOVES))
		for off in _falling_garbage.get("shape", []):
			var gc : int = gcol + int(off.x)
			var gvr : int = (gdy + int(off.y)) - SPAWN_ROWS
			if gc >= 0 and gc < COLS and gvr >= 0 and gvr < ROWS:
				_draw_blockage(gc, gvr, gdecay)
	# Outer frame.
	draw_rect(Rect2(0, 0, w, h), COLOR_FRAME, false, 2.0)
	# Target ring (a team-fight scene marks the player's current foe).
	if _highlight.a > 0.0:
		draw_rect(Rect2(-4, -4, w + 8, h + 8), _highlight, false, 4.0)
	if _show_preview:
		_draw_next_preview(w)


# A small "next piece" box to the right of the field.
func _draw_next_preview(field_w: float) -> void:

	var s : float = CELL * 0.82          # preview cell size
	var pad : float = 12.0               # uniform inner padding
	# The frame snugly fits the tetromino ENVELOPE — widest piece (I = 4 cells)
	# by tallest (2 cells at spawn) — so every piece shares ONE tidy box with no
	# wasted space, and each is CENTRED inside it (below).
	var box_w : float = 4.0 * s + pad * 2.0
	var box_h : float = 2.0 * s + pad * 2.0
	var bx : float = field_w + 22.0
	var by : float = 0.0
	draw_rect(Rect2(bx, by, box_w, box_h), COLOR_EMPTY, true)
	draw_rect(Rect2(bx, by, box_w, box_h), COLOR_FRAME, false, 2.0)
	if _next < 0:
		return
	# Centre THIS piece by its own bounding box (pieces spawn at different offsets,
	# so a fixed anchor looks lopsided) — measure min/max cell, then offset so the
	# bbox is centred in the frame both ways.
	var cells : Array = SHAPES[_next][0]
	var min_c : int = 9
	var max_c : int = -9
	var min_r : int = 9
	var max_r : int = -9
	for cell in cells:
		min_c = mini(min_c, int(cell[0]))
		max_c = maxi(max_c, int(cell[0]))
		min_r = mini(min_r, int(cell[1]))
		max_r = maxi(max_r, int(cell[1]))
	var ox : float = bx + (box_w - float(max_c - min_c + 1) * s) * 0.5 - float(min_c) * s
	var oy : float = by + (box_h - float(max_r - min_r + 1) * s) * 0.5 - float(min_r) * s
	for cell in cells:
		var x : float = ox + int(cell[0]) * s
		var y : float = oy + int(cell[1]) * s
		draw_rect(Rect2(x + 1, y + 1, s - 2, s - 2), COLORS[_next], true)
		draw_rect(Rect2(x + 1, y + 1, s - 2, s - 2), COLORS[_next].darkened(0.4), false, 1.0)


func _draw_cell(col: int, vis_row: int, color: Color) -> void:

	_draw_cell_rect(col, vis_row, color, false)
	# Bevel highlight + dark edge for a chunky block look.
	var x : float = col * CELL
	var y : float = vis_row * CELL
	draw_rect(Rect2(x + 2, y + 2, CELL - 4, CELL - 4), color.lightened(0.12), false, 2.0)


# Is (col, abs_row) the SETTLED spot of a tile currently mid-reveal-fall? Those cells are
# skipped in the static grid pass and drawn sliding by _draw_reveal_anims instead.
func _is_reveal_target(col: int, abs_row: int) -> bool:

	for a in _revealed_cells:
		if int(a["col"]) == col and int(a["to"]) == abs_row:
			return true
	return false


# Draw each just-ripened tile sliding from its old row to its settled row (eased like a
# fall) with a brightened fill + glow ring — so the blockage→usable flip AND the drop into
# the gap beneath are SEEN, never an instant pop ([[animate-everything-principle]]).
func _draw_reveal_anims() -> void:

	var p : float = clampf(1.0 - _reveal_t / REVEAL_TIME, 0.0, 1.0)
	var e : float = p * p   # ease-in — accelerate as it falls
	for a in _revealed_cells:
		var abs_r : float = lerpf(float(a["from"]), float(a["to"]), e)
		var y : float = (abs_r - float(SPAWN_ROWS)) * CELL
		if y + CELL <= 0.0:
			continue   # still above the visible field
		var x : float = float(a["col"]) * CELL
		var col : Color = a["color"]
		draw_rect(Rect2(x + 1, y + 1, CELL - 2, CELL - 2), col.lightened(0.35), true)
		draw_rect(Rect2(x + 1, y + 1, CELL - 2, CELL - 2), COLOR_CLEAR_FLASH, false, 2.5)


# A blockage garbage cell: dark + inert, ripening toward the usable stone colour as it
# nears decay (so you SEE it about to turn), with an X so it reads as "can't clear yet".
func _draw_blockage(col: int, vis_row: int, age: int) -> void:

	# Bruise (slow decay → age above the normal max) reads PURPLE; ordinary blockage grey.
	var bruise : bool = age > DECAY_MOVES
	var base : Color = COLOR_BRUISE_DK if bruise else COLOR_GARBAGE_BLOCK
	var ripe : Color = COLOR_BRUISE if bruise else COLOR_GARBAGE
	var t : float = 1.0 - clampf(float(age) / float(DECAY_MOVES), 0.0, 1.0)
	_draw_cell(col, vis_row, base.lerp(ripe, t * 0.6))
	var x : float = col * CELL
	var y : float = vis_row * CELL
	var m : float = 7.0
	var xc : Color = Color(0, 0, 0, 0.5)
	draw_line(Vector2(x + m, y + m), Vector2(x + CELL - m, y + CELL - m), xc, 2.0)
	draw_line(Vector2(x + CELL - m, y + m), Vector2(x + m, y + CELL - m), xc, 2.0)


func _draw_cell_rect(col: int, vis_row: int, color: Color, hollow: bool) -> void:

	var x : float = col * CELL
	var y : float = vis_row * CELL
	if hollow:
		draw_rect(Rect2(x + 2, y + 2, CELL - 4, CELL - 4), color, false, 2.0)
	else:
		draw_rect(Rect2(x + 1, y + 1, CELL - 2, CELL - 2), color, true)
		draw_rect(Rect2(x + 1, y + 1, CELL - 2, CELL - 2), color.darkened(0.4), false, 1.0)

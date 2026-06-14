## The Mining puzzle board — a faithful reskin of YPP Foraging's core.
##
## The player frames four rock tiles with a 2x2 cursor and ROTATES them
## (CW / CCW) to line up 3+ of the same mineral kind in a row or column.
## A match crumbles those tiles; everything above falls (gravity) and
## fresh rock drops in from the top.
##
## ORE CHUNKS (phase 2) are the only thing that scores. A chunk enters
## from the TOP of the board after every few moves and sits on the rock,
## falling as a single rigid body whenever the rock beneath it is
## cleared. When a chunk's whole footprint reaches the floor it is
## EXTRACTED into the haul. Extracting several chunks from one move is a
## combo — a rising multiplier makes big plays pay off. The session runs
## until a target number of chunks have been dug out (the progress
## meter / "banana column" reskin).
##
## Phases 3 (special pieces) and 4 (the Mine work-site + Forge hire /
## delivery loop) come next. See [[mining-spec]].
class_name MiningBoard
extends Node2D


## Running total of rock tiles crumbled — minor feedback only.
signal rock_cleared(total: int)
## Total ore in the haul changed (the real score).
signal ore_changed(total_ore: int)
## One move extracted `count` chunks for `ore_gained` ore (count >= 2 is
## a combo worth a banner).
signal combo_landed(count: int, ore_gained: int)
## Progress meter changed — chunks still to dig this session.
signal progress_changed(remaining: int, target: int)
## The session's chunk target has all been extracted.
signal session_ended(total_ore: int, chunks_extracted: int)


## Board dimensions, in cells. 8 wide x 12 tall mirrors Foraging's feel.
const COLS : int = 8
const ROWS : int = 12
## Pixel size of one cell — MUST match MiningRockTile.CELL_SIZE,
## MiningCursor.CELL and OreChunk.CELL.
const CELL : float = 44.0
## Number of distinct rock kinds — MUST match MiningRockTile.RockKind.
const KIND_COUNT : int = 5

## How many chunks must be dug out to finish a session (the progress
## meter length). A short, satisfying shift.
const CHUNK_TARGET : int = 6
## A new chunk enters this many player moves after the last one.
const SPAWN_EVERY_MOVES : int = 3
## Never more than this many chunks on the board at once (Foraging caps
## containers at three).
const MAX_CHUNKS_ON_BOARD : int = 3

## Animation timing.
const ROTATE_TIME : float = 0.10     # the 2x2 swap
const CLEAR_TIME : float = 0.16      # crumble shrink/fade
const FALL_PER_ROW : float = 0.040   # gravity duration scales with drop
const FALL_MIN : float = 0.06
const FALL_MAX : float = 0.26
const EXTRACT_TIME : float = 0.24    # chunk pop-out

## Held-movement (DAS) for the cursor.
const DAS_INITIAL_DELAY : float = 0.16
const DAS_REPEAT_INTERVAL : float = 0.05

## Runaway-cascade backstop.
const MAX_CASCADE_DEPTH : int = 200

## Board styling.
const BACKING_COLOR : Color = Color(0.10, 0.09, 0.12, 1.0)
const GRID_LINE_COLOR : Color = Color(0.0, 0.0, 0.0, 0.28)
const FRAME_COLOR : Color = Color(0.52, 0.42, 0.28, 0.95)
## Matches the mining scene's Background ColorRect (mining.tscn). The SPAWN COVER — which replaces the costly
## clip_children — is painted this colour so tiles sliding in from above the board blend into the backdrop until
## they enter the grid (Troy 2026-06-13, mobile perf).
const SCENE_BG_COLOR : Color = Color(0.07, 0.07, 0.1, 1.0)

## A special tool appears when one move crumbles at least this much rock
## (a "combo" of clears); the more cleared, the higher the chance.
const SPECIAL_MIN_CLEAR : int = 6
const SPECIAL_CHANCE_BASE : float = 0.28
const SPECIAL_CHANCE_PER_EXTRA : float = 0.05
const SPECIAL_CHANCE_MAX : float = 0.70
## How many distinct special kinds exist — MUST match SpecialPiece.SpecialKind.
const SPECIAL_KIND_COUNT : int = 5

## Seepage-ant facing → (col, row) delta. Indices match SpecialPiece.Facing
## (0=up, 1=right, 2=down, 3=left).
const ANT_DIRS : Array = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Bites a freshly-spawned seepage ant has before it dies.
const ANT_CHARGES : int = 5
## Chance, each move, that an ant randomly turns to a new heading instead
## of carrying straight on — makes it wander unpredictably.
const ANT_TURN_CHANCE : float = 0.3

const ROCK_TILE_SCENE : PackedScene = preload("res://puzzles/mining/rock_tile/rock_tile.tscn")
const ORE_CHUNK_SCENE : PackedScene = preload("res://puzzles/mining/ore_chunk/ore_chunk.tscn")
const SPECIAL_PIECE_SCENE : PackedScene = preload("res://puzzles/mining/special_piece/special_piece.tscn")


## grid[row][col] -> MiningRockTile, OreChunk (the same reference fills
## every cell of its footprint), or null. Row 0 is the top; gravity pulls
## toward the bottom (row ROWS-1).
var grid : Array = []

## Cursor top-left cell. The 2x2 covers (row,col)..(row+1,col+1).
var cursor_row : int = 0
var cursor_col : int = 0
## When the cursor frames a special tool, the cursor shrinks to 1x1 on
## this cell and a click activates the tool instead of rotating. (-1,-1)
## means no special under the cursor (normal 2x2 rotation mode).
var _active_special_cell : Vector2i = Vector2i(-1, -1)
## The special whose NAME label is currently shown (framed by the cursor), so
## it can be cleared when the cursor moves off it.
var _framed_special : SpecialPiece = null

## True while a rotation + its cascade is animating — board-mutating
## input is locked out until it settles.
var _resolving : bool = false
## True once the chunk target is met — the board is frozen, awaiting the
## results screen.
var _session_over : bool = false

## DAS state for held cursor movement.
var _move_dir : Vector2i = Vector2i.ZERO
var _das_timer : float = 0.0

var _rock_cleared_total : int = 0
var _ore_total : int = 0
var _chunks_spawned : int = 0
var _chunks_extracted : int = 0
var _moves_since_spawn : int = 0

@onready var _cursor : MiningCursor = $Cursor


func _ready() -> void:

	# Hide the off-board spawn rows with a static cover instead of clip_children (a heavy WebGL stencil over ~96
	# tiles — the mobile jerkiness; see [SpawnCover]). Only the top overflows here: extraction pops up + fades in.
	SpawnCover.add_above(self, Vector2(COLS * CELL, ROWS * CELL), SCENE_BG_COLOR)
	_init_grid()
	_update_cursor()
	queue_redraw()
	# Open with one chunk already sitting at the top so the player has
	# something to dig toward immediately. Snap it straight into place
	# (no slide-in animation at startup — only later spawns slide in).
	var first : OreChunk = _spawn_chunk()
	if first != null:
		_chunks_spawned += 1
		first.position = _cell_pos(first.top_row, first.left_col)
	progress_changed.emit(CHUNK_TARGET - _chunks_extracted, CHUNK_TARGET)


func _draw() -> void:

	var w : float = COLS * CELL
	var h : float = ROWS * CELL
	var rect : Rect2 = Rect2(0.0, 0.0, w, h)
	# Rock-face backing.
	draw_rect(rect, BACKING_COLOR)
	# Carved cell grooves: a dark cut + a 1px lit lip just right/below, so the
	# grid reads as routed sockets the gems are set into (vs flat hairlines).
	var groove : Color = Color(0.0, 0.0, 0.0, 0.42)
	var lip : Color = Color(1.0, 1.0, 1.0, 0.045)
	for c in range(1, COLS):
		var x : float = c * CELL
		draw_line(Vector2(x, 0.0), Vector2(x, h), groove, 1.5)
		draw_line(Vector2(x + 1.0, 0.0), Vector2(x + 1.0, h), lip, 1.0)
	for r in range(1, ROWS):
		var y : float = r * CELL
		draw_line(Vector2(0.0, y), Vector2(w, y), groove, 1.5)
		draw_line(Vector2(0.0, y + 1.0), Vector2(w, y + 1.0), lip, 1.0)
	# Beveled brass frame (outer dark, brass band, bright inner inlay) — the
	# same premium-metal language as Gem Drop / the forge.
	draw_rect(rect, Palette.SKY_VOID, false, 7.0)
	draw_rect(rect.grow(-3.5), Palette.BRASS_FRAME, false, 4.0)
	draw_rect(rect.grow(-6.5), Palette.BRASS_INLAY, false, 1.5)


# --- Input -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventMouseMotion:
		_set_cursor_from_mouse()
		return
	if _resolving or _session_over:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_perform_action(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			_perform_action(true)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				get_viewport().set_input_as_handled()
				_perform_action(true)
			KEY_X, KEY_Z:
				get_viewport().set_input_as_handled()
				_perform_action(false)


func _process(delta: float) -> void:

	if _resolving or _session_over:
		return
	var dir : Vector2i = Vector2i.ZERO
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if dir.x != 0:
		dir.y = 0
	if dir == Vector2i.ZERO:
		_move_dir = Vector2i.ZERO
		return
	if dir != _move_dir:
		_move_dir = dir
		_move_cursor(dir)
		_das_timer = DAS_INITIAL_DELAY
	else:
		_das_timer -= delta
		while _das_timer <= 0.0:
			_move_cursor(dir)
			_das_timer += DAS_REPEAT_INTERVAL


func _set_cursor_from_mouse() -> void:

	var local : Vector2 = get_local_mouse_position()
	var new_col : int = clampi(roundi(local.x / CELL - 1.0), 0, COLS - 2)
	var new_row : int = clampi(roundi(local.y / CELL - 1.0), 0, ROWS - 2)
	if new_col != cursor_col or new_row != cursor_row:
		cursor_col = new_col
		cursor_row = new_row
		_update_cursor()


func _move_cursor(dir: Vector2i) -> void:

	cursor_col = clampi(cursor_col + dir.x, 0, COLS - 2)
	cursor_row = clampi(cursor_row + dir.y, 0, ROWS - 2)
	_update_cursor()


func _update_cursor() -> void:

	if not _cursor:
		return
	# If a special tool sits in the framed 2x2, shrink to a 1x1 cursor on
	# it (the player will activate it instead of rotating). Otherwise the
	# normal 2x2 selector.
	var sp_cell : Vector2i = _special_in_cursor()
	# Clear the name label on the previously-framed special.
	if is_instance_valid(_framed_special):
		_framed_special.framed = false
		_framed_special = null
	if sp_cell.x >= 0:
		_active_special_cell = sp_cell
		_cursor.span_cells = 1
		_cursor.position = _cell_pos(sp_cell.x, sp_cell.y)
		# Pop the special's NAME label so the player knows what it does.
		var sp : Variant = grid[sp_cell.x][sp_cell.y]
		if sp is SpecialPiece:
			sp.framed = true
			_framed_special = sp
	else:
		_active_special_cell = Vector2i(-1, -1)
		_cursor.span_cells = 2
		_cursor.position = _cell_pos(cursor_row, cursor_col)


# The top-left-most special cell within the framed 2x2, or (-1,-1) if the
# 2x2 holds no special.
func _special_in_cursor() -> Vector2i:

	for dr in 2:
		for dc in 2:
			var r : int = cursor_row + dr
			var c : int = cursor_col + dc
			if grid[r][c] is SpecialPiece:
				return Vector2i(r, c)
	return Vector2i(-1, -1)


# --- Rotation + cascade ----------------------------------------------

# The player's action button. If a special tool is framed, activate it
# (direction follows the button: CW/right vs CCW/left). Otherwise rotate
# the four cells as a ring. Rotation is REFUSED unless all four cells are
# plain rock tiles (you cannot rotate a chunk, a special or a hole).
func _perform_action(clockwise: bool) -> void:

	if _resolving or _session_over:
		return
	if _active_special_cell.x >= 0:
		var sp : Variant = grid[_active_special_cell.x][_active_special_cell.y]
		if sp is SpecialPiece:
			await _activate_special(_active_special_cell, sp, not clockwise)
			return
	var r : int = cursor_row
	var c : int = cursor_col
	var nw : Variant = grid[r][c]
	var ne : Variant = grid[r][c + 1]
	var se : Variant = grid[r + 1][c + 1]
	var sw : Variant = grid[r + 1][c]
	if not (nw is MiningRockTile and ne is MiningRockTile \
			and se is MiningRockTile and sw is MiningRockTile):
		# Blocked: the 2x2 holds a chunk, a hole, or an empty cell. Give clear
		# feedback so the spot reads as blocked, not broken (Troy 2026-06-15).
		if is_instance_valid(_cursor):
			_cursor.play_deny()
		return
	if clockwise:
		# each tile moves one corner clockwise: NW->NE->SE->SW->NW
		grid[r][c] = sw
		grid[r][c + 1] = nw
		grid[r + 1][c + 1] = ne
		grid[r + 1][c] = se
	else:
		grid[r][c] = ne
		grid[r][c + 1] = se
		grid[r + 1][c + 1] = sw
		grid[r + 1][c] = nw
	_resolving = true
	_moves_since_spawn += 1
	var cells : Array = [
		Vector2i(r, c), Vector2i(r, c + 1),
		Vector2i(r + 1, c), Vector2i(r + 1, c + 1)]
	await _animate_cells_to_grid(cells, ROTATE_TIME)
	if not is_inside_tree():
		return
	await _resolve_cascade()
	if not is_inside_tree():
		return
	_resolving = false
	_update_cursor()
	# Session ends once every targeted chunk has been dug out and the
	# board holds no more chunks.
	if _chunks_extracted >= CHUNK_TARGET and _chunks_on_board().is_empty():
		_end_session()


# Resolve a move: maybe drop in a new chunk, then repeatedly clear
# matches / settle bodies / extract floor chunks / refill until stable.
# Chunks dug out across the whole move are scored together as one combo.
func _resolve_cascade() -> void:

	if _spawn_due():
		var ch : OreChunk = _spawn_chunk()
		if ch != null:
			_chunks_spawned += 1
			_moves_since_spawn = 0
			await _animate_all_to_grid()
			if not is_inside_tree():
				return

	# Every move, the seepage ants chomp the tile they face + advance (or
	# die). The holes they leave are settled by the cascade loop below.
	await _advance_ants()
	if not is_inside_tree():
		return

	# Ore VALUES of the chunks dug out this move (captured at extraction
	# time — the chunk NODES are freed by _animate_extract, so we must not
	# hold their references for scoring afterward).
	var move_extraction_values : Array = []
	# Rock crumbled by MATCHES this move — drives the chance of a special
	# tool appearing (the "combo" of normal-piece clears).
	var tiles_cleared_this_move : int = 0
	var depth : int = 0
	while is_inside_tree() and depth < MAX_CASCADE_DEPTH:
		depth += 1
		var changed : bool = false

		# 1. crumble tile matches
		var matched : Array = _find_matches()
		if not matched.is_empty():
			_rock_cleared_total += matched.size()
			tiles_cleared_this_move += matched.size()
			rock_cleared.emit(_rock_cleared_total)
			await _animate_clear(matched)
			if not is_inside_tree():
				return
			changed = true

		# 2. gravity — tiles and chunks fall into the gaps
		if _settle_logical():
			await _animate_all_to_grid()
			if not is_inside_tree():
				return
			changed = true

		# 3. extract any chunk that reached the floor
		var extracted : Array = _extract_floor_chunks()
		if not extracted.is_empty():
			for e in extracted:
				move_extraction_values.append(e.ore_value())
			await _animate_extract(extracted)
			if not is_inside_tree():
				return
			changed = true

		# 4. refill open sky at the top
		if _refill_logical():
			await _animate_all_to_grid()
			if not is_inside_tree():
				return
			changed = true

		if not changed:
			break

	if not move_extraction_values.is_empty():
		_award_extractions(move_extraction_values)
	await _maybe_spawn_special(tiles_cleared_this_move)


# --- Match detection -------------------------------------------------

func _find_matches() -> Array:

	var found : Dictionary = {}
	for r in ROWS:
		var start : int = 0
		while start < COLS:
			var kind : int = _kind_at(r, start)
			var stop : int = start
			if kind != -1:
				while stop + 1 < COLS and _kind_at(r, stop + 1) == kind:
					stop += 1
			if kind != -1 and (stop - start + 1) >= 3:
				for c in range(start, stop + 1):
					found["%d,%d" % [r, c]] = Vector2i(r, c)
			start = stop + 1
	for c in COLS:
		var start : int = 0
		while start < ROWS:
			var kind : int = _kind_at(start, c)
			var stop : int = start
			if kind != -1:
				while stop + 1 < ROWS and _kind_at(stop + 1, c) == kind:
					stop += 1
			if kind != -1 and (stop - start + 1) >= 3:
				for r in range(start, stop + 1):
					found["%d,%d" % [r, c]] = Vector2i(r, c)
			start = stop + 1
	return found.values()


# Rock-kind at a cell, or -1 if it is empty OR holds a chunk (chunks
# never participate in matches).
func _kind_at(r: int, c: int) -> int:

	var t : Variant = grid[r][c]
	if t is MiningRockTile:
		return t.rock_kind
	return -1


# --- Gravity (rigid bodies) ------------------------------------------

# Drop every tile and chunk as far as it can go, treating each chunk as a
# single rigid body. Returns true if anything moved. Updates the grid +
# each chunk's top_row/left_col; the visual catch-up is _animate_all_to_grid.
func _settle_logical() -> bool:

	var any_moved : bool = false
	var safety : int = 0
	while safety < ROWS + 2:
		safety += 1
		var moved_this_pass : bool = false
		var handled_chunks : Dictionary = {}
		# Bottom-up so a lower body vacates a cell before the body above
		# it is tested — each body falls at most one row per pass.
		for r in range(ROWS - 1, -1, -1):
			for c in COLS:
				var obj : Variant = grid[r][c]
				if obj == null:
					continue
				if obj is OreChunk:
					var cid : int = obj.get_instance_id()
					if handled_chunks.has(cid):
						continue
					handled_chunks[cid] = true
					if _chunk_can_drop(obj):
						_drop_chunk(obj)
						moved_this_pass = true
				else:
					if r + 1 <= ROWS - 1 and grid[r + 1][c] == null:
						grid[r + 1][c] = obj
						grid[r][c] = null
						moved_this_pass = true
		if moved_this_pass:
			any_moved = true
		else:
			break
	return any_moved


func _chunk_can_drop(chunk: OreChunk) -> bool:

	var bottom : int = chunk.top_row + chunk.height() - 1
	if bottom + 1 > ROWS - 1:
		return false
	for c in range(chunk.left_col, chunk.left_col + chunk.width()):
		if grid[bottom + 1][c] != null:
			return false
	return true


func _drop_chunk(chunk: OreChunk) -> void:

	_clear_chunk_cells(chunk)
	chunk.top_row += 1
	_set_chunk_cells(chunk)


# --- Extraction ------------------------------------------------------

# Any chunk whose footprint reaches the floor row is dug out. Removes it
# from the grid + progress, returns the freed chunk nodes (still in the
# tree, awaiting their pop-out animation).
func _extract_floor_chunks() -> Array:

	var extracted : Array = []
	var seen : Dictionary = {}
	for c in COLS:
		var obj : Variant = grid[ROWS - 1][c]
		if obj is OreChunk:
			var cid : int = obj.get_instance_id()
			if seen.has(cid):
				continue
			seen[cid] = true
			extracted.append(obj)
	for ch in extracted:
		_clear_chunk_cells(ch)
		_chunks_extracted += 1
		progress_changed.emit(maxi(CHUNK_TARGET - _chunks_extracted, 0), CHUNK_TARGET)
	return extracted


# Score the chunks dug out this move. Multiple chunks = a combo with a
# rising multiplier, so the second chunk is worth more than the first
# (faithful to Foraging's "each successive container scores more").
func _award_extractions(ore_values: Array) -> void:

	var gained : int = 0
	for i in ore_values.size():
		var mult : float = 1.0 + 0.5 * i
		gained += int(round(float(ore_values[i]) * mult))
	_ore_total += gained
	ore_changed.emit(_ore_total)
	if ore_values.size() >= 2:
		combo_landed.emit(ore_values.size(), gained)


# --- Special tools ---------------------------------------------------

# Fire the framed special tool, then resolve the resulting cascade. The
# tool is consumed. `go_left` is the chosen direction (drill only).
func _activate_special(cell: Vector2i, sp: SpecialPiece, go_left: bool) -> void:

	_resolving = true
	_moves_since_spawn += 1
	match sp.special_kind:
		SpecialPiece.SpecialKind.PICKAXE:
			await _animate_clear(_pickaxe_cells(cell))
		SpecialPiece.SpecialKind.DRILL:
			await _animate_clear(_drill_cells(cell, go_left))
		SpecialPiece.SpecialKind.CAVE_IN:
			await _animate_clear(_cave_in_cells(cell))
		SpecialPiece.SpecialKind.TREMOR:
			# Consume the tool BEFORE shifting. _tremor_shift reads `grid`,
			# so the now-null cell is skipped by its loop — the freed node is
			# never written into the new grid (no dangling ref, freed once),
			# and the opened cell refills via the cascade.
			grid[cell.x][cell.y] = null
			if is_instance_valid(sp):
				sp.queue_free()
			_tremor_shift(-1 if go_left else 1)
			await _animate_all_to_grid()
		SpecialPiece.SpecialKind.SEEPAGE:
			# Re-aim the ant (CW = right/C, CCW = left/X). It is NOT consumed
			# here — every ant then chomps + advances during the cascade.
			var step : int = 3 if go_left else 1
			sp.facing = ((sp.facing + step) % 4) as SpecialPiece.Facing
	if not is_inside_tree():
		return
	await _resolve_cascade()
	if not is_inside_tree():
		return
	_resolving = false
	_update_cursor()
	if _chunks_extracted >= CHUNK_TARGET and _chunks_on_board().is_empty():
		_end_session()


# Pickaxe: the tool cell + every non-chunk piece in the column below it
# (chunks are passed over — that is how a stuck chunk gets freed).
func _pickaxe_cells(cell: Vector2i) -> Array:

	var cells : Array = [cell]
	for r in range(cell.x + 1, ROWS):
		var obj : Variant = grid[r][cell.y]
		if obj is OreChunk:
			continue
		if obj != null:
			cells.append(Vector2i(r, cell.y))
	return cells


# Drill: the tool cell + every non-chunk piece in its row to one side.
func _drill_cells(cell: Vector2i, go_left: bool) -> Array:

	var cells : Array = [cell]
	if go_left:
		for c in range(cell.y - 1, -1, -1):
			var obj : Variant = grid[cell.x][c]
			if obj is OreChunk:
				continue
			if obj != null:
				cells.append(Vector2i(cell.x, c))
	else:
		for c in range(cell.y + 1, COLS):
			var obj : Variant = grid[cell.x][c]
			if obj is OreChunk:
				continue
			if obj != null:
				cells.append(Vector2i(cell.x, c))
	return cells


# Cave-in: BLAST the 5x5 around the tool — every non-chunk piece (rock
# tiles + the tool itself + any other tools caught in it) is crumbled.
# Chunks are NOT destroyed. The shared cascade then collapses everything
# above the void downward (gravity — chunks and rock fall in) and refills
# from the top, instead of the hole being instantly repacked. Returns the
# cells to clear so it reuses _animate_clear like the pickaxe/drill.
func _cave_in_cells(cell: Vector2i) -> Array:

	var cells : Array = []
	for dr in range(-2, 3):
		for dc in range(-2, 3):
			var r : int = cell.x + dr
			var c : int = cell.y + dc
			if r < 0 or r >= ROWS or c < 0 or c >= COLS:
				continue
			var obj : Variant = grid[r][c]
			if obj == null or obj is OreChunk:
				continue
			cells.append(Vector2i(r, c))
	return cells


# A special may appear after a move whose matches crumbled a lot of rock
# — the bigger the clear, the better the odds. It replaces one existing
# rock tile (so it is immediately reachable) and pops into view.
func _maybe_spawn_special(tiles_cleared: int) -> void:

	if tiles_cleared < SPECIAL_MIN_CLEAR:
		return
	var chance : float = clampf(
		SPECIAL_CHANCE_BASE + SPECIAL_CHANCE_PER_EXTRA * float(tiles_cleared - SPECIAL_MIN_CLEAR),
		0.0, SPECIAL_CHANCE_MAX)
	if randf() >= chance:
		return
	await _spawn_special()


func _spawn_special() -> void:

	var tile_cells : Array = []
	for r in ROWS:
		for c in COLS:
			if grid[r][c] is MiningRockTile:
				tile_cells.append(Vector2i(r, c))
	if tile_cells.is_empty():
		return
	var rc : Vector2i = tile_cells[randi() % tile_cells.size()]
	var old : Variant = grid[rc.x][rc.y]
	if old != null and is_instance_valid(old):
		old.queue_free()
	var sp : SpecialPiece = _make_special(_random_special_kind())
	sp.position = _cell_pos(rc.x, rc.y)
	sp.scale = Vector2.ZERO
	add_child(sp)
	grid[rc.x][rc.y] = sp
	var tw : Tween = create_tween()
	tw.tween_property(sp, "scale", Vector2.ONE, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func _random_special_kind() -> int:

	return randi() % SPECIAL_KIND_COUNT


func _make_special(kind: int) -> SpecialPiece:

	var sp : SpecialPiece = SPECIAL_PIECE_SCENE.instantiate()
	sp.special_kind = kind as SpecialPiece.SpecialKind
	if sp.special_kind == SpecialPiece.SpecialKind.SEEPAGE:
		sp.facing = (randi() % 4) as SpecialPiece.Facing
		sp.charges = ANT_CHARGES
	return sp


# Tremor: shift the WHOLE board one column (dx = +1 right / -1 left).
# Chunks shift too, so you can knock one off a side — but a chunk that
# would run off the edge (or into another chunk) anchors in place, and
# any tile/special shoved off-board or into a chunk is crushed. The
# opened trailing edge is refilled by the cascade.
func _tremor_shift(dx: int) -> void:

	var chunks : Array = _chunks_on_board()
	# Tentative destination per chunk: shift if it stays in-bounds.
	var dest : Dictionary = {}
	for ch in chunks:
		var nl : int = ch.left_col + dx
		var inb : bool = nl >= 0 and nl + ch.width() - 1 <= COLS - 1
		dest[ch] = nl if inb else ch.left_col
	# Resolve chunk-vs-chunk collisions: a SHIFTED chunk that would land on
	# another chunk reverts to its original column. We seed the anchored
	# chunks (those not shifting) into the occupancy map FIRST, then test
	# each shifted chunk against the full map — so the revert never depends
	# on iteration order or shift direction (two shifted chunks can't
	# collide since they translate by the same amount). Repeat to a fixed
	# point: a reverted chunk becomes an anchor for the next pass.
	var changed : bool = true
	while changed:
		changed = false
		var occ : Dictionary = {}
		for ch in chunks:
			if dest[ch] == ch.left_col:
				for dr in ch.height():
					for dc in ch.width():
						occ["%d,%d" % [ch.top_row + dr, dest[ch] + dc]] = ch
		for ch in chunks:
			if dest[ch] == ch.left_col:
				continue
			var collided : bool = false
			for dr in ch.height():
				for dc in ch.width():
					if occ.has("%d,%d" % [ch.top_row + dr, dest[ch] + dc]):
						collided = true
						break
				if collided:
					break
			if collided:
				dest[ch] = ch.left_col
				changed = true
			else:
				for dr in ch.height():
					for dc in ch.width():
						occ["%d,%d" % [ch.top_row + dr, dest[ch] + dc]] = ch
	# Build the shifted board.
	var new_grid : Array = []
	for r in ROWS:
		var row : Array = []
		for c in COLS:
			row.append(null)
		new_grid.append(row)
	for ch in chunks:
		ch.left_col = dest[ch]
		for dr in ch.height():
			for dc in ch.width():
				new_grid[ch.top_row + dr][ch.left_col + dc] = ch
	var crushed : Array = []
	for r in ROWS:
		for c in COLS:
			var obj : Variant = grid[r][c]
			if obj == null or obj is OreChunk:
				continue
			var nc : int = c + dx
			if nc >= 0 and nc < COLS and new_grid[r][nc] == null:
				new_grid[r][nc] = obj
			else:
				crushed.append(obj)
	grid = new_grid
	for obj in crushed:
		if is_instance_valid(obj):
			obj.queue_free()


# Seepage ants: each move, every ant eats the tile/special directly in
# front of it and advances into that cell, spending one bite. It dies on
# its last bite, or starves (dies in place) if it faces a wall, a hole or
# a chunk. Ants eat other specials (and each other). Holes are settled by
# the cascade loop afterward.
func _advance_ants() -> void:

	var ant_infos : Array = []
	for r in ROWS:
		for c in COLS:
			var obj : Variant = grid[r][c]
			if obj is SpecialPiece and obj.special_kind == SpecialPiece.SpecialKind.SEEPAGE:
				ant_infos.append({ "ant": obj, "row": r, "col": c })
	if ant_infos.is_empty():
		return
	var doomed : Array = []   # nodes to crumble + free (eaten prey and dead ants)
	var moves : Array = []    # [ant, target_pos] for surviving ants
	for info in ant_infos:
		var ant : SpecialPiece = info["ant"]
		var r : int = info["row"]
		var c : int = info["col"]
		# Skip an ant already eaten by an earlier ant this pass.
		if not is_instance_valid(ant) or grid[r][c] != ant:
			continue
		# Wander: now and then the ant randomly picks a new heading;
		# otherwise it keeps going the way it faced.
		if randf() < ANT_TURN_CHANCE:
			ant.facing = (randi() % 4) as SpecialPiece.Facing
		var dir : Vector2i = ANT_DIRS[ant.facing]
		var fr : int = r + dir.y
		var fc : int = c + dir.x
		if fr < 0 or fr >= ROWS or fc < 0 or fc >= COLS \
				or grid[fr][fc] == null or grid[fr][fc] is OreChunk:
			# Starve: nothing edible ahead → die in place, leaving a hole.
			grid[r][c] = null
			doomed.append(ant)
			continue
		var prey : Variant = grid[fr][fc]
		doomed.append(prey)
		grid[r][c] = null
		ant.charges -= 1
		if ant.charges <= 0:
			grid[fr][fc] = null
			doomed.append(ant)
		else:
			grid[fr][fc] = ant
			moves.append([ant, _cell_pos(fr, fc)])
	# An ant that advanced this pass but was then eaten by a later ant is
	# in BOTH lists. Let "doomed" win (consume in place) and drop the
	# phantom slide, so it isn't tweened to a new cell while being freed.
	var doomed_ids : Dictionary = {}
	for n in doomed:
		if is_instance_valid(n):
			doomed_ids[n.get_instance_id()] = true
	var live_moves : Array = []
	for m in moves:
		if not doomed_ids.has(m[0].get_instance_id()):
			live_moves.append(m)
	var tw : Tween = create_tween().set_parallel(true)
	var animating : bool = false
	for n in doomed:
		if is_instance_valid(n):
			animating = true
			tw.tween_property(n, "scale", Vector2.ZERO, 0.12)
			tw.tween_property(n, "modulate:a", 0.0, 0.12)
	for m in live_moves:
		animating = true
		tw.tween_property(m[0], "position", m[1], 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not animating:
		tw.kill()
		return
	await tw.finished
	# Free each doomed node once (guard against any duplicate references).
	var freed : Dictionary = {}
	for n in doomed:
		if is_instance_valid(n) and not freed.has(n.get_instance_id()):
			freed[n.get_instance_id()] = true
			n.queue_free()


# --- Chunk spawning --------------------------------------------------

func _spawn_due() -> bool:

	return _moves_since_spawn >= SPAWN_EVERY_MOVES \
		and _chunks_spawned < CHUNK_TARGET \
		and _chunks_on_board().size() < MAX_CHUNKS_ON_BOARD


# Drop a new chunk in at the top: it takes the top rows of some columns
# (the rock there is pushed out) and rests on the rock below until the
# player digs beneath it. Returns null if the top is too congested to fit
# one right now (it will retry next move). The node is placed ABOVE the
# board so _animate_all_to_grid slides it in.
func _spawn_chunk() -> OreChunk:

	var size : int = _random_chunk_size()
	var w : int = OreChunk.SIZE_SPECS[size]["w"]
	var h : int = OreChunk.SIZE_SPECS[size]["h"]
	# Columns where the top h x w block holds no existing chunk.
	var candidates : Array = []
	for lc in range(0, COLS - w + 1):
		var ok : bool = true
		for dr in h:
			for dc in w:
				if grid[dr][lc + dc] is OreChunk:
					ok = false
					break
			if not ok:
				break
		if ok:
			candidates.append(lc)
	if candidates.is_empty():
		return null
	var left : int = candidates[randi() % candidates.size()]
	# Push out the rock currently in the footprint.
	for dr in h:
		for dc in w:
			# Footprint holds no chunk (candidate search guaranteed it), so
			# free whatever rock OR special tool is displaced.
			var existing : Variant = grid[dr][left + dc]
			if existing != null and is_instance_valid(existing):
				existing.queue_free()
			grid[dr][left + dc] = null
	var chunk : OreChunk = _make_chunk(size)
	chunk.top_row = 0
	chunk.left_col = left
	add_child(chunk)
	_set_chunk_cells(chunk)
	# Start above the board so it slides down into view.
	chunk.position = _cell_pos(-h, left)
	return chunk


func _random_chunk_size() -> int:

	var roll : float = randf()
	if roll < 0.58:
		return OreChunk.ChunkSize.NUGGET
	elif roll < 0.88:
		return OreChunk.ChunkSize.VEIN
	return OreChunk.ChunkSize.GEM_POCKET


func _make_chunk(size: int) -> OreChunk:

	var chunk : OreChunk = ORE_CHUNK_SCENE.instantiate()
	chunk.chunk_size = size as OreChunk.ChunkSize
	return chunk


# --- Refill ----------------------------------------------------------

# Fill the open sky (contiguous empty cells from the top) of each column
# with fresh rock. Empty pockets TRAPPED under a chunk are deliberately
# left empty — that is the "stuck chunk" situation a special would clear.
# Returns true if any tile was added.
func _refill_logical() -> bool:

	var added : bool = false
	for c in COLS:
		var top_filled : int = ROWS
		for r in ROWS:
			if grid[r][c] != null:
				top_filled = r
				break
		# rows [0, top_filled-1] are open sky → fill them
		for r in top_filled:
			var t : MiningRockTile = _make_tile(_random_kind())
			add_child(t)
			# Spawn stacked above the board so they slide in top-down.
			t.position = _cell_pos(r - top_filled, c)
			grid[r][c] = t
			added = true
	return added


# --- Animation -------------------------------------------------------

func _animate_cells_to_grid(cells: Array, time: float) -> void:

	var tw : Tween = create_tween().set_parallel(true)
	var moved : bool = false
	for cell in cells:
		var t : Variant = grid[cell.x][cell.y]
		if t == null:
			continue
		var target : Vector2 = _cell_pos(cell.x, cell.y)
		if not t.position.is_equal_approx(target):
			moved = true
			tw.tween_property(t, "position", target, time) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not moved:
		tw.kill()
		return
	await tw.finished


# Tween every tile + chunk to its grid home (skips bodies already in
# place). Used after gravity, refill and chunk entry.
func _animate_all_to_grid() -> void:

	var tw : Tween = create_tween().set_parallel(true)
	var moved : bool = false
	var seen_chunks : Dictionary = {}
	for r in ROWS:
		for c in COLS:
			var obj : Variant = grid[r][c]
			if obj == null:
				continue
			var target : Vector2
			if obj is OreChunk:
				var cid : int = obj.get_instance_id()
				if seen_chunks.has(cid):
					continue
				seen_chunks[cid] = true
				target = _cell_pos(obj.top_row, obj.left_col)
			else:
				target = _cell_pos(r, c)
			if not obj.position.is_equal_approx(target):
				moved = true
				var dist_rows : float = absf(target.y - obj.position.y) / CELL
				var dur : float = clampf(dist_rows * FALL_PER_ROW, FALL_MIN, FALL_MAX)
				tw.tween_property(obj, "position", target, dur) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not moved:
		tw.kill()
		return
	await tw.finished


func _animate_clear(cells: Array) -> void:

	var tw : Tween = create_tween().set_parallel(true)
	var doomed : Array = []
	for cell in cells:
		var t : Variant = grid[cell.x][cell.y]
		if t == null:
			continue
		doomed.append([cell, t])
		var centre : Vector2 = _cell_pos(cell.x, cell.y) + Vector2(CELL, CELL) * 0.5
		tw.tween_property(t, "scale", Vector2.ZERO, CLEAR_TIME)
		tw.tween_property(t, "modulate:a", 0.0, CLEAR_TIME)
		tw.tween_property(t, "position", centre, CLEAR_TIME)
	if doomed.is_empty():
		tw.kill()
		return
	await tw.finished
	for d in doomed:
		var cell : Vector2i = d[0]
		var t : Variant = d[1]
		grid[cell.x][cell.y] = null
		if is_instance_valid(t):
			t.queue_free()


func _animate_extract(chunks: Array) -> void:

	var tw : Tween = create_tween().set_parallel(true)
	for ch in chunks:
		tw.tween_property(ch, "scale", Vector2(1.25, 1.25), EXTRACT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(ch, "position", ch.position + Vector2(0.0, -CELL * 0.5), EXTRACT_TIME)
		tw.tween_property(ch, "modulate:a", 0.0, EXTRACT_TIME)
	await tw.finished
	for ch in chunks:
		if is_instance_valid(ch):
			ch.queue_free()


# --- Grid setup + helpers --------------------------------------------

func _init_grid() -> void:

	grid = []
	for r in ROWS:
		var row : Array = []
		for c in COLS:
			row.append(null)
		grid.append(row)
	for r in ROWS:
		for c in COLS:
			var kind : int = _random_kind_avoiding(r, c)
			var t : MiningRockTile = _make_tile(kind)
			t.position = _cell_pos(r, c)
			add_child(t)
			grid[r][c] = t


func _random_kind_avoiding(r: int, c: int) -> int:

	for _attempt in 12:
		var kind : int = _random_kind()
		var makes_h : bool = c >= 2 and _kind_at(r, c - 1) == kind and _kind_at(r, c - 2) == kind
		var makes_v : bool = r >= 2 and _kind_at(r - 1, c) == kind and _kind_at(r - 2, c) == kind
		if not makes_h and not makes_v:
			return kind
	return _random_kind()


func _random_kind() -> int:

	return randi() % KIND_COUNT


func _make_tile(kind: int) -> MiningRockTile:

	var t : MiningRockTile = ROCK_TILE_SCENE.instantiate()
	t.rock_kind = kind as MiningRockTile.RockKind
	return t


# Write a chunk reference into every cell of its footprint.
func _set_chunk_cells(chunk: OreChunk) -> void:

	for dr in chunk.height():
		for dc in chunk.width():
			grid[chunk.top_row + dr][chunk.left_col + dc] = chunk


# Clear a chunk reference out of every cell of its footprint.
func _clear_chunk_cells(chunk: OreChunk) -> void:

	for dr in chunk.height():
		for dc in chunk.width():
			grid[chunk.top_row + dr][chunk.left_col + dc] = null


# All distinct chunks currently on the board.
func _chunks_on_board() -> Array:

	var seen : Dictionary = {}
	var chunks : Array = []
	for r in ROWS:
		for c in COLS:
			var obj : Variant = grid[r][c]
			if obj is OreChunk and not seen.has(obj.get_instance_id()):
				seen[obj.get_instance_id()] = true
				chunks.append(obj)
	return chunks


func _end_session() -> void:

	if _session_over:
		return
	_session_over = true
	session_ended.emit(_ore_total, _chunks_extracted)


func _cell_pos(row: int, col: int) -> Vector2:

	return Vector2(col * CELL, row * CELL)

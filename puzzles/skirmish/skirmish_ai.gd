## Heuristic Tetris bot for every AI-controlled board (the duel opponent + the
## boarding's allies AND foes). PURE + static: given a grid snapshot + the active
## piece type, it returns the best {rot, px} placement via a 1-ply El-Tetris-style
## scan (aggregate height, holes, bumpiness, clearable lines — blockage-aware).
##
## Runs on the MAIN THREAD each piece — that's deliberate. [[puzzle-ai-threading]]
## requires a background Thread for HEAVY per-turn AI (deep minimax: poker,
## Gem Drop). This is a ≤40-placement single-ply scan with trivial arithmetic
## (sub-millisecond), so threading it would be pure ceremony with no hitch to
## avoid. If the bot ever gains real lookahead, move it onto a Thread then.
## See [[combat-puzzle-direction]].
class_name SkirmishAI
extends RefCounted


const COLS : int = SkirmishBoard.COLS
const ROWS : int = SkirmishBoard.TOTAL_ROWS

# El-Tetris-style feature weights (tuned for "competent, not perfect").
const W_AGG_HEIGHT : float = -0.51
const W_LINES : float = 0.76
const W_HOLES : float = -0.36
const W_BUMPINESS : float = -0.18

# --- Difficulty: skill-scaled imperfection (see [[combat-puzzle-direction]]) ---
# A weaker foe adds noise to each candidate's score so it often picks a worse
# spot. NOISE_MAX is on the order of the gap between good placements (the
# El-Tetris deltas run ~2-10), so at low skill it flips the choice often, at
# high skill it's negligible. TUNE in playtest. (The bigger weak-foe lever — an
# occasional fully-random "blunder" — lives in the duel, which knows the skill.)
const NOISE_MAX : float = 4.0
## Quadratic falloff keeps mid-tiers distinct + flattens the top end.
const NOISE_EXP : float = 2.0


## Best placement for [param piece_type] on [param grid] (rows of -1 / filled).
## [param skill] in [0,1] scales the AI's accuracy: 1.0 plays optimally; lower
## values add noise to each candidate's score so a weaker foe frequently picks
## a worse spot (leaves holes, stacks crookedly) — believable imperfection, not
## a rigged dummy. Returns {rot, px}; falls back to the spawn {rot:0, px:3} if
## nothing fits (a board so full the next piece tops out anyway).
static func best_placement(grid: Array, piece_type: int, skill: float = 1.0) -> Dictionary:

	if piece_type < 0 or piece_type >= SkirmishBoard.SHAPES.size():
		return {"rot": 0, "px": 3}
	var noise : float = NOISE_MAX * pow(1.0 - clampf(skill, 0.0, 1.0), NOISE_EXP)
	var best_score : float = -INF
	var best : Dictionary = {"rot": 0, "px": 3}
	for rot in 4:
		var cells : Array = SkirmishBoard.SHAPES[piece_type][rot]
		for px in range(-2, COLS + 1):
			var landing : int = _drop_y(grid, cells, px)
			if landing == _UNPLACEABLE:
				continue
			var sim : Array = _with_piece(grid, cells, px, landing)
			var score : float = _evaluate(sim)
			if noise > 0.0:
				score += randf_range(-noise, noise)
			if score > best_score:
				best_score = score
				best = {"rot": rot, "px": px}
	return best


## A uniformly-random VALID placement — the AI's "blunder" pick for a weak foe
## (the duel rolls for this on a fraction of pieces). Falls back to the spawn.
static func random_placement(grid: Array, piece_type: int) -> Dictionary:

	if piece_type < 0 or piece_type >= SkirmishBoard.SHAPES.size():
		return {"rot": 0, "px": 3}
	var options : Array = []
	for rot in 4:
		var cells : Array = SkirmishBoard.SHAPES[piece_type][rot]
		for px in range(-2, COLS + 1):
			if _drop_y(grid, cells, px) != _UNPLACEABLE:
				options.append({"rot": rot, "px": px})
	if options.is_empty():
		return {"rot": 0, "px": 3}
	return options[randi() % options.size()]


const _UNPLACEABLE : int = -9999


# Lowest py the piece (cells at origin px) can rest at, or _UNPLACEABLE if it
# can't sit at this column/rotation at all (off the sides, or the spawn area
# is already blocked here).
static func _drop_y(grid: Array, cells: Array, px: int) -> int:

	for cell in cells:
		var c : int = px + int(cell[0])
		if c < 0 or c >= COLS:
			return _UNPLACEABLE
	if _collides(grid, cells, px, 0):
		return _UNPLACEABLE
	var py : int = 0
	while not _collides(grid, cells, px, py + 1):
		py += 1
	return py


static func _collides(grid: Array, cells: Array, px: int, py: int) -> bool:

	for cell in cells:
		var c : int = px + int(cell[0])
		var r : int = py + int(cell[1])
		if c < 0 or c >= COLS or r >= ROWS:
			return true
		if r >= 0 and int(grid[r][c]) >= 0:
			return true
	return false


static func _with_piece(grid: Array, cells: Array, px: int, py: int) -> Array:

	var out : Array = []
	for row in grid:
		out.append(row.duplicate())
	for cell in cells:
		var c : int = px + int(cell[0])
		var r : int = py + int(cell[1])
		if r >= 0 and r < ROWS and c >= 0 and c < COLS:
			out[r][c] = 0  # value is irrelevant — evaluation only checks "filled"
	return out


static func _evaluate(grid: Array) -> float:

	var heights : Array = []
	heights.resize(COLS)
	for c in COLS:
		var h : int = 0
		for r in ROWS:
			if int(grid[r][c]) >= 0:
				h = ROWS - r
				break
		heights[c] = h

	var agg : int = 0
	for h in heights:
		agg += int(h)

	var holes : int = 0
	for c in COLS:
		var seen : bool = false
		for r in ROWS:
			if int(grid[r][c]) >= 0:
				seen = true
			elif seen:
				holes += 1

	var bump : int = 0
	for c in range(COLS - 1):
		bump += absi(int(heights[c]) - int(heights[c + 1]))

	# A row only scores as a clearable LINE if it's full AND free of un-decayed
	# blockage garbage (which the real board won't clear — see SkirmishBoard
	# _row_clearable). Without this the bot chases rows it can't actually complete
	# and buries itself behind its own garbage. Decayed garbage counts (it clears).
	var lines : int = 0
	for r in ROWS:
		var full : bool = true
		for c in COLS:
			var v : int = int(grid[r][c])
			if v < 0 or v == SkirmishBoard.GARBAGE_CELL:
				full = false
				break
		if full:
			lines += 1

	return (W_AGG_HEIGHT * float(agg) + W_LINES * float(lines)
		+ W_HOLES * float(holes) + W_BUMPINESS * float(bump))
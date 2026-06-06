## THE LOFT — the LIFT duty-station of the voyage. Mechanically a faithful reskin of YPP
## BILGING ([[bilging-research]] + [[loft-spec]]) — but the FICTION is OURS: this is the
## SKY, not the sea. The rock-ship is settling into THE STARDUST (the luminous drift the
## floating islands hang in); you SING breath-stones alight to clear deadweight and
## climb back aloft. (No water, no bilge — that's the YPP skin we replaced.)
##
## SLICE 1 (this build) — the core:
##   • a 2-WIDE horizontal CURSOR; click/space FREELY swaps the pair under it (any
##     swap is legal — no match required, no spring-back). Mouse or arrow keys move it.
##   • match 3+ same-hue in a row/column -> ignite + clear; DOWN gravity; cascades.
##   • refill from a seeded bag, NO spawn-matches (deterministic -> same seed, same round).
##   • COMBO SCORING = the lift + the skill ceiling: a cleared line of length L is worth
##     2L-3; a move that clears N lines AT ONCE banks (sum of line values) x N (the
##     combo). Cascade/chain steps after the swap score x1 (low) — so the skill is the
##     engineered ONE-MOVE combo, not luck.
##   • THE STARDUST is drawn rising from the floor = how far she's sunk: it creeps UP a little
##     each swap and is driven DOWN by each clear's lift, so its level reads your live
##     efficiency (TURN-PACED, no real-time clock — Troy's locked call).
##   • a MOVES-LIMITED round -> session_ended(total_lift); the scene records 'loft' mastery.
##
## Async-resolve like [MiningBoard]: every logical change is followed by an awaited tween
## ([[animate-everything-principle]]); input locked while resolving. Capture lift as a
## PRIMITIVE before freeing a stone ([[await-after-free-gotcha]]).
## LATER slices: the Stardust's BITE (sluggish-below + sink consequence), specials, voyage
## integration (footing seeds Skirmish).
class_name LoftBoard
extends Node2D


## Total lift banked this round (the score) — (total_lift).
signal lift_changed(total_lift: int)
## Swaps remaining this round — (remaining, total).
signal moves_changed(remaining: int, total: int)
## The Stardust's level (rows risen from the floor) changed — (level).
signal stardust_changed(level: float)
## A scored combo worth announcing — (name, lift_gained). For the banner.
signal combo_scored(combo_name: String, lift_gained: int)
## The round ended — (total_lift, sank). sank = the Stardust swallowed her (an early SUNK
## end), vs a normal moves-spent finish.
signal session_ended(total_lift: int, sank: bool)


## Board dims (tall + narrow) + pixel cell size.
const COLS : int = 6
const ROWS : int = 12
const CELL : float = 44.0   # MUST match LoftStone.SIZE
const HUE_COUNT : int = 5   # MUST match LoftStone.HUES.size()

## Swap budget per round (every swap is a move, hit or miss).
const MOVES_PER_ROUND : int = 30

## THE STARDUST's level, in ROWS risen from the floor. Starts a bit HIGH and you drive it
## DOWN; baseline 3 = "clear sky" (can't climb below). Each move applies ONE net change —
## a small ambient rise UP minus the pieces your clears lift DOWN — shown as a single
## smooth GLIDE (never the per-swap up-then-down jitter). So a regular match reads as
## downward progress; whiffs/weak moves let it creep up. (Lift/score is combo-weighted
## SEPARATELY — that's the skill ceiling; the Stardust is just "am I clearing enough".)
const STARDUST_BASELINE : float = 3.0
const STARDUST_START : float = 5.0
const STARDUST_RISE_PER_MOVE : float = 0.18
const STARDUST_LIFT_PER_PIECE : float = 0.16

## THE STARDUST'S BITE: above STARDUST_DANGER the ambient rise SURGES (×STARDUST_BITE_MULT)
## — the drift is gaining on you; let it reach SINK_LEVEL and the round ends EARLY, SUNK
## (less lift banked → worse voyage footing). You escape by clearing hard. Tunable.
const STARDUST_DANGER : float = 8.0
const STARDUST_BITE_MULT : float = 2.0
const SINK_LEVEL : float = 10.0
## In a VOYAGE the per-move rise is hole-scaled: RISE_BASE + HOLE_RISE_PER_HOLE × the ship's open
## holes (0 holes ⇒ barely creeps; a leaky hull floods fast). The Loft scene computes it from ship
## condition and pushes it in via [method set_effective_rise] — the board stays PlayerState-free.
const RISE_BASE : float = 0.06
const HOLE_RISE_PER_HOLE : float = 0.12
## Live per-move ambient rise — STARDUST_RISE_PER_MOVE when standalone, or the hole-scaled voyage
## value the Loft pushes in. Only mutated via [method set_effective_rise].
var _effective_rise_per_move : float = STARDUST_RISE_PER_MOVE
## True only while flying a FIGHT leg (set by the Loft via [method set_can_sink]) — lets the Stardust
## SINK the ship at SINK_LEVEL. Calm legs never sink, even at high Stardust.
var _can_sink : bool = false

## BALLAST (the bilging "crab" reskin): a heavy dross-stone that DRIFTS IN from the top
## and FALLS like any stone (Troy: it must budge down, not float) — but you can't SWAP or
## MATCH it. You clear BENEATH it to sink it DOWN into THE STARDUST — or let the Stardust
## rise to it — and it SLOUGHS (cleared "out of the Stardust") for a big LIFT bonus (∝ the
## Stardust's depth × how many at once), nudging it back. One drifts in every
## CRAB_SPAWN_EVERY clearing moves (via the refill), capped at CRAB_MAX on the board.
const CRAB_SPAWN_EVERY : int = 4
const CRAB_MAX : int = 3
const BALLAST_LIFT_BASE : float = 4.0   # bonus = round(BASE × stardust) × count
const BALLAST_STARDUST_RELIEF : float = 0.8  # rows the Stardust dips per ballast sloughed
const SLOUGH_TIME : float = 0.28

## Animation timing.
const SWAP_TIME : float = 0.12
const CLEAR_TIME : float = 0.16
const FALL_PER_ROW : float = 0.045
const FALL_MIN : float = 0.06
const FALL_MAX : float = 0.26
const MAX_CASCADE_DEPTH : int = 200

## Held-cursor movement (DAS) for the keyboard.
const DAS_DELAY : float = 0.16
const DAS_REPEAT : float = 0.05

## Styling.
const BACKING_COLOR : Color = Color(0.09, 0.11, 0.17, 1.0)
const GRID_LINE_COLOR : Color = Color(0.0, 0.0, 0.0, 0.26)
const FRAME_COLOR : Color = Color(0.50, 0.60, 0.82, 0.95)
const STARDUST_FILL : Color = Color(0.07, 0.05, 0.15, 0.62)
const STARDUST_LINE : Color = Color(0.52, 0.40, 0.82, 0.85)
const CURSOR_COLOR : Color = Color(0.98, 0.66, 0.24, 1.0)
## The Stardust's twinkling glitter layer (a canvas_item shader painted over the abyss fill).
const STARDUST_SHADER : Shader = preload("res://puzzles/loft/board/stardust_sparkle.gdshader")

const STONE_SCENE : PackedScene = preload("res://puzzles/loft/stone/stone.tscn")


## grid[row][col] = a LoftStone node, or null. The logical source of truth.
var grid : Array = []

var _resolving : bool = false
var _session_over : bool = false
## Hard input lock (independent of _resolving) — held while a voyage EVENT plays over the board (the
## boarding cry) so no stray swap sneaks in before the board is snapshotted.
var _input_locked : bool = false
## Bumped each time a fresh round begins (reset_round). An in-flight swap/cascade captures this at
## its start + bails after any await if it changed — so a stale leg's resolution can never corrupt
## the freshly re-dealt board (the [[await-after-free-gotcha]] guard, extended to mid-leg re-deals).
var _round_gen : int = 0
## VOYAGE (continuous) mode: the board is ONE unbroken session for the whole crossing — no per-leg
## swap cap, no moves-end, no sink-end (the chart's ARRIVAL ends it, the Stardust is just pressure).
## Standalone keeps the moves-limited round. Set by the Loft when it's flown AS a voyage.
var _voyage_mode : bool = false
var _total_lift : int = 0
var _moves_left : int = MOVES_PER_ROUND
## Running count of swaps made (the rate's denominator) — drives the duty rating in voyage mode,
## where there's no cap to count DOWN from.
var _swaps_made : int = 0
## Logical Stardust level; _stardust_display eases toward it (the smooth shown glide).
var _stardust : float = STARDUST_START
var _stardust_display : float = STARDUST_START
## Pieces cleared across the current move's whole cascade (applied to the Stardust once).
var _pieces_this_move : int = 0
## Ballast (crab) drift-in pacing: moves since the last one entered + a per-move guard so
## only ONE drifts in per spawn.
var _moves_since_crab : int = 0
var _crab_spawned_this_move : bool = false

## The LEFT cell of the 2-wide cursor (covers col, col+1). Vector2i(row, col).
var _cursor : Vector2i = Vector2i(0, 0)
var _move_dir : Vector2i = Vector2i.ZERO
var _das_timer : float = 0.0

var _overlay : LoftOverlay
var _stardust_fx : ColorRect   # the sparkle glitter riding over the Stardust fill (driven in paint_overlay)
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:

	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_rng.randomize()
	_init_grid()
	@warning_ignore("integer_division")
	var start_cursor : Vector2i = Vector2i(ROWS / 2, (COLS - 2) / 2)
	_cursor = start_cursor
	_overlay = LoftOverlay.new()
	_overlay.board = self
	_overlay.z_index = 50
	add_child(_overlay)
	# THE STARDUST SPARKLE — a twinkling glitter over the abyss (a canvas_item shader masked to below the
	# rise line via surface_y, tinted calm→danger). A child of the overlay so it rides at z=50 above the
	# stones + clips to the board; paint_overlay drives its uniforms.
	_stardust_fx = ColorRect.new()
	_stardust_fx.size = Vector2(float(COLS) * CELL, float(ROWS) * CELL)
	_stardust_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fx_mat : ShaderMaterial = ShaderMaterial.new()
	fx_mat.shader = STARDUST_SHADER
	_stardust_fx.material = fx_mat
	_overlay.add_child(_stardust_fx)
	queue_redraw()
	lift_changed.emit(_total_lift)
	moves_changed.emit(_moves_left, MOVES_PER_ROUND)
	stardust_changed.emit(_stardust)


func _draw() -> void:

	var w : float = COLS * CELL
	var h : float = ROWS * CELL
	draw_rect(Rect2(0.0, 0.0, w, h), BACKING_COLOR)
	for c in range(1, COLS):
		draw_line(Vector2(c * CELL, 0.0), Vector2(c * CELL, h), GRID_LINE_COLOR, 1.0)
	for r in range(1, ROWS):
		draw_line(Vector2(0.0, r * CELL), Vector2(w, r * CELL), GRID_LINE_COLOR, 1.0)
	draw_rect(Rect2(0.0, 0.0, w, h), FRAME_COLOR, false, 3.0)


# Painted by the z-lifted [LoftOverlay] so the Stardust + cursor sit ABOVE the stones.
func paint_overlay(ov: LoftOverlay) -> void:

	var w : float = COLS * CELL
	# The Stardust: the drift fills from the floor up to the (smoothly-glided) shown level.
	var top_y : float = (float(ROWS) - _stardust_display) * CELL
	# As it climbs from STARDUST_DANGER toward SINK_LEVEL, the Stardust reddens — the bite warning.
	var danger : float = clampf(
		(_stardust_display - STARDUST_DANGER) / maxf(0.5, SINK_LEVEL - STARDUST_DANGER), 0.0, 1.0)
	var fill_col : Color = STARDUST_FILL.lerp(Color(0.55, 0.06, 0.12, 0.66), danger)
	var line_col : Color = STARDUST_LINE.lerp(Color(1.0, 0.30, 0.30, 0.95), danger)
	ov.draw_rect(Rect2(0.0, top_y, w, float(ROWS) * CELL - top_y), fill_col, true)
	ov.draw_line(Vector2(0.0, top_y), Vector2(w, top_y), line_col, 2.0)
	# Drive the sparkle layer: mask it to below the rise line + tint it calm→danger.
	if _stardust_fx != null:
		var fxm : ShaderMaterial = _stardust_fx.material
		fxm.set_shader_parameter("surface_y", top_y / (float(ROWS) * CELL))
		fxm.set_shader_parameter("danger", danger)
	# The 2-wide swap cursor.
	if _is_cell(_cursor):
		var x : float = _cursor.y * CELL
		var y : float = _cursor.x * CELL
		ov.draw_rect(Rect2(x + 2.0, y + 2.0, CELL * 2.0 - 4.0, CELL - 4.0), CURSOR_COLOR, false, 3.0)


# --- Input (move the 2-wide cursor; swap the pair under it) -----------

func _unhandled_input(event: InputEvent) -> void:

	if _resolving or _session_over or _input_locked:
		return
	if event is InputEventMouseMotion:
		_set_cursor_from_mouse()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_do_swap()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_do_swap()


func _process(delta: float) -> void:

	# Ease the SHOWN Stardust toward its logical level (one move = one change, glided —
	# never a per-swap up/down jitter).
	if not is_equal_approx(_stardust_display, _stardust):
		_stardust_display = lerpf(_stardust_display, _stardust, clampf(delta * 9.0, 0.0, 1.0))
		if absf(_stardust_display - _stardust) < 0.004:
			_stardust_display = _stardust
		if _overlay != null:
			_overlay.queue_redraw()
	if _resolving or _session_over or _input_locked:
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
		_das_timer = DAS_DELAY
	else:
		_das_timer -= delta
		while _das_timer <= 0.0:
			_move_cursor(dir)
			_das_timer += DAS_REPEAT


func _set_cursor_from_mouse() -> void:

	var local : Vector2 = get_local_mouse_position()
	# Centre the 2-wide frame ON the cursor: snap its middle to the cell boundary
	# nearest the mouse, so you point AT the junction between the pair you'll swap.
	var col : int = clampi(roundi(local.x / CELL) - 1, 0, COLS - 2)
	var row : int = clampi(floori(local.y / CELL), 0, ROWS - 1)
	var next : Vector2i = Vector2i(row, col)
	if next != _cursor:
		_cursor = next
		_overlay.queue_redraw()


# dir is (col-delta, row-delta).
func _move_cursor(dir: Vector2i) -> void:

	_cursor.y = clampi(_cursor.y + dir.x, 0, COLS - 2)
	_cursor.x = clampi(_cursor.x + dir.y, 0, ROWS - 1)
	_overlay.queue_redraw()


# --- Swap + resolve --------------------------------------------------

func _do_swap() -> void:

	if _resolving or _session_over:
		return
	var a : Vector2i = _cursor                                # (row, col)
	var b : Vector2i = Vector2i(_cursor.x, _cursor.y + 1)     # (row, col+1)
	if grid[a.x][a.y] == null or grid[b.x][b.y] == null:
		return
	# A BALLAST is immovable — a swap touching one does nothing + costs NO move (not a whiff).
	if _is_ballast(grid[a.x][a.y]) or _is_ballast(grid[b.x][b.y]):
		return
	_resolving = true
	var gen : int = _round_gen   # if a fresh round (reset_round) begins mid-cascade, bail after awaits
	_swaps_made += 1
	if _voyage_mode:
		moves_changed.emit(_swaps_made, -1)   # continuous: report swaps MADE, no cap (total = -1)
	else:
		_moves_left -= 1
		moves_changed.emit(_moves_left, MOVES_PER_ROUND)
	_pieces_this_move = 0
	_moves_since_crab += 1
	_crab_spawned_this_move = false
	_swap_cells(a, b)
	await _animate_pair(a, b)
	if not is_inside_tree() or gen != _round_gen:
		return
	await _resolve_cascade(0, gen)
	if not is_inside_tree() or gen != _round_gen:
		return
	# ONE net Stardust change for the whole move — a small ambient rise UP minus what the
	# move's clears lifted DOWN — eased into view by _process (no per-swap jitter).
	# The Stardust's BITE: above the danger line the ambient rise SURGES (it's gaining on
	# you). Clears still pull it down — you escape only by clearing hard.
	var rise : float = _effective_rise_per_move
	if _stardust >= STARDUST_DANGER:
		rise *= STARDUST_BITE_MULT
	var net : float = rise - float(_pieces_this_move) * STARDUST_LIFT_PER_PIECE
	_stardust = clampf(_stardust + net, STARDUST_BASELINE, float(ROWS))
	stardust_changed.emit(_stardust)
	# If the Stardust just climbed to a lodged ballast, it sloughs into the Stardust — big lift +
	# the Stardust recedes (the rescue). Done BEFORE the sink check, so a ballast can save you.
	await _check_ballast_slough(gen)
	if not is_inside_tree() or gen != _round_gen:
		return
	_resolving = false
	# Voyage mode is CONTINUOUS — the chart's ARRIVAL ends the crossing, not moves or a sink (a high
	# Stardust just costs you rating + footing, never a hard restart). Standalone ends on sink/moves.
	if _voyage_mode:
		# Continuous crossing — ARRIVAL ends it, not moves. But on a FIGHT leg the Stardust CAN swallow
		# her: reaching SINK_LEVEL ends the session SUNK and the voyage handles the consequence (LOST IN
		# THE STARDUST). Calm legs never sink — _can_sink stays false there.
		if _can_sink and _stardust >= SINK_LEVEL:
			_end_session(true)
		return
	if _stardust >= SINK_LEVEL:
		_end_session(true)     # the Stardust swallowed her — SUNK, round over
	elif _moves_left <= 0:
		_end_session(false)


# Ignite matches, drop into the gaps, refill — repeat until stable. The FIRST clear
# (step 0) is the move's COMBO (multiplier = number of lines); cascade steps after
# are chains, scored x1 (low) — so combos, not luck, own the lift. [param start_step] > 0
# resolves everything as chains (used after a ballast slough — not an engineered combo).
func _resolve_cascade(start_step: int = 0, gen: int = -1) -> void:

	var step : int = start_step
	var depth : int = 0
	while is_inside_tree() and depth < MAX_CASCADE_DEPTH:
		if gen != -1 and gen != _round_gen:
			return   # a fresh round began mid-cascade — abandon this stale resolution
		depth += 1
		var lines : Array = _find_match_lines()
		if lines.is_empty():
			break
		var cleared : Array = _lines_cells(lines)
		# Lift (the SCORE) = the combo model: the swap's first clear scores
		# x(number of lines) — the combo; cascade/chain steps after score x1 (low).
		var base : int = 0
		for ln in lines:
			base += 2 * int(ln["length"]) - 3
		var mult : int = lines.size() if step == 0 else 1
		var lift : int = base * mult
		_total_lift += lift
		lift_changed.emit(_total_lift)
		# Tally pieces cleared — the whole move's total hits the Stardust ONCE afterward
		# (in _do_swap) so cascades count but never cause a mid-cascade Stardust jitter.
		_pieces_this_move += cleared.size()
		if step == 0:
			_announce_combo(lines, lift)
		await _animate_clear(cleared, gen)
		if not is_inside_tree() or (gen != -1 and gen != _round_gen):
			return
		if _settle_logical():
			await _animate_all_to_grid()
			if not is_inside_tree() or (gen != -1 and gen != _round_gen):
				return
		if _refill_logical():
			await _animate_all_to_grid()
			if not is_inside_tree() or (gen != -1 and gen != _round_gen):
				return
		step += 1


func _announce_combo(lines: Array, lift: int) -> void:

	var n : int = lines.size()
	var longest : int = 0
	for ln in lines:
		longest = maxi(longest, int(ln["length"]))
	var combo_name : String = ""
	if n == 1:
		if longest == 4:
			combo_name = "Good"
		elif longest >= 5:
			combo_name = "Great"
	elif n == 2:
		combo_name = "Yarrr!" if longest >= 5 else ("Har!" if longest >= 4 else "Arrr!")
	elif n == 3:
		combo_name = "Bingo!"
	else:
		combo_name = "Vegas!" if longest >= 5 else "Skylark!"
	if not combo_name.is_empty():
		combo_scored.emit(combo_name, lift)


# --- Ballast slough (the special's payoff) ---------------------------

# THE STARDUST reached one or more lodged ballasts → they slough into the Stardust. Award a LIFT
# bonus (∝ the Stardust's height × how many at once), drop the Stardust back (jettisoned weight =
# the rescue), then settle + resolve any matches the gaps opened (as chains). Capture the
# bonus/count as PRIMITIVES before freeing ([[await-after-free-gotcha]]).
func _check_ballast_slough(gen: int = -1) -> void:

	var doomed : Array = []
	for r in ROWS:
		for c in COLS:
			if _is_ballast(grid[r][c]) and _stardust >= float(ROWS - r):
				doomed.append(Vector2i(r, c))
	if doomed.is_empty():
		return
	var count : int = doomed.size()
	var bonus : int = roundi(BALLAST_LIFT_BASE * _stardust) * count
	_total_lift += bonus
	lift_changed.emit(_total_lift)
	combo_scored.emit("Ballast!", bonus)
	await _animate_slough(doomed)
	if not is_inside_tree() or (gen != -1 and gen != _round_gen):
		return
	for cell in doomed:
		var s : Variant = grid[cell.x][cell.y]
		if is_instance_valid(s):
			s.queue_free()
		grid[cell.x][cell.y] = null
	# Jettisoned weight = lift: the Stardust recedes (the push-your-luck rescue).
	_stardust = clampf(_stardust - BALLAST_STARDUST_RELIEF * float(count), STARDUST_BASELINE, float(ROWS))
	stardust_changed.emit(_stardust)
	if _settle_logical():
		await _animate_all_to_grid()
		if not is_inside_tree() or (gen != -1 and gen != _round_gen):
			return
	if _refill_logical():
		await _animate_all_to_grid()
		if not is_inside_tree() or (gen != -1 and gen != _round_gen):
			return
	await _resolve_cascade(1, gen)   # matches the freed gaps opened = chains (x1), not a combo


# Each freed ballast is JETTISONED — drops away through the board floor + fades into the
# Stardust (clipped by the board), so the slough is SEEN, never an instant pop.
func _animate_slough(cells: Array) -> void:

	var tw : Tween = create_tween().set_parallel(true)
	var any : bool = false
	for cell in cells:
		var s : Variant = grid[cell.x][cell.y]
		if s == null:
			continue
		any = true
		tw.tween_property(s, "position", s.position + Vector2(0.0, CELL * 3.0), SLOUGH_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(s, "modulate:a", 0.0, SLOUGH_TIME)
	if not any:
		tw.kill()
		return
	await tw.finished


# --- Match detection (as LINES, so combos can be counted + scored) ----

# Every maximal 3+ run (horizontal or vertical) as {cells, length}. An L/T counts as
# two lines (its horizontal run + its vertical run) — the "3x3" double.
func _find_match_lines() -> Array:

	var lines : Array = []
	for r in ROWS:
		var c : int = 0
		while c < COLS:
			var hue : int = _hue_at(r, c)
			var c2 : int = c
			if hue != -1:
				while c2 + 1 < COLS and _hue_at(r, c2 + 1) == hue:
					c2 += 1
			if hue != -1 and (c2 - c + 1) >= 3:
				var cells : Array = []
				for cc in range(c, c2 + 1):
					cells.append(Vector2i(r, cc))
				lines.append({"cells": cells, "length": c2 - c + 1})
			c = c2 + 1
	for c in COLS:
		var r : int = 0
		while r < ROWS:
			var hue : int = _hue_at(r, c)
			var r2 : int = r
			if hue != -1:
				while r2 + 1 < ROWS and _hue_at(r2 + 1, c) == hue:
					r2 += 1
			if hue != -1 and (r2 - r + 1) >= 3:
				var cells : Array = []
				for rr in range(r, r2 + 1):
					cells.append(Vector2i(rr, c))
				lines.append({"cells": cells, "length": r2 - r + 1})
			r = r2 + 1
	return lines


# Union of all line cells (the clear-set; L/T overlaps dedup here).
func _lines_cells(lines: Array) -> Array:

	var seen : Dictionary = {}
	for ln in lines:
		for cell in ln["cells"]:
			seen[cell] = true
	return seen.keys()


# --- Gravity + refill (DOWN) -----------------------------------------

func _settle_logical() -> bool:

	var moved : bool = false
	for c in COLS:
		var write_row : int = ROWS - 1
		for r in range(ROWS - 1, -1, -1):
			var s : Variant = grid[r][c]
			if s == null:
				continue
			# A BALLAST falls like any stone (it must budge down, never float) — it's only
			# special in that it can't be swapped or matched. So no anchor branch here.
			if r != write_row:
				grid[write_row][c] = s
				grid[r][c] = null
				moved = true
			write_row -= 1
	return moved


func _refill_logical() -> bool:

	var added : bool = false
	# Maybe one BALLAST (crab) drifts in from the top THIS refill (its own column's top cell).
	var crab_col : int = _choose_crab_column()
	for c in COLS:
		var empties : int = 0
		for r in ROWS:
			if grid[r][c] == null:
				empties += 1
			else:
				break
		for r in range(empties - 1, -1, -1):
			var s : LoftStone
			if c == crab_col and r == 0:
				s = _make_ballast()           # drifts in at the top, then falls + lodges
				_moves_since_crab = 0
				_crab_spawned_this_move = true
			else:
				s = _make_stone(_pick_refill_hue(r, c))
			add_child(s)
			s.position = _cell_pos(r - empties, c)   # stacked above, slides in
			grid[r][c] = s
			added = true
	return added


# Pick a column for a crab to drift into this refill (its top cell), or -1 for none: only
# once per move, only after the CRAB_SPAWN_EVERY gap, only under the on-board CRAB_MAX, and
# only a column whose top cell is empty (so the refill actually fills row 0 there).
func _choose_crab_column() -> int:

	if _crab_spawned_this_move or _moves_since_crab < CRAB_SPAWN_EVERY or _crab_count() >= CRAB_MAX:
		return -1
	var candidates : Array = []
	for c in COLS:
		if grid[0][c] == null:
			candidates.append(c)
	if candidates.is_empty():
		return -1
	return candidates[_rng.randi() % candidates.size()]


func _crab_count() -> int:

	var n : int = 0
	for r in ROWS:
		for c in COLS:
			if _is_ballast(grid[r][c]):
				n += 1
	return n


# A refill hue that does NOT complete a 3-run with the settled stones below/left of
# it — drawn from the seeded RNG (stays deterministic).
func _pick_refill_hue(r: int, c: int) -> int:

	for _attempt in 16:
		var hue : int = _rng.randi() % HUE_COUNT
		var down : bool = _hue_at(r + 1, c) == hue and _hue_at(r + 2, c) == hue
		var left : bool = _hue_at(r, c - 1) == hue and _hue_at(r, c - 2) == hue
		if not down and not left:
			return hue
	return _rng.randi() % HUE_COUNT


# --- Animation -------------------------------------------------------

func _animate_pair(a: Vector2i, b: Vector2i) -> void:

	var tw : Tween = create_tween().set_parallel(true)
	for cell in [a, b]:
		var s : Variant = grid[cell.x][cell.y]
		if s != null:
			tw.tween_property(s, "position", _cell_pos(cell.x, cell.y), SWAP_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


func _animate_clear(cells: Array, gen: int = -1) -> void:

	var tw : Tween = create_tween().set_parallel(true)
	var doomed : Array = []
	for cell in cells:
		var s : Variant = grid[cell.x][cell.y]
		if s == null:
			continue
		doomed.append([cell, s])
		_spawn_clear_burst(s)   # a shard puff as the gem shatters (borrow #5b) — pos read now, before free
		tw.tween_property(s, "scale", Vector2.ZERO, CLEAR_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(s, "modulate:a", 0.0, CLEAR_TIME)
	if doomed.is_empty():
		tw.kill()
		return
	await tw.finished
	# A fresh round began mid-clear → leave the re-dealt grid ALONE (reset_round already swept these
	# stones into its own out-tween + frees them; nulling here could wipe a freshly-dealt cell).
	if gen != -1 and gen != _round_gen:
		return
	for d in doomed:
		var cell : Vector2i = d[0]
		grid[cell.x][cell.y] = null
		if is_instance_valid(d[1]):
			d[1].queue_free()


## A shard puff where a stone clears (borrow #5b). The position is read NOW, synchronously, before the
## stone's clear-tween + free — never after an await (the await-after-free gotcha).
func _spawn_clear_burst(stone: LoftStone) -> void:

	if stone == null:
		return
	var b : ClearBurst = ClearBurst.make(LoftStone.HUES[stone.hue % LoftStone.HUES.size()], 9)
	b.position = stone.position
	add_child(b)


func _animate_all_to_grid() -> void:

	var tw : Tween = create_tween().set_parallel(true)
	var moved : bool = false
	for r in ROWS:
		for c in COLS:
			var s : Variant = grid[r][c]
			if s == null:
				continue
			var target : Vector2 = _cell_pos(r, c)
			if not s.position.is_equal_approx(target):
				moved = true
				var dist_rows : float = absf(target.y - s.position.y) / CELL
				var dur : float = clampf(dist_rows * FALL_PER_ROW, FALL_MIN, FALL_MAX)
				tw.tween_property(s, "position", target, dur) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not moved:
		tw.kill()
		return
	await tw.finished


# --- Grid setup + helpers --------------------------------------------

func _init_grid() -> void:

	_populate_grid(false)


# Build a fresh full board. [param from_above] stacks each new stone ABOVE its column (so a caller
# can tween them down for an animated deal); otherwise they're placed straight at their cells.
func _populate_grid(from_above: bool) -> void:

	grid = []
	for r in ROWS:
		var row : Array = []
		for c in COLS:
			row.append(null)
		grid.append(row)
	for c in COLS:
		for r in range(ROWS - 1, -1, -1):
			var s : LoftStone = _make_stone(_pick_refill_hue(r, c))
			s.position = _cell_pos(r, c) if not from_above else _cell_pos(r - ROWS, c)
			add_child(s)
			grid[r][c] = s


## Re-deal a FRESH round IN PLACE — the voyage's NEXT leg, WITHOUT a scene reload (so the chart
## keeps sailing + the HUD persists; no black between-leg flash). The old stones drop away and a
## new board falls in ([[animate-everything-principle]]); the Stardust resets to its start footing
## on the (briefly) empty board. All round state resets + the HUD signals re-emit. Bumps _round_gen
## so any in-flight swap from the prior leg bails. Safe to fire-and-forget (locks input itself).
func reset_round() -> void:

	_round_gen += 1          # invalidate any in-flight swap/cascade from the leg just finished
	_resolving = true
	_session_over = true     # lock input + session logic while the re-deal plays
	# Sweep the old stones away (drop through the floor + fade), then free them.
	var old : Array = []
	for r in ROWS:
		for c in COLS:
			if grid[r][c] != null:
				old.append(grid[r][c])
				grid[r][c] = null
	var leaving : Array = old.filter(func(s): return is_instance_valid(s))
	if not leaving.is_empty():
		var tw_out : Tween = create_tween().set_parallel(true)
		for s in leaving:
			tw_out.tween_property(s, "position", s.position + Vector2(0.0, CELL * float(ROWS)), 0.22) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw_out.tween_property(s, "modulate:a", 0.0, 0.22)
		await tw_out.finished
		if not is_inside_tree():
			return
		for s in leaving:
			if is_instance_valid(s):
				s.queue_free()
	# Reset round state on the now-empty board. Snap the Stardust to its start footing (a clean
	# slate — NOT an ease, which on a well-played leg would read backwards, the drift RISING the
	# instant you succeeded).
	_total_lift = 0
	_moves_left = MOVES_PER_ROUND
	_stardust = STARDUST_START
	_stardust_display = STARDUST_START
	_pieces_this_move = 0
	_moves_since_crab = 0
	_crab_spawned_this_move = false
	_move_dir = Vector2i.ZERO
	_das_timer = 0.0
	@warning_ignore("integer_division")
	_cursor = Vector2i(ROWS / 2, (COLS - 2) / 2)
	if _overlay != null:
		_overlay.queue_redraw()   # the cursor frame reads at centre for the whole deal (no end-jump)
	lift_changed.emit(_total_lift)
	moves_changed.emit(_moves_left, MOVES_PER_ROUND)
	stardust_changed.emit(_stardust)
	# Deal the new board, falling in from above.
	_rng.randomize()
	_populate_grid(true)
	await _animate_all_to_grid()
	if not is_inside_tree():
		return
	_session_over = false
	_resolving = false
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


# --- Voyage (continuous) mode: one unbroken session for the whole crossing -----------

## Flip the board into the voyage's CONTINUOUS mode (no swap cap / no moves-or-sink end — the chart
## drives leg ends + arrival). Re-emits the swap count in the no-cap form so the HUD reads right.
func set_voyage_mode(on: bool) -> void:

	_voyage_mode = on
	if on:
		moves_changed.emit(_swaps_made, -1)


## Push the hole-scaled per-move rise (the Loft computes it from ship condition; the board stays
## PlayerState-free). Composes UNDER the danger bite — a leaky hull in danger floods doubly fast.
func set_effective_rise(rise: float) -> void:

	_effective_rise_per_move = rise


## Seed the Stardust at embark from ship condition (a perfect hull starts at the baseline / aloft; a
## battered one higher). Snaps BOTH the logical level AND the eased display so the gauge doesn't drift
## from the old seed (mirrors reset_round's snap).
func set_stardust_start(level: float) -> void:

	_stardust = clampf(level, STARDUST_BASELINE, float(ROWS))
	_stardust_display = _stardust
	stardust_changed.emit(_stardust)


## Arm/disarm the SINK for this leg — the Loft sets it true only while flying a FIGHT leg (false on
## calm legs + once the fight's done), so calm stretches never sink even at high Stardust.
func set_can_sink(on: bool) -> void:

	_can_sink = on


## Hard-lock (or release) board input while a voyage event plays over it (the boarding cry).
func lock_input(on: bool) -> void:

	_input_locked = on


## Is a swap/cascade currently resolving? (The Loft waits for this to clear before snapshotting the
## board to carry across a boarding, so it captures a STABLE grid.)
func is_resolving() -> bool:

	return _resolving


## Snapshot the live board to a plain Dictionary so the SAME station can be restored after a boarding
## (the skirmish is a separate scene, so the node is freed — we rebuild from this). Cells: a hue 0..4,
## -1 = ballast, -2 = empty.
func serialize() -> Dictionary:

	var cells : Array = []
	for r in ROWS:
		var row : Array = []
		for c in COLS:
			var s : Variant = grid[r][c]
			if s == null:
				row.append(-2)
			elif _is_ballast(s):
				row.append(-1)
			else:
				row.append(int((s as LoftStone).hue))
		cells.append(row)
	return {
		"cells": cells,
		"stardust": _stardust,
		"lift": _total_lift,
		"swaps_made": _swaps_made,
		"moves_since_crab": _moves_since_crab,
	}


## Rebuild the board from a serialize() snapshot (continue the SAME station after a boarding) — clears
## the freshly-dealt grid, repopulates from the saved cells, restores lift/Stardust/swaps. Bumps
## _round_gen so any in-flight swap bails. No re-deal animation (it's a CONTINUATION, not a new round).
func restore(state: Dictionary) -> void:

	_round_gen += 1
	for r in ROWS:
		for c in COLS:
			if is_instance_valid(grid[r][c]):
				grid[r][c].queue_free()
	_populate_from(state.get("cells", []))
	# Defensive: a normal snapshot is gap-free, but if one ever caught a mid-cascade board, settle the
	# columns + snap the stones to rest so nothing floats (it's a continuation — no fall animation).
	if _settle_logical():
		for r in ROWS:
			for c in COLS:
				if grid[r][c] != null:
					grid[r][c].position = _cell_pos(r, c)
	_stardust = float(state.get("stardust", STARDUST_START))
	_stardust_display = _stardust
	_total_lift = int(state.get("lift", 0))
	_swaps_made = int(state.get("swaps_made", 0))
	_moves_since_crab = int(state.get("moves_since_crab", 0))
	_crab_spawned_this_move = false
	_pieces_this_move = 0
	_resolving = false
	_session_over = false
	_move_dir = Vector2i.ZERO
	_das_timer = 0.0
	@warning_ignore("integer_division")
	_cursor = Vector2i(ROWS / 2, (COLS - 2) / 2)
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()
	lift_changed.emit(_total_lift)
	stardust_changed.emit(_stardust)
	if _voyage_mode:
		moves_changed.emit(_swaps_made, -1)


# Build the grid from saved cell codes (hue 0..4 / -1 ballast / -2 empty), placing stones at rest.
func _populate_from(cells: Array) -> void:

	grid = []
	for r in ROWS:
		var row : Array = []
		for c in COLS:
			row.append(null)
		grid.append(row)
	for r in ROWS:
		for c in COLS:
			var code : int = -2
			if r < cells.size() and c < int((cells[r] as Array).size()):
				code = int(cells[r][c])
			if code == -2:
				continue
			var s : LoftStone = _make_ballast() if code == -1 else _make_stone(code)
			s.position = _cell_pos(r, c)
			add_child(s)
			grid[r][c] = s


func _make_stone(hue: int) -> LoftStone:

	var s : LoftStone = STONE_SCENE.instantiate()
	s.hue = hue
	return s


# A BALLAST dross-stone (the special). Same scene as a hue stone, flagged immovable.
func _make_ballast() -> LoftStone:

	var s : LoftStone = STONE_SCENE.instantiate()
	s.is_ballast = true
	return s


func _is_ballast(s: Variant) -> bool:

	return s != null and (s as LoftStone).is_ballast


func _hue_at(r: int, c: int) -> int:

	if r < 0 or r >= ROWS or c < 0 or c >= COLS:
		return -1
	var s : Variant = grid[r][c]
	if s == null:
		return -1
	# A ballast matches NO hue (it never joins/forms a run) — treated like a wall.
	if (s as LoftStone).is_ballast:
		return -1
	return s.hue


# Centre of cell (row, col) — stones are drawn centred on their origin.
func _cell_pos(row: int, col: int) -> Vector2:

	return Vector2(col * CELL + CELL * 0.5, row * CELL + CELL * 0.5)


func _is_cell(cell: Vector2i) -> bool:

	return cell.x >= 0 and cell.x < ROWS and cell.y >= 0 and cell.y < COLS


func _swap_cells(a: Vector2i, b: Vector2i) -> void:

	var tmp : Variant = grid[a.x][a.y]
	grid[a.x][a.y] = grid[b.x][b.y]
	grid[b.x][b.y] = tmp


func _end_session(sank: bool = false) -> void:

	if _session_over:
		return
	_session_over = true
	session_ended.emit(_total_lift, sank)

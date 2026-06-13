## Headless regression test for the mobile "board freezes right after a line clears"
## lockup (Troy 2026-06-13). The board is a pure _process-driven engine with no tree
## dependencies, so we drive it manually (call _ready + _process ourselves). Run:
##   Godot_v4.6.3_console.exe --headless --path <proj> --script res://puzzles/skirmish/test_skirmish_freeze.gd
extends SceneTree


func _initialize() -> void:

	var ok : bool = true
	var board : SkirmishBoard = SkirmishBoard.new()
	board._ready()   # grid init + initial _spawn (no tree needed)

	var rows : int = SkirmishBoard.ROWS
	var cols : int = SkirmishBoard.COLS

	# --- Test A: _step_down() with no active piece must be a NO-OP (never index
	# SHAPES[-1] -> the phantom L piece that re-locked mid-clear). ---
	board._piece = -1
	var before : String = _grid_signature(board, rows, cols)
	board._step_down()
	var after : String = _grid_signature(board, rows, cols)
	var a_ok : bool = (board._piece == -1) and (before == after)
	print("Test A (no SHAPES[-1] phantom on _piece<0): ", "PASS" if a_ok else "FAIL")
	ok = ok and a_ok

	# --- Test B: a fat frame that banks a 2nd soft-drop step onto a piece that
	# locks-and-RIPENS-garbage (the reveal beat, which returns from _lock WITHOUT
	# resetting _fall_t) must NOT re-enter _step_down() with _piece = -1. The OLD
	# unguarded loop did: it ran the phantom SHAPES[-1] (L) piece, which re-locked
	# mid-reveal — overwriting the just-locked cells with -1 AND spawning a fresh
	# piece DURING the reveal beat (the crossed _revealing/_piece state that froze).
	board._over = false
	board._clearing = false
	board._revealing = false
	board._topping_out = false
	board._falling_garbage = {}
	board._pending_attack = {}
	board._lines = 0
	for r in rows:
		for c in cols:
			board._grid[r][c] = -1
			board._garbage_age[r][c] = 0
	# A lone blockage cell up top, age 1 -> it RIPENS on the next lock (triggering the
	# reveal beat) but completes no row.
	board._grid[0][cols - 1] = SkirmishBoard.GARBAGE_CELL
	board._garbage_age[0][cols - 1] = 1
	# Active I piece resting on the floor at cols 0..3 (locks on the next step_down).
	board._piece = 0
	board._rot = 0
	board._px = 0
	board._py = rows - 2
	board._soft = true
	board._soft_lockout = false
	board._fall_t = 0.0

	# delta 0.1 >= 2 * SOFT_DROP_INTERVAL(0.03): iter 1 locks -> _age_garbage ripens
	# the blockage -> _revealing=true, _piece=-1, return (no _fall_t reset). _fall_t is
	# still >= interval, so the OLD loop runs iter 2 _step_down() with _piece=-1.
	board._process(0.1)

	# DISCRIMINATING: right after the fat frame, mid-reveal, there must be NO active
	# piece yet (the next spawn waits for the reveal to finish) and the I piece's
	# just-locked cells must be intact (the phantom would have stamped -1 over them).
	var mid_clean : bool = board._revealing and board._piece == -1 \
		and board._grid[rows - 1][0] == 0 and board._grid[rows - 1][1] == 0 \
		and board._grid[rows - 1][2] == 0 and board._grid[rows - 1][3] == 0

	# And it must still resolve to a normal playable state (no permanent freeze).
	var frozen : bool = true
	for _i in range(400):
		board._process(0.016)
		if (not board._clearing) and (not board._revealing) and board._piece >= 0 and not board._over:
			frozen = false
			break

	var b_ok : bool = mid_clean and (not frozen)
	print("Test B (no phantom re-entry on the reveal beat): ", "PASS" if b_ok else "FAIL",
		"  [mid_clean=", mid_clean, " frozen=", frozen,
		" revealing=", board._revealing, " piece=", board._piece, " over=", board._over, "]")
	ok = ok and b_ok

	# --- Test C: the post-spawn soft-drop lockout must AUTO-EXPIRE on touch (a held joystick-down sends no
	# release to clear it), so hold-to-soft-drop survives spawns — but stay release-only on desktop. ---
	# Clean active-piece state at the top (slow normal gravity won't lock it during the short pump).
	for r in rows:
		for c in cols:
			board._grid[r][c] = -1
	board._over = false
	board._clearing = false
	board._revealing = false
	board._topping_out = false
	board._piece = 0
	board._rot = 0
	board._px = 3
	board._py = 0
	board._soft = false

	# TOUCH: lockout set on a spawn -> auto-expires within the grace.
	board._is_touch = true
	board._soft_lockout = true
	board._soft_lockout_t = SkirmishBoard.SOFT_LOCKOUT_TOUCH_GRACE
	for _i in range(16):   # ~0.26s of frames, well past the 0.12s grace
		board._process(0.016)
	var touch_expired : bool = not board._soft_lockout

	# DESKTOP: same lockout must PERSIST (cleared only by a key release, not a timer).
	board._is_touch = false
	board._soft_lockout = true
	board._soft_lockout_t = SkirmishBoard.SOFT_LOCKOUT_TOUCH_GRACE
	for _i in range(16):
		board._process(0.016)
	var desktop_persists : bool = board._soft_lockout

	var c_ok : bool = touch_expired and desktop_persists
	print("Test C (soft-drop lockout: touch auto-expires, desktop persists): ", "PASS" if c_ok else "FAIL",
		"  [touch_expired=", touch_expired, " desktop_persists=", desktop_persists, "]")
	ok = ok and c_ok

	board.free()
	print("RESULT: ", "ALL PASS" if ok else "FAILURE")
	quit(0 if ok else 1)


func _grid_signature(board: SkirmishBoard, rows: int, cols: int) -> String:

	var s : String = ""
	for r in rows:
		for c in cols:
			s += str(board._grid[r][c]) + ","
	return s

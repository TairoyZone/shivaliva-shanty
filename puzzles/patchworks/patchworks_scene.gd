## THE PATCHWORKS — the playable hole-repair station (standalone), a BLOCK BLAST grid. Pick a block
## piece from the tray, rotate/flip it, drop it on the 8×8 hull grid (no overlap); fill a whole ROW or
## COLUMN and it BLASTS clear (a sealed strip). Endless; toss a piece that won't fit. Renders the grid
## + tray here and drives the logical [PatchworksBoard]. See [[patchworks-spec]].
extends PuzzleScene


const GRID_W : int = 8
const GRID_H : int = 8
const CELL : float = 50.0
const GRID_ORIGIN : Vector2 = Vector2(440.0, 92.0)   # top-left of the 8×8 grid
const TRAY_Y : float = 556.0
const TRAY_SLOT_W : float = 150.0
const TRAY_SLOT_H : float = 110.0
const TRAY_GAP : float = 24.0
const TRAY_CELL : float = 20.0
## Every this-many cleared lines seals ONE hull hole on the active ship — the Patchworks→condition
## coupling (playing it MENDS the ship). No-op standalone / on an undamaged hull. See [[ship-condition-research]].
const PATCHWORKS_LINES_PER_HOLE : int = 3

const COLOR_HULL : Color = Color(0.30, 0.21, 0.11, 1.0)
const COLOR_HULL_EDGE : Color = Color(0.16, 0.10, 0.04, 1.0)
const COLOR_BREACH : Color = Color(0.12, 0.10, 0.20, 1.0)            # an empty (Stardust-lit) cell
const COLOR_GRID_LINE : Color = Color(0.24, 0.20, 0.34, 0.7)
const COLOR_PATCH : Color = Color(0.66, 0.48, 0.28, 1.0)            # a planked cell
const COLOR_PATCH_EDGE : Color = Color(0.42, 0.29, 0.15, 1.0)
const COLOR_GHOST_OK : Color = Color(0.55, 0.95, 0.55, 0.6)
const COLOR_GHOST_BAD : Color = Color(0.95, 0.45, 0.40, 0.5)
const COLOR_FLASH : Color = Color(1.0, 0.95, 0.62, 1.0)
const COLOR_TRAY_SLOT : Color = Color(0.20, 0.14, 0.08, 0.94)
const COLOR_PIECE : Color = Color(0.80, 0.62, 0.37, 1.0)

@onready var _board : PatchworksBoard = $Board

var _active_index : int = -1
var _active_cells : Array = []
var _hover_cell : Vector2i = Vector2i.ZERO
var _flash_rows : Array = []
var _flash_cols : Array = []
var _flash_t : float = 0.0
var _flash_active : bool = false
var _lines_toward_seal : int = 0   # accumulates cleared lines; every PATCHWORKS_LINES_PER_HOLE seals a hull hole

var _score_label : Label
var _combo_label : Label
var _flash_label : Label


func _ready() -> void:

	super._ready()
	set_help_text("THE PATCHWORKS — plank the hull\n\n"
		+ "• Click a piece in the tray to pick it up (click it again, or click off the board, to put it back)\n"
		+ "• Mouse-wheel or X / C to rotate · F (or right-click the held piece) to flip\n"
		+ "• Click the grid to lay it down (green = fits, red = won't)\n"
		+ "• Fill a whole ROW or COLUMN → it BLASTS clear; clear on back-to-back moves for a combo\n"
		+ "• Right-click a tray piece (or Toss) to discard one — but a wasted piece costs points + your combo")
	_build_hud()
	_board.grid_changed.connect(_on_grid_changed)
	_board.tray_changed.connect(_on_tray_changed)
	_board.score_changed.connect(_on_score_changed)
	_board.lines_cleared.connect(_on_lines_cleared)
	_board.piece_tossed.connect(_on_piece_tossed)
	_board.start_session()
	if PlayerState.voyage_active:
		_add_voyage_chart()   # manning the Patchworks AS a voyage station → show the crossing context


func _process(_delta: float) -> void:

	if _flash_t > 0.0:
		_flash_active = true
		queue_redraw()
	elif _flash_active:
		# The fade just finished — clear the spent flash and force ONE last redraw so the highlight
		# doesn't linger painted on the board.
		_flash_active = false
		_flash_rows = []
		_flash_cols = []
		queue_redraw()


# --- HUD ---------------------------------------------------------------

func _build_hud() -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_make_label(layer, "The Patchworks", Vector2(40.0, 26.0), 30, Color(0.98, 0.86, 0.5), HORIZONTAL_ALIGNMENT_LEFT, 320.0)
	_score_label = _make_label(layer, "0", Vector2(960.0, 26.0), 28, Color(0.98, 0.9, 0.55), HORIZONTAL_ALIGNMENT_RIGHT, 280.0)
	_combo_label = _make_label(layer, "", Vector2(960.0, 64.0), 20, Color(0.78, 1.0, 0.68), HORIZONTAL_ALIGNMENT_RIGHT, 280.0)
	_flash_label = _make_label(layer, "", Vector2(440.0, 40.0), 44, Color(1.0, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 400.0)
	_flash_label.modulate.a = 0.0
	var toss : Button = Button.new()
	toss.text = "Toss piece"
	toss.position = Vector2(980.0, 556.0)
	toss.custom_minimum_size = Vector2(150.0, 44.0)
	toss.focus_mode = Control.FOCUS_NONE
	toss.add_theme_font_size_override("font_size", 18)
	toss.pressed.connect(_on_toss)
	layer.add_child(toss)


func _make_label(parent: Node, text: String, pos: Vector2, size: int, color: Color, align: HorizontalAlignment, width: float) -> Label:

	var l : Label = Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, 56.0)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l


# --- Rendering ---------------------------------------------------------

func _cell_rect(x: int, y: int) -> Rect2:

	return Rect2(GRID_ORIGIN + Vector2(float(x), float(y)) * CELL + Vector2(2.0, 2.0), Vector2(CELL - 4.0, CELL - 4.0))


func _draw() -> void:

	# Hull frame around the grid.
	var frame : Rect2 = Rect2(GRID_ORIGIN - Vector2(9.0, 9.0), Vector2(GRID_W * CELL + 18.0, GRID_H * CELL + 18.0))
	draw_rect(frame, COLOR_HULL, true)
	draw_rect(frame, COLOR_HULL_EDGE, false, 3.0)
	# Cells: empty = Stardust-lit breach; planked = wood patch.
	for y in GRID_H:
		for x in GRID_W:
			var r : Rect2 = _cell_rect(x, y)
			if _board.grid[y][x]:
				draw_rect(r, COLOR_PATCH, true)
				draw_rect(r, COLOR_PATCH_EDGE, false, 2.0)
			else:
				draw_rect(r, COLOR_BREACH, true)
				draw_rect(r, COLOR_GRID_LINE, false, 1.0)
	# The picked-up piece, ghosted at the hovered cell (green = fits, red = won't). Draw the WHOLE
	# piece even where it overhangs the grid — so you can always see what you're dragging, on or off
	# the board. (It reads red while any cell is off the board, since it won't place there.)
	if _active_index >= 0:
		var ok : bool = _board.can_place(_active_cells, _hover_cell)
		# TELEGRAPH: if dropping here would complete rows/columns, glow them gold so the incoming
		# BLAST is foreseen (same colour the clear flashes in). Only shown for a legal drop.
		if ok:
			var pv : Dictionary = _board.preview_clears(_active_cells, _hover_cell)
			var tg : Color = Color(COLOR_FLASH.r, COLOR_FLASH.g, COLOR_FLASH.b, 0.34)
			for ty in pv["rows"]:
				draw_rect(Rect2(GRID_ORIGIN + Vector2(0.0, float(ty) * CELL), Vector2(GRID_W * CELL, CELL)), tg, true)
			for tx in pv["cols"]:
				draw_rect(Rect2(GRID_ORIGIN + Vector2(float(tx) * CELL, 0.0), Vector2(CELL, GRID_H * CELL)), tg, true)
		var col : Color = COLOR_GHOST_OK if ok else COLOR_GHOST_BAD
		for c in _active_cells:
			var cell : Vector2i = c + _hover_cell
			draw_rect(_cell_rect(cell.x, cell.y), col, true)
	# Blast flash over the just-cleared rows / columns.
	if _flash_t > 0.0:
		var fc : Color = Color(COLOR_FLASH.r, COLOR_FLASH.g, COLOR_FLASH.b, _flash_t * 0.7)
		for y in _flash_rows:
			draw_rect(Rect2(GRID_ORIGIN + Vector2(0.0, float(y) * CELL), Vector2(GRID_W * CELL, CELL)), fc, true)
		for x in _flash_cols:
			draw_rect(Rect2(GRID_ORIGIN + Vector2(float(x) * CELL, 0.0), Vector2(CELL, GRID_H * CELL)), fc, true)
	_draw_tray()


func _draw_tray() -> void:

	for i in _board.tray.size():
		var slot : Rect2 = _tray_slot_rect(i)
		var picked : bool = i == _active_index
		draw_rect(slot, COLOR_TRAY_SLOT, true)
		draw_rect(slot, (Color(0.95, 0.8, 0.4) if picked else COLOR_HULL_EDGE), false, (3.0 if picked else 2.0))
		var cells : Array = _board.tray[i]["cells"]
		var mx : int = 0
		var my : int = 0
		for c in cells:
			mx = maxi(mx, c.x)
			my = maxi(my, c.y)
		var origin : Vector2 = slot.position + (slot.size - Vector2(float(mx + 1), float(my + 1)) * TRAY_CELL) * 0.5
		for c in cells:
			var r : Rect2 = Rect2(origin + Vector2(c) * TRAY_CELL + Vector2(1.0, 1.0), Vector2(TRAY_CELL - 2.0, TRAY_CELL - 2.0))
			draw_rect(r, (COLOR_PATCH if picked else COLOR_PIECE), true)
			draw_rect(r, COLOR_PATCH_EDGE, false, 1.5)


func _tray_slot_rect(i: int) -> Rect2:

	var count : int = _board.tray.size()
	var total : float = count * TRAY_SLOT_W + maxf(count - 1, 0) * TRAY_GAP
	var start_x : float = 640.0 - total * 0.5
	return Rect2(Vector2(start_x + i * (TRAY_SLOT_W + TRAY_GAP), TRAY_Y), Vector2(TRAY_SLOT_W, TRAY_SLOT_H))


# The hull frame (the playable board area) — a click inside it tries to place; a click outside it
# (and outside the tray) returns the held piece to the pile.
func _board_frame_rect() -> Rect2:

	return Rect2(GRID_ORIGIN - Vector2(9.0, 9.0), Vector2(GRID_W * CELL + 18.0, GRID_H * CELL + 18.0))


# --- Input -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:

	if _awaiting_dismiss:
		super._unhandled_input(event)
		return
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_on_left_click(event.position)
			MOUSE_BUTTON_RIGHT:
				_on_right_click(event.position)
			MOUSE_BUTTON_WHEEL_UP:
				_rotate_active(false)
			MOUSE_BUTTON_WHEEL_DOWN:
				_rotate_active(true)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X:
			_rotate_active(false)
		elif event.keycode == KEY_C:
			_rotate_active(true)
		elif event.keycode == KEY_F:
			_flip_active()
		elif event.keycode == KEY_T:
			_on_toss()


func _update_hover(mouse: Vector2) -> void:

	if _active_index < 0:
		return
	# Centre the held piece's bounding box on the cursor (so the cursor sits in the MIDDLE of the
	# piece, not at its top-left corner), sized to the piece.
	var cx : int = 0
	var cy : int = 0
	for c in _active_cells:
		cx = maxi(cx, c.x)
		cy = maxi(cy, c.y)
	_hover_cell = Vector2i(
		roundi((mouse.x - GRID_ORIGIN.x) / CELL - float(cx + 1) * 0.5),
		roundi((mouse.y - GRID_ORIGIN.y) / CELL - float(cy + 1) * 0.5))
	queue_redraw()


func _on_left_click(mouse: Vector2) -> void:

	# A tray slot: pick it up — or, if it's the piece you're already holding, put it back.
	for i in _board.tray.size():
		if _tray_slot_rect(i).has_point(mouse):
			if _active_index == i:
				_active_index = -1
				_active_cells = []
			else:
				_pick_up(i)
			queue_redraw()
			return
	if _active_index < 0:
		return
	if _board_frame_rect().has_point(mouse):
		# On the board → lay it down (an illegal spot just keeps it held so you can reposition).
		_update_hover(mouse)
		if _board.place(_active_index, _active_cells, _hover_cell):
			_active_index = -1
			_active_cells = []
	else:
		# Off the board (and off the tray) → return the piece to the pile, unchanged.
		_active_index = -1
		_active_cells = []
	queue_redraw()


func _on_right_click(mouse: Vector2) -> void:

	# Right-click a TRAY piece to discard it (no need to pick it up first); elsewhere, flip the held piece.
	for i in _board.tray.size():
		if _tray_slot_rect(i).has_point(mouse):
			_board.toss(i)
			if _active_index == i:
				_active_index = -1
				_active_cells = []
			queue_redraw()
			return
	_flip_active()


func _pick_up(i: int) -> void:

	_active_index = i
	_active_cells = (_board.tray[i]["cells"] as Array).duplicate()
	_update_hover(get_viewport().get_mouse_position())   # snap the ghost to the cursor, not the tray slot
	queue_redraw()


func _rotate_active(cw: bool) -> void:

	if _active_index < 0:
		return
	if cw:
		_active_cells = BlockShape.rotate_cw(_active_cells)
	else:
		# Counter-clockwise = three clockwise quarter-turns.
		_active_cells = BlockShape.rotate_cw(BlockShape.rotate_cw(BlockShape.rotate_cw(_active_cells)))
	queue_redraw()


func _flip_active() -> void:

	if _active_index < 0:
		return
	_active_cells = BlockShape.flip_h(_active_cells)
	queue_redraw()


func _on_toss() -> void:

	if _active_index < 0:
		return
	_board.toss(_active_index)
	_active_index = -1
	_active_cells = []
	queue_redraw()


# --- Board signals -----------------------------------------------------

func _on_grid_changed() -> void:

	queue_redraw()


func _on_tray_changed() -> void:

	queue_redraw()


func _on_score_changed(s: int) -> void:

	_score_label.text = str(s)


# Leaving the station → bank the run as Patchworks mastery (a rank-up narrates itself via the event
# feed). Holes were sealed live as you cleared lines. record_puzzle_result is high-water-mark, so the
# idempotent leave path is safe.
func _return_to_launching_scene() -> void:

	PlayerState.record_puzzle_result("patchworks", _board.score)
	super._return_to_launching_scene()


# Manning the Patchworks AS a voyage station → show the voyage CHART (bottom-left, HELD — patching
# doesn't sail the leg) so it reads as part of the crossing, like the Loft + the deck. See [[voyage-loop-research]].
func _add_voyage_chart() -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var chart : VoyageChart = VoyageChart.new()
	chart.place_at(layer, false)
	chart.refresh_from_state(false)


func _on_lines_cleared(rows: Array, cols: Array, combo: int) -> void:

	_flash_rows = rows
	_flash_cols = cols
	_flash_t = 1.0
	var n : int = rows.size() + cols.size()
	# Coupling: cleared lines MEND the active ship — every PATCHWORKS_LINES_PER_HOLE seals one hole
	# (close_hole no-ops + the feed stays quiet when there's no damaged ship, e.g. standalone play).
	_lines_toward_seal += n
	while _lines_toward_seal >= PATCHWORKS_LINES_PER_HOLE:
		_lines_toward_seal -= PATCHWORKS_LINES_PER_HOLE
		PlayerState.close_hole(1)
	_combo_label.text = ("Combo  x%d" % combo) if combo > 1 else ""
	if combo > 1:
		_flash_label.text = "Combo  x%d!" % combo
	elif n >= 3:
		_flash_label.text = "%d lines!" % n
	elif n == 2:
		_flash_label.text = "Double!"
	else:
		_flash_label.text = "Sealed!"
	_flash_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))   # gold for a good clear
	_flash_label.position.y = 40.0
	_flash_label.modulate.a = 1.0
	var tw : Tween = create_tween()
	tw.tween_property(self, "_flash_t", 0.0, 0.4)
	tw.parallel().tween_property(_flash_label, "modulate:a", 0.0, 0.85)


func _on_piece_tossed(penalty: int) -> void:

	_combo_label.text = ""   # the toss broke the combo
	_flash_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.42))   # red for a wasted piece
	_flash_label.text = ("Wasted  -%d" % penalty) if penalty > 0 else "Wasted"
	_flash_label.position.y = 498.0
	_flash_label.modulate.a = 1.0
	var tw : Tween = create_tween()
	tw.tween_property(_flash_label, "modulate:a", 0.0, 0.9)

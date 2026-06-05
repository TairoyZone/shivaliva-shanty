## THE PATCHWORKS engine — the ship's hole-repair station, a BLOCK BLAST grid. Drop rotatable block
## pieces from a 3-slot tray onto a square hull grid (no overlap, in-bounds); whenever a ROW or COLUMN
## fills it BLASTS clear (a sealed strip of hull) and scores, with a COMBO for clearing on consecutive
## moves and a bonus for clearing several lines at once. Endless — toss a piece that won't fit. Pure
## logic + signals; the scene renders + drives input via can_place / place / toss. See [[patchworks-spec]].
class_name PatchworksBoard
extends Node


## The grid changed (a piece landed or lines cleared) — the scene re-renders.
signal grid_changed()
## The tray contents changed — the scene re-renders the 3 piece slots.
signal tray_changed()
## A placement cleared full lines. `rows` / `cols` = the cleared indices; `combo` = the streak of
## consecutive clearing moves. The scene flashes those strips (the BLAST).
signal lines_cleared(rows: Array, cols: Array, combo: int)
signal score_changed(new_score: int)
## A piece was tossed (wasted). `penalty` = points actually lost — the scene flashes it.
signal piece_tossed(penalty: int)

const GRID_W : int = 8
const GRID_H : int = 8
const TRAY_SIZE : int = 3
## Points docked for tossing a piece (a wasted action) — on top of losing the combo streak. No timer
## anywhere; the stakes are the combo + this cost, not a clock.
const TOSS_PENALTY : int = 50

# --- State -------------------------------------------------------------
## grid[y][x] == true when that hull cell is planked.
var grid : Array = []
## The 3 ready pieces — each {"name": String, "cells": Array[Vector2i]} in canonical orientation. The
## scene rotates/flips a picked-up piece itself and passes the oriented cells back to [method place].
var tray : Array = []
var score : int = 0
## Streak of consecutive placements that each cleared at least one line (resets on a no-clear / toss).
var combo : int = 0
var lines_sealed : int = 0


func start_session() -> void:

	grid = []
	for y in GRID_H:
		var row : Array = []
		for x in GRID_W:
			row.append(false)
		grid.append(row)
	score = 0
	combo = 0
	lines_sealed = 0
	tray.clear()
	for i in TRAY_SIZE:
		tray.append(BlockShape.random_piece())
	tray_changed.emit()
	grid_changed.emit()


## Snapshot the board to carry across a boarding (the voyage-station restore). Transient (in-memory).
func serialize() -> Dictionary:

	return {"grid": grid.duplicate(true), "tray": tray.duplicate(true),
		"score": score, "combo": combo, "lines_sealed": lines_sealed}


## Rebuild from a [method serialize] snapshot after a boarding.
func restore(state: Dictionary) -> void:

	grid = (state.get("grid", []) as Array).duplicate(true)
	tray = (state.get("tray", []) as Array).duplicate(true)
	score = int(state.get("score", 0))
	combo = int(state.get("combo", 0))
	lines_sealed = int(state.get("lines_sealed", 0))
	grid_changed.emit()
	tray_changed.emit()
	score_changed.emit(score)


## Can `oriented_cells` (already rotated/flipped + normalized) drop at grid `offset` so every cell
## lands IN-BOUNDS on an empty hull cell (no spill off the grid, no overlap)?
func can_place(oriented_cells: Array, offset: Vector2i) -> bool:

	for c in oriented_cells:
		var t : Vector2i = c + offset
		if t.x < 0 or t.x >= GRID_W or t.y < 0 or t.y >= GRID_H:
			return false
		if grid[t.y][t.x]:
			return false
	return true


## Place tray[piece_index] as `oriented_cells` at `offset`. No-op + false if illegal. A successful
## place planks those cells, draws a fresh tray piece, then clears any full rows/columns.
func place(piece_index: int, oriented_cells: Array, offset: Vector2i) -> bool:

	if piece_index < 0 or piece_index >= tray.size():
		return false
	if not can_place(oriented_cells, offset):
		return false
	for c in oriented_cells:
		var t : Vector2i = c + offset
		grid[t.y][t.x] = true
	tray[piece_index] = BlockShape.random_piece()
	tray_changed.emit()
	_resolve_lines()
	grid_changed.emit()
	return true


## Swap a tray piece for a fresh one — the escape hatch when nothing fits. Breaks the combo streak.
func toss(piece_index: int) -> void:

	if piece_index < 0 or piece_index >= tray.size():
		return
	tray[piece_index] = BlockShape.random_piece()
	combo = 0
	# A wasted piece costs real points (clamped at 0) on top of the broken combo.
	var lost : int = mini(score, TOSS_PENALTY)
	if lost > 0:
		score -= lost
		score_changed.emit(score)
	piece_tossed.emit(lost)
	tray_changed.emit()


## Preview which rows + columns WOULD blast if `oriented_cells` were placed at `offset` (call only
## for a legal placement — i.e. when can_place is true). Returns {"rows": Array, "cols": Array}. The
## scene uses this to TELEGRAPH an incoming clear while the player hovers, before they commit.
func preview_clears(oriented_cells: Array, offset: Vector2i) -> Dictionary:

	var added : Dictionary = {}
	for c in oriented_cells:
		added[c + offset] = true
	var rows : Array = []
	for y in GRID_H:
		var full : bool = true
		for x in GRID_W:
			if not grid[y][x] and not added.has(Vector2i(x, y)):
				full = false
				break
		if full:
			rows.append(y)
	var cols : Array = []
	for x in GRID_W:
		var full : bool = true
		for y in GRID_H:
			if not grid[y][x] and not added.has(Vector2i(x, y)):
				full = false
				break
		if full:
			cols.append(x)
	return {"rows": rows, "cols": cols}


# --- Internals ---------------------------------------------------------

func _resolve_lines() -> void:

	var rows : Array = []
	for y in GRID_H:
		if _row_full(y):
			rows.append(y)
	var cols : Array = []
	for x in GRID_W:
		if _col_full(x):
			cols.append(x)
	var n : int = rows.size() + cols.size()
	if n == 0:
		combo = 0   # a placement that sealed nothing breaks the streak
		return
	for y in rows:
		for x in GRID_W:
			grid[y][x] = false
	for x in cols:
		for y in GRID_H:
			grid[y][x] = false
	combo += 1
	lines_sealed += n
	# Base per line × the combo streak, plus a bonus for clearing several lines at once.
	var gain : int = n * 80 * combo + maxi(n - 1, 0) * 120
	score += gain
	score_changed.emit(score)
	lines_cleared.emit(rows, cols, combo)


func _row_full(y: int) -> bool:

	for x in GRID_W:
		if not grid[y][x]:
			return false
	return true


func _col_full(x: int) -> bool:

	for y in GRID_H:
		if not grid[y][x]:
			return false
	return true

## DEV-ONLY: populate the Lumberjacking board with two fused groups (a 3x2 and a
## 2x2) plus edge/corner pieces, to verify (a) a fused group renders as ONE solid
## block and (b) the frame sits on top so pieces no longer bleed over it. Not shipped.
extends Node2D

const OUT : String = "user://shots"
const CELL : float = 36.0


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	var scene : Node = load("res://puzzles/lumberjacking/lumberjacking.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.5).timeout
	_hide_autoload_ui()

	var found : Array = scene.find_children("*", "LumberjackingBoard", true, false)
	var board : Node = found.front() if not found.is_empty() else null
	if board != null:
		var lp : PackedScene = load("res://puzzles/lumberjacking/log_piece/log_piece.tscn")
		# A 3x2 SUNPINE fusion (rows 10-11, cols 0-2) — also hugs the LEFT frame.
		_place_block(board, lp, 10, 0, 3, 2, 0)
		# A 2x2 CORALWOOD fusion (rows 11-12, cols 3-4).
		_place_block(board, lp, 11, 3, 2, 2, 1)
		# Loose edge/corner pieces to test frame bleed.
		_place(board, lp, 12, 5, 3)   # stormwood, bottom-right corner
		_place(board, lp, 9, 0, 2)    # mosswood, left edge
		_place(board, lp, 12, 2, 1)   # sunpine-adjacent filler
		board._detect_fusions()
		board.queue_redraw()
		if board._overlay != null:
			board._overlay.queue_redraw()
		await get_tree().create_timer(0.4).timeout

	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/lumber_fusion.png" % OUT)
	get_tree().quit()


func _place_block(board: Node, lp: PackedScene, row: int, col: int, w: int, h: int, kind: int) -> void:
	for dy in h:
		for dx in w:
			_place(board, lp, row + dy, col + dx, kind)


func _place(board: Node, lp: PackedScene, row: int, col: int, kind: int) -> void:
	var p : Node2D = lp.instantiate()
	p.wood_kind = kind
	p.variant = 0
	p.position = Vector2(float(col) * CELL, float(row) * CELL)
	board.add_child(p)
	board.grid[row][col] = p


func _hide_autoload_ui() -> void:
	for n in ["HUD", "Overlay", "EventFeed", "ChatBox", "UserPanel"]:
		var node : Node = get_node_or_null("/root/" + n)
		if node:
			_hide_subtree(node)

func _hide_subtree(node: Node) -> void:
	if node is CanvasItem or node is CanvasLayer:
		node.visible = false
	for c in node.get_children():
		_hide_subtree(c)

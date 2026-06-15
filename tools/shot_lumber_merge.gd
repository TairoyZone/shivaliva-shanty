## DEV-ONLY: deterministic proof of the plank-merge fix (Troy 2026-06-15).
## Loads the REAL LumberjackingBoard, injects a known same-kind layout, runs
## the real _detect_fusions, and screenshots. The JUNGLE zig-zag is the exact
## shape the old greedy-rectangle pass left SPLIT (Troy's "red tiles didn't
## merge" bug); every connected jungle cell must now read as one surface.
## Not shipped. Caller backs up the save.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	_hide_autoload_ui()

	# Forest backdrop so it reads like the live scene.
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var bd : Node2D = load("res://components/scenic_backdrop/scenic_backdrop.gd").new()
	bd.set("mode", "forest")
	layer.add_child(bd)

	var board_scene : PackedScene = load("res://puzzles/lumberjacking/board/board.tscn")
	var b : LumberjackingBoard = board_scene.instantiate() as LumberjackingBoard
	add_child(b)
	b.position = Vector2(532, 96)
	await get_tree().process_frame  # let _ready spawn the first pair + overlay

	# Freeze the live game loop and clear whatever spawned.
	b.set_process(false)
	b.set_physics_process(false)
	b.set_process_unhandled_input(false)
	for child in b.get_children():
		if child is LogPiece or child is Knot:
			child.queue_free()
	b.current_pair = {}
	b._init_grid()
	await get_tree().process_frame

	# Injected layout (row, col, WoodKind). JUNGLE(3) zig-zag = the bug repro;
	# OAK(0) 2x2 = clean merge; SPRUCE(2) single + BIRCH(1) 1x3 row = controls
	# that must STAY separate (no 2x2 → no merge).
	var J : int = 3
	var O : int = 0
	var S : int = 2
	var Bk : int = 1
	var layout : Array = [
		[8, 1, J], [8, 2, J],
		[9, 0, J], [9, 1, J], [9, 2, J],
		[10, 0, J], [10, 1, J],
		[8, 4, O], [8, 5, O], [9, 4, O], [9, 5, O],   # OAK 2x2
		[11, 3, S],                                    # lone SPRUCE
		[11, 0, Bk], [11, 1, Bk], [11, 2, Bk],         # BIRCH 1x3 (no 2x2)
	]
	var lp_scene : PackedScene = load("res://puzzles/lumberjacking/log_piece/log_piece.tscn")
	for cell in layout:
		var p : LogPiece = lp_scene.instantiate() as LogPiece
		p.wood_kind = cell[2]
		b.add_child(p)
		p.position = b._cell_world(Vector2i(cell[0], cell[1]))
		b.grid[cell[0]][cell[1]] = p

	b._detect_fusions()
	b.queue_redraw()
	if b._overlay:
		b._overlay.queue_redraw()

	_label("PLANK-MERGE PROOF", Vector2(60, 70), 26)
	_label("JUNGLE zig-zag = old bug shape -> now ALL 7 merge", Vector2(60, 110), 18)
	_label("OAK 2x2 merges - SPRUCE single + BIRCH 1x3 stay separate (no 2x2)", Vector2(60, 134), 18)

	await get_tree().create_timer(0.6).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/lumber_merge.png" % OUT)
	get_tree().quit()


func _label(text: String, pos: Vector2, sz: int) -> void:

	var l : Label = Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_font_size_override("font_size", sz)
	add_child(l)


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

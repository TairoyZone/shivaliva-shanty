## DEV-ONLY: populate a frozen SkirmishBoard with a varied stack + garbage + a
## bruise so the glossy-block / iron-garbage / arena-well glow-up can be verified.
## Not shipped. Caller backs up the save.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	_hide_autoload_ui()
	# Sky-battle backdrop (same as the duel scene) behind both boards.
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var bd : Node2D = load("res://components/scenic_backdrop/scenic_backdrop.gd").new()
	bd.set("mode", "sky_battle")
	layer.add_child(bd)

	# Opponent board at the duel's right position (plain, just its spawned piece).
	var opp : SkirmishBoard = SkirmishBoard.new()
	add_child(opp)
	opp.position = Vector2(675, 116)

	var board : SkirmishBoard = SkirmishBoard.new()
	add_child(board)
	board.position = Vector2(203, 116)   # the duel's player position
	await get_tree().process_frame   # _ready ran: grid + garbage_age init + first spawn
	for b in [board, opp]:
		b.set_process(false)
		b.set_physics_process(false)
		b.set_process_unhandled_input(false)

	var cols : int = SkirmishBoard.COLS
	# A believable varied stack in the bottom rows (gaps carved for realism).
	for r in range(12, 20):
		for c in range(cols):
			var keep : bool = ((c * 7 + r * 3) % 5) != 0
			if r >= 17:
				keep = ((c * 5 + r) % 7) != 0
			if keep:
				board._grid[r][c] = (c + r) % 7
	board._grid[12][3] = -1
	board._grid[12][4] = -1
	board._grid[13][6] = -1
	# Garbage blockages (ripening) + a sticky bruise (purple).
	board._grid[11][8] = SkirmishBoard.GARBAGE_CELL
	board._garbage_age[11][8] = 1
	board._grid[12][8] = SkirmishBoard.GARBAGE_CELL
	board._garbage_age[12][8] = 2
	board._grid[11][1] = SkirmishBoard.GARBAGE_CELL
	board._garbage_age[11][1] = SkirmishBoard.DECAY_MOVES + 2
	board._show_preview = true
	board.set_show_hold(true)
	board._hold = 5   # a J piece stashed in HOLD
	board.queue_redraw()

	await get_tree().create_timer(0.5).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/skirmish_look.png" % OUT)
	get_tree().quit()


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

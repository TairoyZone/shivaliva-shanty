## DEV-ONLY screenshot: captures (1) the full Gem Drop scene to verify the
## Stardust Well board / paddle / background repaint, and (2) a close-up coin
## gallery (human vs rival, resting vs falling-spin vs edge-on, plus a stack)
## to verify the new PROCEDURAL gem art. Windowed; caller backs up the save.
## Not shipped.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	visible = false
	call_deferred("_go")


func _go() -> void:

	# (1) The full Gem Drop scene.
	var scene : Node = load("res://puzzles/gem_drop/gem_drop.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.5).timeout
	# Drop a few coins so some settle cradled in the cupped pads, then warp the
	# mouse over an upper chute (col 7) to trigger the drop preview.
	var found : Array = scene.find_children("*", "GemDropBoard", true, false)
	var board : Node = found.front() if not found.is_empty() else null
	if board != null:
		for col in [5, 6, 8, 9]:
			board._spawn_coin_in_column(col, 0)
		await get_tree().create_timer(1.8).timeout
		# Force the hover preview on (warp_mouse won't register on an unfocused
		# window): freeze the board's _process so it can't reset _hover_col, then
		# drive the preview for col 7 directly.
		board.set_process(false)
		board._hover_col = 7
		board._update_ghost_coin()
		board.queue_redraw()
		await get_tree().create_timer(0.5).timeout
	_save_shot("gemdrop_scene.png")
	scene.queue_free()
	await get_tree().process_frame

	# (2) The coin gallery on a Stardust-void background.
	var gallery : Node2D = Node2D.new()
	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.12, 1.0)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	gallery.add_child(bg)
	# A brass swatch (paddle color) behind the right-hand human coins, to
	# verify the dark separation ring keeps a topaz coin readable on gold.
	var brass : ColorRect = ColorRect.new()
	brass.color = Color(0.78, 0.58, 0.24, 1.0)
	brass.position = Vector2(680, 130)
	brass.size = Vector2(360, 100)
	brass.z_index = -5
	gallery.add_child(brass)
	get_tree().root.add_child(gallery)
	get_tree().current_scene = gallery

	_add_header(gallery, "HUMAN (topaz)", Vector2(60, 150))
	_add_header(gallery, "RIVAL (ruby)", Vector2(60, 330))

	var gem_scene : PackedScene = load("res://puzzles/gem_drop/gem.tscn")
	# [owner, mode, phase, size, x, y]  mode: 0 = rest, 1 = falling-spin
	var specs : Array = [
		[0, 0, 0.0, 1, 280, 180],
		[0, 1, 0.0, 1, 430, 180],
		[0, 1, 0.9, 1, 580, 180],
		[0, 1, 1.45, 1, 730, 180],
		[0, 0, 0.0, 3, 900, 180],
		[1, 0, 0.0, 1, 280, 360],
		[1, 1, 0.0, 1, 430, 360],
		[1, 1, 0.9, 1, 580, 360],
		[1, 1, 1.45, 1, 730, 360],
		[1, 0, 0.0, 5, 900, 360],
	]
	for s in specs:
		var g : Node2D = gem_scene.instantiate()
		gallery.add_child(g)
		g.owner_player = int(s[0])
		g.size = int(s[3])
		g.position = Vector2(float(s[4]), float(s[5]))
		if int(s[1]) == 0:
			g.resting = true
		else:
			g.set("_spin_phase", float(s[2]))
			g.set_process(false)   # freeze this falling frame for the still
		g.queue_redraw()

	await get_tree().create_timer(0.4).timeout
	_save_shot("gem_gallery.png")
	await get_tree().process_frame
	get_tree().quit()


func _add_header(parent: Node2D, text: String, pos: Vector2) -> void:

	var l : Label = Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", Color(0.92, 0.86, 0.6))
	parent.add_child(l)


func _save_shot(shot_name: String) -> void:

	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [OUT, shot_name])

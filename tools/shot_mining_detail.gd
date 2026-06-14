## DEV-ONLY: a gallery of the redesigned Mining special tools (one framed to
## show its name label) + the three ore-chunk sizes + the gem tiles, to verify
## the refinement. Windowed; caller backs up the save. Not shipped.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.10, 1.0)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

	_label("SPECIAL TOOLS  (cursor-framed shows its name)", Vector2(60, 120))
	var sp_scene : PackedScene = load("res://puzzles/mining/special_piece/special_piece.tscn")
	for i in 5:
		var sp : Node2D = sp_scene.instantiate()
		add_child(sp)
		sp.special_kind = i
		sp.position = Vector2(190.0 + i * 150.0, 210.0) - Vector2(22.0, 22.0)
		if i == 2:
			sp.framed = true

	_label("ORE CHUNKS  (nugget  /  vein  /  gem pocket)", Vector2(60, 360))
	var oc_scene : PackedScene = load("res://puzzles/mining/ore_chunk/ore_chunk.tscn")
	var xs : Array = [180.0, 320.0, 540.0]
	for i in 3:
		var oc : Node2D = oc_scene.instantiate()
		add_child(oc)
		oc.chunk_size = i
		oc.position = Vector2(xs[i], 420.0)

	_label("GEM TILES", Vector2(60, 600))
	var t_scene : PackedScene = load("res://puzzles/mining/rock_tile/rock_tile.tscn")
	for i in 5:
		var t : Node2D = t_scene.instantiate()
		add_child(t)
		t.rock_kind = i
		t.position = Vector2(180.0 + i * 50.0, 632.0)

	await get_tree().create_timer(0.5).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/mining_detail.png" % OUT)
	await get_tree().process_frame
	get_tree().quit()


func _label(text: String, pos: Vector2) -> void:

	var l : Label = Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	l.add_theme_font_size_override("font_size", 18)
	add_child(l)

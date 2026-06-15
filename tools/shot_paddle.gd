## DEV-ONLY: a 3.2x close-up of the redesigned Gem Drop paddle (steel arm +
## cradle cup + bronze counterweight + screw-bolt pivot), rest-right / rest-left
## / mid-swing, with a coin nestled in the first cup. Not shipped.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	_hide_autoload_ui()
	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.09, 0.13, 0.19, 1.0)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

	var sw_scene : PackedScene = load("res://puzzles/gem_drop/switch.tscn")
	# [initial_pad_side, mid_swing]
	var specs : Array = [[1, false], [-1, false], [1, true]]
	var xs : Array = [300.0, 660.0, 1010.0]
	for i in 3:
		var sw : Node2D = sw_scene.instantiate()
		add_child(sw)
		sw.column_spacing = 36
		sw.col_left = 0
		sw.col_right = 1
		sw.initial_pad_side = int(specs[i][0])
		sw.position = Vector2(float(xs[i]), 380.0)
		sw.scale = Vector2(3.2, 3.2)
		if bool(specs[i][1]):
			sw.set("visual_pad_t", 0.0)
			sw.set_process(false)

	# A coin resting in the first (rest-right) cup, to prove it seats centred.
	var coin : Node2D = load("res://puzzles/gem_drop/gem.tscn").instantiate()
	add_child(coin)
	coin.owner_player = 0
	coin.resting = true
	coin.scale = Vector2(3.2, 3.2)
	coin.position = Vector2(300.0, 380.0) + Vector2(18.0, -12.0) * 3.2

	_add_label("rest (right)", Vector2(245, 520))
	_add_label("rest (left)", Vector2(610, 520))
	_add_label("mid-swing", Vector2(960, 520))

	await get_tree().create_timer(0.5).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/paddle_detail.png" % OUT)
	get_tree().quit()


func _add_label(text: String, pos: Vector2) -> void:

	var l : Label = Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	l.add_theme_font_size_override("font_size", 18)
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

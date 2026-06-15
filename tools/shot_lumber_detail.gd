## DEV-ONLY: a 3x gallery of the redesigned Lumberjacking pieces — the 4 wood
## kinds (solid), their breaker (axe) variants, and the knot decay states — to
## verify the wood pass. Windowed; caller backs up the save. Not shipped.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	_hide_autoload_ui()
	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.16, 0.11, 0.07, 1.0)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

	var lp : PackedScene = load("res://puzzles/lumberjacking/log_piece/log_piece.tscn")
	_label("PLANK KINDS  (oak / birch / spruce / jungle)", Vector2(60, 110))
	for i in 4:
		var p : Node2D = lp.instantiate()
		add_child(p)
		p.wood_kind = i
		p.variant = 0
		p.position = Vector2(210.0 + i * 150.0, 150.0)
		p.scale = Vector2(3.0, 3.0)

	_label("BREAKERS  (axe-stamped)", Vector2(60, 320))
	for i in 4:
		var p : Node2D = lp.instantiate()
		add_child(p)
		p.wood_kind = i
		p.variant = 1
		p.position = Vector2(210.0 + i * 150.0, 360.0)
		p.scale = Vector2(3.0, 3.0)

	_label("KNOT  (tough -> loosening -> dissolving)", Vector2(60, 530))
	var kn : PackedScene = load("res://puzzles/lumberjacking/knot/knot.tscn")
	for i in 3:
		var k : Node2D = kn.instantiate()
		add_child(k)
		k.state = i
		k.position = Vector2(210.0 + i * 150.0, 570.0)
		k.scale = Vector2(3.0, 3.0)

	await get_tree().create_timer(0.5).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/lumber_detail.png" % OUT)
	get_tree().quit()


func _label(text: String, pos: Vector2) -> void:

	var l : Label = Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", Color(0.88, 0.80, 0.62))
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

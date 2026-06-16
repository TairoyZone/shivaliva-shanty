## DEV-ONLY: render the profile trophy SHELF (a 3-col grid of TrophyCells) at the
## narrow tab width, to verify the 3-top / 2-bottom window layout. Not shipped.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	_hide_autoload_ui()
	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.10, 0.07, 0.05, 1.0)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# A cream card the width of the narrow tab popover (~400px), holding the shelf.
	var card : PanelContainer = PanelContainer.new()
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.20, 0.10, 0.96)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(440, 200)
	card.custom_minimum_size = Vector2(400, 0)
	add_child(card)

	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	var title : Label = Label.new()
	title.text = "Trophies   5"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	col.add_child(title)

	var shelf : VBoxContainer = VBoxContainer.new()
	shelf.add_theme_constant_override("separation", 10)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(shelf)
	var n : int = 0
	var row : HBoxContainer = null
	for t in Trophies.ALL:
		if n >= 5:
			break
		if n % 3 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			shelf.add_child(row)
		row.add_child(TrophyCell.make(t))
		n += 1

	var see_all : Label = Label.new()
	see_all.text = "▸ See all trophies"
	see_all.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	see_all.add_theme_font_size_override("font_size", 12)
	col.add_child(see_all)

	await get_tree().create_timer(0.4).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/trophies_grid.png" % OUT)
	get_tree().quit()


func _hide_autoload_ui() -> void:
	for nm in ["HUD", "Overlay", "EventFeed", "ChatBox", "UserPanel"]:
		var node : Node = get_node_or_null("/root/" + nm)
		if node:
			_hide_subtree(node)

func _hide_subtree(node: Node) -> void:
	if node is CanvasItem or node is CanvasLayer:
		node.visible = false
	for c in node.get_children():
		_hide_subtree(c)

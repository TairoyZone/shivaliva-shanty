## DEV-ONLY: verify the clock widget at "The Dead Of Night" (the longest phase) no longer bleeds the pill.
extends Node2D
const OUT := "user://shots"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	var scene : Node = load("res://levels/shore/shore.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	PlayerState.game_minutes = 30.0   # 12:30 AM -> phase "the dead of night"
	await get_tree().create_timer(1.2).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/clock_night_full.png" % OUT)
	# Crop the top-right corner (where the clock sits) + zoom 2x so the text reads clearly.
	var crop : Image = img.get_region(Rect2i(1280 - 260, 4, 256, 84))
	crop.resize(512, 168, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/clock_night.png" % OUT)
	get_tree().quit()

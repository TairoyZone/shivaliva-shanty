extends Node2D
const OUT := "user://shots"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	var scene : Node = load("res://levels/shore/shore.tscn").instantiate()
	get_tree().root.add_child(scene); get_tree().current_scene = scene
	PlayerState.grant_key(PlayerState.KEY_MINE)
	PlayerState.grant_key(PlayerState.KEY_GROVE)
	await get_tree().create_timer(1.0).timeout
	UserPanel.open("items")
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("%s/bag_trash.png" % OUT)
	get_tree().quit()

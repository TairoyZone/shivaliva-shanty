## DEV-ONLY: verify the Patchworks layout — title centred, Leave top-left, Chat bottom-left.
extends Node2D
const OUT := "user://shots"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	visible = false
	call_deferred("_go")
func _go() -> void:
	var scene : Node = load("res://puzzles/patchworks/patchworks_scene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(1.8).timeout
	get_viewport().get_texture().get_image().save_png("%s/patchworks_layout.png" % OUT)
	get_tree().quit()

## DEV-ONLY: capture the current look of each single-player puzzle so the
## aesthetic refinement pass can assess + verify them. Windowed; caller backs
## up the save. Not shipped.
extends Node2D

const OUT : String = "user://shots"
const SHOTS : Array = [
	["res://puzzles/loft/loft.tscn", "look_loft.png"],
	["res://puzzles/mining/mining.tscn", "look_mining.png"],
	["res://puzzles/lumberjacking/lumberjacking.tscn", "look_lumber.png"],
	["res://puzzles/patchworks/patchworks_scene.tscn", "look_patchworks.png"],
]


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	visible = false
	call_deferred("_go")


func _go() -> void:

	for entry in SHOTS:
		var scene : Node = load(entry[0]).instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(1.4).timeout
		_save(entry[1])
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _save(shot_name: String) -> void:

	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [OUT, shot_name])

extends Node2D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	call_deferred("_go")
func _go() -> void:
	PlayerState.player_power_type = ""   # no style -> everything locked
	var scene : Node = load("res://levels/shore/shore.tscn").instantiate()
	get_tree().root.add_child(scene); get_tree().current_scene = scene
	await get_tree().create_timer(0.6).timeout
	var modal : SkirmishChallengeModal = SkirmishChallengeModal.new()
	get_tree().root.add_child(modal)
	for i in 10: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://shots/ladder_locked.png")
	get_tree().quit()

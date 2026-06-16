extends Node2D
const OUT := "user://shots"
const SHOTS := [["res://levels/healers_hut_interior/healers_hut_interior.tscn", "look_gym.png", 0.8],
	["res://levels/shore/shore.tscn", "look_gym_building.png", 1.0]]
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	for s in SHOTS:
		var scene : Node = load(String(s[0])).instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		if String(s[0]).contains("shore"):
			PlayerState.game_minutes = 750.0
		await get_tree().create_timer(float(s[2])).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s" % [OUT, String(s[1])])
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit()

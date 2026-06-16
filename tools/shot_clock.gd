extends Node2D
const OUT := "user://shots"
const TIMES := [[460.0, "look_clock_day.png"], [30.0, "look_clock_night.png"]]
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	var scene : Node = load("res://levels/shore/shore.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.8).timeout
	for t in TIMES:
		PlayerState.game_minutes = float(t[0])
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s" % [OUT, String(t[1])])
	get_tree().quit()

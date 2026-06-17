## DEV-ONLY: render the PowerTypePicker (the gym master's intro fighting-style choice) over the gym.
extends Node2D
const OUT := "user://shots"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	var scene : Node = load("res://levels/cradle_gym_interior/cradle_gym_interior.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.5).timeout
	PlayerState.player_power_type = ""   # show the first-time intro framing
	var picker : PowerTypePicker = PowerTypePicker.new()
	get_tree().root.add_child(picker)
	# process_frame fires through the picker's tree-pause (a SceneTreeTimer may not) — wait a few frames then shoot.
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/power_pick.png" % OUT)
	get_tree().quit()

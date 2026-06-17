## DEV-ONLY: fire the one-time gym-master intro cinematic + capture (1) Ellison's dialogue and (2) the chained
## power-type picker.
extends Node2D
const OUT := "user://shots"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	PlayerState.gym_intro_seen = false
	PlayerState.player_power_type = ""
	var scene : Node = load("res://levels/cradle_gym_interior/cradle_gym_interior.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(1.4).timeout   # past the 0.5s settle delay; Ellison's first line is up
	get_viewport().get_texture().get_image().save_png("%s/gym_intro_dialog.png" % OUT)
	# Skip the dialogue to fire on_done -> the picker.
	if Overlay.is_active:
		Overlay._close()
	for i in 10:
		await get_tree().process_frame   # process_frame fires through the picker's tree-pause
	get_viewport().get_texture().get_image().save_png("%s/gym_intro_picker.png" % OUT)
	get_tree().quit()

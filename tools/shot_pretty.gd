## DEV-ONLY screenshot: loads the REAL poker scene + opens the chat Log to verify the felt now renders (it was
## hidden behind the opaque Background) and the parchment chat. Windowed; caller backs up the save. Not shipped.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	visible = false
	call_deferred("_go")


func _go() -> void:

	var poker : Node = load("res://puzzles/poker/poker_scene.tscn").instantiate()
	get_tree().root.add_child(poker)
	get_tree().current_scene = poker
	await get_tree().create_timer(1.2).timeout
	PlayerState.log_event("Flop: A♥ 3♦ K♠")
	PlayerState.log_event("Cinder Troy won 240 from the pot.")
	if ChatBox.has_method("_toggle_log"):
		ChatBox._toggle_log()
	await get_tree().create_timer(0.5).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/poker_felt.png" % OUT)
	await get_tree().process_frame
	get_tree().quit()

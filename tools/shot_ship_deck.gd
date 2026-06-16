## DEV-ONLY: capture the ship deck to verify the HUD reshuffle — the vessel/Duty-Report
## panel moved to the TOP-RIGHT (off the ☰), and the always-on gold purse is gone (it's
## in the Backpack now). Keeps the autoload HUD visible on purpose. Caller backs up the save.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	var scene : Node = load("res://levels/ship_deck/ship_deck.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(1.6).timeout   # let spawn / crew / UI build
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/look_ship_deck.png" % OUT)
	get_tree().quit()

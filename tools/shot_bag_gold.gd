## DEV-ONLY: open the Backpack tab to verify the GOLD readout moved into it (off the
## retired top-right HUD purse). Caller backs up the save (add_coins writes it).
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	# Load a real overworld location so the HUD is up + UserPanel will actually show its pane
	# (the bare-scene harness fails _should_show / gets folded on the startup scene-settle).
	var scene : Node = load("res://levels/shore/shore.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	PlayerState.add_coins(1234)   # so the Backpack shows a real total
	await get_tree().create_timer(1.0).timeout   # let the location + HUD settle past startup churn
	UserPanel.open("items")
	await get_tree().create_timer(0.5).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/look_bag.png" % OUT)
	get_tree().quit()

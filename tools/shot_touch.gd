## DEV-ONLY touch-layout shot harness (not shipped). Flips force_touch ON, loads each action puzzle, and saves a
## 1280x720 PNG to user://shots/ so we can eyeball the joystick + button placement for overlaps. Restores
## force_touch OFF at the end. The CALLER backs up + restores save.cfg/settings.cfg too (belt + suspenders).
extends Control

const OUT : String = "user://shots"
const TARGETS : Array = [
	["res://puzzles/mining/mining.tscn", "touch_mining"],
	["res://puzzles/skirmish/skirmish.tscn", "touch_skirmish"],
]


func _ready() -> void:

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	DirAccess.make_dir_recursive_absolute(OUT)
	TouchEnv.set_flag("force_touch", true)
	await get_tree().process_frame
	for t in TARGETS:
		var packed : PackedScene = load(String(t[0]))
		if packed == null:
			continue
		var scene : Node = packed.instantiate()
		add_child(scene)
		for _i in 8:
			await get_tree().process_frame
		await get_tree().create_timer(0.9).timeout
		var img : Image = get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [OUT, String(t[1])])
		scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	TouchEnv.set_flag("force_touch", false)
	get_tree().quit()

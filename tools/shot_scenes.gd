## DEV-ONLY marketing-shot harness (not shipped). Boots windowed, loads each gameplay scene one at a time,
## lets it settle, and saves a clean 1280x720 PNG to user://shots/. Skips any path that fails to load. The
## caller backs up + restores the real save.
extends Control

const OUT : String = "user://shots"
const TARGETS : Array = [
	["res://levels/shore/shore.tscn", "world_shore"],
	["res://levels/tavern/tavern.tscn", "world_tavern"],
	["res://levels/forge_interior/forge_interior.tscn", "world_forge"],
	["res://levels/cradle_gym_interior/cradle_gym_interior.tscn", "world_cradle_gym"],
	["res://puzzles/loft/loft.tscn", "play_loft"],
	["res://puzzles/lumberjacking/lumberjacking.tscn", "play_lumberjacking"],
	["res://puzzles/gem_drop/gem_drop.tscn", "play_gemdrop"],
	["res://puzzles/mining/mining.tscn", "play_mining"],
	["res://puzzles/patchworks/patchworks_scene.tscn", "play_patchworks"],
]


func _ready() -> void:

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	for t in TARGETS:
		var packed : PackedScene = load(String(t[0]))
		if packed == null:
			continue
		var scene : Node = packed.instantiate()
		add_child(scene)
		# let _ready, the player spawn, the camera, and any intro tween settle
		for _i in 4:
			await get_tree().process_frame
		await get_tree().create_timer(0.8).timeout
		var img : Image = get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [OUT, String(t[1])])
		scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit()

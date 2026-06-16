## DEV-ONLY: capture the shore at four times of day to verify the day/night cycle reads physically
## (world tint + day-sky/stars + sun/moon arc). Caller backs up the save (game_minutes persists).
extends Node2D

const OUT : String = "user://shots"
const TIMES : Array = [
	[750.0, "look_day_noon.png"],     # 12:30 — bright, blue sky, sun high
	[1110.0, "look_day_dusk.png"],    # 18:30 — warm sunset
	[30.0, "look_day_night.png"],     # 00:30 — deep blue, stardust + moon
	[390.0, "look_day_dawn.png"],     # 06:30 — cool sunrise
]


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
		var img : Image = get_viewport().get_texture().get_image()
		img.save_png("%s/%s" % [OUT, String(t[1])])
	get_tree().quit()

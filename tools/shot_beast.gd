extends Node2D
const OUT := "user://shots"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	PlayerState.skirmish_opponent = "res://puzzles/skirmish/beasts/beast_lion.tres"
	PlayerState.skirmish_stakes = true
	PlayerState.health = 20   # low health -> ~4 footing clumps bury the player board
	await get_tree().process_frame
	var duel : Node = load("res://puzzles/skirmish/skirmish_duel.tscn").instantiate()
	get_tree().root.add_child(duel)
	get_tree().current_scene = duel
	await get_tree().create_timer(1.1).timeout
	get_viewport().get_texture().get_image().save_png("%s/look_beast_lion.png" % OUT)
	var fails := 0
	if not duel._serious_fight: fails += 1; print("FAIL: _serious_fight not set")
	duel._end_duel(false)   # simulate a loss
	if PlayerState.health != 0: fails += 1; print("FAIL: loss didn't dock health (got %d)" % PlayerState.health)
	print("BEAST STAKES TEST: %s (%d fail)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()

extends Node2D
const OUT := "user://shots"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	var shore : Node = load("res://levels/shore/shore.tscn").instantiate()
	get_tree().root.add_child(shore); get_tree().current_scene = shore
	PlayerState.game_minutes = 800.0
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("%s/look_clock_tr.png" % OUT)
	shore.queue_free()
	await get_tree().process_frame
	var deck : Node = load("res://levels/ship_deck/ship_deck.tscn").instantiate()
	get_tree().root.add_child(deck); get_tree().current_scene = deck
	PlayerState.game_minutes = 800.0
	await get_tree().create_timer(1.4).timeout
	get_viewport().get_texture().get_image().save_png("%s/look_clock_deck.png" % OUT)
	get_tree().quit()

extends Node2D
const OUT := "user://shots"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	var scene : Node = load("res://levels/shore/shore.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	PlayerState.game_minutes = 750.0   # noon — brighten the world behind the panel
	PlayerState.add_affinity("Hearty Brian", 70)
	PlayerState.add_affinity("Stormy Jericho", 30)
	PlayerState.add_affinity("Spritely Mia", 10)
	PlayerState.add_affinity("Flint Kerr", -35)
	await get_tree().create_timer(1.0).timeout
	UserPanel.open("profile")
	await get_tree().create_timer(0.6).timeout
	var pv : Node = _find_profile(get_tree().root)
	if pv != null and pv.get_child_count() > 0 and pv.get_child(0) is ScrollContainer:
		(pv.get_child(0) as ScrollContainer).scroll_vertical = 720
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("%s/look_profile_hearties.png" % OUT)
	get_tree().quit()
func _find_profile(n: Node) -> Node:
	if n is ProfileView:
		return n
	for c in n.get_children():
		var r : Node = _find_profile(c)
		if r != null:
			return r
	return null

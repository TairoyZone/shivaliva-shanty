## DEV-ONLY: open the real ParlorBrowser create panel for poker + gem drop to verify the "free table"
## option is gone and a broke poker player is GATED (disabled Sit + note) rather than forced free.
## Caller backs up the save (add_coins writes it).
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	var scene : Node = load("res://levels/tavern/tavern.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.9).timeout

	_set_gold(5000)
	await _shoot("gem_drop", "look_parlor_gemdrop_cash.png")   # affordable: Sit enabled, "win +10 / lose 5"
	_set_gold(3)
	await _shoot("gem_drop", "look_parlor_gemdrop_broke.png")  # broke: Sit disabled + "need 5 gold" note
	get_tree().quit()


func _set_gold(target: int) -> void:

	var cur : int = PlayerState.total_coins
	if target != cur:
		PlayerState.add_coins(target - cur, "shot")


func _shoot(game_id: String, fname: String) -> void:

	get_tree().paused = false
	# Clear any browser left open by a prior shot (interact() parents it under the PROP, not root) and
	# reset every prop's open-guard so interact() rebuilds fresh against the CURRENT gold.
	var live : Array = []
	_collect_browsers(get_tree().root, live)
	for b in live:
		b.free()
	for p in get_tree().get_nodes_in_group(ParlorTable.GROUP_PARLOR):
		(p as ParlorTable)._browser = null
	await get_tree().process_frame

	var prop : ParlorTable = null
	for p in get_tree().get_nodes_in_group(ParlorTable.GROUP_PARLOR):
		if p is ParlorTable and (p as ParlorTable)._game_id() == game_id:
			prop = p
			break
	if prop == null:
		push_error("no parlor table for " + game_id)
		return
	prop.interact()
	await get_tree().create_timer(0.6).timeout
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [OUT, fname])


func _collect_browsers(n: Node, out: Array) -> void:

	for c in n.get_children():
		if c is ParlorBrowser:
			out.append(c)
		_collect_browsers(c, out)

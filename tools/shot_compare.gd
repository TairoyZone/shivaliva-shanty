## DEV-ONLY: capture a CLEAN initial board for Gem Drop + Mining (no internal
## poking, so it runs on both old and new code) for before/after marketing
## shots. Windowed; caller backs up the save. Not shipped.
extends Node2D

const OUT : String = "user://shots"
const SHOTS : Array = [
	["res://puzzles/gem_drop/gem_drop.tscn", "cmp_gemdrop.png"],
	["res://puzzles/mining/mining.tscn", "cmp_mining.png"],
]


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	for entry in SHOTS:
		var scene : Node = load(entry[0]).instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().process_frame
		_hide_autoload_ui()
		await get_tree().create_timer(1.5).timeout
		_hide_autoload_ui()   # re-hide in case an autoload re-showed itself
		var img : Image = get_viewport().get_texture().get_image()
		img.save_png("%s/%s" % [OUT, entry[1]])
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit()


# Hide the autoload UI subtrees (HUD / Overlay / EventFeed / Chat / Sunshine
# rail) so only the puzzle's OWN HUD remains. They may be CanvasLayers OR plain
# Controls, so hide every visible node under each, whatever its type.
func _hide_autoload_ui() -> void:
	for n in ["HUD", "Overlay", "EventFeed", "ChatBox", "UserPanel"]:
		var node : Node = get_node_or_null("/root/" + n)
		if node:
			_hide_subtree(node)

func _hide_subtree(node: Node) -> void:
	if node is CanvasItem or node is CanvasLayer:
		node.visible = false
	for c in node.get_children():
		_hide_subtree(c)

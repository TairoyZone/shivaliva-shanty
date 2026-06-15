## DEV-ONLY: verify the Patchworks TRASH CAN drop-target in both states (lid closed,
## and lid open while holding a piece over it). Not shipped. Caller backs up the save.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	var scene : Node = load("res://puzzles/patchworks/patchworks_scene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.6).timeout
	_hide_autoload_ui()
	await get_tree().process_frame

	# Closed (no held piece).
	_save("trash_closed.png")

	# Open: actually pick up a tray piece, then mark it hovering the can.
	scene._pick_up(0)
	scene._over_trash = true
	scene.queue_redraw()
	await get_tree().create_timer(0.3).timeout
	_save("trash_open.png")
	get_tree().quit()


func _save(shot_name: String) -> void:

	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [OUT, shot_name])


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

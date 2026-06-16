extends Node2D
const OUT := "user://shots"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")
func _go() -> void:
	PlayerState.jungle_ordeal_beats = []
	PlayerState.jungle_ordeal_pending = ""
	var scene : Node = load("res://levels/jungle_ordeal/jungle_ordeal.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.6).timeout
	if scene.player != null:
		var cam : Camera2D = scene.player.get_node_or_null("Camera2D")
		if cam != null: cam.zoom = Vector2(0.42, 0.42)
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("%s/look_jungle.png" % OUT)
	var gates : Array = []
	_find_gates(scene, gates)
	var fails := 0
	if gates.size() != 5: fails += 1; print("FAIL: expected 5 gates, got %d" % gates.size())
	PlayerState.jungle_ordeal_beats = []
	for b in ["lion","gorilla","rhino","bear"]: PlayerState.ordeal_mark_defeated(b)
	if not PlayerState.ordeal_minors_cleared(): fails += 1; print("FAIL: minors not cleared")
	if PlayerState.ordeal_complete(): fails += 1; print("FAIL: complete before king")
	PlayerState.ordeal_mark_defeated("king")
	if not PlayerState.ordeal_complete(): fails += 1; print("FAIL: not complete after king")
	PlayerState.jungle_ordeal_beats = []
	PlayerState.jungle_ordeal_pending = "lion"; PlayerState.last_skirmish_won = true
	scene._resolve_fight_return()
	if not PlayerState.ordeal_defeated("lion"): fails += 1; print("FAIL: return didn't mark lion")
	print("JUNGLE TEST: %s (%d fail)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()
func _find_gates(n: Node, out: Array) -> void:
	if n is BeastGate: out.append(n)
	for c in n.get_children(): _find_gates(c, out)

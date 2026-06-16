## DEV-ONLY: capture a proud, full-frame storefront shot of every one of the 7 puzzles in its REAL game
## scene (post visual-polish), with only the global overlay chrome (the Sunshine tab rail + Chat box) hidden
## so each puzzle's own board + HUD reads clean. Windowed (needs a real GPU); caller backs up the save.
## Not shipped. Output → user://shots/showcase/.
extends Node2D

const OUT : String = "user://shots/showcase"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	visible = false
	call_deferred("_go")


func _go() -> void:

	await _solo("res://puzzles/loft/loft.tscn", "01_loft.png", 2.4)
	await _solo("res://puzzles/mining/mining.tscn", "02_mining.png", 2.0)
	await _solo("res://puzzles/lumberjacking/lumberjacking.tscn", "03_lumberjacking.png", 2.6)
	await _solo("res://puzzles/patchworks/patchworks_scene.tscn", "04_patchworks.png", 2.0)
	await _skirmish("05_skirmish.png")
	await _gemdrop("06_gemdrop.png")
	await _poker("07_poker.png")
	get_tree().quit()


# A self-playing single-player puzzle: load, let it settle into a populated board, shoot.
func _solo(path: String, fn: String, settle: float) -> void:

	var scene : Node = load(path).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	_hide_chrome()
	await get_tree().create_timer(settle).timeout
	_hide_chrome()
	_save(fn)
	scene.queue_free()
	await get_tree().process_frame


# The real Skirmish DUEL vs Kerr (the swordsman) — both boards fill with stacks, the HUD shows the names.
func _skirmish(fn: String) -> void:

	PlayerState.skirmish_opponent = "res://components/npc/profiles/flint_kerr.tres"
	PlayerState.skirmish_stakes = false
	var scene : Node = load("res://puzzles/skirmish/skirmish_duel.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(2.8).timeout
	_hide_chrome()
	_save(fn)
	scene.queue_free()
	await get_tree().process_frame


# Gem Drop: drop a few coins so they cradle in the cupped paddles, then drive the hover drop-preview on a chute.
func _gemdrop(fn: String) -> void:

	var scene : Node = load("res://puzzles/gem_drop/gem_drop.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.5).timeout
	var found : Array = scene.find_children("*", "GemDropBoard", true, false)
	var board : Node = found.front() if not found.is_empty() else null
	if board != null:
		for col in [4, 5, 6, 8, 9]:
			board._spawn_coin_in_column(col, 0)
		await get_tree().create_timer(1.8).timeout
		board.set_process(false)
		board._hover_col = 7
		board._update_ghost_coin()
		board.queue_redraw()
		await get_tree().create_timer(0.4).timeout
	_hide_chrome()
	_save(fn)
	scene.queue_free()
	await get_tree().process_frame


# Poker: seat the human + the cast, deal, force a full community board → a lively table.
func _poker(fn: String) -> void:

	var scene : Node = load("res://puzzles/poker/poker_scene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.9).timeout
	_hide_chrome()
	scene._seat_human(0, 1000)
	var seats : int = scene._table_seats
	var k : int = 1
	for p in NpcRegistry.all():
		if k >= seats:
			break
		scene._seat_npc(k, p)
		k += 1
	scene._on_deal()
	await get_tree().create_timer(1.0).timeout
	if scene._board.deck != null:
		var comm : Array[Card] = scene._board.deck.deal(5)
		scene._community.set_cards(comm)
	await get_tree().create_timer(0.6).timeout
	_hide_chrome()
	_save(fn)
	scene.queue_free()
	await get_tree().process_frame


# Hide only the GLOBAL overlay chrome (tab rail, chat, dialog) — each puzzle keeps its own board + HUD.
func _hide_chrome() -> void:

	for n in ["UserPanel", "ChatBox", "Overlay", "EventFeed", "HUD"]:
		var node : Node = get_node_or_null("/root/" + n)
		if node:
			_hide_subtree(node)


func _hide_subtree(node: Node) -> void:

	if node is CanvasItem or node is CanvasLayer:
		node.visible = false
	for c in node.get_children():
		_hide_subtree(c)


func _save(fn: String) -> void:

	get_viewport().get_texture().get_image().save_png("%s/%s" % [OUT, fn])

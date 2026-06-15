## DEV-ONLY: seat a full table + deal + force a full community board, so the seat /
## hole-card / community geometry can be verified (the bottom cards must stay on-
## screen AND the seats' cards must not crowd the community). Not shipped.
extends Node2D

const OUT : String = "user://shots"


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	var scene : Node = load("res://puzzles/poker/poker_scene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.9).timeout   # _ready + _begin_seating
	_hide_autoload_ui()

	# Seat the human (bottom) + fill the rest of the ring with the cast, then deal.
	scene._seat_human(0, 1000)
	var seats : int = scene._table_seats
	var k : int = 1
	for p in NpcRegistry.all():
		if k >= seats:
			break
		scene._seat_npc(k, p)
		k += 1
	scene._on_deal()
	await get_tree().create_timer(1.0).timeout   # hole-card deal animation

	# Force a full 5-card community board so the overlap with the seats' cards is visible.
	if scene._board.deck != null:
		var comm : Array[Card] = scene._board.deck.deal(5)
		scene._community.set_cards(comm)
	# Spawn chat bubbles to verify they sit just above each panel (not way overhead).
	if scene._seats.size() > 4:
		SpeechBubble.say(scene._seats[2], "I'll see your bet, friend.")
		SpeechBubble.say(scene._seats[4], "Bold move, hand.")
	await get_tree().create_timer(0.5).timeout

	var img : Image = get_viewport().get_texture().get_image()
	var bub : Image = img.get_region(Rect2i(20, 70, 420, 300))
	bub.resize(840, 600, Image.INTERPOLATE_NEAREST)
	bub.save_png("%s/poker_bubble.png" % OUT)
	img.save_png("%s/poker_dealt.png" % OUT)
	# Zoomed crops (2x) so the bottom margin + the centre overlap read clearly.
	var bottom : Image = img.get_region(Rect2i(430, 470, 420, 250))
	bottom.resize(840, 500, Image.INTERPOLATE_NEAREST)
	bottom.save_png("%s/poker_bottom.png" % OUT)
	var centre : Image = img.get_region(Rect2i(360, 150, 560, 280))
	centre.resize(1120, 560, Image.INTERPOLATE_NEAREST)
	centre.save_png("%s/poker_center.png" % OUT)
	get_tree().quit()


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

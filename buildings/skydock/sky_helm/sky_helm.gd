## SkyHelm — the ship's wheel at the Skydock where the player launches a voyage.
## Jobbing-first ([[voyage-loop-research]] / [[pillage-research]]): interacting opens
## the [VoyagesBoard] notice board — browse AI pillaging crews, apply, accept the
## jobbing invite, and board that crew's walkable [ShipDeck]. (Captaining your own
## ship is later depth — both run the same loop for now.)
@tool
class_name SkyHelm
extends Interactable


# --- Visual placeholder (a ship's wheel on a short post) -------------
const WHEEL_RADIUS : float = 30.0
const POST_HEIGHT : float = 40.0

const COLOR_WOOD : Color = Color(0.52, 0.34, 0.16, 1.0)
const COLOR_WOOD_DARK : Color = Color(0.30, 0.18, 0.08, 1.0)
const COLOR_BRASS : Color = Color(0.82, 0.66, 0.30, 1.0)


func interact() -> void:

	if Engine.is_editor_hint():
		return
	var tree : SceneTree = get_tree()
	# Remember where to drop the player when they disembark ("sail home").
	if tree.current_scene != null:
		PlayerState.voyage_home_scene = tree.current_scene.scene_file_path
	# Open the Voyages notice board — apply, accept the jobbing invite, then board.
	# (Boarding + pillage_phase are handled by the board on Accept.)
	var board : VoyagesBoard = VoyagesBoard.new()
	if tree.current_scene != null:
		tree.current_scene.add_child(board)
	else:
		tree.root.add_child(board)


func set_tooltip_visible(value: bool) -> void:

	if Engine.is_editor_hint():
		return
	if value:
		_refresh_tooltip_text()
	_tooltip.visible = value


func _refresh_tooltip_text() -> void:

	if not PlayerState.has_ship():
		_tooltip.text = "Sign onto a crew — job a pillage   [E]"
		_tooltip.modulate = Color(0.78, 1.0, 0.62, 1.0)
		return
	_tooltip.text = "Set sail — captain your own voyage   [E]"
	_tooltip.modulate = Color(0.78, 1.0, 0.62, 1.0)


func _draw() -> void:

	# Post.
	var post : Rect2 = Rect2(-4.0, -POST_HEIGHT, 8.0, POST_HEIGHT)
	draw_rect(post, COLOR_WOOD)
	draw_rect(post, COLOR_WOOD_DARK, false, 1.2)
	# Wheel centered above the post.
	var c : Vector2 = Vector2(0.0, -POST_HEIGHT - WHEEL_RADIUS * 0.5)
	draw_arc(c, WHEEL_RADIUS, 0.0, TAU, 32, COLOR_WOOD, 6.0)
	draw_arc(c, WHEEL_RADIUS, 0.0, TAU, 32, COLOR_WOOD_DARK, 1.4)
	draw_circle(c, WHEEL_RADIUS * 0.26, COLOR_BRASS)
	draw_circle(c, WHEEL_RADIUS * 0.14, COLOR_WOOD_DARK)
	# Spokes + handles.
	for i in 8:
		var a : float = TAU * i / 8.0
		var dir : Vector2 = Vector2(cos(a), sin(a))
		draw_line(c + dir * (WHEEL_RADIUS * 0.24), c + dir * (WHEEL_RADIUS * 1.18),
			COLOR_WOOD, 3.0)
		draw_circle(c + dir * (WHEEL_RADIUS * 1.18), 2.6, COLOR_BRASS)
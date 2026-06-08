## THE MOORED SHIP — your OWNED vessel, berthed at the Skydock. Walk up + Board her to set sail on a
## SELF-CAPTAINED voyage (PlayerState.captain_own_voyage → the ship deck, holding at the dock). Only PRESENT
## once you own a ship (appears when you buy one); the tooltip + drawn breaches report her live hull state.
## The literal "mount your own ship". @tool Interactable. Built 2026-06-09. See [[voyage-loop-research]].
@tool
class_name MooredShip
extends Interactable


const COLOR_HULL : Color = Color(0.42, 0.27, 0.14, 1.0)
const COLOR_HULL_DARK : Color = Color(0.26, 0.16, 0.08, 1.0)
const COLOR_TRIM : Color = Color(0.82, 0.66, 0.32, 1.0)
const COLOR_MAST : Color = Color(0.34, 0.22, 0.12, 1.0)
const COLOR_SAIL : Color = Color(0.92, 0.89, 0.80, 1.0)
const COLOR_SAIL_SHADE : Color = Color(0.76, 0.72, 0.62, 1.0)
const COLOR_BREACH : Color = Color(0.08, 0.07, 0.15, 1.0)

## Visual size of the moored ship (tune in the inspector). The interaction range is SEPARATE (the Area2D shape).
@export var ship_scale : float = 1.8:
	set(value):
		ship_scale = value
		queue_redraw()


func _ready() -> void:

	super()
	if Engine.is_editor_hint():
		return
	_update_presence()
	if not PlayerState.ships_changed.is_connected(_update_presence):
		PlayerState.ships_changed.connect(_update_presence)


# She only exists at the berth once she's YOURS — appears the moment you buy a ship.
func _update_presence() -> void:

	var owned : bool = PlayerState.has_ship()
	visible = owned
	monitorable = owned   # the player's interaction zone only detects her once she's yours
	queue_redraw()


func interact() -> void:

	if Engine.is_editor_hint():
		return
	if not PlayerState.has_ship():
		return
	var tree : SceneTree = get_tree()
	if tree.current_scene != null:
		PlayerState.voyage_home_scene = tree.current_scene.scene_file_path   # where to step off when you disembark
	var scene : String = PlayerState.captain_own_voyage()
	if scene.is_empty():
		return
	tree.change_scene_to_file(scene)


func set_tooltip_visible(value: bool) -> void:

	if Engine.is_editor_hint():
		return
	if value:
		_refresh_tooltip_text()
	_tooltip.visible = value


func _refresh_tooltip_text() -> void:

	if _tooltip == null:
		return
	var holes : int = PlayerState.ship_open_holes()
	var cond : String = "she's sound" if holes <= 0 else ("%d hole%s open" % [holes, "" if holes == 1 else "s"])
	_tooltip.text = "Board the %s — set sail (%s)   [Click]" % [PlayerState.active_ship_name(), cond]
	_tooltip.modulate = Color(0.78, 1.0, 0.62, 1.0)


func _draw() -> void:

	if not Engine.is_editor_hint() and not PlayerState.has_ship():
		return
	var s : float = ship_scale
	# Side-view sky-ship hull, bow to the right; origin at the deck's mid-base.
	var hull : PackedVector2Array = PackedVector2Array([
		Vector2(-52, -22) * s, Vector2(50, -22) * s, Vector2(72, -8) * s,
		Vector2(44, 12) * s, Vector2(-44, 12) * s, Vector2(-56, -4) * s])
	draw_colored_polygon(hull, COLOR_HULL)
	var outline : PackedVector2Array = hull.duplicate()
	outline.append(hull[0])
	draw_polyline(outline, COLOR_HULL_DARK, 2.0 * s)
	# Deck trim stripe.
	draw_line(Vector2(-52, -22) * s, Vector2(50, -22) * s, COLOR_TRIM, 3.0 * s)
	# Breaches (open holes) — dark notches along the hull, so a battered ship LOOKS battered.
	var holes : int = 0 if Engine.is_editor_hint() else PlayerState.ship_open_holes()
	for i in holes:
		var bx : float = -34.0 + float(i) * 20.0
		draw_rect(Rect2(bx * s, -8.0 * s, 11.0 * s, 14.0 * s), COLOR_BREACH)
	# Mast + a billowed sail.
	var mast_top : Vector2 = Vector2(2, -86) * s
	draw_line(Vector2(2, -22) * s, mast_top, COLOR_MAST, 4.0 * s)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -80) * s, Vector2(44, -62) * s, Vector2(6, -34) * s]), COLOR_SAIL)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -56) * s, Vector2(44, -62) * s, Vector2(6, -34) * s]), COLOR_SAIL_SHADE)
	draw_line(Vector2(6, -80) * s, Vector2(6, -34) * s, COLOR_HULL_DARK, 2.0 * s)
	# Pennant atop the mast.
	draw_line(mast_top, Vector2(2, -94) * s, COLOR_MAST, 3.0 * s)
	draw_colored_polygon(PackedVector2Array([Vector2(2, -94) * s, Vector2(22, -90) * s, Vector2(2, -86) * s]), COLOR_TRIM)

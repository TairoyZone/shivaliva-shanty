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
	# The berth is the ship-management hub now: sail her, swap the active hull, re-christen, or sell
	# (Troy 2026-06-10, the elaborate-ship-system pass). Sailing itself lives in the modal's Sail row.
	DockBerthModal.open(self)


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
	var fleet : int = PlayerState.owned_ships.size()
	var extra : String = ("  ·  fleet of %d" % fleet) if fleet > 1 else ""
	_tooltip.text = "The %s, a %s (%s)%s — her berth   [Click]" % [PlayerState.active_ship_name(),
		ShipClasses.display(PlayerState.active_ship_id()), cond, extra]
	_tooltip.modulate = Color(0.78, 1.0, 0.62, 1.0)


func _draw() -> void:

	if not Engine.is_editor_hint() and not PlayerState.has_ship():
		return
	# The berthed hull DRAWS AS HER CLASS — a skiff is visibly smaller than a galleon, and the mast
	# count climbs with the class (1/2/3). The editor previews the Cloud Cutter (mid class).
	var sid : String = "" if Engine.is_editor_hint() else PlayerState.active_ship_id()
	var def : Dictionary = ShipClasses.get_def(sid)
	var s : float = ship_scale * float(def.get("moor_scale", 1.0))
	var masts : int = int(def.get("masts", 2))
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
	# Breaches (open holes) — dark notches spread along the hull, so a battered ship LOOKS battered
	# (spacing fits the class's full hull cap, so a galleon's nine wounds all land on the planks).
	var holes : int = 0 if Engine.is_editor_hint() else PlayerState.ship_open_holes()
	var cap : int = maxi(int(def.get("max_holes", 4)), 1)
	for i in holes:
		var bx : float = lerpf(-38.0, 46.0, float(i) / float(maxi(cap - 1, 1)))
		draw_rect(Rect2(bx * s, -8.0 * s, 11.0 * s, 14.0 * s), COLOR_BREACH)
	# Masts + billowed sails — one per class mast, spread along the deck (the tallest amidships).
	var mast_xs : Array = [2.0]
	if masts == 2:
		mast_xs = [-22.0, 18.0]
	elif masts >= 3:
		mast_xs = [-32.0, 2.0, 32.0]
	for m in masts:
		var mx : float = float(mast_xs[mini(m, mast_xs.size() - 1)])
		var height : float = 86.0 if absf(mx) < 10.0 else 70.0   # the centre mast stands tallest
		var top : Vector2 = Vector2(mx, -height) * s
		draw_line(Vector2(mx, -22) * s, top, COLOR_MAST, 4.0 * s)
		var sail_top : float = -height + 6.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(mx + 4.0, sail_top) * s, Vector2(mx + 42.0, sail_top + 18.0) * s, Vector2(mx + 4.0, -34) * s]), COLOR_SAIL)
		draw_colored_polygon(PackedVector2Array([
			Vector2(mx + 4.0, sail_top + 24.0) * s, Vector2(mx + 42.0, sail_top + 18.0) * s, Vector2(mx + 4.0, -34) * s]), COLOR_SAIL_SHADE)
		draw_line(Vector2(mx + 4.0, sail_top) * s, Vector2(mx + 4.0, -34) * s, COLOR_HULL_DARK, 2.0 * s)
	# Pennant atop the centre (tallest) mast.
	var pmx : float = float(mast_xs[1 if mast_xs.size() >= 3 else 0])
	var ptop : Vector2 = Vector2(pmx, -86.0 if absf(pmx) < 10.0 else -70.0) * s
	draw_line(ptop, ptop + Vector2(0, -8) * s, COLOR_MAST, 3.0 * s)
	draw_colored_polygon(PackedVector2Array([
		ptop + Vector2(0, -8) * s, ptop + Vector2(20, -4) * s, ptop]), COLOR_TRIM)

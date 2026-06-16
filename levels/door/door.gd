## Reusable door. Extends [Interactable] so the Player's E-press system
## picks it up like any other interactable — walk near, press E, scene
## changes. Draws a wooden door + pulsing gold frame in place of the
## Interactable's default circle.
@tool
class_name Door extends Interactable


## Where the door sits on its host building's silhouette.
##   FRONT: vertical slab on the front face (camera-facing). Used when
##          the door doesn't belong to an iso wall — interior scenes,
##          standalone doors, etc.
##   RIGHT: parallelogram embedded in the building's front-RIGHT iso
##          wall (slants up-right toward the back, sun-lit wall).
##   LEFT:  mirrored — parallelogram in the front-LEFT iso wall
##          (slants up-left, shadow side).
enum WallFacing { FRONT, RIGHT, LEFT }

@export_file("*.tscn") var target_scene : String
## Name of the anchor node in target_scene where the player should appear
## after the transition. Typically the name of the corresponding Door (or
## Table) in the destination scene. Empty = fall back to the target scene's
## default spawn.
@export var target_spawn_anchor : String = ""
@export var wall_facing : WallFacing = WallFacing.FRONT
## (spawn_offset is inherited from [Interactable] — set it per-instance
## in the inspector. (0, 40) works for doors on a building front; flip to
## (0, -60) for an inward-facing door that lands the player inside.)

## LOCKED door: the inventory item id (a "key_*", see [PlayerState.ITEM_DEFS]) the player must HOLD to open
## this door. Empty = always open. Keys are earned + kept forever, so a door unlocks PERMANENTLY once you
## have the key. A padlock draws over a locked door, and clicking it shows [member locked_hint] instead of
## changing scene. See [method PlayerState.grant_key].
@export var required_key : String = ""
## What the "it's locked" popup says — name the key + where to earn it.
@export_multiline var locked_hint : String = "It's locked. You'll need the right key."

## Door dimensions for the placeholder. FRONT uses these as a slab w/h;
## SIDE variants use DOOR_W as the extent ALONG the iso wall and DOOR_H
## as the vertical height (smaller than the smallest building wall_height).
const DOOR_W : float = 60.0
const DOOR_H : float = 80.0
const THRESHOLD_W : float = 100.0
const COLOR_DOOR_FILL : Color = Color(0.42, 0.24, 0.10, 1.0)
const COLOR_DOOR_FRAME : Color = Color(0.85, 0.66, 0.28, 1.0)
const COLOR_DOOR_KNOB : Color = Color(0.95, 0.78, 0.30, 1.0)
const COLOR_THRESHOLD : Color = Color(0, 0, 0, 0.28)

## Iso wall direction normalized: (2, -1) / sqrt(5).
const ISO_DX : float = 0.894427
const ISO_DY : float = -0.447214


func _ready() -> void:

	super._ready()
	if Engine.is_editor_hint():
		return
	# Pulse only while the player is near (gated in set_tooltip_visible) —
	# not every frame for every door regardless of proximity/visibility.
	# (Audit minor: removes continuous per-frame queue_redraw churn.)
	set_process(false)


func _process(_delta: float) -> void:

	# Pulse the frame — runs only while the player is in range.
	queue_redraw()


# The player's InteractionZone toggles this as it enters/leaves range.
# Start/stop the pulse with proximity so far/off-screen doors cost
# nothing per frame.
func set_tooltip_visible(value: bool) -> void:

	super.set_tooltip_visible(value)
	if Engine.is_editor_hint():
		return
	set_process(value)
	queue_redraw()


func interact() -> void:

	if Engine.is_editor_hint():
		return
	if target_scene.is_empty():
		return
	# LOCKED — you don't hold the key yet. Tell the player how to earn it; don't change scene.
	if _is_locked():
		Overlay.show_lore("Locked", locked_hint)
		return
	if not target_spawn_anchor.is_empty():
		PlayerState.request_spawn_at_anchor(target_spawn_anchor)
	Audio.play_sfx("whoosh")   # the door transition whoosh
	# Scene change MUST be deferred — Godot disallows removing CollisionObject
	# nodes during a physics callback, and that's effectively what
	# change_scene_to_file does to this door.
	get_tree().call_deferred("change_scene_to_file", target_scene)


func _draw() -> void:

	var frame_alpha : float = 1.0
	if not Engine.is_editor_hint():
		frame_alpha = 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.004))
	var frame_color : Color = Color(COLOR_DOOR_FRAME.r, COLOR_DOOR_FRAME.g, COLOR_DOOR_FRAME.b, frame_alpha)
	match wall_facing:
		WallFacing.FRONT:
			_draw_front(frame_color)
		WallFacing.RIGHT:
			_draw_side(frame_color, 1.0)
		WallFacing.LEFT:
			_draw_side(frame_color, -1.0)
	# A padlock over any locked door (in the editor too, so a designer sees which doors gate).
	if _is_locked() or (Engine.is_editor_hint() and not required_key.is_empty()):
		_draw_padlock()


# True at RUNTIME when this door needs a key the player doesn't hold yet. The editor never locks
# (PlayerState isn't running there); the padlock there is just a design-time marker.
func _is_locked() -> bool:

	if Engine.is_editor_hint() or required_key.is_empty():
		return false
	return PlayerState.item_count(required_key) <= 0


# A small brass padlock centred on the door face — the "you need a key" tell.
func _draw_padlock() -> void:

	var p : Vector2 = Vector2(0.0, -DOOR_H * 0.55)
	var body : Color = Color(0.88, 0.74, 0.30, 1.0)
	var dark : Color = Color(0.28, 0.20, 0.09, 1.0)
	draw_arc(p + Vector2(0.0, -7.0), 8.0, PI, TAU, 16, dark, 4.0)   # shackle
	var body_rect : Rect2 = Rect2(p.x - 11.0, p.y, 22.0, 17.0)
	draw_rect(body_rect, body)
	draw_rect(body_rect, dark, false, 2.0)
	draw_circle(p + Vector2(0.0, 7.0), 3.0, dark)                   # keyhole
	draw_rect(Rect2(p.x - 1.3, p.y + 7.0, 2.6, 5.0), dark)


# Vertical wooden slab + flat threshold diamond. Origin = foot of door.
func _draw_front(frame_color: Color) -> void:

	var threshold : PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 12.0),
		Vector2(THRESHOLD_W * 0.5, 0.0),
		Vector2(0.0, -12.0),
		Vector2(-THRESHOLD_W * 0.5, 0.0),
	])
	draw_colored_polygon(threshold, COLOR_THRESHOLD)
	var slab : Rect2 = Rect2(-DOOR_W * 0.5, -DOOR_H, DOOR_W, DOOR_H)
	draw_rect(slab, COLOR_DOOR_FILL)
	draw_rect(slab, frame_color, false, 2.5)
	draw_circle(Vector2(slab.end.x - 10.0, -DOOR_H * 0.5), 4.0, COLOR_DOOR_KNOB)


# Parallelogram door embedded in an iso wall.
#   sign_x = +1 → right wall (slants up-right toward the back)
#   sign_x = -1 → left wall  (slants up-left toward the back)
# Origin (0,0) is the foot of the door on the wall surface.
func _draw_side(frame_color: Color, sign_x: float) -> void:

	var hax : float = DOOR_W * 0.5 * ISO_DX * sign_x
	var hay : float = DOOR_W * 0.5 * ISO_DY  # always negative — wall rises away from front
	var bc : Vector2 = Vector2(-hax, -hay)   # bottom-close (front-side of wall)
	var bf : Vector2 = Vector2(hax, hay)     # bottom-far  (back-side of wall)
	var tc : Vector2 = bc + Vector2(0.0, -DOOR_H)
	var tf : Vector2 = bf + Vector2(0.0, -DOOR_H)
	# Door panel (parallelogram slanted along the iso wall).
	draw_colored_polygon(PackedVector2Array([bc, bf, tf, tc]), COLOR_DOOR_FILL)
	# Frame outline.
	draw_polyline(PackedVector2Array([bc, bf, tf, tc, bc]), frame_color, 2.5)
	# Knob on the front-side edge at mid-height, nudged slightly toward back.
	var knob_pos : Vector2 = (bc + tc) * 0.5 + Vector2(sign_x * 6.0, 0.0)
	draw_circle(knob_pos, 4.0, COLOR_DOOR_KNOB)

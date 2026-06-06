## Isometric player — 8-direction movement using GDQuest's CC-BY 4.0
## character spritesheet (purple humanoid, 16 animations: idle_X + run_X
## for north / north_east / east / south_east / south / south_west /
## west / north_west).
##
## Movement velocity is multiplied by `_isometric_factor` (height/width
## ratio of the tileset) so a "raw" diagonal input maps to a tile-aligned
## diagonal on screen. Animation FPS is also adjusted for the iso ratio.
##
## Integration with the rest of our codebase:
##   - Still `class_name Player` (Interactable detection, save_session,
##     BaseLocation spawn etc. all keep working).
##   - Still in the `player` group so PlayerState.save_session() can find us.
##   - Still has an InteractionZone Area2D child that detects [Interactable]
##     instances on layer 4 — pressing E calls `.interact()` on the closest.
##   - Still freezes while [Overlay] is active.
class_name Player
extends CharacterBody2D


const SPEED : float = 320.0
const ANIMATION_FPS : float = 16.0

# Cardinal-direction strings used as animation suffixes. Map iso input
# vectors → screen-direction labels. Names match the SpriteFrames in
# player.tscn (idle_north, run_north, idle_north_east, …). Not a `const`
# because `Vector2.normalized()` is a runtime call — GDScript requires
# const expressions to be evaluable at parse time.
var INPUT_TO_DIRECTION : Dictionary = {
	Vector2(1, -1).normalized(): "north",
	Vector2(1, 0): "north_east",
	Vector2(1, 1).normalized(): "east",
	Vector2(0, 1): "south_east",
	Vector2(-1, 1).normalized(): "south",
	Vector2(-1, 0): "south_west",
	Vector2(-1, -1).normalized(): "west",
	Vector2(0, -1): "north_west",
}

@onready var _sprite : AnimatedSprite2D = %AnimatedSprite2D
@onready var _interaction_zone : Area2D = %InteractionZone

var _nearby_interactables : Array[Interactable] = []
var _isometric_factor : Vector2 = Vector2(1.0, 0.5)
var _last_direction : String = "south"

## Footstep cadence while walking (borrowed lib). _step_t counts up; a step fires each STEP_INTERVAL.
const STEP_INTERVAL : float = 0.32
var _step_t : float = STEP_INTERVAL


func _ready() -> void:

	_interaction_zone.area_entered.connect(_on_InteractionZone_area_entered)
	_interaction_zone.area_exited.connect(_on_InteractionZone_area_exited)
	# Read iso ratio off the first TileMapLayer we can find in the parent
	# scene so movement + animation pace match the world. Falls back to a
	# standard 2:1 iso ratio if no TileMapLayer is around (e.g. unit tests).
	var tile_layer : TileMapLayer = _find_tile_layer()
	if tile_layer and tile_layer.tile_set:
		var ts : Vector2 = Vector2(tile_layer.tile_set.tile_size)
		_isometric_factor = Vector2(1.0, ts.y / ts.x)
	_adjust_animation_fps()
	# Default to idle facing south so the player isn't invisible on spawn.
	_sprite.play("idle_south")


func _find_tile_layer() -> TileMapLayer:

	var parent : Node = get_parent()
	while parent != null:
		for child in parent.get_children():
			if child is TileMapLayer:
				return child
			# Also check one level deeper (e.g. YSortNode2D wrapper).
			for grand in child.get_children():
				if grand is TileMapLayer:
					return grand
		parent = parent.get_parent()
	return null


func _physics_process(delta: float) -> void:

	# Freeze while a fullscreen UI owns the screen — an NPC/lore dialog
	# (Overlay) OR the open backpack (HUD inventory). Otherwise the player
	# would walk around blind behind the overlay.
	if Overlay.is_active or (HUD != null and HUD.is_inventory_open()):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input : Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.is_zero_approx():
		_sprite.play("idle_%s" % _last_direction)
		velocity = Vector2.ZERO
		_step_t = STEP_INTERVAL   # so the first step on resuming plays promptly
		move_and_slide()
		return
	var direction : String = INPUT_TO_DIRECTION.get(input, _last_direction)
	_last_direction = direction
	_sprite.play("run_%s" % direction)
	velocity = _isometric_factor * input * SPEED
	move_and_slide()
	# A footstep on a steady cadence — only when actually moving (not pressing into a wall).
	_step_t += delta
	if _step_t >= STEP_INTERVAL and get_real_velocity().length() > 10.0:
		_step_t = 0.0
		Audio.play_sfx("step_grass", -7.0, 0.14)


func _unhandled_input(event: InputEvent) -> void:

	if not event.is_action_pressed("interact"):
		return
	# Don't fire an interactable underneath a fullscreen UI — the bag's
	# dim only blocks mouse, not the E action, and a dialog shouldn't be
	# interruptible by E either. Mirrors the movement freeze.
	if Overlay.is_active or (HUD != null and HUD.is_inventory_open()):
		return
	if _nearby_interactables.is_empty():
		return
	var closest : Interactable = _nearby_interactables[0]
	var closest_dist : float = global_position.distance_squared_to(closest.global_position)
	for m in _nearby_interactables:
		var d : float = global_position.distance_squared_to(m.global_position)
		if d < closest_dist:
			closest = m
			closest_dist = d
	closest.interact()


func _on_InteractionZone_area_entered(area: Area2D) -> void:

	if not area is Interactable:
		return
	_nearby_interactables.push_back(area)
	area.set_tooltip_visible(true)


func _on_InteractionZone_area_exited(area: Area2D) -> void:

	if not area is Interactable:
		return
	_nearby_interactables.erase(area)
	area.set_tooltip_visible(false)


# Animation FPS gets scaled by the iso projection ratio so diagonal
# movement (which covers less screen distance per unit input) doesn't
# play frames faster than the character is visibly moving.
func _adjust_animation_fps() -> void:

	if _sprite == null or _sprite.sprite_frames == null:
		return
	for animation in _sprite.sprite_frames.get_animation_names():
		if animation.begins_with("idle"):
			continue
		var fps : float = ANIMATION_FPS
		match animation:
			"run_north_west", "run_south_east":
				fps *= _isometric_factor.y
			"run_north", "run_east", "run_south", "run_west":
				fps *= (_isometric_factor.x + _isometric_factor.y) * 0.5
		_sprite.sprite_frames.set_animation_speed(animation, fps)

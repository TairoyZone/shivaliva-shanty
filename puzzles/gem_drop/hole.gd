## A single warp hole used in the Gem Drop round-5 Holes tiebreaker.
## Standalone Node2D so you can drop it into any scene to preview the
## visual + adjust its trigger area. Pure @tool — the visual updates
## live in the editor as you change the [member pair] enum or drag the
## CollisionShape2D's radius handle.
##
## ## How pairing works
##
## Each hole belongs to a [enum Pair] (One / Two / Three / Four). When
## the scene loads, every Hole scans its siblings; two holes sharing
## the same pair link to each other (symmetric — both end up with a
## [member partner] pointing at the other). Place two ONE-holes in a
## scene, they warp into each other automatically; no code wiring.
##
## ## How the trigger works
##
## Two independent sizes:
##   • [member visual_radius] — how big the hole *looks* (drawn disc).
##   • The TriggerArea/Shape child's CircleShape2D radius — how big the
##     warp *trigger* is. Drag the yellow handle in the editor to adjust.
##
## They're decoupled on purpose: you can have a tiny drawn mouth with
## a generous trigger area for forgiveness, or a large visual with a
## pinpoint trigger for precision. The Area2D is NOT monitoring (no
## physics overhead) — [GemDropBoard] uses a per-frame distance check
## via [method contains], reading from the CollisionShape2D's radius.
@tool
class_name Hole
extends Node2D


## Color palette per pair — keyed by [enum Pair]. Sky-toned so the
## pair-identity fill stays distinct from the gold/brass coins.
const PAIR_COLORS : Dictionary = {
	Pair.ONE:   Color(0.42, 0.80, 0.92, 1.0),  # sky cyan
	Pair.TWO:   Color(0.80, 0.52, 0.92, 1.0),  # violet
	Pair.THREE: Color(0.55, 0.90, 0.60, 1.0),  # pale green
	Pair.FOUR:  Color(0.95, 0.62, 0.42, 1.0),  # warm coral
}
## Fallback radius when the CollisionShape2D isn't set up yet (e.g.
## the very first editor draw before _ready resolves the @onready).
const DEFAULT_RADIUS : float = 11.0


## Which pair this hole belongs to. Two holes sharing the same pair
## warp into each other (auto-resolved on _ready by scanning siblings).
## Change in the inspector to repaint the inner color.
enum Pair { ONE, TWO, THREE, FOUR }

@export var pair : Pair = Pair.ONE :
	set(value):
		pair = value
		queue_redraw()

## Drawn size of the hole. Independent of the trigger radius (which
## comes from the TriggerArea/Shape's CircleShape2D). Adjust this for
## visual feel; adjust the CollisionShape2D handle for the warp zone.
@export_range(2.0, 32.0) var visual_radius : float = 11.0 :
	set(value):
		visual_radius = value
		queue_redraw()


@onready var _shape : CollisionShape2D = $TriggerArea/Shape

## Runtime-resolved partner — the Hole this one warps coins TO. Null
## until [method _resolve_partner] runs (on _ready) or if no matching-
## pair sibling exists.
var partner : Hole = null


func _ready() -> void:

	queue_redraw()
	# Editor doesn't need partner-resolution (no gameplay) — it's a
	# pure preview there. At runtime, find this hole's mate.
	if Engine.is_editor_hint():
		return
	_resolve_partner()


# Scan sibling Nodes for the first unpaired [Hole] sharing this one's
# [member pair] enum. Symmetric: whichever hole's _ready fires last
# wires both sides. If three holes share a pair, the third stays
# unpaired (and silently won't warp).
func _resolve_partner() -> void:

	if partner != null:
		return
	var parent_node : Node = get_parent()
	if parent_node == null:
		return
	for sibling in parent_node.get_children():
		if sibling == self or not (sibling is Hole):
			continue
		var other : Hole = sibling as Hole
		if other.pair != pair or other.partner != null:
			continue
		partner = other
		other.partner = self
		return


func _draw() -> void:

	# Dark void — borderless.
	draw_circle(Vector2.ZERO, visual_radius, Color(0.05, 0.03, 0.02, 1.0))
	# Pair-colored center fill — the connection indicator. No rim,
	# so the hole doesn't read as a coin/gem.
	var color : Color = PAIR_COLORS.get(pair, Color.WHITE) as Color
	draw_circle(Vector2.ZERO, visual_radius * 0.5, color.darkened(0.3))


# Read the WARP trigger radius from the child CollisionShape2D's
# CircleShape2D. Independent of [member visual_radius] — drag the
# Area2D handle in the editor to adjust the trigger size separately
# from the drawn disc.
func _get_collision_radius() -> float:

	if _shape == null:
		_shape = get_node_or_null("TriggerArea/Shape") as CollisionShape2D
	if _shape == null or _shape.shape == null:
		return DEFAULT_RADIUS
	var circle : CircleShape2D = _shape.shape as CircleShape2D
	if circle == null:
		return DEFAULT_RADIUS
	return circle.radius


## True if [param coin_position] (in this hole's parent space) is
## inside the warp trigger area. Uses the CollisionShape2D's radius
## (NOT [member visual_radius]) so you can tune the trigger
## independently of the visual.
func contains(coin_position: Vector2) -> bool:

	var r : float = _get_collision_radius()
	return position.distance_squared_to(coin_position) < r * r

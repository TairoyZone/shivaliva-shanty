## Base class for any in-world object the player can press E on.
##
## Doors, Puzzles (Gem Drop, Poker), Docks, NPCs, lore objects —
## anything the player approaches and interacts with — should extend
## this class (or a subclass of it like [Puzzle]). The shared logic:
##
##   - the Player's InteractionZone (Area2D, mask=Interactable) overlaps
##     this Area2D when nearby and calls set_tooltip_visible(true/false),
##   - on E press, the Player calls interact() on the closest one,
##   - interact() emits `interacted` so subclasses can wire up behavior.
##
## Concrete subclasses override `interact()` to do their actual work
## (change scene, launch puzzle, open dialog, etc.) and provide their
## own visual via `_draw()` or a child Sprite — Interactable itself
## draws nothing.
##
## Solid props (table, building) should add a StaticBody2D child to the
## scene that uses this script so the player physically collides with
## the prop in addition to triggering its proximity area.
@tool
class_name Interactable
extends Area2D


signal interacted

@export var marker_label : String = "Marker"
@export var interact_message : String = ""
## Where the player lands when this object is the destination of a scene
## transition — offset from this node's own position. Read by
## BaseLocation when resolving the pending spawn anchor.
@export var spawn_offset : Vector2 = Vector2(0, 60)

## Click-target box (local px, from this node's origin/base) for "you must click ON me, not just be
## nearby" (Troy 2026-06-06). Tight horizontally so clicking the ground beside me doesn't count; tall
## enough to cover a standing figure from the feet (origin) up past the head. Wide/odd-footprint props
## override [method contains_click].
const CLICK_HALF_WIDTH : float = 48.0
const CLICK_ABOVE : float = 140.0
const CLICK_BELOW : float = 28.0

@onready var _tooltip : Label = %Tooltip


func _ready() -> void:

	if Engine.is_editor_hint():
		return
	_tooltip.visible = false


func set_tooltip_visible(value: bool) -> void:

	if Engine.is_editor_hint():
		return
	if value:
		var verb : String = "[Tap]" if TouchEnv.is_touch() else "[Click]"
		_tooltip.text = "%s   %s" % [marker_label, verb]
	_tooltip.visible = value


## Whether a world-space [param point] lands ON this interactable's body — the Player uses this so you must
## AIM at the prop, not merely stand near it. Default: the [constant CLICK_HALF_WIDTH] box around the origin.
func contains_click(point: Vector2) -> bool:

	var local : Vector2 = point - global_position
	return absf(local.x) <= CLICK_HALF_WIDTH and local.y <= CLICK_BELOW and local.y >= -CLICK_ABOVE


func interact() -> void:

	if Engine.is_editor_hint():
		return
	interacted.emit()

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

@onready var _tooltip : Label = %Tooltip


func _ready() -> void:

	if Engine.is_editor_hint():
		return
	_tooltip.visible = false


func set_tooltip_visible(value: bool) -> void:

	if Engine.is_editor_hint():
		return
	if value:
		_tooltip.text = "%s   [Click]" % marker_label
	_tooltip.visible = value


func interact() -> void:

	if Engine.is_editor_hint():
		return
	interacted.emit()

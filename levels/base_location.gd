## Base class for any walkable overworld location (Cradle Rock, tavern,
## future islands). Instantiates the Player and resolves where to spawn
## them in this priority order:
##
##   1. PlayerState.pending_spawn_anchor (string Marker2D name) — set by
##      Door / GemDropTable before they trigger the scene change.
##   2. PlayerState.pending_spawn_position (Vector2) — set by main.gd
##      when resuming from a saved session.
##   3. pirate_spawn_position — the scene's default starting point.
##
## After spawning, the current scene path is saved to PlayerState so the
## player resumes here on next launch.
class_name BaseLocation
extends Node2D

const PLAYER_SCENE : PackedScene = preload("res://player/player.tscn")

@export var pirate_spawn_position : Vector2 = Vector2(640, 540)
## (Legacy) scene this location used to load on ESC. ESC is now the
## backpack key — owned + consumed by the [HUD] in the overworld — so
## this is no longer wired to ESC. Kept as an export for a future
## explicit "quit to title" entry point (e.g. a button in the bag /
## pause screen). NOT read anywhere right now.
@export_file("*.tscn") var escape_scene : String = ""

var player : Player


# NOTE: no ESC handler here anymore. ESC summons the backpack (handled
# in HUD._unhandled_input, which consumes it), so the old ESC-to-title
# leave was removed to avoid fighting the HUD for the key.


func _ready() -> void:

	# Any walkable location is gameplay → ensure the HUD is shown (the
	# title screen hides it; puzzle scenes hide + restore it themselves).
	if HUD:
		HUD.visible = true
	Audio.play_music_track("overworld")   # the overworld bed (guarded — won't restart between locations)
	player = PLAYER_SCENE.instantiate()
	# Parent the player INSIDE YSortNode2D when the scene has one — that
	# way the iso character y-sorts against painted tile objects and
	# building placeholders the same way the GDQuest reference does.
	# Falls back to self for legacy / top-down scenes without YSortNode2D.
	var y_sort_root : Node = find_child("YSortNode2D", false, false)
	if y_sort_root != null:
		y_sort_root.add_child(player)
	else:
		add_child(player)
	player.global_position = _resolve_spawn_position()
	# Record where the player landed so a quit-now resume would restore
	# them here.
	PlayerState.last_scene = scene_file_path
	PlayerState.last_position = player.global_position


func _resolve_spawn_position() -> Vector2:

	var anchor_name : String = PlayerState.consume_anchor()
	if not anchor_name.is_empty():
		var anchor : Node = find_child(anchor_name, true, false)
		if anchor is Node2D:
			# Each spawn-target component (Door, GemDropTable, …)
			# carries its own @export var spawn_offset so the spawn point
			# lives next to the thing it belongs to. Apply it if present.
			var base : Vector2 = (anchor as Node2D).global_position
			var offset_value : Variant = anchor.get("spawn_offset")
			if offset_value is Vector2:
				return base + (offset_value as Vector2)
			return base
	var resumed_pos : Variant = PlayerState.consume_position()
	if resumed_pos != null:
		return resumed_pos
	return pirate_spawn_position

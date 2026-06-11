## Base class for any parlor-game prop the player walks up to and pays
## gold to play (Gem Drop, Poker, and future job-puzzles in the
## Inn on Cradle Rock).
##
## Inherits all the proximity / tooltip / E-press wiring from
## [Interactable]; adds:
##   - `puzzle_scene` — the scene to launch when E is pressed,
##   - `play_cost`   — gold to spend (0 = free),
##   - a dynamic tooltip showing affordability ("5 gold to play"
##     vs "Need 5 gold"),
##   - automatic return-anchor handoff (`PlayerState.request_spawn_at_anchor(name)`)
##     so the player lands back at THIS prop when the puzzle exits.
##
## Concrete puzzles (GemDropTable, etc.) only need a custom
## `_draw()` for visuals. They inherit `interact()` etc. from here.
@tool
class_name Puzzle
extends Interactable


@export_file("*.tscn") var puzzle_scene : String
@export var play_cost : int = 0

var _is_player_nearby : bool = false


func _ready() -> void:

	super._ready()
	if Engine.is_editor_hint():
		return
	PlayerState.coins_changed.connect(_on_PlayerState_coins_changed)


# Override the parent's static tooltip text — puzzle tooltips need to
# show whether the player can afford to play right now.
func set_tooltip_visible(value: bool) -> void:

	if Engine.is_editor_hint():
		return
	_is_player_nearby = value
	if value:
		_refresh_tooltip_text()
	_tooltip.visible = value


func interact() -> void:

	if Engine.is_editor_hint():
		return
	_launch_puzzle(true)


## Launch the puzzle scene, optionally charging [member play_cost] first.
## Split out of [method interact] so [method ParlorTable.launch_table] (driven by the
## [ParlorBrowser]) can launch a FREE table (charge_cost = false) down the same return-anchor +
## scene-change path. Returns silently if the scene is unset or the player can't afford a charged launch.
func _launch_puzzle(charge_cost: bool) -> void:

	if puzzle_scene.is_empty():
		return
	if charge_cost and play_cost > 0:
		if PlayerState.total_coins < play_cost:
			Audio.play_sfx("buzz")   # can't afford — a click that did NOTHING read as broken (audio-gap audit)
			return
		PlayerState.add_coins(-play_cost, ("%s entry" % marker_label) if not marker_label.is_empty() else "Game entry")
	# When the puzzle exits, the destination scene's BaseLocation will
	# find a node by our name and use its position + spawn_offset, so
	# the player lands right next to this prop.
	PlayerState.request_spawn_at_anchor(name)
	Audio.play_sfx("whoosh")   # entering the puzzle — the transition whoosh
	get_tree().change_scene_to_file(puzzle_scene)


func _refresh_tooltip_text() -> void:

	if play_cost <= 0:
		_tooltip.text = "%s   [Click]" % marker_label
		_tooltip.modulate = Color(0.98, 0.92, 0.55, 1.0)
		return
	if PlayerState.total_coins >= play_cost:
		_tooltip.text = "%d gold to play   [Click]" % play_cost
		_tooltip.modulate = Color(0.98, 0.92, 0.55, 1.0)
	else:
		_tooltip.text = "Need %d gold" % play_cost
		_tooltip.modulate = Color(0.98, 0.55, 0.45, 1.0)


func _on_PlayerState_coins_changed(_new_total: int) -> void:

	if _is_player_nearby:
		_refresh_tooltip_text()

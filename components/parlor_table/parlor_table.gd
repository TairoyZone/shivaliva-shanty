## Base class for the parlor-game table props (Poker, Gem Drop). Extends
## [Puzzle] (proximity tooltip, return-anchor, scene launch) and adds the
## social LOBBY layer:
##  • on entry a table may already be NPC-HOSTED — a host + patrons with one
##    open seat; a [ParlorHostBadge] floats above it, and interacting opens
##    a JOIN lobby (gated by rapport with the host, with a "Start your own"
##    escape so play is NEVER blocked);
##  • otherwise the player HOSTS their own table (rapport-weighted auto-fill).
## Concrete tables override the small per-game config hooks + own their
## _draw(). See [[parlor-social-system]].
@tool
class_name ParlorTable
extends Puzzle


## Chance a table is already NPC-hosted when the player arrives (tunable).
const HOST_CHANCE : float = 0.5
## Rapport with the host needed to sit at their game. Below it the join
## screen reads "regulars only" — but "Start your own" always works, so a
## low-rapport player is never blocked from playing (tunable).
const JOIN_AFFINITY_MIN : int = 10

## Every live parlor table joins this group, so the browser (opened from any one prop) can list
## every game's tables and launch each through its own prop.
const GROUP_PARLOR : String = "parlor_tables"

## Open guard — the live [ParlorBrowser], or null.
var _browser : CanvasLayer = null
## NPC-hosted state, rolled once on scene load.
var _hosted : bool = false
var _host_profile : NpcPersonality = null
var _patron_profiles : Array[NpcPersonality] = []


func _ready() -> void:

	super._ready()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP_PARLOR)
	_roll_hosting()


# Roll whether an NPC is already hosting here this visit; if so seat a host
# + patrons (leaving one open seat for the player) and float a host badge.
func _roll_hosting() -> void:

	if randf() >= HOST_CHANCE:
		return
	var seats : int = randi_range(_min_seats(), _max_seats())
	var here : Array[NpcPersonality] = NpcRegistry.pick_for_lobby(
		seats - 1, PlayerState.get_affinity,
		NpcRegistry.profiles_from_paths(PlayerState.last_lobby_seated_paths))
	if here.is_empty():
		return
	_hosted = true
	_host_profile = here[0]
	_patron_profiles = here
	var pip_colors : Array[Color] = []
	for p in here:
		pip_colors.append(p.portrait_color)
	add_child(ParlorHostBadge.create(
		_host_profile.npc_name, _host_profile.portrait_color, pip_colors, _badge_y()))


# Press E at a parlor table → open the TABLE BROWSER for THIS game only (poker table = poker tables,
# gem-drop table = gem-drop tables). A live list of active tables for the one game, with Join +
# Create. (The browser also supports multiple games, so a future "Parlor games!" hub could pass the
# whole GROUP_PARLOR — but a specific table only ever shows its own game.)
func interact() -> void:

	if Engine.is_editor_hint():
		return
	if puzzle_scene.is_empty():
		return
	if is_instance_valid(_browser):
		return
	_browser = ParlorBrowser.create([self], _game_id())
	_browser.cancelled.connect(_on_browser_cancelled)
	add_child(_browser)


func _on_browser_cancelled() -> void:

	_browser = null


# Seat the chosen opponents + stake into the handoff, then launch THIS game. Cash tables charge the
# buy-in; free tables and exit-billed games (Gem Drop) charge nothing here. Called by the browser on
# Join / Create (it's the same stash+launch the old lobby did, now driven by the browser's choice).
func launch_table(seated_paths: Array, free: bool, config: Dictionary = {}) -> void:

	PlayerState.lobby_seated_paths = seated_paths
	PlayerState.free_table = free
	PlayerState.lobby_table_config = config   # poker: {structure, min_bet, seats, turn_time}; else {}
	PlayerState.last_lobby_seated_paths = seated_paths
	_launch_puzzle(_charges_buy_in() and not free)


# --- Read surface for the browser -------------------------------------

# The per-game metadata the browser renders a tab + its rows + stakes from.
func parlor_config() -> Dictionary:

	return {
		"id": _game_id(),
		"name": _game_name(),
		"min_seats": _min_seats(),
		"max_seats": _max_seats(),
		"cash_cost": _cash_cost(),
		"cash_note": _cash_note(),
		"charges_buy_in": _charges_buy_in(),
	}


# The NPC-hosted table rolled for THIS prop on load (so the browser's first row matches the floating
# ParlorHostBadge in the world), or {} if none. `seated` = host + patrons (one open seat is yours).
func hosted_table() -> Dictionary:

	if not _hosted or _host_profile == null:
		return {}
	return {"seated": _patron_profiles}


# Parlor tables DON'T show a "gold to play" / "Need N gold" tooltip — the
# stake (Free vs Cash buy-in) is chosen in the lobby, which surfaces all the
# real info. So the proximity tooltip is just the table's label, never a cost.
func _refresh_tooltip_text() -> void:

	if _tooltip == null:
		return
	var label : String = marker_label if not marker_label.is_empty() else _game_name()
	_tooltip.text = "%s   [E]" % label
	_tooltip.modulate = Color(0.98, 0.92, 0.55, 1.0)


# --- Per-game config (overridden by concrete tables) ------------------

# Stable id matching the mastery key ("poker" / "gem_drop") — the browser tabs + standings key on it.
func _game_id() -> String:
	return ""

func _game_name() -> String:
	return "Game"

func _min_seats() -> int:
	return 2

func _max_seats() -> int:
	return 2

func _cash_cost() -> int:
	return play_cost

func _cash_note() -> String:
	return ""

func _charges_buy_in() -> bool:
	return true

func _badge_y() -> float:
	return -100.0
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

## Open guard — the live [LobbyModal], or null.
var _lobby : LobbyModal = null
## NPC-hosted state, rolled once on scene load.
var _hosted : bool = false
var _host_profile : NpcPersonality = null
var _patron_profiles : Array[NpcPersonality] = []


func _ready() -> void:

	super._ready()
	if Engine.is_editor_hint():
		return
	_roll_hosting()


# Roll whether an NPC is already hosting here this visit; if so seat a host
# + patrons (leaving one open seat for the player) and float a host badge.
func _roll_hosting() -> void:

	if randf() >= HOST_CHANCE:
		return
	var seats : int = randi_range(_min_seats(), _max_seats())
	var here : Array[NpcPersonality] = NpcRegistry.pick_for_lobby(
		seats - 1, PlayerState.get_affinity,
		LobbyModal.profiles_from_paths(PlayerState.last_lobby_seated_paths))
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


# Route: JOIN an NPC's game if one's hosted here, else HOST your own.
func interact() -> void:

	if Engine.is_editor_hint():
		return
	if puzzle_scene.is_empty():
		return
	if is_instance_valid(_lobby):
		return
	if _hosted and _host_profile != null:
		_open_join_lobby()
	else:
		_open_host_lobby()


func _open_host_lobby() -> void:

	_lobby = LobbyModal.create({
		"game_name": _game_name(),
		"min_seats": _min_seats(),
		"max_seats": _max_seats(),
		"default_seats": _max_seats(),
		"affinity_of": PlayerState.get_affinity,
		"cash_cost": _cash_cost(),
		"cash_note": _cash_note(),
		"exclude": LobbyModal.profiles_from_paths(PlayerState.last_lobby_seated_paths),
	})
	_wire_lobby()


func _open_join_lobby() -> void:

	var can_join : bool = PlayerState.get_affinity(_host_profile.npc_name) >= JOIN_AFFINITY_MIN
	_lobby = LobbyModal.create({
		"mode": "join",
		"game_name": _game_name(),
		"host_name": _host_profile.npc_name,
		"host_color": _host_profile.portrait_color,
		"join_profiles": _patron_profiles,
		"can_join": can_join,
		"cash_cost": _cash_cost(),
		"cash_note": _cash_note(),
		"min_seats": _min_seats(),
		"max_seats": _max_seats(),
		"default_seats": _max_seats(),
		"affinity_of": PlayerState.get_affinity,
		"exclude": LobbyModal.profiles_from_paths(PlayerState.last_lobby_seated_paths),
	})
	_wire_lobby()


func _wire_lobby() -> void:

	_lobby.confirmed.connect(_on_lobby_confirmed)
	_lobby.cancelled.connect(_on_lobby_cancelled)
	add_child(_lobby)


func _on_lobby_confirmed(seated_paths: Array, free: bool) -> void:

	_lobby = null
	PlayerState.lobby_seated_paths = seated_paths
	PlayerState.free_table = free
	PlayerState.last_lobby_seated_paths = seated_paths
	# Cash tables charge the buy-in (if this game has one); free tables and
	# games that bill at exit (Gem Drop) charge nothing here.
	_launch_puzzle(_charges_buy_in() and not free)


func _on_lobby_cancelled() -> void:

	_lobby = null


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
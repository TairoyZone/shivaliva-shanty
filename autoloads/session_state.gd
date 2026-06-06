## SessionState — a co-op-ready SEAM (no netcode yet). It mirrors the shape a multiplayer session will need,
## so the rest of the game can already be written against it: a `players` dict (size 1 in single-player),
## add/remove signals, and a LOCAL-AUTHORITY check used to gate input. When ENet lands later this fills in
## and almost nothing else changes. Single-player keeps exactly one always-present local player.
## See [[multiplayer-direction]] / [[godot-borrow-todo]].
extends Node

signal player_added(id: int)
signal player_removed(id: int)

const LOCAL_ID : int = 1

## id -> info dict. One entry in single-player.
var players : Dictionary = {}


func _ready() -> void:

	add_player(LOCAL_ID, {"name": "You", "local": true})


func add_player(id: int, info: Dictionary = {}) -> void:

	if players.has(id):
		return
	players[id] = info
	player_added.emit(id)


func remove_player(id: int) -> void:

	if not players.has(id):
		return
	players.erase(id)
	player_removed.emit(id)


## True when [param id] is controlled by THIS client. Single-player: always (only the local player exists).
## Later this checks the multiplayer authority — gate input on it so co-op "just works" when netcode lands.
func is_local_authority(id: int = LOCAL_ID) -> bool:

	return id == LOCAL_ID

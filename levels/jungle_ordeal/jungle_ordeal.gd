## THE JUNGLE ORDEAL — the Cradle Gym's beast trial, built on Troy's ISOMETRIC TILESET (the same atlas he
## paints every other scene with — NOT a flat top-down draw). A fixed-seed perfect MAZE rendered as iso
## tiles: a flat GroundTileMapLayer floor under a y-sorted WallTileMapLayer of RAISED walls (their tile
## collision blocks you, exactly like the island edge), dressed with jungle trees. Five [BeastGate]s bar
## the solution corridor — Lion → Gorilla → Rhino → Bear → the Jungle King — each a raised wall until you
## beat its serious Skirmish bout; clear it and the wall drops so you pass. Lose and your health falls but
## the run continues (rest at Jade, retry). Beat the King → the Badge of Honour + town respect. The maze is
## generated in code (tune the seed / size); the look is all real tiles. See [[cradle-gym-jungle-ordeal]].
class_name JungleOrdeal
extends BaseLocation

# --- The iso tileset (Troy's, shared with every scene) ---------------
const TILE_SET : TileSet = preload("res://assets/iso/isometric_tileset.tres")
const TILE_SRC : int = 0
const FLOOR_TILE : Vector2i = Vector2i(2, 0)   # walkable iso floor (no collision)
const WALL_TILE : Vector2i = Vector2i(3, 0)    # raised iso wall (full-diamond collision — blocks the player)

const MAZE_W : int = 5        # maze cells wide/tall (the wall grid is 2N+1); iso tiles are big, so keep it tight
const MAZE_H : int = 5
const MAZE_SEED : int = 20260616

const GATE_SCENE : PackedScene = preload("res://levels/jungle_ordeal/beast_gate.tscn")
const DOOR_SCENE : PackedScene = preload("res://levels/door/door.tscn")
const TREE_SCENE : PackedScene = preload("res://levels/forest/tree.tscn")
## The Ordeal entrance lives on the SHORE now (Troy 2026-06-16), so the exit returns there — to the shore's
## "JungleEntry" door, which spawns the player right in front of it.
const SHORE_SCENE : String = "res://levels/shore/shore.tscn"

# Per-beast gate config (id → its profile, display name, hue), in escalating order + the King.
const BEASTS : Dictionary = {
	"lion": {"path": "res://puzzles/skirmish/beasts/beast_lion.tres", "label": "Maned Lion", "color": Color(0.82, 0.6, 0.26, 1.0)},
	"gorilla": {"path": "res://puzzles/skirmish/beasts/beast_gorilla.tres", "label": "Silverback Gorilla", "color": Color(0.42, 0.42, 0.48, 1.0)},
	"rhino": {"path": "res://puzzles/skirmish/beasts/beast_rhino.tres", "label": "Charging Rhino", "color": Color(0.58, 0.58, 0.54, 1.0)},
	"bear": {"path": "res://puzzles/skirmish/beasts/beast_bear.tres", "label": "Grizzled Bear", "color": Color(0.5, 0.34, 0.22, 1.0)},
	"king": {"path": "res://puzzles/skirmish/beasts/beast_jungle_king.tres", "label": "The Jungle King", "color": Color(0.72, 0.22, 0.26, 1.0)},
}

## Rapport every islander gains when you win the whole Ordeal — the town-wide respect (one-time; the
## defeat record is idempotent so it can't be farmed).
const TOWN_RESPECT : int = 12

var _gw : int = 0
var _gh : int = 0
var _wall : Array = []   # [_gw][_gh] bool — true = raised wall cell
var _ground : TileMapLayer
var _walls : TileMapLayer
var _ysort : Node2D


func _ready() -> void:

	mood_tint = Color(0.04, 0.16, 0.07, 0.16)   # a faint dark-green atmosphere over the whole scene
	_generate_maze()
	_build_scene()        # iso floor + raised walls + trees + gates + exit — BEFORE super spawns the player
	super._ready()        # BaseLocation spawns the player under our YSortNode2D, at the start (or gate, on return)
	_resolve_fight_return()


# --- Build the scene from real iso tiles -----------------------------
func _build_scene() -> void:

	# Flat floor layer — renders under everything, no collision.
	_ground = TileMapLayer.new()
	_ground.name = "GroundTileMapLayer"
	_ground.tile_set = TILE_SET
	_ground.modulate = Color(0.60, 0.84, 0.52)   # tint the light island floor to a jungle green (floor only)
	add_child(_ground)

	# Y-sort root: the raised walls + trees + gates + (the player, parented here by BaseLocation) all sort
	# together by depth, the way every other scene's YSortNode2D works.
	_ysort = Node2D.new()
	_ysort.name = "YSortNode2D"
	_ysort.y_sort_enabled = true
	add_child(_ysort)
	_walls = TileMapLayer.new()
	_walls.name = "WallTileMapLayer"
	_walls.tile_set = TILE_SET
	_walls.y_sort_enabled = true
	_walls.modulate = Color(0.58, 0.74, 0.46)   # mossy-green the raised walls (was island-orange)
	_ysort.add_child(_walls)

	var path : Array = _solution_path()
	var gate_cells : Dictionary = _gate_cells(path)   # id → cell
	var cell_is_gate : Dictionary = {}
	for id in gate_cells:
		cell_is_gate[gate_cells[id]] = String(id)

	# Floor on every cell; a raised wall on each wall cell, plus on any UN-BEATEN gate cell (the gate IS a
	# wall until you clear it). A tree dresses each plain wall cell (gate cells stay clear so the gate reads).
	for x in _gw:
		for y in _gh:
			var cell : Vector2i = Vector2i(x, y)
			_ground.set_cell(cell, TILE_SRC, FLOOR_TILE)
			var gate_id : String = String(cell_is_gate.get(cell, ""))
			var solid : bool = _wall[x][y]
			if gate_id != "" and not PlayerState.ordeal_defeated(gate_id):
				solid = true
			if solid:
				_walls.set_cell(cell, TILE_SRC, WALL_TILE)
			if _wall[x][y] and gate_id == "":
				var tree : Node2D = TREE_SCENE.instantiate()
				tree.position = _walls.map_to_local(cell)
				tree.set("size_variation", 0.6 + float((x * 7 + y * 3) % 5) * 0.12)
				_ysort.add_child(tree)

	for id in gate_cells:
		_spawn_gate(String(id), gate_cells[id], path)

	# Exit door + the player's start, at the maze's start cell.
	var start : Vector2i = path[0] if not path.is_empty() else Vector2i(1, 1)
	var start_world : Vector2 = _ground.map_to_local(start)
	pirate_spawn_position = start_world + Vector2(0, 18.0)
	var door : Node = DOOR_SCENE.instantiate()
	door.name = "ForestExit"
	door.position = start_world
	door.target_scene = SHORE_SCENE
	door.target_spawn_anchor = "JungleEntry"
	door.marker_label = "Back to Cradle Rock"
	door.spawn_offset = Vector2(0, 70.0)
	_ysort.add_child(door)


# The cells (id → cell) where each beast gate sits — spread along the solution corridor, King at the end.
func _gate_cells(path: Array) -> Dictionary:

	var out : Dictionary = {}
	if path.size() < 6:
		return out
	var order : Array = PlayerState.ORDEAL_BEASTS
	var fracs : Array = [0.26, 0.46, 0.64, 0.82]
	var used : Dictionary = {}
	for i in order.size():
		var idx : int = clampi(int(round(float(path.size()) * float(fracs[i]))), 2, path.size() - 2)
		while used.has(idx) and idx < path.size() - 2:
			idx += 1
		used[idx] = true
		out[String(order[i])] = path[idx]
	out[PlayerState.ORDEAL_KING] = path[path.size() - 1]
	return out


func _spawn_gate(id: String, cell: Vector2i, path: Array) -> void:

	var cfg : Dictionary = BEASTS[id]
	var g : BeastGate = GATE_SCENE.instantiate()
	g.name = "Gate_%s" % id
	g.beast_id = id
	g.beast_path = String(cfg["path"])
	g.beast_label = String(cfg["label"])
	g.beast_color = cfg["color"]
	g.position = _ground.map_to_local(cell)
	# Return on the APPROACH side (the corridor cell before this gate on the solution path).
	var idx : int = path.find(cell)
	var approach : Vector2i = path[idx - 1] if idx > 0 else cell
	g.spawn_offset = _ground.map_to_local(approach) - _ground.map_to_local(cell)
	_ysort.add_child(g)


# --- Maze generation (recursive backtracker, fixed seed → same labyrinth every run) ---
func _generate_maze() -> void:

	_gw = MAZE_W * 2 + 1
	_gh = MAZE_H * 2 + 1
	_wall = []
	for x in _gw:
		var col : Array = []
		for y in _gh:
			col.append(true)
		_wall.append(col)
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = MAZE_SEED
	var visited : Dictionary = {}
	var stack : Array = [Vector2i(0, 0)]
	visited[Vector2i(0, 0)] = true
	_wall[1][1] = false
	while not stack.is_empty():
		var c : Vector2i = stack[stack.size() - 1]
		var nbrs : Array = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n : Vector2i = c + d
			if n.x >= 0 and n.x < MAZE_W and n.y >= 0 and n.y < MAZE_H and not visited.has(n):
				nbrs.append(n)
		if nbrs.is_empty():
			stack.pop_back()
			continue
		var nn : Vector2i = nbrs[rng.randi() % nbrs.size()]
		visited[nn] = true
		var gc : Vector2i = Vector2i(c.x * 2 + 1, c.y * 2 + 1)
		var gn : Vector2i = Vector2i(nn.x * 2 + 1, nn.y * 2 + 1)
		_wall[(gc.x + gn.x) / 2][(gc.y + gn.y) / 2] = false
		_wall[gn.x][gn.y] = false
		stack.append(nn)


# BFS over open cells from the start node to the King node → the unique solution corridor (grid cells).
func _solution_path() -> Array:

	var start : Vector2i = Vector2i(1, 1)
	var goal : Vector2i = Vector2i(_gw - 2, _gh - 2)
	var came : Dictionary = {start: start}
	var q : Array = [start]
	while not q.is_empty():
		var c : Vector2i = q.pop_front()
		if c == goal:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n : Vector2i = c + d
			if n.x < 0 or n.x >= _gw or n.y < 0 or n.y >= _gh:
				continue
			if _wall[n.x][n.y] or came.has(n):
				continue
			came[n] = c
			q.append(n)
	var path : Array = []
	if not came.has(goal):
		return path
	var cur : Vector2i = goal
	while cur != start:
		path.append(cur)
		cur = came[cur]
	path.append(start)
	path.reverse()
	return path


# On return from a beast bout, record a WIN (the gate's wall then drops). A loss leaves it standing.
func _resolve_fight_return() -> void:

	var id : String = PlayerState.jungle_ordeal_pending
	if id.is_empty():
		return
	PlayerState.jungle_ordeal_pending = ""
	if PlayerState.last_skirmish_won and PlayerState.ordeal_mark_defeated(id):
		var label : String = String(BEASTS.get(id, {}).get("label", "the beast"))
		if id == PlayerState.ORDEAL_KING:
			PlayerState.log_event("The Jungle King falls! The Ordeal is won — the island salutes you.", Color(1.0, 0.86, 0.4))
			_grant_town_respect()
		else:
			PlayerState.log_event("%s is beaten — the way opens." % label, Color(0.7, 0.95, 0.6))


# Win the Ordeal → every islander gains rapport (the town-wide respect). One-time (gated by the idempotent
# defeat record above), so it can't be farmed.
func _grant_town_respect() -> void:

	for profile in NpcRegistry.all():
		PlayerState.add_affinity(profile.npc_name, TOWN_RESPECT)
